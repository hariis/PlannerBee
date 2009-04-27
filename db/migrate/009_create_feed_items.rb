require "migration_helpers" 
class CreateFeedItems < ActiveRecord::Migration
extend MigrationHelpers
  def self.up
    create_table :feed_items,:force => true  do |t|
			t.column :feed_id,  :integer, :null => false
			t.column :title,  :string,  :limit => 1024, :null => false
			
			t.column :published, :datetime, :null => false
			t.column :position,  :integer,   :limit => 3
			t.column :url,  :string,   :limit => 255, :null => false
                        t.column :is_saved, :boolean, :null => false, :default => false
                        t.columns << 'content mediumtext'
    end
	add_index :feed_items, :feed_id, :name => "feed_items_feed_id_index"
	add_index :feed_items, :position, :name => "feed_items_position_index"
	
	foreign_key :feed_items, :feed_id, :feeds
  end

  def self.down
    drop_table :feed_items
  end
end
