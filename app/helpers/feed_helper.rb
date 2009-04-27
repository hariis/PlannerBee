module FeedHelper
  def date_menu_items(start_date, end_date)
     menu_names = (start_date..end_date).collect { |d| d.strftime('%B %d, %Y') }
      menu_values = (start_date..end_date).collect { |d| d.strftime('%Y-%m-%d') }
     [menu_names, menu_values].transpose
  end
  
end
