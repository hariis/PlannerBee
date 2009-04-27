# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
	def hidden_div_if(condition, attributes ={}, &block)
		if condition
			attributes["style"] = "display: none"
		end
		content_tag("div", attributes, &block)
			
	end
        
        def is_owner(item)
             item.user[:id] == current_user.id
        end    
        
       def in_place_select_editor(field_id, options = {})
    
                function = "new Ajax.InPlaceSelectEditor("
                function << "'#{field_id}', "
                function << "'#{url_for(options[:url])}'"
                function << (', ' + options_for_javascript(
                {
                       'selectOptionsHTML' =>
                      %('#{escape_javascript(options[:select_options].gsub(/\n/, ""))}')
                 }
                 )
                ) if options[:select_options]
                    function << ')'
                javascript_tag(function)    
   end
  
   def in_place_select_editor_field(object, method, tag_options = {},
                                   in_place_editor_options = {})
  
          tag = ::ActionView::Helpers::InstanceTag.new(object, method, self)
          tag_options = {:tag => "span",
                   :id => "#{object}_#{method}_#{tag.object.id}_in_place_editor",
                   :class => "in_place_editor_field"}.merge!(tag_options)
          in_place_editor_options[:url] =   in_place_editor_options[:url] ||   url_for({ :action => "set_#{object}_#{method}", :id => tag.object.id })
          tag.to_content_tag(tag_options.delete(:tag), tag_options) +     in_place_select_editor(tag_options[:id], in_place_editor_options)
    
   end
  def display_schedule(item)
        display = ""
        if (item.freq_type > 0 && item.freq_type < 6) ||  item.freq_type == 11 
            display << "Once on:  #{tz(item.start_dt_tm).to_date.to_s(:long) }"
         elsif item.freq_type == 0 
            display << "To Do Next"
         elsif item.freq_type == 12 
            display << "Someday / Maybe"
         elsif item.freq_type == 6 
            display << "#{Schedulehelper::FREQ_INTERVALS_DAILY[item.freq_interval-1][1]}" + "<br/>"
            display << "Starting: #{tz(item.start_dt_tm).to_date.to_s(:long)}<br/>"
            display << "Ending: #{tz(item.end_dt_tm).to_date.to_s(:long)} <br/>"
         elsif item.freq_type == 7 
            display << "#{Schedulehelper::FREQ_INTERVALS_WEEKLY[item.freq_interval-1][1]}  <br/>"
            display << "Starting: #{tz(item.start_dt_tm).to_date.to_s(:long)} <br/>"
            display << "Ending: #{tz(item.end_dt_tm).to_date.to_s(:long)} <br/>"
            vals = Schedulehelper.ExtractFreqIntQualIntoArr(item.freq_interval_qual,false)
            display << "on "
            vals.reverse.each{|val |
            display << "#{Schedulehelper::FREQ_INTERVALS_QUAL_WEEKLY[val][1]}"
            if vals.index(val).to_i != 0 
                display <<   ","
            end 
            }
        elsif item.freq_type == 8 
            display << "#{Schedulehelper::FREQ_INTERVALS_MONTHLY[item.freq_interval-1][1]}  <br/>"
            display << "Starting:  #{tz(item.start_dt_tm).to_date.to_s(:long)} <br/>"
            display << "Ending:  #{tz(item.end_dt_tm).to_date.to_s(:long)}<br/>"
            vals = Schedulehelper.ExtractFreqIntQualIntoArr(item.freq_interval_qual,false)
            display << "on "
            vals.each{|val |
            display << "#{Schedulehelper::FREQ_INTERVALS_QUAL_DATE[val][1] }"
            if vals.index(val).to_i != 0 
                display <<   ","
            end
            } 
       elsif item.freq_type == 9 
            display << "#{ Schedulehelper::FREQ_INTERVALS_MONTHLY[item.freq_interval-1][1]}  <br/>"
            display << "Starting: #{ tz(item.start_dt_tm).to_date.to_s(:long)}<br/>"
            display << "Ending: #{ tz(item.end_dt_tm).to_date.to_s(:long)}<br/>"
            vals = Schedulehelper.ExtractFreqIntQualIntoArr(item.freq_interval_qual,false)
            display << "on "
            vals.each{|val |
            display << "#{Schedulehelper::FREQ_INTERVALS_QUAL_DAY[val][1] }"
            if vals.index(val).to_i != 0 
                display <<   ","
            end
            } 
       elsif item.freq_type == 10 
            display << "#{ Schedulehelper::FREQ_INTERVALS_YEARLY[item.freq_interval-1][1]} <br/>"
            display << "Starting: #{ tz(item.start_dt_tm).to_date.to_s(:long) }<br/>"
            display << "Ending: #{ tz(item.end_dt_tm).to_date.to_s(:long) }<br/>"
        end 
        return display
  end
def tz(time_at)
  TzTime.zone.utc_to_local(time_at.utc)
end

 def relative_day(time)
   if TzTime.at(time) >= TzTime.now.beginning_of_day.utc
     "Today"
   elsif TzTime.at(time) >= (TzTime.now.beginning_of_day - 1.day).utc
     "Yesterday"
   else
     span = (TzTime.now.utc - TzTime.at(time).utc)/(24*3600)
     "#{span.round} days ago"
   end
 end 
end
