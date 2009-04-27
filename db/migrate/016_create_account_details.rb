require "migration_helpers" 
class CreateAccountDetails < ActiveRecord::Migration
extend MigrationHelpers
  def self.up
        create_table :account_details ,:force => true do |t|
                t.column :user_id,  :integer, :null => false
                t.column :tasks_last_flagged_on, :datetime	
                t.column :bookmarks_last_flagged_on, :datetime	
                t.column :feeds_last_flagged_on, :datetime
        end
            add_index :account_details, :user_id, :name => "account_details_user_id_index"
            foreign_key :account_details, :user_id, :users	
  end

  def self.down
    drop_table :account_details
  end
end
