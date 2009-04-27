class AddGoalToEntries < ActiveRecord::Migration
  def self.up
    add_column :entries, :goal_id, :integer
    add_index :entries, :goal_id, :name => "entries_goal_id_index"
  end

  def self.down
    remove_column :entries, :goal_id
  end
end
