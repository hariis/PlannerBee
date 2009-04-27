require "migration_helpers" 
class CreateEntryFeedItemLinks < ActiveRecord::Migration
extend MigrationHelpers
  def self.up
    create_table :entry_feed_item_links, :force => true  do |t|
		t.column :entry_id , :integer, :null => false
                t.column :feed_item_id, :integer, :null => false
    end
	
	add_index :entry_feed_item_links, :feed_item_id
	add_index :entry_feed_item_links,  :entry_id
	
	foreign_key :entry_feed_item_links, :feed_item_id, :feed_items
	foreign_key :entry_feed_item_links, :entry_id, :entries
  end

  def self.down
    drop_table :entry_feed_item_links
  end
end