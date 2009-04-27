class CreateSignups < ActiveRecord::Migration
  def self.up
    create_table :signups, :force => true do |t|
      t.column :name,                     :string
      t.column :email,                     :string      
      t.column :activation_code, :string, :limit => 40
      t.column :activated_at, :datetime
      t.column :granted, :boolean, :default => false
      t.column :remote_ip,    :string
      t.column :created_at, :timestamp, :null => false
      t.column :updated_at, :timestamp,:null => false
    end
    add_index :signups, :email, :name => "signups_email_index"
    add_index :signups, :granted, :name => "signups_granted_index"
  end

  def self.down
    drop_table :signups
  end
end