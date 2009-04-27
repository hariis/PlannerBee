class BookmarkNotifier < ActionMailer::Base
  def send_emails(bookmark,sent_by)
    setup_email(bookmark)
    @subject    += "#{sent_by.login}'s shared items"
  
    @body[:title]  = bookmark.resource.title
    @body[:url]  = bookmark.resource.uri
    @body[:notes]  = bookmark.comments
    @body[:sender] = "#{sent_by.login}"
  end
  
  
  protected
    def setup_email(bookmark)
      @recipients  = "#{bookmark.emails}"
      @from        = "PlannerBee Accounts <plannerbee@plannerbee.com>"
      headers         "Reply-to" => "plannerbee@plannerbee.com"
      @subject     = "[PlannerBee] "
      @sent_on     = TzTime.now
      @content_type = "text/html"
      @body[:bookmark] = bookmark
    end
end