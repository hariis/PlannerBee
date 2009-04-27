class PlannerbeeComment < ActiveRecord::Base
  
  COMMENT_TYPES = {'Please select one...' => 0,'I am requesting a Feature' => 1, 'Something is broken' => 2, 'Something is confusing' => 3, 'Other' => 4}
  
  def save_and_notify
    save
    PlannerbeeCommentNotifier.deliver_send_emails(self)
  end
end
