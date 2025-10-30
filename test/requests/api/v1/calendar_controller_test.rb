require "test_helper"

class Api::V1::CalendarControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @user = users(:one)
    # Assume session-based auth helper available
    sign_in_as(@user)
  end

  test "GET /api/v1/calendar/events month view returns structure" do
    get "/api/v1/calendar/events", params: { year: 2025, month: 2, view: "month" }
    assert_response :success

    body = JSON.parse(@response.body)
    assert body["data"].key?("calendar_structure")
    weeks = body["data"]["calendar_structure"]
    assert_kind_of Array, weeks
    refute_empty weeks
    first_day = weeks.first.first
    assert first_day.key?("date")
    assert first_day.key?("in_current_month")
    # additive
    assert first_day.key?("iso_date")
  end

  test "GET /api/v1/calendar/events week view returns 7 days" do
    get "/api/v1/calendar/events", params: { year: 2025, month: 2, day: 10, view: "week" }
    assert_response :success

    body = JSON.parse(@response.body)
    week_days = body["data"]["calendar_structure"]
    assert_kind_of Array, week_days
    assert_equal 7, week_days.length
    sample = week_days.first
    %w[date day_name day_number is_today is_current_month].each do |k|
      assert sample.key?(k)
    end
    # additive
    assert sample.key?("iso_date")
  end
end


