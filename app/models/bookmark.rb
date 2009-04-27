class Bookmark < ActiveRecord::Base
  include Schedulehelper
  acts_as_taggable
  belongs_to :user  
  belongs_to :resource
  
  has_many :entry_bookmark_links, :dependent => :destroy
  has_many :entries, :through => :entry_bookmark_links
  has_one  :bookmark_status, :dependent =>  :destroy
  
  before_create :set_remind_once_fields 
  #before_update :update_remind_once_fields
  after_save  :flag_for_pickup 
  
  attr_accessor :emails, :comments    
  
  validates_each :start_dt_tm ,:if => :is_periodic, :on => :save do |record,attr,value| 
        if value > record.end_dt_tm then
            record.errors.add(attr,"Sorry, You can't go back in time, yet!")
        end
        if record.end_dt_tm - value < 86400 #A day atleast
           record.errors.add(attr,"The time span between the start date and end date should be atleast a day")
        end
  end
  
  def is_periodic
    
      if self.freq_type == 0 || self.freq_type == 1 || self.freq_type == 2 || self.freq_type == 3 ||
          self.freq_type == 4 || self.freq_type == 5 || self.freq_type == 11 || freq_type == 12 then
          
          return false       
     end
     return true
    
  end
  #These filters are called after both create and edit
  def flag_for_pickup
          if start_dt_tm && (TzTime.zone.utc_to_local(start_dt_tm).to_date <= TzTime.now.to_date ) &&
              end_dt_tm && (TzTime.zone.utc_to_local(end_dt_tm).to_date >= TzTime.now.to_date) &&
              Schedulehelper.IsEntryDueOn(self,TzTime.now.to_date) 
                 #On update, if the entry is already marked for due today, then skip this step
                  BookmarkStatus.flag_entry(self)  if bookmark_status == nil || !is_due_today
                  #Update account_detail if not already
                  user = self.user
                   if !user.are_bookmarks_flagged_today                        
                        user.account_detail.update_attribute(:bookmarks_last_flagged_ons, TzTime.now.utc)
                   end  
           elsif bookmark_status && is_due_today
                #This case is to catch while the entry is being "updated" and if the entry's frequency schedule changed
                #in such a way where it is not due today anymore
                BookmarkStatus.remove_flag(self)
           elsif bookmark_status == nil
                #Entry either starts in the future or not due today
                #Create a dummy record so that if the entry is ended right away, it can be recorded
                self.bookmark_status = BookmarkStatus.new( :user_id => user_id, :bookmark_id => self.id)               
          end
  end
  #TODO Room to refactor the two queries into one
  def self.find_todays_entries(userid)
	user = User.find_by_id(userid)
	user.bookmark_statuses.find(:all, :conditions => ["due_today = 1"] ,:include => [:bookmark], :order => "position asc" )
  end
  
  def self.find_overdue_entries(userid)
	user = User.find_by_id(userid)
       user.bookmark_statuses.find(:all, :conditions => ["overdue_status = 1 and completed = 0"] ,:include => [:bookmark], :order => "overdue_position asc" )      
  end
  def self.find_added_today(userid)
	user = User.find_by_id(userid)
	user.bookmarks.find(:all, :conditions => ["updated_at >= ?", TzTime.now.at_beginning_of_day.utc])
  end
  def self.find_completed_today(userid)
	user = User.find_by_id(userid)
        user.bookmark_statuses.find(:all, :conditions => ["last_viewed >= ?", TzTime.now.at_beginning_of_day.utc])
  end
  def self.findallentries(givendate,userid)
    Bookmark.find(:all, :conditions => ["user_id=? and end_dt_tm >= ?", userid, givendate])
  end
  def self.find_latest10_entries
    BookmarkStatus.find(:all, :conditions => ["last_viewed != false and bookmarks.public = 1"] ,:include => [:bookmark], :order => "last_viewed desc", :limit => 10)
  end 
  def is_due_today      
     return bookmark_status.due_today? if bookmark_status
     return false
  end
  def is_overdue_today
      return bookmark_status.overdue_status? if bookmark_status 
      return false
  end
  #Find all parent entries
  #If the selected parent entry has expired, pull it out explicitly
  def find_parent_tasks(userid)
    user = User.find_by_id(userid)
    current_entries = user.entries.find(:all, :conditions => ["entries.end_dt_tm >= ? ", TzTime.now.utc])
	
    parent_entries = []
    current_entries.collect {|ce| parent_entries << ce }
    self.entries.each do |e|
        if !isItemInList(current_entries, e)
                parent_entries << e
        end		
    end
    
    return parent_entries
  end
  def self.find_entries_for(userid, future_date)
        #This gets all possible entries  
        user = User.find_by_id(userid)
        #future_dt will be at 00:00
        future_dt = Date.parse(future_date)
        future_dt_tm = TzTime.at(future_dt).tomorrow.ago(60).utc  #Moving the time to 23:59
        @qualentries = user.bookmarks.find(:all, :conditions => [ "? BETWEEN start_dt_tm AND end_dt_tm", future_dt_tm])

        @selectedEntries =[]  
        @qualentries.each  do |bookmark|
                next if  bookmark.bookmark_status && bookmark.bookmark_status.completed?
                @selectedEntries << bookmark if Schedulehelper.IsEntryDueOn(bookmark,future_dt)
        end      
        return @selectedEntries
   end
   def self.find_unscheduled_entries(userid)
        user = User.find_by_id(userid)        
        user.bookmarks.find(:all, :conditions => [ "freq_type = 0"])   
   end
   def self.find_next_todo_bookmarks(userid)
        user = User.find_by_id(userid)
        user.bookmarks.find(:all, :conditions => [ "freq_type = 0"])
 end
   def self.find_someday_bookmarks(userid)
        user = User.find_by_id(userid)
        user.bookmarks.find(:all, :conditions => [ "freq_type = 12"])
 end
   def self.flag_user_data(user)
        begin
                 if !user.are_bookmarks_flagged_today      
                    FlagTodaysEntriesFor(user)
                    user.account_detail.update_attribute(:bookmarks_last_flagged_on, TzTime.now.utc)                    
                end
                return true
        rescue => err
                logger.fatal("Caught exception in bookmark's flag_user_data")
                logger.fatal(err)
                return false
        end
  end
  def self.find_live_entries_for(user)
    user.bookmarks.find(:all, :conditions => ["? BETWEEN start_dt_tm AND end_dt_tm", TzTime.now.at_beginning_of_day.tomorrow.ago(60).utc], 
                                            :include => [:bookmark_status])
  end
  #This gets all bookmarks that have started but may or may not have been completed 
  def self.find_started_entries_for(user)		
          user.bookmarks.find(:all, :conditions => ["start_dt_tm <= ? ",  TzTime.now.utc], 
                                            :include => [:bookmark_status])
  end
  def self.FlagTodaysEntriesFor(user)
        user.bookmark_statuses.find(:all).each{|record| record.update_attributes(:due_today => 0, :overdue_status => 0)}	
        @qualentries = find_live_entries_for(user)
          @qualentries.each  do |bookmark|
                next if  bookmark.bookmark_status && bookmark.bookmark_status.completed?             
                BookmarkStatus.flag_entry(bookmark) if bookmark.freq_type != 0 #if Schedulehelper.IsEntryDueOn(bookmark,TzTime.now.to_date)	          
          end
          #Calculate overdue items
         FlagOverdueItemsFor(user) 
  end
  def self.FlagTodaysEntries()
          #Flag by each user, since their timezones are different      
      all_users = User.find(:all, :include => [:account_detail])

      for user in all_users
        TzTime.zone =TimeZone[user.time_zone]
        last_flagged = user.account_detail.bookmarks_last_flagged_on
        next if last_flagged && TzTime.zone.utc_to_local(last_flagged).to_date == TzTime.now.to_date          
        FlagTodaysEntriesFor(user)
        user.account_detail.update_attribute(:bookmarks_last_flagged_on, TzTime.now.utc)
      end          
          	
  end
  def self.FlagOverdueItemsFor(user)
    
                @qualentries = find_started_entries_for(user)

		@qualentries.each  do |bookmark|
                         next if bookmark.freq_type == 0 || bookmark.bookmark_status == nil #If an item has never been scheduled, it will not be flagged overdue
			#Calculate the overdue_count based on existing data for the entry
			bkStatus = bookmark.bookmark_status
					
                        #Get the due_counter
                        n = bkStatus.due_counter		  

                        if n > 1
                              bkStatus.update_attribute(:overdue_status, 1) 
                        end
                        if n == 1 && !bookmark.is_due_today
                              bkStatus.update_attribute(:overdue_status, 1) 
                        end
                        if n == 0 &&  TzTime.now.utc > bookmark.end_dt_tm #No dues and task is past end date, so mark as complete and set flag
                              bkStatus.update_attributes(:completed => 1, :overdue_position => 0, :position => 0) 
                        end
			
		end
  end       
	
	def share_bookmark(sent_by)
		BookmarkNotifier.deliver_send_emails(self,sent_by)
	end
  private
  def isItemInList(list, item)
		if list != nil then
		  list.each do |listitem|
			return true if listitem.id == item.id
		  end
		end
		return false
	end
end
 