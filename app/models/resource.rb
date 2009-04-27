class Resource < ActiveRecord::Base
  has_many :bookmarks
  validates_presence_of :title, :message => "Please enter a title"
  validates_presence_of :uri, :message => "Please enter a url"
  validates_format_of :uri, :with => /^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?\/.*)?$/ix,
							:message => "Please make sure url begins with http/https"
end
