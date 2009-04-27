class EntryBookmarkLink < ActiveRecord::Base
  belongs_to :bookmark
  belongs_to :entry  
end
