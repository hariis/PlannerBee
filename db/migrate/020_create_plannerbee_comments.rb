require "migration_helpers" 
class CreatePlannerbeeComments < ActiveRecord::Migration
extend MigrationHelpers
  def self.up
    create_table :plannerbee_comments do |t|
      t.string :comment_type
      t.text :description
      t.column :user_id,  :integer, :null => false
      t.timestamps
    end
    
    foreign_key :plannerbee_comments, :user_id, :users
  end

  def self.down
    drop_table :plannerbee_comments
  end
end
