require "test_helper"

class CalendarStructureBuilderTest < ActiveSupport::TestCase
  test "week_days returns 7 days with required fields" do
    date = Date.new(2025, 1, 15) # Wednesday
    month = date.month
    builder = Calendar::StructureBuilder.new(date: date, month: month, week_start: :monday)

    days = builder.week_days
    assert_equal 7, days.length
    days.each do |day|
      assert day.key?(:date)
      assert day.key?(:day_name)
      assert day.key?(:day_number)
      assert day.key?(:is_today)
      assert day.key?(:is_current_month)
      assert day.key?(:iso_date)
      assert_kind_of String, day[:iso_date]
    end
  end

  test "month_weeks covers full month with leading and trailing days" do
    date = Date.new(2025, 3, 10)
    month = date.month
    builder = Calendar::StructureBuilder.new(date: date, month: month, week_start: :monday)

    weeks = builder.month_weeks
    refute_empty weeks
    weeks.each do |week|
      assert_equal 7, week.length
      week.each do |day|
        assert day.key?(:date)
        assert day.key?(:in_current_month)
        assert day.key?(:iso_date)
      end
    end

    # Ensure first day is a Monday and last is a Sunday for the computed span
    first_day = weeks.first.first[:date]
    last_day = weeks.last.last[:date]
    assert_equal 1, first_day.cwday # Monday
    assert_equal 7, last_day.cwday  # Sunday
  end

  test "date_range_for_view returns correct ranges" do
    date = Date.new(2025, 2, 20)
    month = date.month
    builder = Calendar::StructureBuilder.new(date: date, month: month, week_start: :monday)

    week_start, week_end = builder.date_range_for_view("week")
    assert_equal date.beginning_of_week(:monday), week_start
    assert_equal date.end_of_week(:monday), week_end

    month_start, month_end = builder.date_range_for_view("month")
    assert_equal date.beginning_of_month, month_start
    assert_equal date.end_of_month, month_end
  end
end


