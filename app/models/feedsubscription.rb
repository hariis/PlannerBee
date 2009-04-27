class Feedsubscription < ActiveRecord::Base
	
  include Schedulehelper
  acts_as_taggable
  belongs_to :user
  belongs_to :feed
  has_many :saved_feed_items, :dependent => :destroy
  has_many :feed_items, :through => :saved_feed_items, :uniq => true
  before_create :set_remind_once_fields 
  after_save  :flag_for_pickup 
  
  validates_each :start_dt_tm ,:if => :is_not_periodic, :on => :save do |record,attr,value| 
        if value > record.end_dt_tm then
            record.errors.add(attr,"Sorry, You can't go back in time, yet!")
        elsif record.end_dt_tm - value < 86400 #A day atleast
           record.errors.add(attr,"The time span between the start date and end date should be atleast a day")        
        end        
  end 
  def is_not_periodic    
	if  self.freq_type == 0 then          
          return false       
	end
	return true    
   
  end
  attr_reader :recently_read_count, :recently_unread_count
  
  def recently_read_count
	counter = 0

	19.downto(0) do |index| 
		if viewstatus[index] == 1  then
			counter = counter + 1               
		end
	end
	return counter
  end
   def recently_unread_count
          counter = 0

	19.downto(0) do |index| 
		if viewstatus[index] == 0  then
			counter = counter + 1               
		end
	end
	return counter
   end
  #These filters are called after both create and edit
    def flag_for_pickup
            if start_dt_tm && (TzTime.zone.utc_to_local(start_dt_tm).to_date <= TzTime.now.to_date) &&       
              end_dt_tm && (TzTime.zone.utc_to_local(end_dt_tm).to_date >= TzTime.now.to_date) && 
              Schedulehelper.IsEntryDueOn(self,TzTime.now.to_date) 
                flag_entry if !due_today?  
                #Update account_detail if not already 
                #This can happen if there was none due when the day began but during the day, due to an edit,
                #a resource became due today
                  user = self.user
                   if !user.are_feeds_flagged_today                        
                        user.account_detail.update_attribute(:feeds_last_flagged_on, TzTime.now.utc)
                   end    
            elsif due_today?  
              remove_flag              
            end
    end
    def are_all_recent_items_read
            #First, find how many feed items are there
            recent_items_count = self.feed.feed_items.size
            if recent_items_count == 1 
                 if viewstatus == 1
                       return true
                 else
                        return false
                 end
            end
            recent_items_count-1.downto(0) do |index| 
		if viewstatus[index] == 0  then
			return false              
		end
            end
            return true
    end
    def flag_entry
        update_attribute(:due_today , 1) if !self.due_today?            
    end
    def remove_flag
        update_attribute(:due_today , 0) if self.due_today?  
    end
	#Get added and modified entries
	def self.find_added_today(userid)
		user = User.find_by_id(userid)
		user.feedsubscriptions.find(:all, :conditions => ["created_at  >= ?", TzTime.now.at_beginning_of_day.utc])
	end
	
	def self.find_unread_and_read_items(subscription)
		feed = Feed.find_by_id(subscription.feed_id)
		feeditems = feed.feed_items.find(:all, :order => 'published DESC')

		#Apply the viewstatus and filter the items
		readitems = []
		unreaditems = []
		index = 0
		for item in feeditems           
			if subscription.viewstatus[index] == 0  then
				unreaditems << item
			else
				readitems << item
			end           
			index = index + 1    
		end

		return unreaditems, readitems
	end
	def find_unread_items
		feed = Feed.find_by_id(feed_id)
		feeditems = feed.feed_items.find(:all, :order => 'published DESC', :limit => 20)

		#Apply the viewstatus and filter the items
		todisplayitems = []      
		index = 0
		for item in feeditems           
			if viewstatus[index] == 0  then
				todisplayitems << item                  
			end           
			index = index + 1    
		end

		return todisplayitems
	end
       
	def find_read_items
		feed = Feed.find_by_id(feed_id)
		feeditems = feed.feed_items.find(:all, :order => 'published DESC', :limit => 20)

		#Apply the viewstatus and filter the items
		todisplayitems = []      
		index = 0
		for item in feeditems           
			if viewstatus[index] == 1  then
				todisplayitems << item                  
			end           
			index = index + 1    
		end

		return todisplayitems
	end
        
   def self.find_read_today(userid)
        user = User.find_by_id(userid)
         #viewstatus = 0 means nothing read , Any other value indicates, something has been read
        user.feedsubscriptions.find(:all, :conditions => ["viewstatus != 0"] ,:include => [:feed])      	
   end
    def self.find_todays_feeds(userid)
        user = User.find_by_id(userid)
        user.feedsubscriptions.find(:all, :conditions => ["due_today = 1"] ,:include => [:feed])      	
   end
    def self.findallentries(givendate,userid)
      Feedsubscription.find(:all, :conditions => ["user_id=? and end_dt_tm >= ? and unread > 0", userid, givendate])
    end
  
  #use this method to gets feeds due for any particular day
  def self.find_entries_for(userid, future_date)
      user = User.find_by_id(userid)
      #future_dt will be at 00:00
      future_dt = Date.parse(future_date)
      future_dt_tm = TzTime.at(future_dt).tomorrow.ago(60).utc  #Moving the time to 23:59
      @qualentries = user.feedsubscriptions.find(:all, :conditions => ["? BETWEEN start_dt_tm AND end_dt_tm", future_dt_tm] ,:include => [:feed])
      @selectedEntries =[]  
      @qualentries.each  do |entry|
              @selectedEntries<< entry if Schedulehelper.IsEntryDueOn(entry,future_dt)
      end      
      return @selectedEntries         
  end
  
 def self.flag_user_data(user)
        begin
                if !user.are_feeds_flagged_today      
                    FlagTodaysEntriesFor(user)
                    user.account_detail.update_attribute(:feeds_last_flagged_on, TzTime.now.utc)                    
                end
                return true
        rescue => err
                logger.fatal("Caught exception in feed subscription's flag_user_data")
                logger.fatal(err)
                return false
        end
  end
  def self.find_live_entries_for(user)
    #We are moving to today at 23:59 so that all entries due today at any time are captured
    #One time entries will be marked with end time of 23:59
    #Periodic entries will be forced to have a span of atleast a day
    user.feedsubscriptions.find(:all, :conditions => ["? BETWEEN start_dt_tm AND end_dt_tm", TzTime.now.at_beginning_of_day.tomorrow.ago(60).utc])
  end
  def self.FlagTodaysEntriesFor(user)
        #Set all due_today for all entries to 0
        user.feedsubscriptions.find(:all).each{|record| record.update_attribute(:due_today, 0)}	
        @qualentries = find_live_entries_for(user)
        @qualentries.each  do |feed|
            feed.flag_entry   if Schedulehelper.IsEntryDueOn(feed,TzTime.now.to_date)      
        end 
  end
  def self.FlagTodaysEntries()
        
         #Flag by each user, since their timezones are different      
      all_users = User.find(:all, :include => [:account_detail])

#      all_users = User.find(:all, :select => "users.time_zone, account_details.id, account_details.user_id, account_details.tasks_last_flagged_on",
#        :joins => "left outer join account_details on account_details.user_id = users.id")
      for user in all_users
        TzTime.zone =TimeZone[user.time_zone]
        last_flagged = user.account_detail.feeds_last_flagged_on
        next if last_flagged && TzTime.zone.utc_to_local(last_flagged).to_date == TzTime.now.to_date          
        FlagTodaysEntriesFor(user)
        user.account_detail.update_attribute(:feeds_last_flagged_on, TzTime.now.utc)
      end      
        		
end

def mark_read(item_id)
          viewitemstatus = 0b1
          feeditem = FeedItem.find_by_id(item_id)
          currentDisplayfeeditems = FeedItem.find(:all, :conditions => ["feed_id = ?", feeditem.feed_id], :order => 'published DESC', :limit => 20)
          
          #Among the list of feeditems, find the index of this item marked read
          index = 0
          for item in currentDisplayfeeditems 
               index = index + 1
                if item.id == feeditem.id then
                    @vieweditem = item                  
                    break
                else                 
                    viewitemstatus = viewitemstatus << 1
                end
          end
          #flash[:notice]="You read Article #{index} on the list"
          #Store it in the Feedsubscription row
        
          unread = self.unread - 1 if self.unread > 0
          viewitemstatus = self.viewstatus + viewitemstatus
          update_attributes(:viewstatus => viewitemstatus, :unread => unread )
            
          
end
def mark_all_read
    feed_items_stored = self.feed.feed_items.size   
    feed_items_stored = feed_items_stored > 20 ? 20 : feed_items_stored        
     #We need to set only as many bits as there are feed items currently we have stored for that feed
     #20  - feed_items_stored gives the bits to shift
      viewitemstatus  =   1048575 >> (20  - feed_items_stored)   #1048575 - All 20 bits set to 1 - Signifies all items read
      update_attributes(:viewstatus => viewitemstatus, :unread => 0)
end
   FREQ_TYPES = [
      ["0", "None"],
      ["6", "Daily"],
      ["7", "Weekly"],
      ["8", "Monthly_by_Date"],
      ["9", "Monthly_by_Day"],
      ["10", "Yearly"]
      
      ]      
end


