require "test_helper"

class InsightsControllerTest < ActionDispatch::IntegrationTest
  test "should get dismiss" do
    get insights_dismiss_url
    assert_response :success
  end

  test "should get undismiss" do
    get insights_undismiss_url
    assert_response :success
  end
end
