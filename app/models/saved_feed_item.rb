class SavedFeedItem < ActiveRecord::Base      
    belongs_to :feedsubscription
    belongs_to :feed_item
    
    def self.find_latest10_saved_posts
                find(:all, :include => [:feed_item, :feedsubscription], :conditions => ['public = 1'] , :order => "created_at desc", :limit => 10)
    end
end
