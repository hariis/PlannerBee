require "authenticated_system"
 
class ApplicationController < ActionController::Base
        require 'entry'
        sliding_session_timeout  2.weeks
         include AuthenticatedSystem         
         session :session_key => '_plannerbee_session_id'
         
   def authenticate
       case request.format
             when Mime::XML, Mime::ATOM
                   if user = authenticate_with_http_basic { |u, p| User.authenticate(u, p) }                            
                      session[:user] = user.id
                   else
                     request_http_basic_authentication
                   end
             else
                  login_required                        
             end
    end
        def displaydate       
               if params[:freqtype] == '0' ||params[:freqtype] == '1' || params[:freqtype] == '2' || params[:freqtype] == '3' || params[:freqtype] == '4' || params[:freqtype] == '5'  || params[:freqtype] == '12'
                  render :nothing => true
               else          
                  #qualstr ="<%= select_tag 'flavors[]',    options_for_select(     @freqintervalsqual.sort{|v1,v2| v1[0].to_i<=>v2[0].to_i}.collect{|k| [ k[1],k[0] ]} ),  { :multiple => true, :size =>7 } %>"

                  if  params[:freqtype]   == '6' then
                        @freqintervals = Schedulehelper::FREQ_INTERVALS_DAILY
                        #qualstr = ""
                  elsif params[:freqtype]   == '7' then
                        @freqintervals = Schedulehelper::FREQ_INTERVALS_WEEKLY
                        @freqintervalsqual= Schedulehelper::FREQ_INTERVALS_QUAL_WEEKLY

                  elsif params[:freqtype]   == '8' then
                        @freqintervals = Schedulehelper::FREQ_INTERVALS_MONTHLY
                        @freqintervalsqual= Schedulehelper::FREQ_INTERVALS_QUAL_DATE

                  elsif params[:freqtype]   == '9' then
                        @freqintervals = Schedulehelper::FREQ_INTERVALS_MONTHLY
                        @freqintervalsqual= Schedulehelper::FREQ_INTERVALS_QUAL_DAY

                  elsif params[:freqtype]   == '10' then
                        @freqintervals = Schedulehelper::FREQ_INTERVALS_YEARLY
                        #qualstr = ""
                  end
        #          datestring = "<table>
        #                        <tr><td>Starting: <%= date_select 'bookmark', 'start_dt' %></td>
        #                            <td>Ending:  <%= date_select :bookmark, :end_dt %></td>
        #                        </tr></table>"    
        #          htmlstring = datestring + "<table><tr><td><%= select_tag 'freq_interval',options_for_select(  @freqintervals.sort{|v1,v2| v1[0].to_i<=>v2[0].to_i}.collect{|k| [ k[1],k[0] ]} ),:selected => '1'%></td><td>" + qualstr + "</td></tr></table>"

                  #render :inline => htmlstring    
                  render :partial => "shared/displaydate"
               end


         end         
        def auto_complete_for_entry_tag_list
              auto_complete_for_tag_list
        end 
        def auto_complete_for_bookmark_tag_list
              auto_complete_for_tag_list
        end
        def auto_complete_for_feedsubscription_tag_list
             @controller = 'feedsubscription'   #TODO Create a separate controller for feedsubscription
              auto_complete_for_tag_list
        end
        def auto_complete_for_feed_item_tag_list
              @controller = 'feed_item'
              auto_complete_for_tag_list
        end
        def auto_complete_for_tag_list
          @tags = []
          controller = @controller ? @controller : controller_name
          keyword = params[:"#{controller}"][:tag_list]
          unless keyword.blank?
                criteria = keyword + '%'
                @tags  = Tag.find(:all, :conditions=>["name like ?",criteria])
          end
          render :partial => "shared/autocomplete_tag_list"
        end
        def feedback            
            comment =  PlannerbeeComment.new(:comment_type => params[:comment_type], 
               :description => params[:comment_text], :user_id => current_user.id )  
            comment.save_and_notify
            render :nothing => true
        end
         def filter_tasks 
               @showall = false        
                if params[:taglist] != nil then
                            tasks = Entry.find_tagged_with_by_user(params[:taglist],current_user)
                            @filtered_tasks = []
                            tasks.each{|task| @filtered_tasks << task if task.end_dt_tm  >= TzTime.now.utc.to_date}
                           tags = Tag.parse(params[:taglist])
                           @displaytags = tags.collect{|t| t}.join(", ")      
                 end           
                @entries = Entry.find_all_current_entries(TzTime.now.utc.to_date,current_user.id)  if (@filtered_tasks && @filtered_tasks.size == 0)        
                 render :update do |page|                          
                            page.replace_html 'link-tasks',  :partial => "shared/filter_tasks"                                                  
                 end              
      end
      def show_all_tasks
          @showall = true
           if params[:taglist] != nil then
                            tasks = Entry.find_tagged_with_by_user(params[:taglist],current_user)
                            @filtered_tasks = []
                            tasks.each{|task| @filtered_tasks << task if task.end_dt_tm  >= TzTime.now.utc.to_date}
                           tags = Tag.parse(params[:taglist])
                           @displaytags = tags.collect{|t| t}.join(", ")      
           end   
           @entries = Entry.find_all_current_entries(TzTime.now.utc.to_date,current_user.id) 
           render :update do |page|                          
                      page.replace_html 'link-tasks',  :partial => "shared/filter_tasks"                                                  
           end      
      end
      def filter_resources
         @showall = false        
                 if params[:taglist] != nil then
                            tasks = Entry.find_tagged_with_by_user(params[:taglist],current_user)
                            @filtered_tasks = []
                            tasks.each{|task| @filtered_tasks << task if task.end_dt_tm  >= TzTime.now.utc.to_date}
                           tags = Tag.parse(params[:taglist])
                           @displaytags = tags.collect{|t| t}.join(", ")      
                 end  
                @entries = Entry.find_all_current_entries(TzTime.now.utc.to_date,current_user.id)  if (@filtered_tasks && @filtered_tasks.size == 0)                 
                 render :update do |page|   
                            page.replace_html 'link-tasks',  :partial => "shared/filter_tasks" 
                 end          
      end
     private
	def is_admin
		current_user.has_role?("admin")
	end
	def isItemInList(list, item)
		if list != nil then
		  list.each do |p|
			return true if p.to_i == item.to_i
		  end
		end
		return false
	end
        alias :does_entry_belong_to_users :isItemInList 
	def validate_emails(emails)		
            #Parse the string into an array
              valid_emails =[]
              valid_emails = string_to_array(emails)             

              offending_email = ""
              addresses = []
              valid_emails.each {|email|
                      if validate_simple_email(email)
                             addresses << email
                              next
                      elsif  validate_ab_style_email(email)
                                addresses << email
                                next
                      else
                          offending_email = email
                              break
                      end			
              }

              if offending_email == ""
                      return true
              else
                  @invalid_emails_message = "Email address: #{offending_email} incorrect.	Please try again."
                      return false
              end
         end   
   def validate_simple_email(email)
        emailRE= /\A[\w\._%-]+@[\w\.-]+\.[a-zA-Z]{2,4}\z/
        return email =~ emailRE
   end         
   def validate_ab_style_email(email)
        email.gsub!(/\A"/, '\1')	 
	 str = email.split(/ /)		 
	 str.delete_if{|x| x== ""}
	 email = str[str.size-1].delete "<>"
	 emailRE= /\A[\w\._%-]+@[\w\.-]+\.[a-zA-Z]{2,4}\z/
	 return email =~ emailRE
   end
    def string_to_array(stringitem)
                #Parse the string into an array
              valid_array =[]
              return if stringitem == nil
              valid_array.concat(stringitem.split(/,/))

              # delete any blank emails
              valid_array = valid_array.delete_if { |t| t.empty? }

              # trim spaces around all tags
              valid_array = valid_array.map! { |t| t.strip }

              # downcase all tags
              valid_array = valid_array.map! { |t| t.downcase }

              # remove duplicates
              valid_array = valid_array.uniq
    end
    def set_timezone
        TzTime.zone =TimeZone[current_user.time_zone]     if logged_in?         
        yield
        TzTime.reset!
    end
    
end