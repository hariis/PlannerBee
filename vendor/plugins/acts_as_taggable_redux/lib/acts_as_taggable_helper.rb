module ActsAsTaggableHelper
  # Create a link to the tag using restful routes and the rel-tag microformat
  def link_to_tag(tag)
    link_to(tag.name, tag_url(tag), :rel => 'tag')
  end
  
  # Generate a tag cloud of the top 100 tags by usage, uses the proposed hTagcloud microformat.
  #
  # Inspired by http://www.juixe.com/techknow/index.php/2006/07/15/acts-as-taggable-tag-cloud/
  def tag_cloud(options = {})
    # TODO: add options to specify different limits and sorts
    tags = Tag.find(:all, :limit => 100, :order => 'taggings_count DESC').sort_by(&:name)
    generate_tagcloud(tags)
  end
   
    def generate_tagcloud(tags)
          # TODO: add option to specify which classes you want and overide this if you want?
          classes = %w(popular v-popular vv-popular vvv-popular vvvv-popular)

          max, min = 0,0
          tags.each do |tag|
            max = tag.taggings_count if tag.taggings_count > max
            min = tag.taggings_count if tag.taggings_count < min
          end

          divisor = ((max - min) / classes.size) + 1

          html =    %(<div id="hTagcloud" class="tagcloudbox">\n)
          html <<   %(  <ul class="popularity">\n)
          tags.each do |tag|
            html << %(    <li>)
            html << link_to(tag.name, "", :class => classes[(tag.taggings_count - min) / divisor]) 
            html << %(</li> \n)
          end
          html <<   %(  </ul>\n)
          html <<   %(</div>\n)
    end
      def tag_cloud_for_user(user, model, options = {})
      # TODO: add options to specify different limits and sorts
      tags = model.tags_for_user(user)

      # TODO: add option to specify which classes you want and overide this if you want?
      classes = %w(popular v-popular vv-popular vvv-popular vvvv-popular)

      max, min = 0, 0
      tags.each do |tag|
        max = tag.count if tag.count.to_i > 0
        min = tag.count if tag.count.to_i < 0
      end

      divisor = ((max.to_i - min.to_i) / classes.size) + 1

      html =    %(<div id="hTagcloud" class="box">\n)
      html <<   %(  <ul class="popularity">\n)
      tags.each do |tag|
        html << %(    <li>)
        #html << link_to(tag.name, tag_url(tag), :class => classes[(tag.taggings_count - min) / divisor]) 
        html << link_to(tag.name, "", :class => classes[(tag.taggings_count - min) / divisor]) 
        html << %(</li> \n)
      end
      html <<   %(  </ul>\n)
      html <<   %(</div>\n)
    end
      
 
     def delicious_tags(obj, user, f)  
      #res = %(<br /><b>Tags:</b> #{f.text_field :tag_list})  
      res = %(<span class="label">Tags:</span>
      <span class="formw"> #{f.text_field :tag_list, :value => obj.tags.collect{|t| t.name}.join("," ) }   <br/>(comma separated) </span>)
       res << %(#{f.hidden_field :user_id, :value => user.id })
      res << %(<div style="border:solid 1px; margin:70px 10px 10px 10px; padding:10px;">)  
      res << spaced_tags_delicious(obj)  
      res << "</div>"  
      return res  
    end  
      
    def spaced_tags_delicious(obj)  
        res = []  
         Tag.find(:all, :order => "name").each do |tag|  
           link = %(javascript:swap_tag('#{tag.name}','#{obj.class.name.tableize.singularize}_tag_list'))  
           res << link_to(tag.name, link)  
         end  
         return res.join(" ")  
       end  
end