class AddUserRoles < ActiveRecord::Migration
    def self.up
      create_table :roles,:force => true do |t|
        t.column :name, :string
      end

      create_table :user_roles,:force => true do |t|
        t.column :user_id, :integer
        t.column :role_id, :integer
        t.column :created_at, :datetime
      end

      add_index :roles, :name
      Role.create(:name => "admin")
      Role.create(:name => "private_beta_tester")
      Role.create(:name => "public_beta_tester")
      Role.create(:name => "member")

    end

    def self.down
      drop_table :roles
      drop_table :user_roles
    end
end