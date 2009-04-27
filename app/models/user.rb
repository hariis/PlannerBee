require 'digest/sha1'
class User < ActiveRecord::Base
  has_many	:entries, :dependent => :destroy
  has_many	:entry_statuses
  has_many	:bookmarks, :dependent => :destroy  
  has_many	:bookmark_statuses
  has_many	:feedsubscriptions, :dependent => :destroy  
  has_many	:feeds, :through => :feedsubscriptions
  has_many :user_roles, :dependent => :destroy  
  has_many :roles, :through => :user_roles
  has_one :account_detail, :dependent => :destroy      
  acts_as_tagger
  # Virtual attribute for the unencrypted password
  attr_accessor :password

  validates_presence_of     :login, :email ,:time_zone, :on => :create, :message => "Please choose your time zone"
  validates_length_of       :login,    :within => 3..10 , :on => :create, :message => "Please pick a Username between 3 and 10 characters"
  validates_length_of       :email,    :within => 3..100, :message => " Please use an email less than 100 characters" 
  validates_exclusion_of    :login, :in => %w( admin superuser gayatri kunju streamlife rohan shreema sampangi contactus info support customersupport help), :message => " Username not allowed" , :on => :create
  validates_format_of 	    :login, :with => /^\w+$/i, :message => " Username can only contain letters and numbers." 
  validates_uniqueness_of   :login, :case_sensitive => false, :message => " Username already taken"
  validates_uniqueness_of   :email, :case_sensitive => false, :message => " An account already exists with this email"
  validates_uniqueness_of   :identity_url, :case_sensitive => false, :allow_nil => true
  validates_format_of 		:email, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :message => "Email is of invalid format."  
  
   with_options :if => :password_required? do |u|
    u.validates_length_of       :password, :within => 5..20, :allow_nil => true, :message => "Please pick a Password between 5 and 20 characters"  
    u.validates_confirmation_of :password, :on => :create, :message => "Please make sure confirmation password matches"  
    u.validates_confirmation_of :password, :on => :update, :allow_nil => true, :message => "Please make sure confirmation password matches"  
  end
  
  
  before_save :encrypt_password
  before_create :make_activation_code 
   
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :login, :email, :password, :password_confirmation, :time_zone
  
  def has_role?(role)
	self.roles.count(:conditions => ["name = ?", role]) > 0
  end

	def add_role(role)
	  return if self.has_role?(role)
	  self.roles << Role.find_by_name(role)
	end
	
  # Activates the user in the database.
  def activate
    @activated = true
    self.activated_at = Time.now.utc
    self.activation_code = nil   
    save(false)
    #Note this in the signups table
    signup = Signup.find_by_email(self.email)
    signup.update_attribute(:activated_at, Time.now.utc) if signup != nil
  end

  def activated?
    !! activation_code.nil?
  end

  # Returns true if the user has just been activated.
  def recently_activated?
    @activated
  end 
  
  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  def self.authenticate(login, password)
    u = find :first, :conditions => ['login = ? and activated_at IS NOT NULL', login] # need to get the salt
    u && u.authenticated?(password) ? u : nil
  end

  # Encrypts some data with the salt.
  def self.encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end

  # Encrypts the password with the user salt
  def encrypt(password)
    self.class.encrypt(password, salt)
  end

  def authenticated?(password)
    crypted_password == encrypt(password)
  end

  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at 
  end

  # These create and unset the fields required for remembering users between browser closes
  def remember_me
    remember_me_for 2.weeks
  end

  def remember_me_for(time)
    remember_me_until time.from_now.utc
  end

  def remember_me_until(time)
    self.remember_token_expires_at = time
    self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
    save(false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save(false)
  end
  

  def send_new_password	
	new_pass = User.random_string(10)
    self.password = self.password_confirmation = new_pass	
    save(false)	
	UserNotifier.deliver_send_password(self)
  end
  def send_new_password_with_activation	
	new_pass = User.random_string(10)
    self.password = self.password_confirmation = new_pass
	make_activation_code
    save(false)	
	UserNotifier.deliver_send_password_with_activation(self)
  end
  def send_activation	
	make_activation_code
    save(false)
	UserNotifier.deliver_send_activation(self)
  end
  
  def forgot_password?
	@forgotpassword
  end
  def send_activation?
	@activation
  end
  def are_tasks_flagged_today
                TzTime.zone =TimeZone[self.time_zone]                
                last_flagged = self.account_detail.tasks_last_flagged_on
                return true if last_flagged && TzTime.zone.utc_to_local(last_flagged).to_date == TzTime.now.to_date
                return false
  end
  def are_bookmarks_flagged_today
                TzTime.zone =TimeZone[self.time_zone]                
                last_flagged = self.account_detail.bookmarks_last_flagged_on
                return true if last_flagged && TzTime.zone.utc_to_local(last_flagged).to_date == TzTime.now.to_date
                return false
  end 
  def are_feeds_flagged_today
                TzTime.zone =TimeZone[self.time_zone]                
                last_flagged = self.account_detail.feeds_last_flagged_on
                return true if last_flagged && TzTime.zone.utc_to_local(last_flagged).to_date == TzTime.now.to_date
                return false
  end 
  protected
  
	  def self.random_string(len)
		#generat a random password consisting of strings and digits
		chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
		newpass = ""
		1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
		return newpass
	  end
  
  
    # before filter 
    def encrypt_password
      return if password.blank?
      self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
      self.crypted_password = encrypt(password)
    end
    
    def password_required?
      crypted_password.blank? || !password.blank?
    end
	
	def not_openid?
      identity_url.blank?
    end
	
	def make_activation_code
      self.activation_code = Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
    end 
    
end
