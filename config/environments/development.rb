# Settings specified here will take precedence over those in config/environment.rb

# In the development environment your application's code is reloaded on
# every request.  This slows down response time but is perfect for development
# since you don't have to restart the webserver when you make code changes.
config.cache_classes = false

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true
config.log_level = :debug # debug, info, warn, error, fatal

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching             = false
config.action_view.cache_template_extensions         = false
config.action_view.debug_rjs                         = true

# Don't care if the mailer can't send
config.action_mailer.raise_delivery_errors = true

config.action_mailer.delivery_method = :smtp
#ActionMailer::Base.smtp_settings[:tls] = true

config.action_mailer.smtp_settings =  {
:address => "smtp.gmail.com",
:port    => "587",
:domain => "plannerbee.com",
:authentication => :plain,
:user_name => "admin@plannerbee.com",
:password => "jayam4rama"
}
config.action_mailer.perform_deliveries = true
config.action_mailer.raise_delivery_errors = true
config.action_mailer.default_charset = "utf-8"

require 'smtp_tls'
DOMAIN = 'http://www.plannerbee.com/'