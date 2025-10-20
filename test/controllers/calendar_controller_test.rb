require "test_helper"

class CalendarControllerTest < ActionDispatch::IntegrationTest
  test "should get Index" do
    get calendar_Index_url
    assert_response :success
  end
end
