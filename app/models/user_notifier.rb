class UserNotifier < ActionMailer::Base
  def signup_notification(user)
    setup_email(user)
    @subject    += 'Please activate your new account'  
    @body[:activationurl]  = DOMAIN + "activate/#{user.activation_code}"
    @body[:url]  = DOMAIN + "home"
  end
  
  def confirm_activation(user)
    setup_email(user)
    @subject    += 'Your account has been activated!'
    @body[:url]  = DOMAIN + "home"
  end
  
  def send_password(user)
	setup_email(user)
	@subject    += 'Your account details'
    @body[:url]  = DOMAIN + "home"
  end
  def send_activation(user)
	setup_email(user)
	@subject    += 'Please activate your new account'
    @body[:url]  = DOMAIN + "home"
	@body[:activationurl]  = DOMAIN + "activate/#{user.activation_code}"
  end
  def send_password_with_activation(user)
	setup_email(user)
	@subject    += 'Your account details'
    @body[:url]  = DOMAIN + "home"
	@body[:activationurl]  = DOMAIN + "activate/#{user.activation_code}"
	
  end
  protected
    def setup_email(user)
      @recipients  = "#{user.email}"
      @from        = "PlannerBee Accounts <plannerbee@plannerbee.com>"
      headers         "Reply-to" => "plannerbee@plannerbee.com"
      @subject     = "[PlannerBee] "
      @sent_on     = Time.now
      @content_type = "text/html"
      @body[:user] = user
    end
end
