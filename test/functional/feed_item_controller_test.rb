require File.dirname(__FILE__) + '/../test_helper'
require 'feed_item_controller'

# Re-raise errors caught by the controller.
class FeedItemController; def rescue_action(e) raise e end; end

class FeedItemControllerTest < Test::Unit::TestCase
  def setup
    @controller = FeedItemController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
