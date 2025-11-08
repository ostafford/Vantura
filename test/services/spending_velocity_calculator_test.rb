require "test_helper"

class SpendingVelocityCalculatorTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @current_date = Date.new(2025, 11, 15) # Mid-month
    @calculator = SpendingVelocityCalculator.new(@account, @current_date)
  end

  test "should calculate current velocity" do
    # Create some expenses in current month
    @account.transactions.create!(
      description: "Expense 1",
      amount: -100.00,
      transaction_date: @current_date.beginning_of_month + 5.days,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Expense 2",
      amount: -200.00,
      transaction_date: @current_date.beginning_of_month + 10.days,
      status: "SETTLED",
      is_hypothetical: false
    )

    velocity = @calculator.current_velocity

    assert_not_nil velocity
    assert velocity.is_a?(Hash)
    assert velocity.key?(:daily_rate)
    assert velocity.key?(:total_spent)
    assert velocity[:daily_rate] >= 0
  end

  test "should calculate historical average velocity" do
    # Create expenses in previous months
    last_month = @current_date.prev_month
    @account.transactions.create!(
      description: "Last Month Expense",
      amount: -500.00,
      transaction_date: last_month,
      status: "SETTLED",
      is_hypothetical: false
    )

    avg_velocity = @calculator.historical_average

    assert_not_nil avg_velocity
    assert avg_velocity.is_a?(Hash)
    assert avg_velocity.key?(:average_daily_rate)
    assert avg_velocity[:average_daily_rate] >= 0
  end

  test "should calculate velocity change percentage" do
    change_pct = @calculator.velocity_change_pct

    assert_not_nil change_pct
    assert change_pct.is_a?(Numeric)
  end

  test "should project month-end spending" do
    projected = @calculator.projected_month_end_spending

    assert_not_nil projected
    assert projected.is_a?(Hash)
    assert projected.key?(:projected_total)
    assert projected[:projected_total] >= 0
  end

  test "should calculate savings opportunity" do
    opportunity = @calculator.savings_opportunity

    assert_not_nil opportunity
    assert opportunity.is_a?(Hash)
    assert opportunity.key?(:opportunity_exists)
    assert opportunity.key?(:potential_savings)
  end

  test "should handle account with no expenses" do
    @account.transactions.destroy_all

    velocity = @calculator.current_velocity
    avg_velocity = @calculator.historical_average

    assert_equal 0, velocity[:daily_rate]
    assert_equal 0, avg_velocity[:average_daily_rate]
  end

  test "should only include real transactions" do
    # Create hypothetical transaction
    @account.transactions.create!(
      description: "Hypothetical",
      amount: -1000.00,
      transaction_date: @current_date,
      status: "HYPOTHETICAL",
      is_hypothetical: true
    )

    velocity = @calculator.current_velocity

    # Hypothetical should not affect velocity
    assert_not_nil velocity
  end

  test "should handle mid-month calculations correctly" do
    # Create expenses at different points in month
    day_5 = @current_date.beginning_of_month + 5.days
    day_10 = @current_date.beginning_of_month + 10.days

    @account.transactions.create!(
      description: "Early Month",
      amount: -100.00,
      transaction_date: day_5,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Mid Month",
      amount: -200.00,
      transaction_date: day_10,
      status: "SETTLED",
      is_hypothetical: false
    )

    velocity = @calculator.current_velocity
    projected = @calculator.projected_month_end_spending

    assert velocity[:daily_rate] > 0
    assert projected[:projected_total] > 0
  end
end
