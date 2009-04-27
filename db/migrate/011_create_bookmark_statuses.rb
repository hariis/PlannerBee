require "migration_helpers" 
class CreateBookmarkStatuses < ActiveRecord::Migration
extend MigrationHelpers
  def self.up
    create_table :bookmark_statuses,:force => true  do |t|
		t.column :user_id,  :integer, :null => false
		t.column :bookmark_id , :integer, :null => false
		
		t.column :due_counter, :integer,   :limit => 3, :default => 0
		t.column :last_viewed, :datetime
		
		t.column :completed, :boolean, :default => false
		t.column :overdue_status,  :boolean, :default => 0
		t.column :due_today,  :boolean, :default => false
                
                t.column :position,  :integer,   :limit => 3, :default => 0
                t.column :overdue_position,  :integer,   :limit => 3, :default => 0
                t.column :completion_history, :text
                
		t.column :created_at, :timestamp, :null => false
		t.column :updated_at, :timestamp,:null => false
    end
	
	add_index :bookmark_statuses, :user_id, :name => "bookmark_statuses_user_id_index"
	add_index :bookmark_statuses, :due_today, :name => "bookmark_statuses_due_today_index"
	add_index :bookmark_statuses, :overdue_status, :name => "bookmark_statuses_overdue_status_index"	
        add_index :bookmark_statuses, :completed, :name => "bookmark_statuses_completed_index"
        add_index :bookmark_statuses, :last_viewed, :name => "bookmark_statuses_last_viewed_index"
        
        
	foreign_key :bookmark_statuses, :user_id, :users
	foreign_key :bookmark_statuses, :bookmark_id, :bookmarks
  end

  def self.down
    drop_table :bookmark_statuses
  end
end
