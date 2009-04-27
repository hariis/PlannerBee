class FeedItemNotifier < ActionMailer::Base
  include TextHelper
  def send_emails(feeditem,sent_by)
    setup_email(feeditem,sent_by)
    @subject    += "#{sent_by.login}'s shared feed items"
  
    @body[:title]  = feeditem.title
    @body[:url]  = feeditem.url
    @body[:published]  = feeditem.published
    @body[:content]  = feeditem.content
    @body[:feedtitle] = feeditem.feed.title
    @body[:sender] = "#{sent_by.login}"
    @body[:comments] = "#{feeditem.comments}"
  end 
  
  protected
    def setup_email(feeditem,sent_by)
      @recipients  = "#{feeditem.emails}"
      @from        = "PlannerBee Accounts <plannerbee@plannerbee.com>"
      headers         "Reply-to" => "plannerbee@plannerbee.com"
      @subject     = "[PlannerBee] "
      @sent_on     = TzTime.now
      @content_type = "text/html"
      @body[:feed_item] = feeditem
    end
end
