class EntryController < ApplicationController
  require_dependency 'entry'
  #before_filter :login_required # :except => [:newapi,:saveapi,:listapi,:listallapi]
  before_filter :authenticate
  around_filter :set_timezone
  before_filter :is_admin, :only => [:flag]
  before_filter :check_if_user_data_current
  
  layout "common" , :except => [:listapi]
  
 	def index
                @entry = flash[:entry] 
                @entries = Entry.find_todays_entries(session[:user])
                @overdues = Entry.find_overdue_entries(session[:user])		
                @addedtoday = Entry.find_added_today(session[:user])
                completedtoday = Entry.find_completed_today(session[:user])
                @completedtoday=[]
                completedtoday.each {|e| @completedtoday << e.entry}	

                #The entry whose details are to be displayed
                @incontext = "task"
                @showentry = flash[:showentry] || (@entries.size > 0 ? @entries[0].entry : nil)
                if @showentry != nil
                      @parent =  @showentry.parent_id ? Entry.find_by_id(@showentry.parent_id) : nil
                      @childentries =  @showentry.find_selected_childentries(current_user.id)
                      @related = Entry.find_tagged_with(@showentry.tags.collect{|t| t.name}.join("," )) 
                end
                @query_types = {'Choose a Custom View' => 1, 'Pick a Date ...' => 2, 'All To Do Next tasks' => 3, 'All Someday / Maybe tasks' => 4}

        respond_to do |format|
              format.html {
                    if @showentry == nil
                          #display the add new task form
                          @entry = Entry.new
                          @parententries = Entry.find_all_current_entries(TzTime.now.utc.to_date,current_user.id)
                          @childentries = @parententries  #Parent list and children list are initially the same
                          @goals =  nil 
                          @bookmarks = current_user.bookmarks
                          @saved_feed_items = []
                          current_user.feedsubscriptions.each{|sub| if sub.feed_items.size > 0 then sub.feed_items.each{|item| @saved_feed_items << item} end}
                          @freqtypes = Schedulehelper::FREQ_TYPES
                          @freqintervals = Schedulehelper::FREQ_INTERVALS_DAILY
                    end
              }
              format.xml { 
                    @entry_items = []
                    @overdue_entry_items = []
                    @entries.each {|e| @entry_items << e.entry }
                    @overdues.each {|e| @overdue_entry_items << e.entry }
                    render :template => 'entry/index.xml.builder', :layout => false
              }
              format.atom
        end
	end
  
	def new
		#Populate the body
		@entry = params[:type] == 'task' ? Entry.new : Goal.new
		@parententries = Entry.find_all_current_entries(TzTime.now.utc.to_date,current_user.id)
		@childentries = @parententries  #Parent list and children list are initially the same
		@bookmarks = current_user.bookmarks
                @saved_feed_items = []
                current_user.feedsubscriptions.each{|sub| if sub.feed_items.size > 0 then sub.feed_items.each{|item| @saved_feed_items << item} end}
		@freqtypes = Schedulehelper::FREQ_TYPES
		@freqintervals = Schedulehelper::FREQ_INTERVALS_DAILY
                @task = params[:type] == 'task' ? true : false
                @goals = params[:type] == 'task' ? Goal.find_pending(TzTime.now.utc.to_date,current_user.id) : nil
               respond_to do |accepts|
                     accepts.html do
                        redirect_to :action => 'index'                       
                      end
                      accepts.js do
                        render :partial => 'new'		
                      end
               end               
	end
	def newapi
		@entry = Entry.new
		@freqtypes = Schedulehelper::FREQ_TYPES
		@freqintervals = Schedulehelper::FREQ_INTERVALS_DAILY
	end
	def edit_inits
		
	end
	helper_method :edit_inits
	def edit
		@entry = Entry.find(params[:id])
		@parententries = @entry.findParententries(TzTime.now.utc.to_date,current_user.id)

		@childentries = @entry.find_child_entries(TzTime.now.utc.to_date,current_user.id)
		#previousSelected = current_user.entries.find_by_parent_id(@entry.id)
		previousSelected = @entry.find_selected_childentries(current_user.id)
		@childentriesSelected = []
		previousSelected.each {|selected|@childentriesSelected << selected.id} if previousSelected

		@bookmarks = current_user.bookmarks
		@bookmarksSelected =[]
		@entry.bookmarks.each {|b|@bookmarksSelected << b.id} if @entry.bookmarks
                
                @saved_feed_items = []
                current_user.feedsubscriptions.each{|sub| if sub.feed_items.size > 0 then sub.feed_items.each{|item| @saved_feed_items << item} end}
                @feed_items_selected =[]
		@entry.feed_items.each {|f|@feed_items_selected << f.id} if @entry.feed_items
                
		@goals = params[:type] == 'task' ? Goal.find_pending(TzTime.now.utc.to_date,current_user.id) : nil
		@freqtypes = Schedulehelper::FREQ_TYPES

		if  @entry.freq_type   == 6 then
			  @freqintervals = Schedulehelper::FREQ_INTERVALS_DAILY
			  
		elsif @entry.freq_type   == 7 then           
			  @freqintervals = Schedulehelper::FREQ_INTERVALS_WEEKLY
			  @freqintervalsqual= Schedulehelper::FREQ_INTERVALS_QUAL_WEEKLY
									 
		elsif @entry.freq_type   == 8 then
			  @freqintervals = Schedulehelper::FREQ_INTERVALS_MONTHLY
			  @freqintervalsqual= Schedulehelper::FREQ_INTERVALS_QUAL_DATE
			  
		elsif @entry.freq_type   == 9 then
			  @freqintervals = Schedulehelper::FREQ_INTERVALS_MONTHLY
			  @freqintervalsqual= Schedulehelper::FREQ_INTERVALS_QUAL_DAY
						  
		elsif @entry.freq_type   == 10 then
			  @freqintervals = Schedulehelper::FREQ_INTERVALS_YEARLY
			  
		end     
		if (@entry.freq_interval_qual)
		  selectedvalues = Schedulehelper::ExtractFreqIntQualIntoArr(@entry.freq_interval_qual,true)   
		  @freqintervalsqual_selected = []
		  selectedvalues.each{|val|@freqintervalsqual_selected << val.to_s }		  
		end
                if request.xhr?
                    render :partial => 'edit', :locals => {:incontext => params[:incontext] }	
                else
                    redirect_to :action => 'index'
                end				
	end
	
	def save
		@user = User.find_by_id(session[:user])
                @is_task = params[:type] == 'task' 
		@entry = @is_task ? Entry.new(params[:entry]) : Goal.new(params[:entry])
		@entry.title = params[:title]  if params[:title] != nil 
		#Make the 'overdue_reminder' set for all entries - It does not make sense to make it a choice for the user
                @entry.overdue_reminder = true
		begin
		@entry.start_dt_tm = TzTime.at(Date.parse(params[:start])).at_beginning_of_day.utc  if params[:start] != nil   #Moving the time to 00:00            
		@entry.end_dt_tm = TzTime.at(Date.parse(params[:end])).tomorrow.ago(60).utc  if params[:end] != nil   #Moving the time to 23:59 
                rescue => err
                  @entry.errors.add("", err)
                  handle_failure
                  return false
                end
		@entry.freq_interval = params[:freq_interval] if (params[:freq_interval] != nil) 

		if (params[:freq_interval_details] != nil) then
		  fix = 0b1
		  @entry.freq_interval_qual = 0
		  
		  params[:freq_interval_details].collect{|char| @entry.freq_interval_qual |= fix << ((char.to_i)-1) } 
		end	
		
                #Store the order of entries prior to this new entry being saved - Used later for setting position index
                @prior_entries = Entry.find_todays_entries(session[:user]) 
                @prior_entries ||= []
		if @user.entries << @entry 		  
			#save attachments
			#save tasks first
			if params[:child_tasks] != nil 
				params[:child_tasks].collect do |taskid|
				  #Get the task
				  @childentry = Entry.find(taskid.to_i) if taskid.to_i != 0
				  #Set the parent id of the task to the new task's id
				   if @childentry != nil 
                                      if @is_task
                                            @childentry.update_attributes(:parent_id => @entry.id)   
                                      else
                                            @childentry.update_attributes(:belongs_to => @entry.id) 
                                      end                                                                          
                                   end
				end
			end

			#save bookmarks next
			if params[:bookmarks] != nil
                            params[:bookmarks].collect do |bookmarkid|
                              EntryBookmarkLink.create(:entry_id => @entry.id, :bookmark_id => bookmarkid.to_i) if bookmarkid.to_i != 0                                                                   			  
                            end
			end
                        #save feed items next
			if params[:feed_items] != nil
                            params[:feed_items].collect do |feeditemid|
                                EntryFeedItemLink.create(:entry_id => @entry.id, :feed_item_id => feeditemid.to_i) if feeditemid.to_i != 0                                       
                            end
			end
                        @context = "task"   
                        
                        #Set the positon index for the new entry depending on its priority     
                        #If this is the first entry that is due today, then set the position to 0 irrespective of its priority
                        #Also set the position to 0 if the priority is low irrespective of the number of tasks already due today
                        #Otherwise, set the position to highest value (size of existing list gives that)
                        # since priority is High and there are more than one item that is already due today
                        #If the priority is low, then readjust the position of the rest of the items by bumping them up by one.
                        if @entry.is_due_today
                            @entry.entry_status.position = @prior_entries.size; @entry.entry_status.save if @prior_entries.size == 0 || @entry.priority == 1
                            @entry.entry_status.position = 0 ; @entry.entry_status.save  if @entry.priority == 3
                            if @entry.priority == 3
                                #Move older entries one level higher
                                @prior_entries.each{|e| e.position  = e.position + 1; e.save}
                            end
                            #@entry.entry_status.position = @entries[@entries.size - 1].position + 1
                            #@entry.entry_status.save if @entry.entry_status.position > 1   #Don't bother saving if the user hasn't ordered the tasks yet
                        end
                         @entries = Entry.find_todays_entries(session[:user]) 
			#goes to rjs	
                        collect_data_for_display			
		else
			handle_failure
		end
	end
        def collect_data_for_display            
            @addedtoday = Entry.find_added_today(session[:user])
            @showentry = @entry
            @displayonly = false
            @duetoday = @entry.is_due_today
            if @showentry
                    @parent = Entry.find_by_id(@showentry.parent_id)
                    @childentries = @showentry.find_selected_childentries(current_user.id)
            end
            @related = Entry.find_tagged_with(@showentry.tags.collect{|t| t.name}.join("," ))
          
        end
	def handle_failure
            #Gather the error messages
            #Why doesn't new template see this @entry object 
            @errorstring = ""
            @entry.errors.each do |attr,e| 
                    @errorstring = @errorstring + "<li>" +  e + "</li>"		
            end 
            @errormessage = "<div id='failure'>
            #{@entry.errors.count} error(s) found.
            <ul>				
            #{@errorstring}			
            </ul>
            Please try again.
            </div>"
            render :update do |page|

                  page.replace_html 'flash-notice',@errormessage			
                  page.show 'flash-notice'
                  page.delay(10) do
                          page.replace_html 'failure', ""
                          page.visual_effect :fade, 'flash-notice'
                  end
                  page.show 'taskdetails'
            end          
        end
	def saveapi
	  @user = User.find_by_id(current_user.id)
	  @entry = Entry.new(params['entry'])
	  if (params[:flavors] != nil) then
		  fix = 0b1
		  @entry.freq_interval_qual = 0
		  
		  params[:flavors].collect{|char| @entry.freq_interval_qual |= fix << ((char.to_i)-1) } 
	  end
		
	   @entry.user_id = @user.id
	   @entry.tag_list=params[:tag_list]
		 
	  if @entry.save
		  flash[:notice]="Successfully saved #{@entry.formatted_title}"
	  else
		  
		  redirect_to :action => 'newapi'
		end
	end


	def update
		  @user = User.find_by_id(session[:user])
		  @entry = Entry.find(params[:id])
                   
                  #Save key original data
                  old_freq_type = @entry.freq_type
                  old_start_dt = @entry.start_dt_tm
                  @was_due_today = @entry.is_due_today
                 #Prepare data
                 freq_interval_qual = 0
		  if (params[:freq_interval_details] != nil) then
			  fix = 0b1           
			  params[:freq_interval_details].collect{|char| freq_interval_qual |= fix << ((char.to_i)-1) } 
		  end  
                  
                  #Set tagging parameters
                  @entry.user_id = @user.id
                  @entry.tag_list= params[:entry][:tag_list]
                  
                  #Fill the object with form data
                  @entry.title = params[:entry][:title]
                  @entry.notes = params[:entry][:notes]
                  
                  @entry.public = params[:entry][:public]
                  @entry.priority = params[:entry][:priority]
                  #@entry.overdue_reminder = params[:entry][:overdue_reminder]
		  
                  begin          
		  @entry.start_dt_tm = TzTime.at(Date.parse(params[:start])).at_beginning_of_day.utc  if params[:start] != nil   #Moving the time to 00:00            
                  @entry.end_dt_tm = TzTime.at(Date.parse(params[:end])).tomorrow.ago(60).utc  if params[:end] != nil   #Moving the time to 23:59 
                  rescue => err
                      @entry.errors.add("", err)
                      handle_failure
                      return false
                  end
                  @entry.freq_type = params[:entry][:freq_type]
                  @entry.freq_interval = params[:freq_interval]
                  @entry.freq_interval_qual = freq_interval_qual
                    
                  @entry.parent_id = params[:entry][:parent_id]
                    
                  #Determine if set_remind_once_fields needs to be called
                  new_freq_type = params[:entry][:freq_type].to_i
                  new_start_dt = @entry.start_dt_tm
                  if old_freq_type != new_freq_type &&  isItemInList( [0,1,2,3,4,5,11],new_freq_type )  
                                @entry.set_remind_once_fields
                  elsif new_freq_type == 11 && old_start_dt != new_start_dt
                                @entry.set_remind_once_fields
                  end
                  
                    if @entry.save
				#Update bookmarks
				previousSelected = []
				currentSelected = []
				@entry.bookmarks.each {|bk|previousSelected << bk.id} if @entry.bookmarks
				
				currentSelected = params[:bookmarks]
				
				#Add the new bookmarks
				if currentSelected != nil
				  currentSelected.collect do |currentid|
                                      if currentid.to_i != 0 && !isItemInList(previousSelected,currentid)                                                    
                                          EntryBookmarkLink.create(:entry_id => @entry.id, :bookmark_id => currentid.to_i)           
                                      end
				  end
				end
				#Delete the stale bookmarks  
				if previousSelected != nil
				  previousSelected.collect do |previousid|
                                    if previousid != 0 && !isItemInList(currentSelected,previousid)
                                         EntryBookmarkLink.find(:first, :conditions => ["entry_id = ? and bookmark_id =?", @entry.id, previousid]).destroy
                                    end			
				  end
				end
				#Update feed items
				previousSelected = []
				currentSelected = []
				@entry.feed_items.each {|fi|previousSelected << fi.id} if @entry.feed_items
				
				currentSelected = params[:feed_items]
				
				#Add the new feed items
				if currentSelected != nil
				  currentSelected.collect do |currentid|
                                      if currentid.to_i != 0 && !isItemInList(previousSelected,currentid)
                                          EntryFeedItemLink.create(:entry_id => @entry.id, :feed_item_id => currentid.to_i) 
                                      end
				  end
				end
				#Delete the stale feed items  
				if previousSelected != nil
				  previousSelected.collect do |previousid|
                                      if previousid != 0 && !isItemInList(currentSelected,previousid)
                                          EntryFeedItemLink.find(:first, :conditions => ["entry_id = ? and feed_item_id =?", @entry.id, previousid]).destroy
                                      end			
				  end
				end
				#Update child entries
				@childentriesSelected = @entry.find_selected_childentries(@user.id)
				
				previousSelected = []
				currentSelected = []
				@childentriesSelected.each {|b|previousSelected << b.id} if @childentriesSelected
				currentSelected = params[:child_tasks]
				
				#Make new assignments
				if currentSelected != nil 
				  currentSelected.collect do |taskid|
					if taskid.to_i != 0 && !isItemInList(previousSelected,taskid)
					  #Get the task
					  childentry = Entry.find(taskid.to_i) 
					  #Set the parent id of the task to the new task's id
					  childentry.update_attribute(:parent_id, @entry.id) if childentry != nil  
					end
				  end
				end
				#Reset the parent of the previously selected entries
				if previousSelected != nil
				  previousSelected.collect do |previousid|
					if !isItemInList(currentSelected,previousid)
					  #Get the task
					  @childentry = Entry.find(previousid.to_i) 
					  #Set the parent id of the task to the new task's id
					  @childentry.update_attribute(:parent_id, nil) if @childentry != nil  
					end
				  end
				end
				
				#get ready for the updating all the lists
				collect_data_for_display
                                @entries = Entry.find_todays_entries(session[:user])
				@overdues = Entry.find_overdue_entries(session[:user])
				
				completedtoday = Entry.find_completed_today(session[:user])
				@completedtoday=[]
				completedtoday.each {|e| @completedtoday << e.entry}
				#goes to rjs
				@context = params[:context]    
                                @entry.reload                                
		  else
			       handle_failure
		  end
	end

	def destroy
		Entry.find(params[:id]).destroy
		redirect_to :action => 'list'
	end
  
	def show
                respond_to do |format|
                  format.html do
                      flash[:showentry] = Entry.find_by_id(params[:id])
                      redirect_to :action => 'index'
                      end
          
          format.js do
              @showentry = Entry.find_by_id(params[:id])
              if @showentry
                  @parent = Entry.find_by_id(@showentry.parent_id)
                  @childentries = @showentry.find_selected_childentries(current_user.id)
                  @goal = Entry.find_by_id(@showentry.belongs_to) if @showentry.belongs_to
              end
              @incontext = params[:incontext]
              @duetoday = params[:duetoday]
              @displayonly = params[:displayonly]
              @related = Entry.find_tagged_with(@showentry.tags.collect{|t| t.name}.join("," ))
              #tagcloud_hash = {} 
              #current_user.entries.each do |e| 
              #e.tags.each do |tag|   
              #if tagcloud_hash.has_key?(tag) then
              #tagcloud_hash[tag] =  tagcloud_hash[tag] + 1
              #else 
              #tagcloud_hash[tag] =  1 
              #end
              #end 
              #end 
              #@tagcloud_user = generate_tagcloud(tagcloud_hash)
          end
      end
	end

	def list
              redirect_to :action => 'index'
        end
	def listapi
		@entries = Entry.find_todays_entries(current_user.id)
		@overdues = Entry.find_overdue_entries(current_user.id)
		@code = "success" if @entries != nil
		respond_to do |wants|
		  wants.xml 
		end
	end
	def listall
		session[:jumpto]=request.parameters
		@entries = Entry.find_live_entries()
		render_action 'list'
		end
	def listallapi
		@entries = Entry.findallentries(TzTime.now.utc,current_user.id)
		respond_to do |wants|
		  wants.xml { render :xml => @entries.to_xml }
		end
	end
	
	
	def items
         @entries = Entry.GetEntriesFor(TzTime.now.to_date,session[:user]) 
         if @entries.length == 0
             @entries = Entry.findallentries(TzTime.now.utc,session[:user])
         end
         @code = "success"
         render :layout => false
	end

	def displaychildtasks      		
		if params[:id] == nil  #new action #TODO create a static method
#			@entries = Entry.find_all_current_entries(TzTime.now.to_date,current_user.id)
#			@childentries =[]
#			@entries.each do |entry|
#			  @childentries << entry if entry.id != params[:taskid].to_i          
#			end 
                        tags = Tag.parse(params[:taglist])
                         @displaytags = tags.collect{|t| t}.join(", ")     
                         
                        @childentries =[]
                        @showall = params[:type] != nil ? true : false
                       
                        @childtasks = Entry.find_child_entries(TzTime.now.utc.to_date,current_user.id, params[:taskid].to_i )
                        @filtered_childtasks = Entry.find_filtered_child_entries(TzTime.now.utc.to_date,current_user.id, params[:taskid].to_i, params[:taglist])
                         render :update do |page|                           
                              page.replace_html 'link-child-tasks', :partial => "filter_child_tasks", :locals => {:parentid => params[:taskid].to_i}
                         end                                                          
           
		else   #Edit action
			parentid = params[:parentid]
			if parentid.empty? then
			  parentid = 0 
			end
			@entry = Entry.find(params[:id])
			@childentries = @entry.find_child_entries_for(TzTime.now.utc.to_date,current_user.id, parentid.to_i)
                         htmlstring = "<%= select_tag 'child_tasks[]',    options_for_select(@childentries.collect{|e| [ e.title,e.id ]} ),  { :multiple => true, :size => 4, :include_blank => true } %>"       
                        render :inline => htmlstring    
		end			   
	end

    
	def flag
              Entry.FlagTodaysEntries()
              #render_action 'list'
              redirect_to :action => 'list'
	end
	
        def find               
                if params[:want] != nil then
                    @entries = Entry.find_tagged_with_by_user(params[:want],current_user)
                    tags = Tag.parse(params[:want])
                   displaytags = tags.collect{|t| t}.join(", ")
                   
                    if @entries.size == 0 
                       @results_heading = "No tasks found with '<i>#{displaytags}</i>'"
                    else
                       @results_heading = "Results for '<i>#{displaytags}</i>'"
                    end
                    
                else
                    render :nothing
                end
      end
      def tagcloud
       
      end
      
      def save_order
           params[:task_list].each_with_index do |pos, idx|
                  t = EntryStatus.find_by_entry_id(pos.to_i)
                  t.position = idx
                  t.save!
            end
          
            @entries = Entry.find_todays_entries(session[:user])
           render :update do |page|
                page.replace_html("task_list", :partial => "shared/entries", :object => @entries, :locals => {:duetoday => true, :outline => false  })
                page.sortable "task_list", :url=>{:action=>:save_order}
            end            
           
      end
      def save_overdue_order
        
        params[:overduetask_list].each_with_index do |pos, idx|
                  t = EntryStatus.find_by_entry_id(pos.to_i)
                  t.overdue_position = idx
                  t.save!
            end
          
            @overdues = Entry.find_overdue_entries(session[:user])
           render :update do |page|
                page.replace_html("overduetask_list", :partial => "shared/entries", :object => @overdues, :locals => {:duetoday => false, :outline => false  })
                page.sortable "overduetask_list", :url=>{:action=>:save_overdue_order}
            end 
      end
      def view_future
                @future_entries = nil
                  begin
                          if params['future_date'] != nil && Date.parse(params[:future_date]) !=  nil
                              @future_entries = Entry.find_entries_for(current_user.id, params['future_date']) 
                          end 
                          render :partial => 'displayonlyentries', :object => @future_entries
                
                  rescue 
                        render :text => "Invalid date"
                  end
      end
      def show_query_results
                query_type = params[:query_type]
              case query_type.to_i
                  when 1
                        render :update do |page|
                               page.hide 'pick_a_date'
                               page.replace_html 'query_results', ""
                        end
                   when 2  #Pick a date
                             render :update do |page|
                                    page.show 'pick_a_date'
                             end
                   when 3  #View all Next to do tasks
                     render :update do |page|
                                page.hide 'pick_a_date'
                                page.replace_html 'query_results', ""
                                @unscheduled_entries = Entry.find_next_todo_entries(current_user.id) 
                                #render :partial => 'shared/subscriptions', :object => @unscheduled_entries, :locals => {:unread => true, :outline => false, :section => 5}
                                page.replace_html("query_results", :partial => "displayonlyentries", :object => @unscheduled_entries, :locals => {:unread => true, :outline => false, :section => 5})
                     end
                     when 4  #View all Someday tasks
                     render :update do |page|
                                page.hide 'pick_a_date'
                                page.replace_html 'query_results', ""
                                @unscheduled_entries = Entry.find_someday_entries(current_user.id) 
                                #render :partial => 'shared/subscriptions', :object => @unscheduled_entries, :locals => {:unread => true, :outline => false, :section => 5}
                                page.replace_html("query_results", :partial => "displayonlyentries", :object => @unscheduled_entries, :locals => {:unread => true, :outline => false, :section => 5})
                     end
               end


        
      end
      def advanced_search   
            if !request.post?
                render :partial => 'advanced_search'
            else
                #Gather the search parameters
                if params[:keywords] != nil then
                    @entries = Entry.find_tagged_with(params[:keywords])
                    tags = Tag.parse(params[:keywords])
                   @displaytags = tags.collect{|t| t}.join(", ")
                   
                    if @entries.size == 0 
                       @results_heading = "<div style='font-weight: bold;color:#107CE0;text-align:center;padding-top:10px;'>Search Results </div>No tasks found with '<i>#{@displaytags}</i>'"
                       render :inline => @results_heading
                    else
                                 @results_heading = "Results for '<i>#{@displaytags}</i>'"
                                 #Filter by scheduled date, users and public status
                                 #Check if the scheduled date provided is valid
                                 begin
                                      @scheduled_date = Date.parse(params[:scheduled_date])
                                      if params[:scheduled_date] != nil && @scheduled_date !=  nil                                                  
                                              #Prepare the users list to search in
                                              #Filter by friend user's tasks first
                                             valid_usernames = string_to_array(params[:usernames])                                                    
                                              @friend_entries = []
                                              @comm_entries = []
                                              @entries.each  do |entry|
                                                      next if  entry.public? == false || (entry.entry_status && entry.entry_status.ended?) || entry.user == current_user
                                                      if  valid_usernames.size == 0 ||   does_entry_belong_to_users(valid_usernames, entry.user.login)
                                                                @friend_entries << entry
                                                      else
                                                                @comm_entries << entry                                                                    
                                                      end                                                            
                                            end 
                                            #Now filter by the scheduled date
                                            @friend_entries_on_date = []
                                            @comm_entries_on_date = []
                                            @friend_entries.each  do |entry|
                                                if Schedulehelper.IsEntryDueOn(entry,@scheduled_date)
                                                    @friend_entries_on_date << entry if Schedulehelper.IsEntryDueOn(entry,@scheduled_date)
                                                    @friend_entries.delete(entry)
                                                else
                                                    user_tz_offset = TzTime.zone.utc_offset
                                                    tzdiff = TimeZone[entry.user.time_zone].utc_offset -  user_tz_offset  
                                                    if tzdiff > 0
                                                        #Try again for the next day
                                                        if Schedulehelper.IsEntryDueOn(entry,@scheduled_date + 1)
                                                            @alt_date = @scheduled_date + 1
                                                            @friend_entries_on_alt_date << entry if Schedulehelper.IsEntryDueOn(entry,@scheduled_date)
                                                            @friend_entries.delete(entry)
                                                        end
                                                    elsif tzdiff < 0
                                                       #Try again for the next day
                                                        if Schedulehelper.IsEntryDueOn(entry,@scheduled_date - 1)
                                                            @alt_date = @scheduled_date - 1
                                                            @friend_entries_on_alt_date << entry if Schedulehelper.IsEntryDueOn(entry,@scheduled_date)
                                                            @friend_entries.delete(entry)
                                                        end
                                                    end
                                                end
                                            end
                                            @comm_entries.each  do |entry|
                                                if Schedulehelper.IsEntryDueOn(entry,@scheduled_date)
                                                        @comm_entries_on_date << entry 
                                                        @comm_entries.delete(entry)
                                                end
                                            end
                                      end 
                                      render :partial => 'advanced_search_results'

                                rescue => err
                                     render :inline => "There was some error. Please try again later.", :type => 'rhtml'
                                     logger.error(err)
                                end               
                                 
                    end
                    
                else
                   
                             render :update do |page|                                   
                                    render :inline => "Type some keywords and Try again" , :type => 'rhtml' 
                            end
                end
            end
      end
      def filter_bookmarks 
               @showall = false        
                if params[:taglist] != nil then
                            @filtered_bks = Bookmark.find_tagged_with_by_user(params[:taglist],current_user)
                            tags = Tag.parse(params[:taglist])
                           @displaytags = tags.collect{|t| t}.join(", ")      
                 end         
                 @bookmarks = current_user.bookmarks     if (@filtered_bks && @filtered_bks.size == 0)    
                 render :update do |page|                          
                            page.replace_html 'link-bookmarks',  :partial => "filter_bookmarks"                                                  
                 end              
      end
      def show_all_bookmarks
          @showall = true
          if params[:taglist] != nil then
                            @filtered_bks = Bookmark.find_tagged_with_by_user(params[:taglist],current_user)
                            tags = Tag.parse(params[:taglist])
                           @displaytags = tags.collect{|t| t}.join(", ")      
           end  
           @bookmarks = current_user.bookmarks        
           render :update do |page|                          
                      page.replace_html 'link-bookmarks',  :partial => "filter_bookmarks"                                                  
           end      
      end
       def filter_posts 
               @showall = false        
                if params[:taglist] != nil then
                            @filtered_posts = FeedItem.find_tagged_with_by_user(params[:taglist],current_user)
                            tags = Tag.parse(params[:taglist])
                           @displaytags = tags.collect{|t| t}.join(", ")      
                 end         
                 
                  @saved_feed_items = []
                  current_user.feedsubscriptions.each{|sub| if sub.feed_items.size > 0 then sub.feed_items.each{|item| @saved_feed_items << item} end}
                 
                 render :update do |page|                          
                            page.replace_html 'link-posts',  :partial => "filter_posts"                                                  
                 end              
      end
      def show_all_posts
          @showall = true
          if params[:taglist] != nil then
                           @filtered_posts = FeedItem.find_tagged_with_by_user(params[:taglist],current_user)
                            tags = Tag.parse(params[:taglist])
                           @displaytags = tags.collect{|t| t}.join(", ")      
           end  
           @saved_feed_items = []
           current_user.feedsubscriptions.each{|sub| if sub.feed_items.size > 0 then sub.feed_items.each{|item| @saved_feed_items << item} end}
           
           render :update do |page|                          
                      page.replace_html 'link-posts',  :partial => "filter_posts"                                                  
           end      
      end
      def filter_tasks 
               @showall = false        
                tags = Tag.parse(params[:taglist])
                @displaytags = tags.collect{|t| t}.join(", ")     
               if params[:parentid] != nil
                        @childtasks = Entry.find_child_entries(TzTime.now.utc.to_date,current_user.id, params[:parentid].to_i )
                        @filtered_childtasks = Entry.find_filtered_child_entries(TzTime.now.utc.to_date,current_user.id, params[:parentid].to_i, params[:taglist])
               elsif params[:taglist] != nil then
                            tasks = Entry.find_tagged_with_by_user(params[:taglist],current_user)
                            @filtered_childtasks = []
                            tasks.each{|task| @filtered_childtasks << task if (task.end_dt_tm  >= TzTime.now.utc.to_date || task.entry_status.overdue_status?)}                           
                            @childtasks = Entry.find_all_current_entries(TzTime.now.utc.to_date,current_user.id)  if (@filtered_childtasks && @filtered_childtasks.size == 0)    
                 end  
               
                 render :update do |page|   
                           if params[:from] == 'sub-task'
                               page.replace_html 'link-child-tasks', :partial => "filter_child_tasks", :locals => {:parentid => params[:parentid]}
                          else                       
                              page.replace_html 'link-parent-tasks',  :partial => "filter_tasks"
                              page.replace_html 'link-child-tasks', :partial => "filter_child_tasks", :locals => {:parentid => nil}
                          end  
                 end              
      end
      def show_all_tasks
          @showall = true
           tags = Tag.parse(params[:taglist])
           @displaytags = tags.collect{|t| t}.join(", ")         
           if params[:parentid] != nil
                    @childtasks = Entry.find_child_entries(TzTime.now.utc.to_date,current_user.id, params[:parentid].to_i )
                    @filtered_childtasks = Entry.find_filtered_child_entries(TzTime.now.utc.to_date,current_user.id, params[:parentid].to_i, params[:taglist])
           elsif params[:taglist] != nil then
                      tasks = Entry.find_tagged_with_by_user(params[:taglist],current_user)
                      @filtered_childtasks = []
                      tasks.each{|task| @filtered_childtasks << task if (task.end_dt_tm  >= TzTime.now.utc.to_date || task.entry_status.overdue_status?)}                            
                     @childtasks = Entry.find_all_current_entries(TzTime.now.utc.to_date,current_user.id) 
             end  
           
           render :update do |page|    
                    if params[:from] == 'sub-task'
                         page.replace_html 'link-child-tasks', :partial => "filter_child_tasks", :locals => {:parentid => params[:parentid]}
                    else                       
                        page.replace_html 'link-parent-tasks',  :partial => "filter_tasks"
                        page.replace_html 'link-child-tasks', :partial => "filter_child_tasks", :locals => {:parentid => nil}
                    end                                                          
           end      
      end
      def filter_goal_resources
                 filter_resources
                  render :update do |page|   
                            page.replace_html 'link-bookmarks',  :partial => "filter_bookmarks" if @bookmarks.size > 0
                            page.replace_html 'link-posts',  :partial => "filter_posts"  if @saved_feed_items.size > 0
                            page.replace_html 'link-child-tasks', :partial => "filter_child_tasks", :locals => { :parentid => nil} if @childtasks.size > 0
                 end   
      end
      def filter_task_resources    
                filter_resources
                 render :update do |page|   
                            page.replace_html 'link-bookmarks',  :partial => "filter_bookmarks" if @bookmarks.size > 0
                            page.replace_html 'link-posts',  :partial => "filter_posts"  if @saved_feed_items.size > 0
                            page.replace_html 'link-parent-tasks',  :partial => "filter_tasks" if @childtasks.size > 0
                            page.replace_html 'link-child-tasks', :partial => "filter_child_tasks", :locals => { :parentid => nil} if @childtasks.size > 0
                 end          
      end
      
      def filter_resources
              @showall = false        
                if params[:taglist] != nil then
                            @filtered_bks = Bookmark.find_tagged_with_by_user(params[:taglist],current_user)
                            tags = Tag.parse(params[:taglist])
                           @displaytags = tags.collect{|t| t}.join(", ")      
                 end         
                 @bookmarks = current_user.bookmarks    
       
                if params[:taglist] != nil then
                            @filtered_posts = FeedItem.find_tagged_with_by_user(params[:taglist],current_user)
                            tags = Tag.parse(params[:taglist])
                           @displaytags = tags.collect{|t| t}.join(", ")      
                 end         
                   
                @saved_feed_items = []
                current_user.feedsubscriptions.each{|sub| if sub.feed_items.size > 0 then sub.feed_items.each{|item| @saved_feed_items << item} end}
                 
                 if params[:taglist] != nil then
                            tasks = Entry.find_tagged_with_by_user(params[:taglist],current_user)
                            @filtered_childtasks = []
                            tasks.each{|task| @filtered_childtasks << task if (task.end_dt_tm  >= TzTime.now.utc.to_date || task.entry_status.overdue_status?)}
                           tags = Tag.parse(params[:taglist])
                           @displaytags = tags.collect{|t| t}.join(", ")      
                 end  
                @childtasks = Entry.find_all_current_entries(TzTime.now.utc.to_date,current_user.id)  
      end
      private
      def check_if_user_data_current
        Entry.flag_user_data(current_user)  if logged_in?
      end
end
