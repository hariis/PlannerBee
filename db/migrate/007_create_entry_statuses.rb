require "migration_helpers" 
class CreateEntryStatuses < ActiveRecord::Migration
extend MigrationHelpers
  def self.up
    create_table :entry_statuses,:force => true  do |t|
		t.column :user_id,  :integer, :null => false
		t.column :entry_id , :integer, :null => false
		
		t.column :times_scheduled,  :integer,   :limit => 3, :default => 0
		t.column :times_done,  :integer,   :limit => 3, :default => 0
		t.column :times_donelate,  :integer,   :limit => 3, :default => 0
		t.column :times_skipped,  :integer,   :limit => 3, :default => 0
		
		t.column :overdue_status,  :boolean, :default => false
		t.column :due_today,  :boolean, :default => false               
                
                t.column :last_marked, :datetime  #Necessary for calculating the latest entries
                                
                t.column :ended,  :boolean, :default => false                
                t.column :skipped_on, :text
                t.column :completion_history, :text
                
                t.column :position,  :integer,   :limit => 3, :default => 0
                t.column :overdue_position,  :integer,   :limit => 3, :default => 0
                
		t.column :created_at, :timestamp, :null => false
		t.column :updated_at, :timestamp,:null => false
    end
	
	add_index :entry_statuses, :user_id, :name => "entry_statuses_user_id_index"
	add_index :entry_statuses, :overdue_status, :name => "entry_statuses_overdue_status_index"
	add_index :entry_statuses, :due_today, :name => "entry_statuses_due_today_index"
        add_index :entry_statuses, :last_marked, :name => "entry_statuses_last_marked_index"   
        add_index :entry_statuses, :ended, :name => "entry_statuses_ended_index"        
	
	foreign_key :entry_statuses, :user_id, :users
	foreign_key :entry_statuses, :entry_id, :entries
  end

  def self.down
    drop_table :entry_statuses
  end
end
