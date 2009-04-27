class HomeController < ApplicationController
  #before_filter :login_required, :except => [:listapi,:listallapi, :welcome]
  before_filter :authenticate, :except => [:welcome]
  around_filter :set_timezone
  before_filter :check_if_user_data_current, :only => [:index]                          

  layout "common", :except => [:welcome]
  
	def index
		@user = User.find_by_id(current_user.id)
                @subscriptions = Feedsubscription.find_todays_feeds(@user.id)
		@entries = Entry.find_todays_entries(session[:user])
		@bookmarks = Bookmark.find_todays_entries(session[:user])
	end
	def welcome
              @latest_entries = Entry.find_latest10_entries
              @latest_bookmarks = Bookmark.find_latest10_entries
              @latest_feeds = SavedFeedItem.find_latest10_saved_posts
              @signup = Signup.new              
	end
        def plaxo
          
        end
        private
        def check_if_user_data_current
                Entry.flag_user_data(current_user)  if logged_in?
                Bookmark.flag_user_data(current_user)  if logged_in?
                Feedsubscription.flag_user_data(current_user)  if logged_in?
        end
end
