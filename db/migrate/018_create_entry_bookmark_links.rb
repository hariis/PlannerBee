require "migration_helpers" 
class CreateEntryBookmarkLinks < ActiveRecord::Migration
extend MigrationHelpers
  def self.up
    create_table :entry_bookmark_links, :force => true  do |t|
		t.column :bookmark_id, :integer
		t.column :entry_id , :integer
    end
	
	add_index :entry_bookmark_links,  :entry_id
	add_index :entry_bookmark_links,  :bookmark_id
        
	foreign_key :entry_bookmark_links, :bookmark_id, :bookmarks
	foreign_key :entry_bookmark_links, :entry_id, :entries
  end

  def self.down
    drop_table :entry_bookmark_links
  end
end
