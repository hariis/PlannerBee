 
module SlidingSessionTimeout
  
  def self.included(controller)
    controller.extend(ClassMethods)
  end
  
  module ClassMethods
    
    def sliding_session_timeout(seconds, expiry_func=nil)
      @sliding_session_timeout = seconds
      @sliding_session_expiry_func = expiry_func
      
      prepend_before_filter do |c|
        if c.session[:sliding_session_expires_at] && c.session[:sliding_session_expires_at] < Time.now
          c.send @sliding_session_expiry_func unless @sliding_session_expiry_func.nil?
          c.reset_session
        else
          c.session[:sliding_session_expires_at] = Time.now + @sliding_session_timeout
        end
      end # before_filter
      
    end # sliding_session_timeout
  
  end # ClassMethods

end
