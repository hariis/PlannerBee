require "migration_helpers" 
class CreateSavedFeedItems < ActiveRecord::Migration
extend MigrationHelpers
  def self.up
    create_table :saved_feed_items, :force => true  do |t|
        t.column :feedsubscription_id, :integer, :null => false
        t.column :feed_item_id, :integer, :null => false
        t.column :created_at, :timestamp, :null => false
	t.column :updated_at, :timestamp,:null => false
        t.column :rating, :integer, :default => 0
        t.column :comments, :text
        t.column :public, :boolean, :null => false, :default => false
    end	
	
	add_index :saved_feed_items,  :feedsubscription_id
	
	foreign_key :saved_feed_items, :feedsubscription_id, :feedsubscriptions
	foreign_key :saved_feed_items, :feed_item_id, :feed_items
  end

  def self.down
    drop_table :saved_feed_items
  end
end
