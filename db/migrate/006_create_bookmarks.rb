require "migration_helpers" 
class CreateBookmarks < ActiveRecord::Migration
extend MigrationHelpers
  def self.up
    create_table :bookmarks,:force => true  do |t|
          t.column :user_id,  :integer, :null => false	
          t.column :resource_id, :integer, :null => false	
          t.column :notes, :text	

          t.column :start_dt_tm, :datetime, :null => false
          t.column :end_dt_tm, :datetime, :null => false
          t.column :freq_type,  :integer,   :limit => 2, :null => false
          t.column :freq_interval, :integer,   :limit => 2
          t.column :freq_interval_qual, :integer


          t.column :public, :boolean, :null => false, :default => false
          t.column :priority,  :integer,   :limit => 2, :null => false

          t.column :created_at, :timestamp, :null => false
          t.column :updated_at, :timestamp,:null => false
    end
	add_index :bookmarks, :user_id, :name => "bookmarks_user_id_index"	
	add_index :bookmarks, :start_dt_tm, :name => "bookmarks_start_dt_index"
	add_index :bookmarks, :end_dt_tm, :name => "bookmarks_end_dt_index"
	add_index :bookmarks, :freq_type, :name => "bookmarks_freq_type_index"        
        add_index :bookmarks, :public, :name => "bookmarks_public_index"
	add_index :bookmarks, :updated_at, :name => "bookmarks_created_at_index"
        
	foreign_key :bookmarks, :user_id, :users
        foreign_key :bookmarks, :resource_id, :resources
  end

  def self.down
    drop_table :bookmarks
  end
end
