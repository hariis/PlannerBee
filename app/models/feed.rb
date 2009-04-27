class Feed < ActiveRecord::Base
  
  has_many :feedsubscriptions, :dependent =>  :destroy
  has_many :users, :through => :feedsubscriptions
  has_many :feed_items, :dependent =>  :destroy   
  
  require 'feed-normalizer'  
  
  validates_presence_of :title, :message => "Please enter a title"
  validates_presence_of :url, :message => "Please enter a url"
  
  
  def self.gather    
		feeds = Feed.find(:all)
		@feedstories = []
		
		for feed in feeds
			agg = FeedNormalizer::FeedNormalizer.parse open(feed.url) 
			raise(feed.url) if agg == nil
			@feedstories = []
			
			for item in agg.entries
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
				
				#Trim the feeditems at 20 items
				itemstodelete = 0
				if (20 - feed.feed_items.size) < @feedstories.size 
					  itemstodelete = @feedstories.size - (20 - feed.feed_items.size)
					  itemstodelete = 20 if itemstodelete > 20
					  feeditems = feed.feed_items.find(:all,:conditions =>["is_saved = false"], :order => 'published ASC', :limit => itemstodelete)
					  for feeditem in feeditems                             
						FeedItem.find(feeditem.id).destroy
					  end                          
				end
					
				#update everybody's subscription
				subscriptions = Feedsubscription.find(:all, :conditions => ["feed_id = ?", feed.id])
				for subscription in subscriptions
					unread_count = subscription.unread + @feedstories.size
					subscription.update_attributes(:unread => unread_count)
					if itemstodelete != 0 then
							  #update the viewstatus in feedsubscription
							  newstatus = subscription.viewstatus << itemstodelete
							  subscription.viewstatus = newstatus & 1048575
					end				
					  
					feed.update_attributes(:latest_post => @feedstories[0].date_published)
			
				end                   
				 
				agg.clean!
				for item in @feedstories
					 #Add all items to feed_items table
					 item.clean!
					 fi = FeedItem.new
					 fi.title = item.title
					 fi.content = item.content
					 #fi.content = awesome_truncate(item.content, 500)
					 fi.published = item.date_published
					 fi.url = item.urls.first
					 feed.feed_items << fi                         
				end                  
				
			end     
		
		
		end
	end
end
