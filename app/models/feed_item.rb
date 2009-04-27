class FeedItem < ActiveRecord::Base
    belongs_to :feed
    has_many :entry_feed_item_links, :dependent => :destroy
    has_many :entries, :through => :entry_feed_item_links
    has_many :saved_feed_items, :dependent => :destroy
    has_many :feedsubscriptions, :through => :saved_feed_items , :uniq => true
    has_many :raving_fans, :through => :saved_feed_items, :source => :feedsubscriptions, 
      :conditions => 'saved_feed_items.rating >= 4'
    acts_as_taggable
    acts_as_list :scope => :feed_id
    
    attr_accessor :emails, :comments
    
    def share(sent_by)
	FeedItemNotifier.deliver_send_emails(self,sent_by)
    end    
    
    def mark_saved
            #self.saved_feed_items.create(:feedsubscription => subscription, :rating => 3)
            self.update_attribute(:is_saved, true)
    end
    
    
     def find_saved_item(subscription)
            row = self.saved_feed_items.find( :first, :conditions =>{ :feedsubscription_id => subscription.id} )            
      end
    
end
