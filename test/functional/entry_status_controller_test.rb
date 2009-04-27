require File.dirname(__FILE__) + '/../test_helper'
require 'entry_status_controller'

# Re-raise errors caught by the controller.
class EntryStatusController; def rescue_action(e) raise e end; end

class EntryStatusControllerTest < Test::Unit::TestCase
  def setup
    @controller = EntryStatusController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
