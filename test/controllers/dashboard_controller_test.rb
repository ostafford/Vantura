require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    sign_in_as(:one)
    get root_url
    assert_response :success
  end

  test "should redirect to login when not authenticated" do
    get root_url
    assert_redirected_to new_session_url
  end
end
