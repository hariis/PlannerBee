class BookmarkController < ApplicationController
  #before_filter :login_required, :except => [:newapi,:saveapi,:listapi,:listallapi]
  before_filter :authenticate
  around_filter :set_timezone
  before_filter :is_admin, :only => [:flag]
  before_filter :check_if_user_data_current
  
  layout "common", :except => [:listapi]  
  
  def logout
    session[:user]=nil
  end
  
  def index
      @bookmarks = Bookmark.find_todays_entries(session[:user])
      @overdues = Bookmark.find_overdue_entries(session[:user])		
      @showbookmark = flash[:showbookmark] || (@bookmarks.size > 0 ? @bookmarks[0].bookmark : nil)
      @addedtoday = Bookmark.find_added_today(session[:user])		
      @related = @showbookmark ? Bookmark.find_tagged_with(@showbookmark.tags.collect{|t| t.name}.join("," )) :nil

      @query_types = {'Choose a view' => 1, 'Pick a Date ...' => 2, 'To Read Next bookmarks' => 3, 'Someday / Maybe bookmarks' => 4}
      @context = "bookmark" 
      if @showbookmark == nil
          #Display the add new bookmark form
          @bookmark =  Bookmark.new
          @entries = Entry.find_all_current_entries(TzTime.now.utc.to_date,current_user.id)
          @freqtypes = Schedulehelper::FREQ_TYPES
          @freqintervals = Schedulehelper::FREQ_INTERVALS_DAILY                       
      end
  end
  
  def new
    @bookmark = flash[:bookmark] || Bookmark.new
    @entries = Entry.find_all_current_entries(TzTime.now.utc.to_date,current_user.id)
    @freqtypes = Schedulehelper::FREQ_TYPES
    @freqintervals = Schedulehelper::FREQ_INTERVALS_DAILY 
    @context = "bookmark" 
    render :partial => 'new'
  end  
   def copy          
          @bookmark = Bookmark.find_by_id(params[:id].to_i)         
          @entries = Entry.find_all_current_entries(TzTime.now.utc.to_date,current_user.id)
        @freqtypes = Schedulehelper::FREQ_TYPES
        @freqintervals = Schedulehelper::FREQ_INTERVALS_DAILY  
        @context = params[:incontext]
	render :partial => 'new'
  end
  
  def edit
        @bookmark = Bookmark.find(params[:id])
        gather_data_for_current_bookmark		
	render :partial => 'edit', :locals => {:incontext => params[:incontext] }
  end
  def quickadd
    @user = User.find_by_id(session[:user])    
    title = params[:bktitle]
     url = params[:bkurl]
      #Save the Resource first, if not existing already
      uriRE= /^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?\/.*)?$/ix             
      if url =~ uriRE
      else
          @resource = Resource.new
           @resource.errors.add("", "Please make sure url format is appropriate")
           handle_quickadd_failure(@resource) 
           return
      end
      @resource = Resource.find(:first, :conditions => ["uri = ?", url ])
      if @resource == nil
          @resource = Resource.new(:title => title, :uri => url) 
          if !@resource.save
            handle_quickadd_failure(@resource)
            return
          end
      end
      
	  @bookmark = @user.bookmarks.find(:first, :conditions => ["resource_id = ?", @resource.id])
	  if @bookmark == nil
		  #User is not subscribed to this resource yet 	          
		  @bookmark = Bookmark.new
                  @bookmark.resource_id = @resource.id
                  @bookmark.freq_type = 0
                  @bookmark.priority = 2
                  @bookmark.tag_list=params[:bktags]	if params[:bktags] != ""
                  @bookmark.user_id=current_user.id
                  @user.bookmarks << @bookmark
                  render :update do |page|
                          #Gather the error messages
                          page.replace_html 'quickadd-status',"<div id='success'>Bookmark saved.</div>"

                          page.show 'quickadd-status'
                           page.delay(2) do
                                page.replace_html 'quickadd-status', ""
                                page.visual_effect :fade, 'quickadd-status'
                                #Updated the display of Linked bookmarks with this one
                                @showall = false        
                                if params[:bktags] != nil && params[:bktags] != "" then
                                            @filtered_bks = Bookmark.find_tagged_with_by_user(params[:bktags],current_user)
                                            tags = Tag.parse(params[:bktags])
                                           @displaytags = tags.collect{|t| t}.join(", ")      
                                 end         
                                 @bookmarks = current_user.bookmarks                                                        
                                 page.replace_html 'link-bookmarks',  :partial => "entry/filter_bookmarks"                                       
                          end                                     
                  end
          else			
              #Bookmark already exists for this resource for this user                  
              
          end
  end
   def save
      @user = User.find_by_id(session[:user])
      #Save the Resource first, if not existing already
      uriRE= /^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?\/.*)?$/ix             
      if params[:url] =~ uriRE
      else
          @resource = Resource.new
           @resource.errors.add("", "Please make sure url format is appropriate")
           handle_failure(@resource) 
           return
      end
      @resource = Resource.find(:first, :conditions => ["uri = ?", params[:url] ])
      if @resource == nil
          @resource = Resource.new(:title => params[:title], :uri => params[:url]) 
          if !@resource.save
            handle_failure(@resource)
            return
          end
      end
      
	  @bookmark = @user.bookmarks.find(:first, :conditions => ["resource_id = ?", @resource.id])
	  if @bookmark == nil
		  #User is not subscribed to this resource yet 	          
		  @bookmark = Bookmark.new(params['bookmark']) 
                  @bookmark.priority = 2   #Not any more user-settable - In order to keep the form simple and less cluttered
                  @bookmark.resource_id = @resource.id
                  begin
                       @bookmark.start_dt_tm = TzTime.at(Date.parse(params[:start])).at_beginning_of_day.utc  if params[:start] != nil   #Moving the time to 00:00            
                       @bookmark.end_dt_tm = TzTime.at(Date.parse(params[:end])).tomorrow.ago(60).utc  if params[:end] != nil   #Moving the time to 23:59 
                  rescue => err
                            @bookmark.errors.add("", err)
                            handle_failure(@bookmark)
                            return false
                  end
                  @bookmark.freq_interval = params[:freq_interval] if params[:freq_interval] != nil 
		  if (params[:freq_interval_details] != nil) then
			  fix = 0b1
			  @bookmark.freq_interval_qual = 0
			  
			  params[:freq_interval_details].collect{|char| @bookmark.freq_interval_qual |= fix << ((char.to_i)-1) } 
		  end
		 	
		  #@bookmark.tag_list=params[:tag_list]		  
				
		  if @user.bookmarks << @bookmark
		 
                      #save linked tasks next
                      if params[:parent_tasks] != nil
                          params[:parent_tasks].collect do |taskid|
                             EntryBookmarkLink.create(:entry_id => taskid.to_i, :bookmark_id => @bookmark.id) if taskid.to_i != 0	                                 
                          end
                      end	  

                      #goes to rjs
                      @bookmarks = Bookmark.find_todays_entries(session[:user])
                      @addedtoday = Bookmark.find_added_today(session[:user])
                      @showbookmark = @bookmark
                      @related = @showbookmark ? Bookmark.find_tagged_with(@showbookmark.tags.collect{|t| t.name}.join("," )) :nil
                      @context = params[:context]
                      status_message = "Bookmark saved: #{@bookmark.resource.title}"
                      @flash_message = "<div id='success'>#{status_message}</div>"
                      
                        #Removing the ability to email during bookmark creation to Simplify
                        #validate the email addresses, if any, before attempting to save 
                        #send emails
#                        emails = @bookmark.emails
#                        @bookmark.comments = params[:comments]
#                        if emails.length > 0
#                              if validate_emails(emails) 
#                                      #now send emails
#                                      @bookmark.share_bookmark(current_user) if emails.length > 0
#                                      status_message += " and shared with your friends."
#                                      @flash_message = "<div id='success'>#{status_message}</div>"
#                              else
#                                      status_message += "<br/>However, " + @invalid_emails_message
#                                      @flash_message = "<div id='success'>#{status_message}</div>"
#                              end
#                        else
#                                  @flash_message = "<div id='success'>#{status_message}</div>"
#                         end		  
				
		  else
				handle_failure(@bookmark)
		  end
          else			
              #Bookmark already exists for this resource for this user                    
              gather_data_for_current_bookmark		
              render :partial => 'edit', :locals => {:incontext => params[:context] }
          end
  end
  def handle_quickadd_failure(entity)
      #Gather the error messages
      @errorstring = ""
      entity.errors.each do |attr,e| 
              @errorstring = @errorstring + "<li>" + e + "</li>"		
      end 
      @errormessage = 
      "<div id='failure'>
      #{entity.errors.count} error(s) found.
      <ul>				
      #{@errorstring}			
      </ul>
      Please try again.
      </div>"

      render :update do |page|
              #Gather the error messages
              page.replace_html 'quickadd-status',@errormessage

              page.show 'quickadd-status'
              page.delay(10) do
                      page.replace_html 'failure', ""
                      page.visual_effect :fade, 'quickadd-status'
              end
              page.show 'quickadd'                                       
      end
  end
   
  def handle_failure(entity)
      #Gather the error messages
      @errorstring = ""
      entity.errors.each do |attr,e| 
              @errorstring = @errorstring + "<li>" + e + "</li>"		
      end 
      @errormessage = 
      "<div id='failure'>
      #{entity.errors.count} error(s) found.
      <ul>				
      #{@errorstring}			
      </ul>
      Please try again.
      </div>"

      render :update do |page|
              #Gather the error messages
              page.replace_html 'flash-notice',@errormessage

              page.show 'flash-notice'
              page.delay(10) do
                      page.replace_html 'failure', ""
                      page.visual_effect :fade, 'flash-notice'
              end
              page.show 'taskdetails'                                       
      end
  end
  
     
	def update                
		@bookmark = flash[:bookmark] || Bookmark.find(params[:id])
		
                 #Save key original data
                  old_freq_type = @bookmark.freq_type
                  old_start_dt    = @bookmark.start_dt_tm                
                @was_due_today = @bookmark.is_due_today
                #Prepare data
		freq_interval_qual = 0
		if (params[:freq_interval_details] != nil) then
			fix = 0b1           
			params[:freq_interval_details].collect{|char| freq_interval_qual |= fix << ((char.to_i)-1) } 
		end              
                
                #Set tagging parameters
                @bookmark.user_id = current_user.id                
                @bookmark.tag_list= params[:bookmark][:tag_list]
                
                 #Fill up the object                 
                  @bookmark.notes = params[:bookmark][:notes]                  
                  @bookmark.public = params[:bookmark][:public]
                  #@bookmark.priority = params[:bookmark][:priority]                  
		  
                  begin         
                  
		  @bookmark.start_dt_tm = TzTime.at(Date.parse(params[:start])).at_beginning_of_day.utc  if params[:start] != nil   #Moving the time to 00:00            
		  @bookmark.end_dt_tm = TzTime.at(Date.parse(params[:end])).tomorrow.ago(60).utc  if params[:end] != nil   #Moving the time to 23:59 
                  rescue => err
                      @bookmark.errors.add("", err)
                      handle_failure(@bookmark)
                      return false
                  end
                  @bookmark.freq_type = params[:bookmark][:freq_type]
                  @bookmark.freq_interval = params[:freq_interval]
                  @bookmark.freq_interval_qual = freq_interval_qual                 
                  
                  #Determine if set_remind_once_fields needs to be called
                  new_freq_type = params[:bookmark][:freq_type].to_i
                  new_start_dt = @bookmark.start_dt_tm
                  if old_freq_type != new_freq_type &&  isItemInList( [0,1,2,3,4,5,11],new_freq_type )  
                                @bookmark.set_remind_once_fields
                  elsif new_freq_type == 11 && old_start_dt != new_start_dt
                                @bookmark.set_remind_once_fields
                  end
                  
		if @bookmark.save                   

			#Update parent entries
			previousSelected = []
			currentSelected = []
			@bookmark.entries.each {|entry|previousSelected << entry.id} if @bookmark.entries
			
			currentSelected = params[:parent_tasks]
			
			#Add the new parent entries
			if currentSelected != nil
			  currentSelected.collect do |currentid|
                            if currentid.to_i != 0 && !isItemInList(previousSelected,currentid)
                                  EntryBookmarkLink.create(:entry_id => currentid, :bookmark_id => @bookmark.id) if currentid != 0	
                            end
			  end
			end
			#Delete the stale entry links
			if previousSelected != nil
			  previousSelected.collect do |previousid|
				if previousid.to_i != 0 && !isItemInList(currentSelected,previousid) 					
                                        EntryBookmarkLink.find(:first, :conditions => ["entry_id = ? and bookmark_id =?", previousid.to_i, @bookmark.id]).destroy
				end			
			  end
			end
			
			@bookmarks = Bookmark.find_todays_entries(session[:user])
			@overdues = Bookmark.find_overdue_entries(session[:user])			
			@addedtoday = Bookmark.find_added_today(session[:user])
                        @showbookmark = @bookmark.reload
			@related = @showbookmark ? Bookmark.find_tagged_with(@showbookmark.tags.collect{|t| t.name}.join("," )) :nil
			#goes to rjs
			@context = params[:context]

		else
			handle_failure(@bookmark)
		end
	end

	def destroy
		Bookmark.find(params[:id]).destroy
		redirect_to :action => 'index'
	end
	def items
		@entries = Bookmark.GetEntriesFor(TzTime.now.to_date,session[:user]) 
		if @entries.length == 0
			@entries = Bookmark.findallentries(TzTime.now.utc,session[:user])
		end
		@code = "success"
		render :layout => false
	end
  
	def show		
      respond_to do |format|
          format.html do
              flash[:showbookmark] =  Bookmark.find_by_id(params[:id])
              redirect_to :action => 'index'                       
          end
          format.js do
              @showbookmark = Bookmark.find_by_id(params[:id])
              @related = @showbookmark ? Bookmark.find_tagged_with(@showbookmark.tags.collect{|t| t.name}.join("," )) :nil
              @incontext = params[:incontext]	
              @displayonly = params[:displayonly]
          end
      end    
  end
	
  def list
		@bookmarks = Bookmark.find_todays_entries(session[:user])
	end
        def gather_data_for_current_bookmark
            @freqtypes = Schedulehelper::FREQ_TYPES
    
        if  @bookmark.freq_type   == 6 then
              @freqintervals = Schedulehelper::FREQ_INTERVALS_DAILY

        elsif @bookmark.freq_type   == 7 then           
              @freqintervals = Schedulehelper::FREQ_INTERVALS_WEEKLY
              @freqintervalsqual= Schedulehelper::FREQ_INTERVALS_QUAL_WEEKLY

        elsif @bookmark.freq_type   == 8 then
              @freqintervals = Schedulehelper::FREQ_INTERVALS_MONTHLY
              @freqintervalsqual= Schedulehelper::FREQ_INTERVALS_QUAL_DATE

        elsif @bookmark.freq_type   == 9 then
              @freqintervals = Schedulehelper::FREQ_INTERVALS_MONTHLY
              @freqintervalsqual= Schedulehelper::FREQ_INTERVALS_QUAL_DAY

        elsif @bookmark.freq_type   == 10 then
              @freqintervals = Schedulehelper::FREQ_INTERVALS_YEARLY

        end     
        if (@bookmark.freq_interval_qual)
          selectedvalues = Schedulehelper::ExtractFreqIntQualIntoArr(@bookmark.freq_interval_qual,true)   
          @freqintervalsqual_selected = []
          selectedvalues.each{|val|@freqintervalsqual_selected << val.to_s } 
        end
	
	#Get the parent tasks
	@parenttasks = @bookmark.find_parent_tasks(current_user.id)	
	@parenttasks_selected = []
	@bookmark.entries.each {|b|@parenttasks_selected << b.id} if @parenttasks
  end
	def listapi
		@bookmarks = Bookmark.find_todays_entries(current_user.id)
		@code = "success" if @bookmarks != nil
		respond_to do |wants|
		  wants.xml 
		end
	end
	def listall
		session[:jumpto]=request.parameters
		@bookmarks = Bookmark.findallentries(TzTime.now.utc,session[:user])
		render_action 'list'
	end
	def listallapi
		@bookmarks = Bookmark.findallentries(TzTime.now.utc,current_user.id)
		respond_to do |wants|
		  wants.xml { render :xml => @bookmarks.to_xml }
		end
	end
	def done
                user = User.find_by_id(session[:user])
		@bookmark = user.bookmarks.find_by_id( params[:id] )
		@bookmark.bookmark_status.markDone if @bookmark.bookmark_status
	
		flash[:context] = params[:incontext]
		flash[:bookmark] = @bookmark
		flash[:done] = true
		if request.xhr?
			redirect_to :action => 'completed'
		else
			redirect_to :controller => 'bookmark',:action => 'index'
		end	
	end
	def overdue_done
		user = User.find_by_id(session[:user])
		@bookmark = user.bookmarks.find_by_id( params[:id] )
		@bookmark.bookmark_status.mark_overdue_done if @bookmark.bookmark_status
                
		flash[:context] = params[:incontext]
		flash[:bookmark] = @bookmark
		flash[:overdue_done] = true
		if request.xhr?
			redirect_to :action => 'completed'
		else
			redirect_to :controller => 'bookmark',:action => 'index'
		end	
	end
	def complete
		
		@bookmark = Bookmark.find_by_id(params['id'], :conditions => ["user_id=?" , session[:user]])
		@bookmark.bookmark_status.markComplete
	  
		#redirect_to :action => 'index'
		flash[:context] = params[:incontext]		
		flash[:bookmark] = @bookmark
		flash[:completed] = true
		if request.xhr?
			redirect_to :action => 'completed'
		else
			redirect_to :controller => 'bookmark',:action => 'index'
		end
	end
	
	def completed
		@bookmark = flash[:bookmark]
                @bookmark_status = @bookmark.bookmark_status
                @showbookmark = @bookmark
                @related = @showbookmark ? Bookmark.find_tagged_with(@showbookmark.tags.collect{|t| t.name}.join("," )) :nil
                
		@context = flash[:context]
		@done = flash[:done]
		@overduedone = flash[:overdue_done]	
                @completed = flash[:completed]
		@bookmarks = Bookmark.find_todays_entries(session[:user])
		@overdues = Bookmark.find_overdue_entries(session[:user])			
	end
	
	def flag
	  Bookmark.FlagTodaysEntries()
	  #render_action 'list'
	  redirect_to :action => 'index'
	end
	def find
                if params[:want] != nil then
                    @entries = Bookmark.find_tagged_with_by_user(params[:want],current_user)
                    tags = Tag.parse(params[:want])
                    displaytags = tags.collect{|t| t}.join(", ")
                    if @entries.size == 0 
                       @results_heading = "No bookmarks found with #{displaytags}."
                    else
                       @results_heading = "Results for #{displaytags}"
                    end
                else
                    render :nothing
                end
        end
        
        def tagcloud
       
        end
        
  def send_email
	  #validate the email addresses, if any, before attempting to save 
	  #send emails
	  @bookmark = Bookmark.find_by_id(params[:id]) 
	  
	  @emails = params[:emails]
	  
	  if @emails.length > 0
		if validate_emails(@emails) 
			#now send emails
			@bookmark.share_bookmark if @emails.length > 0
			status_message = "Shared with your friends."
			@flash_message = "<div id='success'>#{status_message}</div>"
			@showbookmark = @bookmark
			@incontext = "bookmark"
		else
			status_message = @invalid_emails_message
			@flash_message = "<div id='failure'>#{status_message}</div>"
		end
	  end
  end
   def save_order
           params[:bk_list].each_with_index do |pos, idx|
                  t = BookmarkStatus.find_by_bookmark_id(pos.to_i)
                  t.position = idx
                  t.save!
            end
          
            @bookmarks = Bookmark.find_todays_entries(session[:user])
           render :update do |page|
                page.replace_html("bk_list", :partial => "shared/bookmarks", :object => @bookmarks, :locals => {:outline => false } )
                page.sortable "bk_list", :url => {:action=>:save_order}
            end            
           
      end
      def save_overdue_order
        
        params[:overduebk_list].each_with_index do |pos, idx|
                  t = BookmarkStatus.find_by_bookmark_id(pos.to_i)
                  t.overdue_position = idx
                  t.save!
            end
          
            @overdues = Bookmark.find_overdue_entries(session[:user])
           render :update do |page|
                page.replace_html("overduebk_list", :partial => "overdues", :object => @overdues )
                page.sortable "overduebk_list", :url => {:action=>:save_overdue_order}
            end 
      end
      
      def share
                #validate the email addresses, if any, before attempting to save 
                #send emails
                @bookmark = Bookmark.find_by_id(params[:id])
                @bookmark.emails = params[:bookmark][:emails]
                @bookmark.comments = params[:comments]
                if @bookmark.emails.length > 0
                      if validate_emails(@bookmark.emails) 
                              #now send emails
                              @bookmark.share_bookmark(current_user) 
                              @status_message = "<div id='success'>Bookmark shared with your friends.</div>"
                              
                      else
                              @status_message = "<div id='failure'>There was a problem sharing. <br/>" + @invalid_emails_message + "</div>"
                              
                      end
                else
                          @status_message = "<div id='failure'>Please type valid email addresses.</div>"
                 end		  
       
      end
      def view_future
                @future_entries = nil
                  begin
                          if params['future_date'] != nil && Date.parse(params[:future_date]) !=  nil
                              @future_entries = Bookmark.find_entries_for(current_user.id, params['future_date']) 
                          end 
                          render :partial => 'todays', :object => @future_entries
                
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
                   when 3  #View all unscheuled
                     render :update do |page|
                                page.hide 'pick_a_date'
                                page.replace_html 'query_results', ""
                                @unscheduled_entries = Bookmark.find_next_todo_bookmarks(current_user.id) 
                                #render :partial => 'shared/subscriptions', :object => @unscheduled_entries, :locals => {:unread => true, :outline => false, :section => 5}
                                page.replace_html("query_results", :partial => "todays", :object => @unscheduled_entries)
                     end
                   when 4 #View all unscheuled
                     render :update do |page|
                                page.hide 'pick_a_date'
                                page.replace_html 'query_results', ""
                                @unscheduled_entries = Bookmark.find_someday_bookmarks(current_user.id) 
                                #render :partial => 'shared/subscriptions', :object => @unscheduled_entries, :locals => {:unread => true, :outline => false, :section => 5}
                                page.replace_html("query_results", :partial => "todays", :object => @unscheduled_entries)
                     end
               end
      end
    
private
      def check_if_user_data_current
            Bookmark.flag_user_data(current_user) if logged_in?
      end
end
