require "migration_helpers" 
class CreateFeedsubscriptions < ActiveRecord::Migration
extend MigrationHelpers
  def self.up
    create_table :feedsubscriptions,:force => true  do |t|
          t.column :user_id,  :integer, :null => false
          t.column :feed_id,  :integer, :null => false

          t.column :start_dt_tm, :datetime, :null => false
          t.column :end_dt_tm, :datetime, :null => false
          t.column :freq_type,  :integer,   :limit => 2, :null => false
          t.column :freq_interval, :integer,   :limit => 2
          t.column :freq_interval_qual, :integer

          t.column :unread, :integer,   :limit => 3, :default => 0
          t.column :viewstatus, :integer, :default => 0

          t.column :priority,  :integer,   :limit => 2			

          t.column :due_today,  :boolean, :default => false			

          t.column :created_at, :timestamp, :null => false
          t.column :updated_at, :timestamp,:null => false
    end
	add_index :feedsubscriptions, :user_id, :name => "feedsubscriptions_user_id_index"
	add_index :feedsubscriptions, :feed_id, :name => "feedsubscriptions_feed_id_index"
	add_index :feedsubscriptions, :due_today, :name => "feedsubscriptions_due_today_index"
        add_index :feedsubscriptions, :created_at, :name => "feedsubscriptions_created_at_index"
        add_index :feedsubscriptions, :viewstatus, :name => "feedsubscriptions_viewstatus_index"
        add_index :feedsubscriptions, :unread, :name => "feedsubscriptions_unread_index"
        add_index :feedsubscriptions, :start_dt_tm, :name => "feedsubscriptions_start_dt_tm_index"
        add_index :feedsubscriptions, :end_dt_tm, :name => "feedsubscriptions_end_dt_tm_index"
        
	foreign_key :feedsubscriptions, :user_id, :users
	foreign_key :feedsubscriptions, :feed_id, :feeds
  end

  def self.down
    drop_table :feedsubscriptions
  end
end
