class CreateResources < ActiveRecord::Migration
  def self.up
    create_table :resources,:force => true  do |t|
          t.column :title,  :string,   :limit => 255, :null => false
          t.column :uri,  :string,   :limit => 1024, :null => false
          
          t.column :created_at, :timestamp, :null => false
          t.column :updated_at, :timestamp,:null => false
    end
	add_index :resources, :uri, :name => "bookmarks_uri_index"
  end

  def self.down
    drop_table :resources
  end
end

