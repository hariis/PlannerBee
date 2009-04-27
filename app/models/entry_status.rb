class EntryStatus < ActiveRecord::Base
	belongs_to :user
	belongs_to :entry	
	serialize  :skipped_on
	serialize  :completion_history
	def markDone
		#If this is a current entry only
		gap = times_scheduled - (times_done + times_donelate + times_skipped)
		
		if gap > 0
		                        
                    completed_dates = EntryStatus.deepcopy(completion_history)
                    completed_dates = {} if completion_history == nil
                    #Look for today's date in the local time zone in the history and mark that entry done
                    #TODO if the user changes time zone after the entries have been flagged,
                    # something must be done to shift  the  today's date entries into new local time if they are pending
                    if completed_dates["#{TzTime.now.to_date}"] == ""
                          completed_dates["#{TzTime.now.to_date}"] = "#{TzTime.now.to_date}"
			  
			  #Check to see if there are any more scheduled entries left
			  #IF none and gap == 1 then consider this task has ended and mark it so
			  #Then check its goal's status also
		          future_entries = Schedulehelper.get_future_scheduled_dates(entry)
		          
                          ended_status = (future_entries.size == 0  && gap == 1) ? 1 : 0	      
			  position_id = (future_entries.size == 0  && gap == 1) ?  999 :  position #999 - so it goes down the list
			  
                          update_attributes(:last_marked => TzTime.now.utc,:times_done => times_done + 1,
			    :completion_history => completed_dates, :ended => ended_status, :position => position_id) 
			  mark_goal_complete if ended_status == 1
                    end
		else
		    logger.fatal("The gap is = 0 or less and the done action got performed")
		    raise
                    self.update_attributes(:last_marked => TzTime.now.utc, :due_today => 0) 
		end
	  
	end
        def mark_undone         
          #Should be removed
          completed_dates = EntryStatus.deepcopy(completion_history)
          completed_dates = {} if completion_history == nil
              if completed_dates["#{TzTime.now.to_date}"] != ""
                          completed_dates["#{TzTime.now.to_date}"] = ""

                          skipped_days = EntryStatus.deepcopy(skipped_on)
                          skipped_days = {} if skipped_on == nil                       
                          skipped_days.delete_if {|key,value| key == "#{TzTime.now.to_date}" } 
                          times_skipped_count = skipped_days.keys.length
                          
                          #Figure out if this task had previously been marked Done or Skipped
                          times_done_count = times_done
                          if times_skipped_count == times_skipped
                               #Nothing got deleted from the skipped_on hash
                               #That means this item had previously been marked Done
                               #So decrement the done count
                                times_done_count = times_done_count - 1
                          end
                          update_attributes(:last_marked => TzTime.now.utc,:times_done => times_done_count, :completion_history => completed_dates, 
                                                             :skipped_on => skipped_days, :times_skipped => times_skipped_count, :ended => 0) 
              end
        end
        
	def markOverdueDone(scheduled_date, done_on)
	  
	  completed_dates = EntryStatus.deepcopy(completion_history)
          completed_dates = {}	if completion_history == nil
          if completed_dates[scheduled_date] == ""
                  completed_dates[scheduled_date] = done_on	
		  #Check to see if there are any more scheduled entries left
		  #IF none and gap == 1 then consider this task has ended and mark it so
		  #Then check its goal's status also
		  future_entries = Schedulehelper.get_future_scheduled_dates(entry)
		  gap = self.times_scheduled - (self.times_done + self.times_donelate + self.times_skipped)
		  ended_status = (future_entries.size == 0  && gap == 1) ? 1 : 0	     
		  od_position_id = (future_entries.size == 0  && gap == 1) ? 999 : overdue_position
		  
                   update_attributes(:last_marked => TzTime.now.utc,:times_donelate => times_donelate + 1,
			 :completion_history => completed_dates, :ended => ended_status, :overdue_position =>  od_position_id) 
		   mark_goal_complete if ended_status == 1
          end
	end
        
        #overdue_undone is encompassing the functionality of undone
        #overdue_undone undoes any date whereas undone undoes only for today's date
        #undone method can be removed
        def mark_overdue_undone(scheduled_date)
                		
                completed_dates = EntryStatus.deepcopy(completion_history)
                completed_dates = {}	if completion_history == nil
                if completed_dates["#{TzTime.now.to_date}"] != ""
                          completed_dates[scheduled_date] = ""

                          skipped_days = EntryStatus.deepcopy(skipped_on)
                          skipped_days = {} if skipped_on == nil                       
                          skipped_days.delete_if {|key,value| key == scheduled_date } 
                          times_skipped_count = skipped_days.keys.length
                          
                          #Figure out if this task had previously been marked Done or Skipped
                          times_done_count = times_done
                          if times_skipped_count == times_skipped
                               #Nothing got deleted from the skipped_on hash
                               #That means this item had previously been marked Done
                               #So decrement the done count
                                times_done_count = times_done_count - 1
                          end
                          update_attributes(:last_marked => TzTime.now.utc,:times_donelate => times_done_count, :completion_history => completed_dates,
                                                           :skipped_on => skipped_days, :times_skipped => times_skipped_count) 
			  #mark_goal_incomplete  Not necessary - A goal that has been ended cannot be undone as a task that has ended cannot be undone either
                end
        end
	def markSkipped
		#If this is a current entry only
		gap = times_scheduled - (times_done + times_donelate + times_skipped)
	  
		if gap > 0			
                        skipped_days = EntryStatus.deepcopy(skipped_on)
                        skipped_days = {} if skipped_on == nil   
                          if !skipped_days.has_key?("#{TzTime.now.to_date}")     #If user clicked twice on the link quickly, avoid recording it twice                        
                                  skipped_days["#{TzTime.now.to_date}"] = "#{TzTime.now.to_date}"

                                  completed_dates = EntryStatus.deepcopy(completion_history)
                                  completed_dates = {}	if completion_history == nil
                                  completed_dates["#{TzTime.now.to_date}"] = "#{TzTime.now.to_date}"
				  #Check to see if there are any more scheduled entries left
				  #IF none and gap == 1 then consider this task has ended and mark it so
				  #Then check its goal's status also
				  future_entries = Schedulehelper.get_future_scheduled_dates(entry)

				  ended_status = (future_entries.size == 0  && gap == 1) ? 1 : 0	  
				  position_id = (future_entries.size == 0  && gap == 1) ? 999 :  position #999 - so it goes down the list
				  
                                  update_attributes(:last_marked => TzTime.now.utc, :times_skipped => times_skipped + 1, 
				    :skipped_on => skipped_days, :completion_history => completed_dates, :ended => ended_status, :position => position_id) 
				  
				  mark_goal_complete if ended_status == 1
                          end
		else
		    raise
			self.update_attributes(:last_marked => TzTime.now.utc, :due_today => 0)
		end
	  
	end
	def markOverdueSkipped(scheduled_date)
	  #gap = self.times_scheduled - (self.times_done + self.times_donelate + self.times_skipped)  
	 
	  skipped_days = EntryStatus.deepcopy(skipped_on) 
          skipped_days = {} if skipped_on == nil
                if !skipped_days.has_key?(scheduled_date)     #If user clicked twice on the link quickly, avoid recording it twice
                        skipped_days[scheduled_date] = "#{TzTime.now.to_date}"

                        completed_dates = EntryStatus.deepcopy(completion_history)
                        completed_dates = {}	if completion_history == nil
                        completed_dates[scheduled_date] = "#{TzTime.now.to_date}"
			#Check to see if there are any more scheduled entries left
			#IF none and gap == 1 then consider this task has ended and mark it so
			#Then check its goal's status also
			future_entries = Schedulehelper.get_future_scheduled_dates(entry)
			gap = self.times_scheduled - (self.times_done + self.times_donelate + self.times_skipped)
			ended_status = (future_entries.size == 0  && gap == 1) ? 1 : 0	  
			od_position_id = (future_entries.size == 0  && gap == 1) ? 999 : overdue_position
			
                        update_attributes(:times_skipped => times_skipped + 1,:last_marked => TzTime.now.utc,
			  :skipped_on => skipped_days, :completion_history => completed_dates, :ended => ended_status, :overdue_position =>  od_position_id) 
			mark_goal_complete if ended_status == 1
                end
	end
	def markComplete
                #Mark the leftovers as skipped
                #Set the end_date to today so that FlagTodaysEntries does not pick it up
                #Not advisable to change the end_dt so adding a new field called ended to track the forcibly ended items
                #Set the gap to 0 so that FlagOverdueItems does not pick it up
                #Set the flags overdue_status and due_today to 0 so that it is not picked up during the day
                if !ended
                        skipped_days = EntryStatus.deepcopy(skipped_on) 	  
                        skipped_days = {} if skipped_on == nil

                        #Located the pending dates and mark as skipped
                        completed_dates = EntryStatus.deepcopy(completion_history)
                        completed_dates = {}	if completion_history == nil
                        completed_dates.each_pair do |key, value|
                             if value == "" 
                               completed_dates[key] = "#{TzTime.now.to_date}"
                               skipped_days[key] = "#{TzTime.now.to_date}"
                             end
                        end       

                        gap = self.times_scheduled - (times_done + times_donelate + times_skipped) 

                        if gap > 0 	      
                                self.update_attributes(:times_skipped => times_skipped + gap, :ended => 1,:last_marked => TzTime.now.utc,
				  :skipped_on => skipped_days, :completion_history => completed_dates, :position => 0, :overdue_position => 0)
                        else
                                self.update_attributes( :ended => 1,:last_marked => TzTime.now.utc, :skipped_on => skipped_days, :completion_history => completed_dates)
                        end
			mark_goal_complete 
                end
	end
	
	def self.flag_entry(entry)
		begin
                          entryStatus = entry.entry_status
                          return if  entryStatus && entryStatus.ended?
                          if entryStatus != nil    #This check is necessary to distinguish an entry that is just created and being flagged  for due the same day  
                                  all_dates = Schedulehelper.GetDatesUpToToday(entry)
                                  return if all_dates.length == 0  #Not due yet

                                  completed_dates = deepcopy(entryStatus.completion_history)
                                  completed_dates = {} if entryStatus.completion_history == nil
                                  latest_scheduled_date = completed_dates.size > 0 ? completed_dates.sort.last[0] : nil
                                  #Go through each element and add to the history only those
                                  # that are not already present AND are past the latest date in the history
                                  #  This latter condition is to accomodate the case when the freq type has changed.
                                  #Here, we want only those dates from the list of scheduled dates(all_dates) as per the new frequency_type
                                  # that are past the latest date in the history which is as per the old freq_types  
                                 #Back fill the missing scheduled dates
                                  for date in all_dates
                                    #These are dates in local timezone
                                      completed_dates["#{date}"] = "" if completed_dates.length == 0 || 
                                                                                                 (!completed_dates.has_key?(date) &&
                                                                                                   ( latest_scheduled_date != nil && date > Date.parse(latest_scheduled_date) ) )
                                  end                               
                                 
                                  due_today_status = completed_dates.has_key?("#{TzTime.now.to_date}")  ? true : false                                       
 
                                  times_scheduled_count = completed_dates.keys.length
                                 
                                  assign_position = entryStatus.position == 0 ? entry.priority : entryStatus.position
                                  entryStatus.update_attributes(:due_today => due_today_status, :times_scheduled => times_scheduled_count, :completion_history => completed_dates, :position => assign_position) 
                          else
                                  completed_dates = {}
                                  all_dates = Schedulehelper.GetDatesUpToToday(entry)
                                  for date in all_dates
                                      completed_dates["#{date}"] = "" if !completed_dates.has_key?(date)
                                  end 
             
                                  times_scheduled_count = completed_dates.keys.length


                                  entryStatus = EntryStatus.new(:due_today => 1, :times_scheduled => times_scheduled_count, :user_id => entry.user_id,:completion_history => completed_dates, :position => entry.priority)
                                  
                                  entry.entry_status  = entryStatus
                          end
	rescue => err
                logger.fatal("Caught exception in entry_status's flag_entry")
                logger.fatal(err)
                
        end
		
		#if (entryStatus.last_scheduled_dt == nil || (entryStatus.last_scheduled_dt != nil && entryStatus.last_scheduled_dt !=  TzTime.now.to_date) ) then
		#  entryStatus.update_attributes(:last_scheduled_dt => TzTime.now.to_date, :times_scheduled => entryStatus.times_scheduled + 1)
		#  @selectedEntries << entry
		#end

		
	end
        def self.remove_flag(entry)
                entryStatus = entry.entry_status
                return if  entryStatus && entryStatus.ended?
                if entryStatus != nil    #This check is necessary to distinguish an entry that is just created and being flagged  for due the same day  
                    completed_dates = deepcopy(entryStatus.completion_history)
                    completed_dates = {} if entryStatus.completion_history == nil   
                    #Remove the entry from the history                    
                    completed_dates.delete_if {|key, value| key == "#{TzTime.now.to_date}" }  #Delete today's key
                    
                    times_scheduled_count = completed_dates.keys.length
                    assign_position = entryStatus.position == 0 ? entry.priority : entryStatus.position
                    
                    #If the entry has been marked done or skipped, then few more columns need to be reset as well
                    times_done_count = entryStatus.times_done
                    times_skipped_count = entryStatus.times_skipped
                    if entryStatus.last_marked && entryStatus.last_marked.to_date == TzTime.now.utc.to_date
                            #check If skipped, Remove if in skipped array
                            skipped_days = EntryStatus.deepcopy(entryStatus.skipped_on)
                            skipped_days = {} if entryStatus.skipped_on == nil                       
                            skipped_days.delete_if {|key,value| key == "#{TzTime.now.to_date}" } 
                            times_skipped_count = skipped_days.keys.length  #One way to check if item got deleted is by getting the size of the hash
                            
                            if times_skipped_count == entryStatus.times_skipped
                                  #Nothing got deleted from the skipped hash
                                  #So the entry must have been marked done
                                  times_done_count = times_done_count - 1
                            end
                    end
                    entryStatus.update_attributes(:due_today => 0, :times_scheduled => times_scheduled_count, 
                                                                            :completion_history => completed_dates, :position => assign_position,
                                                                           :times_done => times_done_count, :skipped_on => skipped_days, :times_skipped => times_skipped_count) 
                end
        end
        
        def is_pending
            completion_dates = completion_history 
            pendingdates = {} 
            completion_dates = {} if completion_dates == nil 
            completion_dates.each_pair { |key,value| pendingdates[key] = value if Date.parse(key) != TzTime.now.to_date && (value == "" )}  
            return true if pendingdates.size > 0
            return false
        end
        private
        def self.deepcopy(obj)
            Marshal::load(Marshal::dump(obj))
        end
	def mark_goal_complete 
		#Get the goal object
		#Get all its sub tasks
		#If all of their 'ended' statuses == 1, then mark goal's ended = 1
		goal = Entry.find_by_id(self.entry.belongs_to)
		return if goal == nil
		
		sub_tasks = Entry.find(:all, :conditions => ["belongs_to == ?",goal.id ])
		all_ended = true
		sub_tasks.collect {|task| all_ended &= task.entry_status.ended }
		
	        if all_ended
			goal.markComplete
	        else
		        #Do nothing
                end
        end
end
