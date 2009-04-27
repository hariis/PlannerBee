class EntryFeedItemLink < ActiveRecord::Base
    belongs_to :entry
    belongs_to :feed_item  
end