class UserObserver < ActiveRecord::Observer
  def after_create(user)
    UserNotifier.deliver_signup_notification(user)
  end

  def after_save(user)
    
	UserNotifier.deliver_send_password(user) if user.forgot_password?
	
	#UserNotifier.deliver_send_activation(user) if user.send_activation?	
	
	UserNotifier.deliver_confirm_activation(user) if user.recently_activated?
	  
  end
end
