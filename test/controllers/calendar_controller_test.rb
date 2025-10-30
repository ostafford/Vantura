require "test_helper"

class CalendarControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    sign_in_as(:one)
    get calendar_url
    assert_response :success
  end

  test "should render week view" do
    sign_in_as(:one)
    get calendar_url(view: "week")
    assert_response :success
  end

  test "should redirect to login when not authenticated" do
    get calendar_url
    assert_redirected_to new_session_url
  end
end
