class BookmarkStatus < ActiveRecord::Base
	belongs_to :user
	belongs_to :bookmark	
	serialize :completion_history
	def markDone 
		
		completed_dates = BookmarkStatus.deepcopy(completion_history)
                completed_dates = {} if completion_history == nil
                completed_dates["#{TzTime.now.to_date}"] = "#{TzTime.now.to_date}"

		self.update_attributes(:last_viewed => TzTime.now.utc, :due_counter => due_counter - 1, :completion_history => completed_dates) 	  
	end
	def mark_overdue_done	  
		
                #Located the pending dates and mark as skipped
                completed_dates = BookmarkStatus.deepcopy(completion_history)
                completed_dates = {}	if completion_history == nil
                completed_dates.each_pair do |key, value|                     
                       completed_dates[key] = "#{TzTime.now.to_date}"  if value == ""                        
                 end
                
          
                #decrement the due_counter
                to_reduce = 0                
                if due_today?
                  to_reduce = due_counter - 1
                else
                  to_reduce = due_counter
                end              
                
		self.update_attributes(:last_viewed => TzTime.now.utc, :due_counter => due_counter - to_reduce, :completion_history => completed_dates ) 	  
	end
	def self.flag_entry(bookmark)
		
		bkStatus = bookmark.bookmark_status
                
		if bkStatus != nil
                        all_dates = Schedulehelper.GetDatesUpToToday(bookmark)
                        return if all_dates.length == 0  #Not due yet
                        
                        completed_dates = deepcopy(bkStatus.completion_history)
                        completed_dates = {} if bkStatus.completion_history == nil    
                        latest_scheduled_date = completed_dates.size > 0 ? completed_dates.sort.last[0] : nil                        
                        #Go through each element and add to the history only those
                        # that are not already present AND are past the latest date in the history
                        #  This latter condition is to accomodate the case when the freq type has changed.
                        #Here, we want only those dates from the list of scheduled dates(all_dates) as per the new frequency_type
                        # that are past the latest date in the history which is as per the old freq_types  
                       #Back fill the missing scheduled dates
                        for date in all_dates
                            completed_dates["#{date}"] = "" if completed_dates.length == 0 ||
                                                                                        (!completed_dates.has_key?(date) && ( latest_scheduled_date != nil && date > Date.parse(latest_scheduled_date) ) )
                        end                               

                        if completed_dates.has_key?("#{TzTime.now.to_date}")
                               due_today_status = true
                        else
                                #Just backfilling past scheduled dates                                
                                due_today_status = false
                        end
                        pending_count =  0
                        completed_dates.each_pair {|key,value| pending_count += 1 if value == ""}
                       
                        assign_position = bkStatus.position == 0 ? bookmark.priority : bkStatus.position
			# The if condition is so that during update operation, the status record doesn't get updated again
			bkStatus.update_attributes(:due_counter => pending_count, :due_today => due_today_status, :completion_history => completed_dates, :position => assign_position) 
		else
                        completed_dates = {}                       
                        completed_dates["#{TzTime.now.to_date}"] = "" if !completed_dates.has_key?("#{TzTime.now.to_date}")
                        
			bkStatus = BookmarkStatus.new(:due_counter => 1, :due_today => true, :user_id => bookmark.user_id, :completion_history => completed_dates, :position => bookmark.priority)
			bookmark.bookmark_status  = bkStatus
		end

		#if (entryStatus.last_scheduled_dt == nil || (entryStatus.last_scheduled_dt != nil && entryStatus.last_scheduled_dt !=  TzTime.now.to_date) ) then
		#  entryStatus.update_attributes(:last_scheduled_dt => TzTime.now.to_date, :times_scheduled => entryStatus.times_scheduled + 1)
		#  @selectedEntries << entry
		#end		
	end
        def self.remove_flag(bookmark)
            bkStatus = bookmark.bookmark_status
            if bkStatus != nil
                    completed_dates = deepcopy(bkStatus.completion_history)
                    completed_dates = {} if bkStatus.completion_history == nil
                    #Remove the entry from the history                    
                    completed_dates.delete_if {|key, value| key == "#{TzTime.now.to_date}" }  #Delete today's key
                   
                    pending_count =  0
                    completed_dates.each_pair {|key,value| pending_count += 1 if value == ""}
                
                    assign_position = bkStatus.position == 0 ? bookmark.priority : bkStatus.position
                    # The if condition is so that during update operation, the status record doesn't get updated again
                    bkStatus.update_attributes(:due_counter => pending_count, :due_today => 0,
                                                   :completion_history => completed_dates, :position => assign_position) 
            end
        end
	def markComplete                
		self.update_attributes(:completed => 1, :due_counter => 0, :last_viewed => TzTime.now.utc, :due_today => 0) 	 
	end
        
        def is_due_today
            due_today?
        end
        def is_overdue_today
            overdue_status?
        end
         private
        def self.deepcopy(obj)
            Marshal::load(Marshal::dump(obj))
        end
end
