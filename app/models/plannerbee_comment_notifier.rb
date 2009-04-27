class PlannerbeeCommentNotifier < ActionMailer::Base
  def send_emails(comment)
    setup_email(comment)
    @subject    += "Feedback | " + PlannerbeeComment::COMMENT_TYPES.index(comment.comment_type.to_i )
    @body[:comment_type]  = PlannerbeeComment::COMMENT_TYPES.index(comment.comment_type.to_i )
    @body[:description]  = comment.description
  end
  
  
  protected
    def setup_email(comment)
      @recipients  = "plannerbee@gmail.com"
      @from        = "PlannerBee Feedback <plannerbee@plannerbee.com>"
      headers         "Reply-to" => "plannerbee@plannerbee.com"
      @subject     = "[PlannerBee] "
      @sent_on     = TzTime.now
      @content_type = "text/html"
      @body[:comment] = comment
    end
end