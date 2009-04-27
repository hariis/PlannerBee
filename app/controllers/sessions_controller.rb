# This controller handles the login/logout function of the site.  
class SessionsController < ApplicationController
  
  layout "standard-layout"
  def new
	flash[:error] = nil
  end

  def create
    if using_open_id?
      open_id_authentication
    else
      password_authentication(params[:login], params[:password])
    end	
  end
  
  def destroy
    self.current_user.forget_me if logged_in?
    cookies.delete :auth_token
    reset_session
    flash[:notice] = "You have been logged out."
    redirect_back_or_default('/')
  end  
  
  protected
  
    def password_authentication(login, password)
      self.current_user = User.authenticate(login, password)
      if logged_in?
        if params[:remember_me] == "1"
          self.current_user.remember_me
          cookies[:auth_token] = { :value => self.current_user.remember_token , :expires => self.current_user.remember_token_expires_at }
        end
        successful_login
      else
		user = User.find_by_login(login)
		if user && !user.activated?
			failed_login("Your account is not activated yet. <br/> Please check your email for instructions. <br/> 
			              If you would like the Activation instructions to be resent, please request it through 'Resend Activation' link below" )
		else
		    failed_login('Invalid login or password')
		end
      end
    end

    def open_id_authentication
      # Pass optional :required and :optional keys to specify what sreg fields you want.
      # Be sure to yield registration, a third argument in the #authenticate_with_open_id block.
      authenticate_with_open_id(params[:openid_url], :required => [ :nickname, :email ]) do |result, identity_url, registration|
        if result.successful?
          if !@user = User.find_by_identity_url(identity_url)
            @user = User.new(:identity_url => identity_url)
            assign_registration_attributes!(registration)
          end
          self.current_user = @user
          successful_login
        else
          failed_login(result.message || "Sorry could not log in with identity URL: #{identity_url}")
        end
      end
    end

    # registration is a hash containing the valid sreg keys given above
    # use this to map them to fields of your user model
    def assign_registration_attributes!(registration)
      { :login => 'nickname', :email => 'email' }.each do |model_attribute, registration_attribute|
        unless registration[registration_attribute].blank?
          @user.send("#{model_attribute}=", registration[registration_attribute])
        end
      end
      @user.save!
    end

  private
  
    def successful_login
      redirect_back_or_default('/home')
      flash[:notice] = "Logged in successfully!"
    end

    def failed_login(message)
      flash.now[:error] = message
      render :action => 'new'		
    end

end
