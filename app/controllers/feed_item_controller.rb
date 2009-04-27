class FeedItemController < ApplicationController
    #before_filter :login_required
    before_filter :authenticate
    around_filter :set_timezone
    layout "feed"
    
    def share
          #validate the email addresses, if any, before attempting to save 
          #send emails
          @feeditem = FeedItem.find_by_id(params[:id])
          item_id = "emails_" + "#{@feeditem.id}"
          @feeditem.emails = params[:feed_item][item_id]
          @feeditem.comments = params[:comments]
          if @feeditem.emails.length > 0
              if validate_emails(@feeditem.emails) 
                      #now send emails
                      begin
                              @feeditem.share(current_user) 
                              @status_message = "<div id='success'>Post shared with your friends.</div>"
                      rescue
                             @status_message = "<div id='failure'>There was a problem sending. Please try again in a few minutes.</div>"
                      end
              else
                      @status_message = "<div id='failure'>There was a problem sharing. <br/>" + @invalid_emails_message + "</div>"
              end
          else
              @status_message = "<div id='failure'>Please type valid email addresses.</div>"
           end		  
       
      end   
    def save
          @feeditem = FeedItem.find_by_id(params[:id])
          if params[:subscription_id].to_i != 0
            @subscription = Feedsubscription.find_by_id(params[:subscription_id])
          else
            @subscription = Feedsubscription.new(:feed_id => @feeditem.feed.id, :freq_type => 0 )
            current_user.feedsubscriptions << @subscription
          end
          @feeditem.user_id = current_user.id
          @feeditem.tag_list= params[:feed_item][:tag_list]
          
          #Create a saved feed item object
          saved_feed_item = SavedFeedItem.new(:feedsubscription => @subscription, :rating => 3,
                                    :comments => params[:comments], :public => params[:public])
          @feeditem.saved_feed_items << saved_feed_item
          @feeditem.mark_saved
          
          #save linked tasks next
          if params[:parent_tasks] != nil
              params[:parent_tasks].collect do |taskid|
                 EntryFeedItemLink.create(:entry_id => taskid.to_i, :feed_item_id => @feeditem.id) if taskid.to_i != 0	                                 
              end
          end
          #Mark feed item as read
          @context = params[:context]
          @subscription.mark_read(@feeditem.id)  if @context == "feed"
          
          @comments = params[:comments]
          
          #@currentDisplayfeeditems = @subscription.find_unread_items # We simply scroll up
          @item_saved = true
          render :template => 'feed/done', :layout => false
    end
    def show
      @feeditem = FeedItem.find_by_id(params[:id])
      @feed = @feeditem.feed
      @subscription = Feedsubscription.find(:first, :conditions => ["user_id = ? and feed_id =?", current_user.id, @feed.id] )
      
      if @subscription != nil
           @my_saved_item = @subscription.saved_feed_items.find(:first, :conditions =>{ :feed_item_id => @feeditem.id})
           @my_comments = @my_saved_item ?   @my_saved_item.comments : nil 
           @subscription_id = @subscription.id
      else
           @subscription_id = 0
      end
      @task_owner = User.find_by_id(params[:task_owner])
      if (current_user != @task_owner)
          @task_owner_subscription = Feedsubscription.find(:first, :conditions => ["user_id = ? and feed_id =?", @task_owner.id, @feed.id] )
          if @task_owner_subscription 
               saved_item = @task_owner_subscription.saved_feed_items.find(:first, :conditions =>{ :feed_item_id => @feeditem.id})
               @owner_comments =  (saved_item  && saved_item.public?) ?   saved_item.comments : nil     
          end
      end
    end
end
