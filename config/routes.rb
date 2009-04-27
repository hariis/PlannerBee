ActionController::Routing::Routes.draw do |map|
  # The priority is based upon order of creation: first created -> highest priority.
  map.resources :users
  map.connect 'sessions/new', :controller => "sessions" ,:action => 'new'
  map.resource :sessions, :controller => "session"
  #map.open_id_complete 'session', :controller => "session", :action => "create", :requirements => { :method => :get }
  map.resource :session
  
  map.signup '/signupnow', :controller => 'users', :action => 'new'
  map.login  '/login', :controller => 'sessions', :action => 'new'
  map.logout '/logout', :controller => 'sessions', :action => 'destroy'
  map.activate '/activate/:activation_code', :controller => 'users', :action => 'activate'
  map.forgot_password '/forgot_password', :controller => 'users', :action => 'forgot_password'
  map.forgot_password '/lost_activation', :controller => 'users', :action => 'lost_activation'
  map.resource :entries, :tags
  # Sample of regular route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  # map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # You can have the root of your site routed by hooking up '' 
  # -- just remember to delete public/index.html.
  # map.connect '', :controller => "welcome"

  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  map.connect ':controller/service.wsdl', :action => 'wsdl'

  # Install the default route as the lowest priority.
  map.connect 'bookmark/newapi/:title/:url', :controller => "bookmark" ,:action => 'newapi'
  
  map.connect ':controller/:action.:format'
  map.connect ':controller/:action/:id.:format'
  map.connect ':controller/:action/:id'  
  map.connect '/entryapi/list', :controller => "entryapi" ,:action => 'list'
  map.connect '', :controller => "home" ,:action => 'welcome' 
end
