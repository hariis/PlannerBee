class Entry < ActiveRecord::Base
  include Schedulehelper
  acts_as_taggable
  belongs_to 	:user
  has_one 	:entry_status, :dependent => :destroy
  has_many :entry_bookmark_links, :dependent => :destroy
  has_many :bookmarks, :through => :entry_bookmark_links
  has_many :entry_feed_item_links, :dependent => :destroy
  has_many :feed_items, :through => :entry_feed_item_links
  
  #TODO Check if this should be before_validation
  before_create :set_remind_once_fields 
  #before_update :update_remind_once_fields 
  after_save  :flag_for_pickup 
  validates_presence_of :title, :message => "Please enter a title"
  validates_length_of   :notes, :maximum => 1000, :message => "Notes exceeded limit of 1000 characters", :if => Proc.new{|entry| entry.notes && entry.notes.size != 0}
  validates_each :notes ,:if => :is_not_blank, :on => :save do |record,attr,value| 
        if value.size > 1000 then
            record.errors.add(attr,"Notes exceeded limit of 1000 characters. Hmm")
        end
  end
  def is_not_blank    
	if self.notes && self.notes.size > 0 then          
          return true       
	end
	return false    
   
  end
  validates_each :start_dt_tm ,:if => :is_periodic, :on => :save do |record,attr,value| 
        if value > record.end_dt_tm then
            record.errors.add(attr,"Sorry, You can't go back in time, yet!")
        end
        if record.end_dt_tm - value < 86400 #A day atleast
           record.errors.add(attr,"The time span between the start date and the end date should be atleast a day")
        end
  end

  def is_periodic    
	if freq_type == 0 || freq_type == 1 || freq_type == 2 || freq_type == 3 ||
          freq_type == 4 || freq_type == 5 || freq_type == 11 || freq_type == 12 then
          
          return false       
	end
	return true      
  end

  #These filters are called after both creating new and updating existing entries
  def flag_for_pickup       
          if start_dt_tm && (TzTime.zone.utc_to_local(start_dt_tm).to_date <= TzTime.now.to_date ) && #Is this portion of the check necessary
              end_dt_tm && (TzTime.zone.utc_to_local(end_dt_tm).to_date >= TzTime.now.to_date) &&   #Is this portion of the check necessary
              Schedulehelper.IsEntryDueOn(self,TzTime.now.to_date) 
                    #On update, if the entry is already marked for due today, then skip this step
                  EntryStatus.flag_entry(self)  if entry_status == nil || !is_due_today
                  #Update account_detail if not already
                  user = self.user
                   if !user.are_tasks_flagged_today                        
                        user.account_detail.update_attribute(:tasks_last_flagged_on, TzTime.now.utc)
                   end     
                  
          elsif entry_status && is_due_today     #Here 'is_due_today'  is returning the status as it was before the update since it is merely a flag 
                #This case is to catch while the entry is being updated and if the entry's frequency schedule changed
                #in such a way where it is not due to day anymore
                EntryStatus.remove_flag(self)
          elsif entry_status == nil
                    #Entry either starts in the future or not due today       
                   #Create a dummy record so that if the entry is ended right away, it can be recorded
                   self.entry_status =  EntryStatus.new( :user_id => self.user_id)              
          end
  end
  
  def formatted_title
    return title.capitalize
  end
  #Find all parent entries
  #If the selected parent entry has expired, pull it out explicitly
  def findParententries(givendate,userid)
	  #entries = Entry.find(:all, :conditions => ["user_id=? and entries.end_dt_tm >= ? ", userid, givendate])
	  entries = Entry.find(:all, :include => [:entry_status], :conditions => ["entries.user_id= ? and entry_statuses.ended = 0", userid])
	      #Also pull out the selected child entries if not already 
	      #Get already selected child entries
	      selected_children = find_selected_childentries(userid)

	  @otherentries = []
	  foundCurrentParent = false
	  entries.each do |e|
	    if e.id != id && !isItemInList(selected_children,e) && e[:type] != 'Goal'  then
	      @otherentries << e
	      if e.id == parent_id then
		foundCurrentParent = true
	      end
	    end    
	  end
	  #Even if the stored parent task has expired, pull it out for display
	  if foundCurrentParent == false then
	    parent = Entry.find(:first, :conditions => ["user_id =? and entries.id = ?", userid, parent_id])
	    @otherentries << parent if parent != nil
	  end
	  return @otherentries
  end
  def isAncestor(ancestors,entry)
    ancestors.each do |a|
       return true if a == entry
    end
    return false
  end
  alias :isItemInList :isAncestor
  def self.isAncestor(ancestors,entry)
    ancestors.each do |a|
       return true if a == entry
    end
    return false
  end
  #Find all possible children entries - This is done by excluding self and ancestors
  def find_child_entries(givendate,userid)
	  #@entries = Entry.find(:all, :conditions => ["user_id=? and entries.end_dt_tm >= ? ", userid, givendate])
	  @entries = Entry.find(:all, :include => [:entry_status], :conditions => ["entries.user_id= ? and entry_statuses.ended = 0", userid])
	  @otherChildentries = []

	  #Grab all the ancestors of this entry
	  @ancestors = []    
	  parentid = parent_id 
	  while parentid != nil
	      @ancestors << parentid
	      parent = Entry.find_by_id(parentid)
	      parentid = parent.parent_id
	  end

	  #Store all entries except self and ancestors
	  @entries.each do |e|
	    if e.id != id && !isAncestor(@ancestors,e.id)  && e[:type] != 'Goal' then
	      @otherChildentries << e
	    end 
	    #@otherChildentries << e unless e.id == id || isAncestor(@ancestors)
    end
    #Also make sure  the selected child entries are present in the list if not already 
    #Get already selected child entries
    selected_children = find_selected_childentries(userid)
    selected_children.each {|ce|
            if !isItemInList(@otherChildentries,ce) then
                    @otherChildentries << ce
            end
    }
    return @otherChildentries
  end
  #Find selected child tasks
  def find_selected_childentries(userid)
    @entries = Entry.find(:all, :conditions => ["user_id=? and parent_id = ? ", userid, self.id])
    
    
    return @entries
  end
  #Same as above except the parent is provided - Used when parent is just being selected 
  def find_child_entries_for(givendate,userid,parent)
    @entries = Entry.find_all_current_entries(givendate,userid)
    @otherChildentries = []
    
    @ancestors = []
    
    if parent != 0 then 
      parentid = parent
      while parentid != nil
          @ancestors << parentid
          parent = Entry.find_by_id(parentid)
          parentid = parent.parent_id
      end
    end
    @entries.each do |e|
      if e.id != id && !isAncestor(@ancestors,e.id) then
        @otherChildentries << e
      end 
      #@otherChildentries << e unless e.id == id || isAncestor(@ancestors)
    end
    
    return @otherChildentries
  end
  def self.find_child_entries(givendate,userid,parent)
        @entries = Entry.find_all_current_entries(givendate,userid)
        @otherChildentries = []

        @ancestors = []

        if parent != 0 then 
          parentid = parent
          while parentid != nil
              @ancestors << parentid
              parent = Entry.find_by_id(parentid)
              parentid = parent.parent_id
          end
        end
        @entries.each do |e|
          if !self.isAncestor(@ancestors,e.id) then
            @otherChildentries << e
          end          
        end
        return @otherChildentries
  end
  def self.find_filtered_child_entries(givendate,userid,parent,taglist)
        @filtered_entries = []
        if taglist != nil then
                    tasks = Entry.find_tagged_with_by_user(taglist,User.find_by_id(userid))                    
                    tasks.each{|task| @filtered_entries << task if (task.end_dt_tm  >= givendate || task.entry_status.overdue_status?)}                  
         end  
        @otherChildentries = []
        @ancestors = []

        if parent != 0 then 
          parentid = parent
          while parentid != nil
              @ancestors << parentid
              parent = Entry.find_by_id(parentid)
              parentid = parent.parent_id
          end
        end
        @filtered_entries.each do |e|
          if !self.isAncestor(@ancestors,e.id) then
            @otherChildentries << e
          end          
        end
        return @otherChildentries
  end
  def is_due_today
        return entry_status.due_today? if entry_status 
	 return false
  end
  def is_overdue_today
	 return entry_status.overdue_status? if entry_status 
	 return false
  end
  #Find all the entries - Does it make sense?
  def self.find_all_current_entries(givendate,userid)
        #Return all entries that have not ended as of the given date
	user = User.find_by_id(userid)
        #user.entries.find(:all, :conditions => ["end_dt_tm >= ? ", givendate])
        #the problem with the below query is if an entry does not have its overdue_reminder flag set and is expired, but it is still pending, it won't get picked up
        #user.entries.find(:all, :include => [:entry_status], :conditions => ["end_dt_tm >= ? or entry_statuses.overdue_status = 1", givendate])
        #following query will pickup past, present and future tasks that simply are not completed yet
        entries = user.entries.find(:all, :include => [:entry_status], :conditions => ["entry_statuses.ended = 0"])
	 @onlyentries = []	 
	  entries.each {  |e| 	@onlyentries << e    if e[:type] != 'Goal'  }
	  return @onlyentries
  end
  
  def self.update_attribute(name,value)
    update_attribute(name,value)
  end
  #Get added and modified entries
  def self.find_added_today(userid)
	user = User.find_by_id(userid)
	user.entries.find(:all, :conditions => ["updated_at > ?", TzTime.now.at_beginning_of_day.utc])
  end
  def self.find_completed_today(userid)
	user = User.find_by_id(userid)
	user.entry_statuses.find(:all, :conditions => ["last_marked = ?", TzTime.now.utc.to_date])
  end
  #Do this search in EntryStatuses table and get the entry ids and grab those entries from the entry table
  def self.find_todays_entries(userid)
    user = User.find_by_id(userid)
    user.entry_statuses.find(:all, :conditions => ["due_today = 1"] ,:include => [:entry], :order => "position asc" )
  end
  
  def self.find_overdue_entries(userid)
    user = User.find_by_id(userid)
    #user.entry_statuses.find(:all, :conditions => ["overdue_status = 1 and ended = 0"] ,:include => [:entry], :order => "overdue_position asc")
    user.entry_statuses.find(:all, :conditions => ["overdue_status = 1"] ,:include => [:entry], :order => "overdue_position asc")
  end
  def self.find_latest10_entries
    marked_entries = EntryStatus.find(:all, :include => [:entry], :conditions => ['last_marked != false and entries.public = 1'] , :order => "last_marked desc", :limit => 10)
    #There could be undone entries included as well - so remove them from the list
    latest10_completed_entries = []
    marked_entries.each {|e| latest10_completed_entries << e if e.completion_history["#{e.last_marked.to_date}"] != ""}
    return latest10_completed_entries
  end   
   def self.find_entries_for(userid, future_date)
        #This gets all possible entries  
        user = User.find_by_id(userid)
        future_dt = Date.parse(future_date)
        future_dt_tm = TzTime.at(future_dt).tomorrow.ago(60).utc  #Moving the time to 23:59
        @qualentries = user.entries.find(:all, :conditions => [ "? BETWEEN start_dt_tm AND end_dt_tm", future_dt_tm])

        @selectedEntries =[]  
        @qualentries.each  do |entry|
                next if  entry.entry_status && entry.entry_status.ended?
                @selectedEntries<< entry if Schedulehelper.IsEntryDueOn(entry,TzTime.at(future_dt).to_date)
        end      
        return @selectedEntries
   end     
 def self.find_unscheduled_entries(userid)
        user = User.find_by_id(userid)
        user.entries.find(:all, :conditions => [ "freq_type = 0"])
 end
  def self.find_next_todo_entries(userid)
        user = User.find_by_id(userid)
        user.entries.find(:all, :conditions => [ "freq_type = 0"])
 end
   def self.find_someday_entries(userid)
        user = User.find_by_id(userid)
        user.entries.find(:all, :conditions => [ "freq_type = 12"])
 end
  #Helpers for Flagging entries for Today and Overdue As of Today for ALL items
  #This should run at midnight for every time zone TODO
  #This gets all entries that have started but may or may not have ended that needs overdue reminder  
  def self.find_started_entries_for(user)		
#      user.entries.find(:all, :conditions => [ "start_dt <= ? and overdue_reminder = 1 ",  TzTime.now.to_date],
#        :select => "entries.id,entries.freq_type,entries.end_dt,
#        entry_statuses.id, entry_statuses.times_scheduled, entry_statuses.times_done,entry_statuses.times_donelate,
#        entry_statuses.times_skipped,entry_statuses.overdue_status,entry_statuses.due_today,
#        entry_statuses.ended, entry_statuses.position, entry_statuses.overdue_position",
#        :joins => "left outer join entry_statuses on entry_statuses.entry_id = entries.id")
    user.entries.find(:all, :conditions => [ "start_dt_tm <= ?",  TzTime.now.utc],
        :include => [:entry_status])
  end
  #This gets all possible entries  
  def self.find_live_entries_for(user)
        #WARNING: Keep in mind freq_types 0,12 when making changes to the query
        #We are moving to today at 23:59 so that all entries due today at any time are captured
        #One time entries will be marked with end time of 23:59
        #Periodic entries will be forced to have a span of atleast a day
        
#        user.entries.find(:all, :conditions => [ "? BETWEEN start_dt AND end_dt",  TzTime.now.to_date],
#        :select => "entries.id,entries.start_dt, entries.end_dt,entries.freq_type, entries.freq_interval,
#        entries.freq_interval_qual,entries.user_id,entries.priority,
#        entry_statuses.id, entry_statuses.times_scheduled, entry_statuses.due_today, entry_statuses.position,
#        entry_statuses.overdue_position,entry_statuses.last_scheduled, entry_statuses.completion_history,
#        entry_statuses.ended",
#        :joins => "left outer join entry_statuses on entry_statuses.entry_id = entries.id")
        user.entries.find(:all, :conditions => [ "? BETWEEN start_dt_tm AND end_dt_tm",  TzTime.now.at_beginning_of_day.tomorrow.ago(60).utc],
               :include => [:entry_status])
  end
  def self.flag_user_data(user)
        begin
                if !user.are_tasks_flagged_today      
                    FlagTodaysEntriesFor(user)
                    user.account_detail.update_attribute(:tasks_last_flagged_on, TzTime.now.utc)                    
                end
                return true
        rescue=> err
                logger.fatal("Caught exception in entry's flag_user_data")
                logger.fatal(err)
                return false
        end
  end
  def self.FlagTodaysEntriesFor(user)
            #Set due_today and overdue_status flags for all entries to 0
            user.entry_statuses.find(:all).each{|record| record.update_attributes( :due_today => 0,:overdue_status => 0) }
            @qualentries = find_live_entries_for(user)		
            @qualentries.each  do |entry|          
                EntryStatus.flag_entry(entry) if entry.freq_type != 0 
                #if Schedulehelper.IsEntryDueOn(entry,TzTime.now.to_date)
                #We want to flag_entry even if it is not due today, because, there  may be a need to backfill scheduled dates
            end  
            #Calculate overdue items
            FlagOverdueItemsFor(user)      
  end
  def self.FlagTodaysEntries()
      #Flag by each user, since their timezones are different      
      all_users = User.find(:all, :include => [:account_detail])

#      all_users = User.find(:all, :select => "users.time_zone, account_details.id, account_details.user_id, account_details.tasks_last_flagged_on",
#        :joins => "left outer join account_details on account_details.user_id = users.id")
      for user in all_users
        TzTime.zone =TimeZone[user.time_zone]
        last_flagged = user.account_detail.tasks_last_flagged_on
        next if last_flagged && TzTime.zone.utc_to_local(last_flagged).to_date == TzTime.now.to_date          
        FlagTodaysEntriesFor(user)
        #Mark a flag that this user has been flagged for the day    
        user.account_detail.update_attribute(:tasks_last_flagged_on, TzTime.now.utc)
      end      
  end
  def self.FlagOverdueItemsFor(user)
      @qualentries = find_started_entries_for(user)

      @qualentries.each  do |entry|
               next if entry.freq_type == 0 || entry.entry_status == nil
              #Calculate the overdue_count based on existing data for the entry
              entryStatus = entry.entry_status  
              
              n = entryStatus.times_scheduled.to_i - (entryStatus.times_done.to_i + entryStatus.times_donelate.to_i + entryStatus.times_skipped.to_i)
              if n > 1  #Definitely overdue
                    entryStatus.update_attributes(:overdue_status => 1, :overdue_position => entryStatus.position) if entry.overdue_reminder == true
              end
              if n == 1  && !entryStatus.due_today? #Contingent upon whether the task is due today
                    entryStatus.update_attributes(:overdue_status => 1, :overdue_position => entryStatus.position) if entry.overdue_reminder == true
              end
               #This is now done as and when an entry is marked done or skipped
		#Mark as complete the expired and completed tasks  
#              if n == 0 &&  TzTime.now.utc > entry.end_dt_tm #No dues and task is past end date, so mark as complete and set flag
#                    entryStatus.update_attributes(:ended => 1, :overdue_position => 0, :position => 0) 
#              end 
      end
  end   
  
end

 class Goal < Entry
      def self.find_pending(givendate,userid)
            Goal.find(:all, :include => [:entry_status], :conditions => ["entries.user_id= ? and entry_statuses.ended = 0", userid])
      end
 end