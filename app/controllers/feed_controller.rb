class FeedController < ApplicationController
  #before_filter :login_required, :except => [:newapi,:saveapi,:listapi,:listallapi,:gather]
  before_filter :authenticate
  around_filter :set_timezone
  before_filter :is_admin, :only => [:flag, :gather]
  before_filter :check_if_user_data_current
  
  require 'feed-normalizer'
  require 'rexml/document' 
  include Schedulehelper
  layout "common", :except => [:listapi]
  
  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  #verify :method => :post, :only => [ :save, :done, :update ],
   #      :redirect_to => { :action => :list }
  def logout
    session[:user]=nil
  end
  def index
              #REFACTOR WITH subscription.feed and subscription.feed.feeditems TODO
                @user = User.find_by_id(current_user.id)
                @subscriptions = Feedsubscription.find_todays_feeds(@user.id)

		#Always display the first feed's items by default
		if @subscriptions.size != 0
			#Get the first feed's items
			#subscription = Feedsubscription.find(:first, :conditions => ["user_id=? and feed_id = ?",@user.id,@feeds[0].id])
			@currentDisplayfeeditems = @subscriptions[0].find_unread_items
                        @subscription = @subscriptions[0]
		else
			@currentDisplayfeeditems = nil
                        @subscription = nil
		end
                @read_subscriptions = Feedsubscription.find_read_today(session[:user])
		@addedtoday = Feedsubscription.find_added_today(session[:user])
                @entries = Entry.find_all_current_entries(TzTime.now.to_date,current_user.id)
                @query_types = {'Choose a view' => 1, 'Pick a date' => 2}
  end  
  
  def new
          @feed = flash[:feed] || (params[:id] && Feed.find(params[:id]))  #The latter comes from the Tasks page
          if @feed == nil
                @message  = "<div id='failure'>
                                            No feeds were available. Please check the url provided and try again.
                                            </div>" 
                 render :update do |page|    
                    page.show 'flash-notice'
                    page.delay(3) do                            
                            page.visual_effect :fade, 'flash-notice'        
                    end
                    page.show 'feeddetails'
                    page.replace_html 'flash-notice', @message   
                    page.replace_html 'feeddetails', :partial => 'subscribe'                    
                 end
          else
                  #Check if user is already subscribed
                  @feedsubscription = Feedsubscription.find(:first, :conditions => ["user_id=? and feed_id = ?",current_user,@feed.id ])
                  if @feedsubscription == nil
                      @freqtypes = Feedsubscription::FREQ_TYPES
                      @freqintervals = Schedulehelper::FREQ_INTERVALS_DAILY
                      @feedsubscription = flash[:feedsubscription] ||Feedsubscription.new
                      @context = params[:context] ? params[:context] : 'feed'
                     
                        render :update do |page| 
                              page.hide 'flash-notice'
                              page.show 'feeddetails'
                              page.replace_html 'feeddetails', :partial => 'new'
                       end 
                  else
                          flash[:feed] = @feed
                          @message  = "<div id='success'>
                                            You are already subscribed. You may now edit your subscription if you wish.
                                            </div>" 
                         load_schedule_data
                          render :update do |page|   
                              page.show 'flash-notice'
                              page.show 'feeddetails'
                              page.replace_html 'flash-notice', @message
                              page.replace_html 'feeddetails', :partial => 'edit'
                          end
                  end
                  
          end
  end
	def newapi
		@feed = Feed.new
		@freqtypes = Schedulehelper::FREQ_TYPES
		@freqintervals = Schedulehelper::FREQ_INTERVALS_DAILY
	end
   def edit
      @feed = flash[:feed] || Feed.find(params[:id])
      @feedsubscription = Feedsubscription.find(:first, :conditions => ["user_id=? and feed_id = ?",session[:user],@feed.id ])
      redirect_to :action => 'list' if @feedsubscription == nil
      load_schedule_data      
      @context = params[:context] ? params[:context] : 'feed'
       render :update do |page|   
              page.hide 'flash-notice'             
              page.show 'feeddetails'
              page.replace_html 'feeddetails', :partial => 'edit'
       end 
  end
   
	
	
   def subscribe
		render :partial => 'subscribe'
   end
   def validate_feed
          @user = User.find_by_id(current_user.id)
          feedurl = params[:url]
          @feed = Feed.find_by_url(feedurl)
          if @feed == nil	
                  #Validate the feed first
                  begin
                      agg = FeedNormalizer::FeedNormalizer.parse open(feedurl)

                      if agg == nil
                              links = []
                              links = parse(feedurl)
                              links.each do |url| 
                                  agg = FeedNormalizer::FeedNormalizer.parse open(url)
                                  if agg != nil 
                                      feedurl = url
                                  end
                              end                                                            
                      end
                  rescue  Exception => err
                            @feed = nil
                  end
                  if agg != nil
                       @feed = Feed.find_by_url(feedurl)
                        if @feed == nil
                            title = agg.title[0...250]
                            @feed = Feed.new(:title => title, :url => feedurl)        
                            @feed.save
                        end
                  end						
          end
          flash[:feed] = @feed
          redirect_to :action => :new
   end
   def save
        #raise params.inspect
        @user = User.find_by_id(current_user.id)
        @feed = Feed.find_by_id(params[:id])

        savesubscription	  
  end
  def savesubscription
	@feedsubscription = Feedsubscription.find(:first, :conditions => ["user_id=? and feed_id = ?",session[:user],@feed.id ])
	if @feedsubscription == nil
	  @feedsubscription = Feedsubscription.new(params[:feedsubscription])
	  @feedsubscription.tag_list=params[:feedsubscription][:tag_list]
	  @feedsubscription.feed_id = @feed.id
	  
	  @feedsubscription.unread = @feed.feed_items.size
	  begin
	  @feedsubscription.start_dt_tm = TzTime.at(Date.parse(params[:start])).at_beginning_of_day.utc  if params[:start] != nil   #Moving the time to 00:00            
	  @feedsubscription.end_dt_tm = TzTime.at(Date.parse(params[:end])).tomorrow.ago(60).utc  if params[:end] != nil   #Moving the time to 23:59 
          rescue => err
              @feedsubscription.errors.add("", err)
              handle_failure
              return false
          end
	  @feedsubscription.freq_type = params[:feedsubscription][:freq_type]
	  @feedsubscription.freq_interval = params[:freq_interval]
	  if (params[:freq_interval_details] != nil) then
		  fix = 0b1
		  @feedsubscription.freq_interval_qual = 0
		  
		  params[:freq_interval_details].collect{|char| @feedsubscription.freq_interval_qual |= fix << ((char.to_i)-1) } 
	  end      


	  if @user.feedsubscriptions << @feedsubscription
		  feeds =[]
		  feeds << @feed
		  getitems(feeds)  #TODO This may be a bad idea - May take longer and save will be delayed
		  
		  #goes to rjs
		  @status_message = "#{@feed.title} subscribed."
		  #@feedsubscription.flag_for_pickup
		  @feedsubscription.reload
		  @subscriptions = Feedsubscription.find_todays_feeds(session[:user])
                  @addedtoday = Feedsubscription.find_added_today(session[:user])
                  @currentDisplayfeeditems = @feedsubscription.find_unread_items
                  @context = params[:context]
		  render(:action => :save)
	  else			  
		  handle_failure
	  end	
	end
  end
  def handle_failure
    
            #Gather the error messages
            #Why doesn't new template see this @entry object 
            @errorstring = ""

            @feedsubscription.errors.each do |attr,e| 
                    @errorstring = @errorstring + "<li>" + e + "</li>"		
            end
            @errormessage = 
            "<div id='failure'>
            #{@feedsubscription.errors.count} error(s) found.
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
              page.show 'feeddetails'                                       
              end    
  end
  def saveapi
      @user = User.find_by_id(session[:user])
      @feed = Feed.new(params['feed'])
      if (params[:freqintervalsqual] != nil) then
          fix = 0b1
          @feed.freq_interval_qual = 0
          
          params[:freqintervalsqual].collect{|char| @feed.freq_interval_qual |= fix << ((char.to_i)-1) } 
      end
        
       @feed.user_id = @user.id
       @feed.tag_list=params[:tag_list]
         
      if @feed.save
          flash[:notice]="Successfully saved #{@feed.title}"
      else
          flash[:warning]="Save failed. Try Again"
          redirect_to :action => 'new'
        end
  end

	def show2
		session[:jumpto]=request.parameters
		@user = User.find_by_id(session[:user])
		@subscriptions = []
		if (params[:id])
		  @subscriptions = Feedsubscription.find(:all, :conditions => ["user_id=? and feed_id = ?",session[:user],params[:id] ])
		else
		  @subscriptions = Feedsubscription.GetEntriesFor(TzTime.now.to_date,session[:user])
		end

		@feeds =[]        
		for subscription in @subscriptions  
			@currentDisplayfeeditems = subscription.find_unread_items
			 feed = Feed.find_by_id(subscription.feed_id)
			 #~ feeditems = feed.feed_items.find(:all, :conditions => ["? > ?", published, subscription.last_item_read])
			 @feeds << [feed  , @currentDisplayfeeditems ]             
		end
		@savedsubscription = flash[:feedsubscription] || nil
		
	end
    def show #TODO check if displayonly is used
          @user = User.find_by_id(session[:user])
          @subscription = Feedsubscription.find(:first, :conditions => ["user_id=? and feed_id = ?",@user.id,params[:id] ])
          @entries = Entry.find_all_current_entries(TzTime.now.to_date,current_user.id)
          if params[:unread] == "true"
                  @currentDisplayfeeditems = @subscription.find_unread_items
                  render :partial => 'shared/feeddetails', :locals => {:unread => params[:unread], :subscription => @subscription}
          else
                  @currentDisplayfeeditems = @subscription.find_read_items
                  render :partial => 'shared/feeddetails', :locals => {:unread => params[:unread], :subscription => @subscription}
          end	

  end
	def list        
		session[:jumpto]=request.parameters
		@user = User.find_by_id(current_user_id)
		@subscriptions = Feedsubscription.GetEntriesFor(TzTime.now.to_date,session[:user])
		@feeds =[]        
		for subscription in @subscriptions             
			 feed = Feed.find_by_id(subscription.feed_id)       
			 @feeds << feed            
		end   
	end
     def listapi
       
       session[:jumpto]=request.parameters
        @user = User.find_by_id(current_user_id)
        session[:user] = current_user_id
        @subscriptions = Feedsubscription.GetEntriesFor(TzTime.now.to_date,current_user_id)
        @feeds =[]
        for subscription in @subscriptions  
             #@currentDisplayfeeditems = Feedsubscription.find_unread_items(subscription)
             feed = Feed.find_by_id(subscription.feed_id)             
             @feeds << [feed  , subscription ]             
        end
        @code = "success" if @feeds != nil
        respond_to do |wants|
            wants.xml
            #If hash, then you see <nil-classes> in output
            #wants.xml { render :xml => @user.to_xml}
        end
        
     end
     def listall
        session[:jumpto]=request.parameters
        @user = User.find_by_id(current_user_id)
        @subscriptions = Feedsubscription.findallentries(TzTime.now.utc,session[:user])
        @feeds =[]        
        for subscription in @subscriptions      
             feed = Feed.find_by_id(subscription.feed_id)       
             @feeds << feed            
        end 
        render_action 'list'
      end
      def listallapi
        @entries = Feed.findallentries(TzTime.now.utc,current_user_id)
        respond_to do |wants|
          wants.xml { render :xml => @entries.to_xml }
        end
      end
      
    def done  #read  #TODO Move this to Feed.rb
          @subscription = Feedsubscription.find_by_id(params[:subscription_id])      
          
          #subscription.update_attribute(:viewstatus, viewstatus)
           if @subscription.mark_read(params[:id])
              #@currentDisplayfeeditems = @subscription.find_unread_items
              @feeditem = FeedItem.find_by_id(params[:id])
              @item_saved = false 
              @context = params[:context]              
          else
              flash[:warning]="There is some problem with this subscription. Please refresh and try again."
              flash[:feedsubscription] = @subscription
              redirect_to :action => 'index'
          end
        end
    
        def mark_all_read
          
           @subscription = Feedsubscription.find_by_id(params[:subscription_id])         
         
          if @subscription.mark_all_read then                         
                  redirect_to :action => 'index' 
           else
                  flash[:warning]="There is some problem with this subscription. Please refresh page and try again."
                  flash[:feedsubscription] = @subscription
                  redirect_to :action => 'index'              
          end
          #subscription.update_attribute(:viewstatus, viewstatus)
          
        end
        def update
                    @feed = Feed.find(params[:id])
              
                    @feedsubscription = Feedsubscription.find(:first, :conditions => ["user_id=? and feed_id = ?",session[:user],@feed.id ])
                    @was_due_today = @feedsubscription.due_today?
                    @feedsubscription.tag_list= params[:feedsubscription][:tag_list]
                    
                    freq_interval_qual = 0
                    if (params[:freq_interval_details] != nil) then
                        fix = 0b1           
                        params[:freq_interval_details].collect{|char| freq_interval_qual |= fix << ((char.to_i)-1) } 
                    end              
                    begin
                    start_dt = TzTime.at(Date.parse(params[:start])).at_beginning_of_day.utc  if params[:start] != nil   #Moving the time to 00:00            
                    end_dt = TzTime.at(Date.parse(params[:end])).tomorrow.ago(60).utc  if params[:end] != nil   #Moving the time to 23:59 
                    rescue => err
                      @feedsubscription.errors.add("", err)
                      handle_failure
                      return false
                    end 
                      if @feedsubscription.update_attributes(
                           :start_dt_tm => start_dt, :end_dt_tm => end_dt,
                         :freq_type => params[:feedsubscription][:freq_type], :freq_interval => params[:freq_interval],:freq_interval_qual => freq_interval_qual )

                            #goes to rjs
                            @feedsubscription.reload
                            @status_message = "#{@feed.title} subscription updated."
                            #@feedsubscription.flag_for_pickup
                            @context = params[:context]
                            if @feedsubscription.due_today?
                                @subscriptions = Feedsubscription.find_todays_feeds(session[:user])
                                @show_subscription = @feedsubscription
                                @currentDisplayfeeditems = @feedsubscription.find_unread_items
                                @subscriptions = Feedsubscription.find_todays_feeds(session[:user])
                            else
                                @subscriptions = Feedsubscription.find_todays_feeds(session[:user])
                                @show_subscription = @subscriptions.size > 0 ? @subscriptions[0] : nil
                                @currentDisplayfeeditems =  @show_subscription && @show_subscription.find_unread_items
                            end                           
                      else
                            handle_failure
                      end               
        end
      
      def destroy
        
        jumpto = session[:jumpto] || {:controller => 'feed', :action => 'list'}
        session[:jumpto] = nil
                
        @feed = Feed.find(params[:id])
        title = @feed.title
        @feedsubscription = Feedsubscription.find(:first, :conditions => ["user_id=? and feed_id = ?",session[:user],@feed.id ])
        @feedsubscription.destroy if @feedsubscription
        flash[:message]= "#{title} unsubscribed."
        #clean up feed if there is no one else subscribed
        @feedsubscription = Feedsubscription.find(:all, :conditions => ["feed_id = ?",@feed.id ])
        if @feedsubscription.size == 0
          @feed.feed_items.destroy_all
          @feed.destroy 
        end
        redirect_to(jumpto)
      end
      def unsubscribe
		@subscription = Feedsubscription.find_by_id(params[:id], :conditions => ["user_id=?" , session[:user]])
		@subscription.destroy
	  
		redirect_to :action => 'index'
	  end
      
      def gather
            #~ @user = User.find_by_id(current_user_id)
            #~ @subscriptions = Feedsubscription.GetEntriesFor(TzTime.now.to_date,session[:user])
            #~ feeds = []
            #~ for subscription in @subscriptions  
                 #~ feed = Feed.find_by_id(subscription.feed_id)
                 #~ feeds << feed 
            #~ end
            feeds = Feed.find(:all)
            @feedstories = []
            getitems(feeds)
            
          redirect_to :action => 'index'
      end

	def flag
		Feedsubscription.FlagTodaysEntries()
		redirect_to :action => 'index'
	end

    def view_future
          @future_entries = nil
            begin
                    if params['future_date'] != nil && Date.parse(params[:future_date]) !=  nil
                        @future_entries = Feedsubscription.find_entries_for(current_user.id, params['future_date']) 
                    end 
                    render :partial => 'shared/subscriptions', :object => @future_entries, :locals => {:unread => true, :outline => false, :section => 5}

            rescue 
                  render :text => "Invalid date"
            end
      end        
     
      def view_saved
                 @subscription = Feedsubscription.find_by_id(params[:subscription_id])  
                 @currentDisplayfeeditems = @subscription.feed_items.find(:all, :order => "published desc")
                 render :partial => 'shared/feeddetails', :locals => {:unread => true, :subscription => @subscription}
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
                                @unscheduled_entries = Feedsubscription.find_unscheduled_entries(current_user.id) 
                                #render :partial => 'shared/subscriptions', :object => @unscheduled_entries, :locals => {:unread => true, :outline => false, :section => 5}
                                page.replace_html("query_results", :partial => "shared/subscriptions", :object => @unscheduled_entries, :locals => {:unread => true, :outline => false, :section => 5})
                     end
               end


        
      end
private
	

def getitems(feeds)

	for feed in feeds
		agg = FeedNormalizer::FeedNormalizer.parse open(feed.url) 
		raise(feed.url) if agg == nil
		@feedstories = []
		
		for item in agg.entries
    item.date_published = Time.now.utc unless item.date_published
			if !feed.latest_post
				@feedstories.push(item)
			else
				 if item.date_published > feed.latest_post                   
					@feedstories.push(item)
				end
			end
		end
		
		if (@feedstories.size > 0)
			@feedstories.sort! { |a,b| b.date_published <=> a.date_published }
			
			#Take the latest 20 only at the max
                        @feedstories = @feedstories[0...20]
      
                        #Make room in DB for the latest feed items
                        #We store a max of 20 items only at any given time
                        #Hence delete feed items up to 20 to store the newer items just gathered
			itemstodelete = 0
                        stored_feed_items = feed.feed_items.find(:all, :conditions => ["is_saved = false"], :order => 'published ASC')
                        stored_count = stored_feed_items.size
                        space_left = (20 - stored_count)
			if space_left < @feedstories.size 
				  itemstodelete = @feedstories.size - space_left
				  itemstodelete = stored_count if itemstodelete > stored_count
				  feeditems = stored_feed_items[0...itemstodelete]
				  for feeditem in feeditems                             
					FeedItem.find(feeditem.id).destroy
				  end                          
			end
				
			#update everybody's subscription
			subscriptions = Feedsubscription.find(:all, :conditions => ["feed_id = ?", feed.id])
			for subscription in subscriptions				
				if itemstodelete != 0 then
						  #update the viewstatus in feedsubscription
						  newstatus = subscription.viewstatus << itemstodelete  #Ex: 7 << 1 returns 14
						  subscription.viewstatus = newstatus & 1048575              #Ex: 14 & 7 returns 6
				end
                                
				total_unread_count = subscription.unread + @feedstories.size
                                
				subscription.update_attributes(:unread => total_unread_count  ) 

        
				#feed.update_attribute(:latest_post , @feedstories[0].date_published)
                                feed.update_attribute(:latest_post , Time.now.utc)
			end                   
			 
			agg.clean!
			for item in @feedstories
				 #Add all items to feed_items table
				 item.clean!
				 fi = FeedItem.new
				 fi.title = item.title[0...1024]
				 fi.content = item.content
				 uriRE= /^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?\/.*)?$/ix             
                                 if item.content =~ uriRE
                                        fi.content = item.description
                                 end
				 fi.published = item.date_published
				 fi.url = item.urls.first
				 feed.feed_items << fi                         
			end                  
			
		end     
	end

end
def parse2(url)
    doc = REXML::Document.new Net::HTTP.get(URI.parse(url))
    links = []
    data = []
     root = doc.root
     root.elements["head"].each_element("//link") {|link| links << link} 
    links.each do |link|
        type = link.attributes['type']
        if type == "application/rss+xml" || type == "application/atom+xml"
          data << link.attributes['href']
        end  
    end    
    return data
end
def parse(url)
  open(url, "User-Agent" => "Ruby/#{RUBY_VERSION}",
    "From" => "",
    "Referer" => "") { |f|
                 
    # Save the response body
    @doc = f.read
    # HPricot RDoc: http://code.whytheluckystiff.net/hpricot/
    doc = Hpricot(@doc)
    
  # Retrive the links
  urls = []
  (doc/"/html/head/link").each do |link|
     type = link.attributes['type']
        if type == "application/rss+xml" || type == "application/atom+xml"
          urls << link.attributes['href']
        end
  end
  
  return urls
  }
end
private
      def check_if_user_data_current
        Feedsubscription.flag_user_data(current_user)  if logged_in?
    end
    def load_schedule_data
        @freqtypes = Feedsubscription::FREQ_TYPES    
        
      if  @feedsubscription.freq_type   == 6 then
            @freqintervals = Schedulehelper::FREQ_INTERVALS_DAILY
            
      elsif @feedsubscription.freq_type   == 7 then           
            @freqintervals = Schedulehelper::FREQ_INTERVALS_WEEKLY
            @freqintervalsqual= Schedulehelper::FREQ_INTERVALS_QUAL_WEEKLY
                                   
      elsif @feedsubscription.freq_type   == 8 then
            @freqintervals = Schedulehelper::FREQ_INTERVALS_MONTHLY
            @freqintervalsqual= Schedulehelper::FREQ_INTERVALS_QUAL_DATE
            
      elsif @feedsubscription.freq_type   == 9 then
            @freqintervals = Schedulehelper::FREQ_INTERVALS_MONTHLY
            @freqintervalsqual= Schedulehelper::FREQ_INTERVALS_QUAL_DAY
                        
      elsif @feedsubscription.freq_type   == 10 then
            @freqintervals = Schedulehelper::FREQ_INTERVALS_YEARLY
            
      end     
      
      if (@feedsubscription.freq_interval_qual)
          selectedvalues = Schedulehelper::ExtractFreqIntQualIntoArr(@feedsubscription.freq_interval_qual,true)   
          @freqintervalsqual_selected = []
          selectedvalues.each{|val|@freqintervalsqual_selected << val.to_s }
      end 
   end
end
