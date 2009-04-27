class CreateFeeds < ActiveRecord::Migration
  def self.up
    create_table :feeds,:force => true  do |t|
			t.column :title,  :string,  :limit => 255, :null => false
			t.column :url,  :string,   :limit => 255, :null => false
			
			t.column :latest_post, :datetime
    end
	add_index :feeds, :url, :name => "feeds_url_index"
  end

  def self.down
    drop_table :feeds
  end
end
