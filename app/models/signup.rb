class Signup < ActiveRecord::Base
  validates_length_of       :email,    :within => 3..100, :message => " Please use an address less than 100 characters" 
  validates_uniqueness_of   :email, :case_sensitive => false, :message => "address is already in our list. Please be patient. "
  validates_format_of 	    :email, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :message => "is of invalid format."  
  validates_format_of 	    :name, :with => /^\w+$/i, :message => " can only contain letters and numbers." 
end
