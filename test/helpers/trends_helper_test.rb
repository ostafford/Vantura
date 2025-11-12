require "test_helper"

class TrendsHelperTest < ActionView::TestCase
  include TrendsHelper

  setup do
    @account = accounts(:one)
    @current_date = Date.new(2025, 10, 15)
    @trends_stats = TrendsStatsCalculator.call(@account, @current_date)
  end

  test "should return savings rate" do
    assert_not_nil trends_savings_rate
    assert trends_savings_rate.is_a?(Numeric)
  end

  test "should return last month savings rate" do
    assert_not_nil trends_last_month_savings_rate
    assert trends_last_month_savings_rate.is_a?(Numeric)
  end

  test "should return savings rate change" do
    assert_not_nil trends_savings_rate_change
    assert trends_savings_rate_change.is_a?(Numeric)
  end

  test "should return three month avg savings rate" do
    assert_not_nil trends_three_month_avg_savings_rate
    assert trends_three_month_avg_savings_rate.is_a?(Numeric)
  end

  test "should return savings rate trend direction" do
    assert_not_nil trends_savings_rate_trend_direction
    assert_includes ["improving", "stable", "declining"], trends_savings_rate_trend_direction
  end

  test "should return spending rate data" do
    assert_not_nil trends_spending_rate_data
    assert trends_spending_rate_data.is_a?(Hash)
  end

  test "should return spending rate" do
    assert_not_nil trends_spending_rate
    assert trends_spending_rate.is_a?(Numeric)
  end

  test "should return income utilization percentage" do
    assert_not_nil trends_income_utilization_pct
    assert trends_income_utilization_pct.is_a?(Numeric)
    assert trends_income_utilization_pct >= 0
  end

  test "should return days of income remaining when positive net" do
    # This may be nil if net savings is negative
    if trends_days_of_income_remaining
      assert trends_days_of_income_remaining.is_a?(Numeric)
      assert trends_days_of_income_remaining > 0
    end
  end

  test "should return recurring vs discretionary data" do
    assert_not_nil trends_recurring_vs_discretionary
    assert trends_recurring_vs_discretionary.is_a?(Hash)
  end

  test "should return recurring total" do
    assert_not_nil trends_recurring_total
    assert trends_recurring_total.is_a?(Numeric)
    assert trends_recurring_total >= 0
  end

  test "should return discretionary total" do
    assert_not_nil trends_discretionary_total
    assert trends_discretionary_total.is_a?(Numeric)
    assert trends_discretionary_total >= 0
  end

  test "should return recurring percentage" do
    assert_not_nil trends_recurring_pct
    assert trends_recurring_pct.is_a?(Numeric)
    assert trends_recurring_pct.between?(0, 100)
  end

  test "should return discretionary percentage" do
    assert_not_nil trends_discretionary_pct
    assert trends_discretionary_pct.is_a?(Numeric)
    assert trends_discretionary_pct.between?(0, 100)
  end

  test "should return category changes" do
    assert_not_nil trends_category_changes
    assert trends_category_changes.is_a?(Array)
  end

  test "should return top category increase" do
    # May be nil if no increases
    if trends_top_category_increase
      assert trends_top_category_increase.is_a?(Hash)
      assert trends_top_category_increase.key?(:name)
      assert trends_top_category_increase.key?(:change_amount)
    end
  end

  test "should return top category decrease" do
    # May be nil if no decreases
    if trends_top_category_decrease
      assert trends_top_category_decrease.is_a?(Hash)
      assert trends_top_category_decrease.key?(:name)
      assert trends_top_category_decrease.key?(:change_amount)
    end
  end

  test "should return income stability data" do
    assert_not_nil trends_income_stability
    assert trends_income_stability.is_a?(Hash)
  end

  test "should return income stability score" do
    assert_not_nil trends_income_stability_score
    assert trends_income_stability_score.is_a?(Numeric)
    assert trends_income_stability_score.between?(0, 100)
  end

  test "should return income stability message" do
    assert_not_nil trends_income_stability_message
    assert trends_income_stability_message.is_a?(String)
    assert_includes ["consistent", "varies month-to-month"], trends_income_stability_message
  end

  test "should return quick actions" do
    assert_not_nil trends_quick_actions
    assert trends_quick_actions.is_a?(Array)
  end

  test "should handle nil trends stats gracefully" do
    @trends_stats = nil

    assert_equal 0, trends_savings_rate
    assert_equal 0, trends_last_month_savings_rate
    assert_equal 0, trends_savings_rate_change
    assert_equal 0, trends_three_month_avg_savings_rate
    assert_equal "stable", trends_savings_rate_trend_direction
    assert_equal({}, trends_spending_rate_data)
    assert_equal 0, trends_spending_rate
    assert_equal 0, trends_income_utilization_pct
    assert_nil trends_days_of_income_remaining
    assert_equal({}, trends_recurring_vs_discretionary)
    assert_equal 0, trends_recurring_total
    assert_equal 0, trends_discretionary_total
    assert_equal 0, trends_recurring_pct
    assert_equal 0, trends_discretionary_pct
    assert_equal [], trends_category_changes
    assert_nil trends_top_category_increase
    assert_nil trends_top_category_decrease
    assert_equal({}, trends_income_stability)
    assert_equal 100, trends_income_stability_score
    assert_equal "consistent", trends_income_stability_message
    assert_equal [], trends_quick_actions
  end
end

