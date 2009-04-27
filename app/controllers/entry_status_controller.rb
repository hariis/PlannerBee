class EntryStatusController < ApplicationController
       require_dependency 'entry'
       require_dependency 'entry_status'
        before_filter :authenticate
         around_filter :set_timezone
	def done
		entryStatus = EntryStatus.find(:first, :conditions => ["entry_id = ? and user_id = ?" , params[:id], current_user])
		entryStatus.markDone
		flash[:entry] = entryStatus.entry
		flash[:done] = true
		flash[:context] = params[:incontext]
		flash[:action_performed] = "done"
		if request.xhr?
			redirect_to :action => 'completed'
		else
			redirect_to :controller => 'entry',:action => 'index'
		end
		#redirect_back_or_default(:controller => 'entry',:action => 'index')	   
	end
        def undone
		entryStatus = EntryStatus.find(:first, :conditions => ["entry_id = ? and user_id = ?" , params[:id], current_user])
		entryStatus.mark_undone
		flash[:entry] = entryStatus.entry
		flash[:done] = true
		flash[:context] = params[:incontext]
		flash[:action_performed] = "undone"
		if request.xhr?
			redirect_to :action => 'completed'
		else
			redirect_to :controller => 'entry',:action => 'index'
		end
		#redirect_back_or_default(:controller => 'entry',:action => 'index')	   
	end
	def overduedone
		entryStatus = EntryStatus.find(:first, :conditions => ["entry_id = ? and user_id = ?" , params[:id], current_user])
                done_on = params[:done_on][:year] + "-" + params[:done_on][:month] + "-" + params[:done_on][:day]
	    
                entryStatus.markOverdueDone( params[:date], TzTime.at(Date.parse(done_on)).to_date.to_s  )
	    
		flash[:entry] = entryStatus.entry
		flash[:overduedone] = true
		flash[:context] = params[:incontext]
		flash[:action_performed] = "done"
		if request.xhr?
			redirect_to :action => 'completed'
		else
			redirect_to :controller => 'entry',:action => 'index'
		end
		#redirect_back_or_default(:controller => 'entry',:action => 'index')
	end
        def overdue_undone
		entryStatus = EntryStatus.find(:first, :conditions => ["entry_id = ? and user_id = ?" , params[:id], current_user])
		entryStatus.mark_overdue_undone(params[:date])
	    
		flash[:entry] = entryStatus.entry
		flash[:overduedone] = true
		flash[:context] = params[:incontext]
		flash[:action_performed] = "undone"
		if request.xhr?
			redirect_to :action => 'completed'
		else
			redirect_to :controller => 'entry',:action => 'index'
		end
		#redirect_back_or_default(:controller => 'entry',:action => 'index')
	end
	def skip
		entryStatus = EntryStatus.find(:first, :conditions => ["entry_id = ? and user_id = ?" , params[:id], current_user])
		entryStatus.markSkipped
		
		flash[:entry] = entryStatus.entry
		flash[:done] = true
		flash[:context] = params[:incontext]
		flash[:action_performed] = "skipped"
		if request.xhr?
			redirect_to :action => 'completed'
		else
			redirect_to :controller => 'entry',:action => 'index'
		end
		#redirect_back_or_default(:controller => 'entry',:action => 'index')

	end
	def overdueskip
		entryStatus = EntryStatus.find(:first, :conditions => ["entry_id = ? and user_id = ?" , params[:id], current_user])
		entryStatus.markOverdueSkipped(params[:date])
	  
		flash[:entry] = entryStatus.entry
		flash[:overduedone] = true
		flash[:context] = params[:incontext]
		flash[:action_performed] = "skipped"
		if request.xhr?
			redirect_to :action => 'completed'
		else
			redirect_to :controller => 'entry',:action => 'index'
		end
		
		#redirect_back_or_default(:controller => 'entry',:action => 'index')
	end
	def complete
		entryStatus = EntryStatus.find(:first, :conditions => ["entry_id = ? and user_id = ?" , params[:id], current_user])
		entryStatus.markComplete
	    
		flash[:entry] = entryStatus.entry
		flash[:completed] = true
		
		flash[:context] = params[:incontext]
		flash[:action_performed] = "ended"
		if request.xhr?
			redirect_to :action => 'completed'
		else
			redirect_to :controller => 'entry',:action => 'index'
		end
		
		#redirect_back_or_default(:controller => 'entry',:action => 'index')
	end
	
	def completed
		@entry = flash[:entry]
                @entry_status = @entry.entry_status
		@done = flash[:done]
		@overduedone = flash[:overduedone]	
                @completed = flash[:completed]
		@action_perfomed = flash[:action_performed]
		
		#The entry whose details are to be displayed
		@context = flash[:context]
		
                #Data for the entry that will be displayed
                
                @showentry = @entry
                @entries = Entry.find_todays_entries(session[:user])		
                @overdues = Entry.find_overdue_entries(session[:user])          
                #@addedtoday = Entry.find_added_today(session[:user])
            
                @incontext = 'task'
                @displayonly = false
                @duetoday = @entry.is_due_today
                if @showentry
                        @parent = Entry.find_by_id(@showentry.parent_id)
                        @childentries = @showentry.find_selected_childentries(current_user.id)
                end
                @related = Entry.find_tagged_with(@showentry.tags.collect{|t| t.name}.join("," ))
          
	end
end
