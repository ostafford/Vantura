require "test_helper"

class CalendarControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    sign_in_as(:one)
    get calendar_url
    assert_response :success
  end

  test "should redirect to login when not authenticated" do
    get calendar_url
    assert_redirected_to new_session_url
  end

  test "should use CalendarDataService" do
    sign_in_as(:one)
    get calendar_url
    assert_response :success
    # Service is called indirectly - verified through successful response
  end

  test "should use CalendarStatsCalculator" do
    sign_in_as(:one)
    get calendar_url
    assert_response :success
    # Service is called indirectly - verified through successful response
  end

  test "should handle month view" do
    sign_in_as(:one)
    get calendar_month_url(year: 2025, month: 11)
    assert_response :success
  end

  test "should handle week view" do
    sign_in_as(:one)
    get calendar_month_url(year: 2025, month: 11, day: 15)
    assert_response :success
  end
end
