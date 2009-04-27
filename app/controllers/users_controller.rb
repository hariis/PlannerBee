class UsersController < ApplicationController
  #before_filter :login_required, :only => [:edit, :update, :destroy, :admin, :index]
  before_filter :authenticate, :only => [:edit, :update, :destroy, :admin, :index]
  around_filter :set_timezone, :only => [:edit, :update, :destroy, :admin, :index]
  layout :choose_layout  
  in_place_edit_for :user, :time_zone
  in_place_edit_for :user, :email
 
  def new
	flash.now[:error] = nil
  end

  def create
    if params[:buzz] == "jointhehive"
              @user = User.new(params[:user])
              @user.save!
                  @user.add_role("admin") if User.find( :all).size== 1
                  @user.add_role("private_beta_tester")
                  @user.add_role("member")
                  #There is still the Activation step before the user can log in
                  #So don't set this just yet
              #self.current_user = @user

              flash[:notice] = "Thanks for signing up! <br/>
                                                    One last step. Please check your email and <br/>
                                                    follow the instructions to activate your account."

              redirect_to :controller => 'sessions', :action => 'new'
    else
              flash[:notice] = "Buzz Code invalid! <br/>
                                                    Please try again."
             redirect_to :controller => 'users', :action => 'new'
    end
  rescue ActiveRecord::RecordInvalid
    
	errorstring = ""
	@user.errors.each do |attr,e| 
		errorstring = errorstring + "<li>" + " " +  e + "</li>"		
	end 
	errormessage = "
	#{@user.errors.count} error(s) found.
	<ul>				
	#{errorstring}			
	</ul>
	Please try again."
	
	flash.now[:error] = errormessage	  
	render :action => 'new'	
  end
	
	def activate
		code = params[:activation_code]
		if code != nil
			self.current_user = User.find_by_activation_code(code)
			if logged_in? && !current_user.activated?
			  current_user.activate
			  flash[:notice] = "Signup complete!"
                          current_user.account_detail = AccountDetail.new
			  redirect_back_or_default('/home')
			else			    
				flash[:notice] = "Your Activation code could not be found. <br/>
				  You can do one of two things. <br/>
				  Check your email for the activation url and try again OR <br/>  
				  Request the Activation instructions to be resent"				
			end							 
		end
	end
	
  def forgot_password
	@errormessage = nil
  end
  def lost_activation
       @errormessage = nil
  end
  def send_password
    user = User.find_by_email(params[:email])
	if user
		if user.activated?
			user.send_new_password
			flash[:notice] = "Your login details have been sent."
			redirect_back_or_default('/login')
		else			
			user.send_new_password_with_activation
			flash[:notice] = "You have not activated your account yet. <br/>
			                  Your new password and activation details have been sent. <br/>
							  Pleae activate your account first."
			#flash[:notice] = "Pleae activate your account first."
			redirect_back_or_default('/login')
		end
	else
		@errormessage= "Cannot find an account with this email address. <br/> Please check your email address."
		render :action => 'forgot_password'
	end
  end
  def send_activation
    user = User.find_by_email(params[:email])
	if user		
		if user.activated?
			flash[:notice] = "Your account is already active."
			redirect_back_or_default('/home')
		else
			user.send_activation
			flash[:notice] = "Your activation email has been sent."
			redirect_back_or_default('/login')
		end
	else
		@errormessage= "Cannot find an account with this email address. <br/> Please check your email address."
		render :action => 'lost_activation'
	end
  end
  def index
    @user = User.find(session[:user])
    respond_to do |format|
      format.html
      format.xml { render :xml => @user.to_xml }
    end
  end
  def update
    @user = User.find(session[:user])
    @user.attributes = params[:user]
    
    
    @user.save! and flash[:notice]="Your settings have been saved."
	
	respond_to do |format|
                      format.html { redirect_to :action => 'index' }
                      format.xml  { head 200 }
        end
	
	rescue ActiveRecord::RecordInvalid
    
		errorstring = ""
		@user.errors.each do |attr,e| 
			errorstring = errorstring + "<li>" + attr.capitalize + " " +  e + "</li>"		
		end 
		errormessage = "
		#{@user.errors.count} error(s) found.
		<ul>				
		#{errorstring}			
		</ul>
		Please try again."
		
		flash[:error] = errormessage	  
		redirect_to :action => 'index'
	
	
    
  end
  
  def change_password_update
        if User.authenticate(current_user.login, params[:old_password])
            if ((params[:user][:password] == params[:user][:password_confirmation]) && !params[:user][:password_confirmation].blank?)
                current_user.password_confirmation = params[:user][:password_confirmation]
                current_user.password = params[:user][:password]
                
                
                send_change_password_request
            
                
                 
            else
                flash[:error] = "New Password mismatch. Please Try Again!" 
                redirect_to :action => 'index'
            end
        else
            flash[:error] = "Old password incorrect. Please Try Again!" 
            redirect_to :action => 'index'
        end
        
    end
  
  def send_change_password_request
                current_user.save! and flash[:notice]="Password successfully updated."
	
                respond_to do |format|
                              format.html { redirect_to :action => 'index' }
                              format.xml  { head 200 }
                end
	
                rescue ActiveRecord::RecordInvalid
    
		errorstring = ""
		current_user.errors.each do |attr,e| 
			errorstring = errorstring + "<li>" + attr.capitalize + " " +  e + "</li>"		
		end 
		errormessage = "
		#{current_user.errors.count} error(s) found.
		<ul>				
		#{errorstring}			
		</ul>
		Please try again."
		
		flash[:error] = errormessage	  
		redirect_to :action => 'index'
    
  end
  def change_password
            render :update do |page|
			
			page.hide 'flash-message'
			
                        page.visual_effect :appear, 'change-form'
			#page.delay(10) do
			#	page.replace_html 'failure', ""
			#	page.visual_effect :fade, 'flash-notice'
			#end
			#Populate the body
			page.replace_html("change-form", :partial => "change_password")
			
		end
	
  end
  private
  def choose_layout    
    if [ 'update', 'index', 'change_password' ].include? action_name
      'myaccount'
    else
      'standard-layout'
    end
  end
end
