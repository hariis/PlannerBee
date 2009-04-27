class SignupController < ApplicationController
  
        def create
            @signup = Signup.new(params[:signup])
            @signup.remote_ip = request.remote_ip
            if @signup.save
                render :update do |page|                   
                    page.replace_html 'request-status',"Thank you! We will notify as soon as we are ready!"
                end
            else
                 render :update do |page|
                   page.replace_html("request", :partial => 'home/signup')
                    page.show 'request_signup'
                    page.replace_html "request-status", ''                    
                end
            end
          end
end