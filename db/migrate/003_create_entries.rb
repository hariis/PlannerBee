require "migration_helpers" 
class CreateEntries < ActiveRecord::Migration
extend MigrationHelpers
  def self.up
    create_table :entries ,:force => true do |t|
			t.column :user_id,  :integer, :null => false
			t.column :parent_id,  :integer
			
			t.column :title,  :string,   :limit => 50, :null => false
			t.column :notes, :text
			
			t.column :start_dt_tm, :datetime, :null => false
			t.column :end_dt_tm, :datetime, :null => false
			t.column :freq_type,  :integer,   :limit => 2, :null => false
			t.column :freq_interval, :integer,   :limit => 2
			t.column :freq_interval_qual, :integer
			
			t.column :overdue_reminder, :boolean
			t.column :public, :boolean, :null => false, :default => false
			t.column :priority,  :integer,   :limit => 2, :null => false
			
			t.column :created_at, :timestamp, :null => false
			t.column :updated_at, :timestamp,:null => false
    end
	add_index :entries, :user_id, :name => "entries_user_id_index"
	add_index :entries, :parent_id, :name => "entries_parent_id_index"
	add_index :entries, :start_dt_tm, :name => "entries_start_dt_index"
	add_index :entries, :end_dt_tm, :name => "entries_end_dt_index"
        add_index :entries, :freq_type, :name => "entries_freq_type_index"
        add_index :entries, :overdue_reminder, :name => "entries_overdue_reminder_index"
        add_index :entries, :public, :name => "entries_public_index"
	add_index :entries, :updated_at, :name => "entries_created_at_index"
        
	foreign_key :entries, :user_id, :users
	foreign_key :entries, :parent_id, :entries
	
	
  end

  def self.down
    drop_table :entries
  end
end