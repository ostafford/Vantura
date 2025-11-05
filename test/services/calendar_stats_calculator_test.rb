require "test_helper"

class CalendarStatsCalculatorTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @account = @user.accounts.create!(
      up_account_id: "test_calendar_stats_account",
      display_name: "Test Calendar Stats Account",
      account_type: "TRANSACTIONAL",
      current_balance: 1000.0
    )
    @date = Date.new(2025, 11, 15)
    @start_date = @date.beginning_of_month
    @end_date = @date.end_of_month
  end

  test "returns expected structure" do
    stats = CalendarStatsCalculator.call(@account, @date, @start_date, @end_date, "month")

    assert_instance_of Hash, stats
    assert_includes stats, :hypothetical_income
    assert_includes stats, :hypothetical_expenses
    assert_includes stats, :actual_income
    assert_includes stats, :actual_expenses
    assert_includes stats, :transaction_count
    assert_includes stats, :month_day
    assert_includes stats, :total_days
    assert_includes stats, :progress_pct
    assert_includes stats, :week_income
    assert_includes stats, :week_expenses
    assert_includes stats, :week_transaction_count
    assert_includes stats, :week_total
    assert_includes stats, :week_expense_count
    assert_includes stats, :week_income_count
    assert_includes stats, :month_expense_count
    assert_includes stats, :month_income_count
    assert_includes stats, :top_expense_merchants
    assert_includes stats, :top_income_merchants
  end

  test "calculates hypothetical income correctly" do
    @account.transactions.create!(
      description: "Hypothetical Income",
      amount: 1000.0,
      transaction_date: @date,
      status: "HYPOTHETICAL",
      is_hypothetical: true
    )

    stats = CalendarStatsCalculator.call(@account, @date, @start_date, @end_date, "month")
    assert_equal 1000.0, stats[:hypothetical_income]
  end

  test "calculates hypothetical expenses correctly" do
    @account.transactions.create!(
      description: "Hypothetical Expense",
      amount: -500.0,
      transaction_date: @date,
      status: "HYPOTHETICAL",
      is_hypothetical: true
    )

    stats = CalendarStatsCalculator.call(@account, @date, @start_date, @end_date, "month")
    assert_equal 500.0, stats[:hypothetical_expenses]
  end

  test "calculates actual income correctly" do
    @account.transactions.create!(
      description: "Salary",
      amount: 3000.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = CalendarStatsCalculator.call(@account, @date, @start_date, @end_date, "month")
    assert_equal 3000.0, stats[:actual_income]
  end

  test "calculates actual expenses correctly" do
    @account.transactions.create!(
      description: "Expense",
      amount: -200.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = CalendarStatsCalculator.call(@account, @date, @start_date, @end_date, "month")
    assert_equal 200.0, stats[:actual_expenses]
  end

  test "calculates transaction count correctly" do
    @account.transactions.create!(
      description: "Transaction 1",
      amount: -100.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Transaction 2",
      amount: 500.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = CalendarStatsCalculator.call(@account, @date, @start_date, @end_date, "month")
    assert_equal 2, stats[:transaction_count]
  end

  test "calculates month progress correctly" do
    stats = CalendarStatsCalculator.call(@account, @date, @start_date, @end_date, "month")

    assert_equal 15, stats[:month_day]
    assert_equal 30, stats[:total_days] # November has 30 days
    # Progress: 15/30 = 50%
    assert_equal 50, stats[:progress_pct]
  end

  test "calculates week stats for week view" do
    week_start = @date.beginning_of_week(:monday)
    week_end = @date.end_of_week(:monday)

    @account.transactions.create!(
      description: "Week Expense",
      amount: -100.0,
      transaction_date: week_start + 2.days,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Week Income",
      amount: 500.0,
      transaction_date: week_start + 3.days,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = CalendarStatsCalculator.call(@account, @date, week_start, week_end, "week")

    assert_equal 500.0, stats[:week_income]
    assert_equal 100.0, stats[:week_expenses]
    assert_equal 2, stats[:week_transaction_count]
    assert_equal 400.0, stats[:week_total]
  end

  test "returns zero for week stats in month view" do
    stats = CalendarStatsCalculator.call(@account, @date, @start_date, @end_date, "month")

    assert_equal 0, stats[:week_income]
    assert_equal 0, stats[:week_expenses]
    assert_equal 0, stats[:week_transaction_count]
    assert_equal 0, stats[:week_total]
  end

  test "calculates week counts for week view" do
    week_start = @date.beginning_of_week(:monday)
    week_end = @date.end_of_week(:monday)

    @account.transactions.create!(
      description: "Week Expense",
      amount: -100.0,
      transaction_date: week_start + 2.days,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Week Income",
      amount: 500.0,
      transaction_date: week_start + 3.days,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = CalendarStatsCalculator.call(@account, @date, week_start, week_end, "week")

    assert_equal 1, stats[:week_expense_count]
    assert_equal 1, stats[:week_income_count]
  end

  test "calculates month counts for month view" do
    @account.transactions.create!(
      description: "Month Expense 1",
      amount: -100.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Month Expense 2",
      amount: -200.0,
      transaction_date: @date - 5.days,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Month Income",
      amount: 500.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = CalendarStatsCalculator.call(@account, @date, @start_date, @end_date, "month")

    assert_equal 2, stats[:month_expense_count]
    assert_equal 1, stats[:month_income_count]
  end

  test "returns top expense merchants for month view" do
    @account.transactions.create!(
      description: "Grocery",
      amount: -100.0,
      merchant: "Grocery Store",
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = CalendarStatsCalculator.call(@account, @date, @start_date, @end_date, "month")

    assert_instance_of Array, stats[:top_expense_merchants]
    # Uses TransactionMerchantService internally
  end

  test "returns top income merchants for month view" do
    @account.transactions.create!(
      description: "Salary",
      amount: 3000.0,
      merchant: "Employer",
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = CalendarStatsCalculator.call(@account, @date, @start_date, @end_date, "month")

    assert_instance_of Array, stats[:top_income_merchants]
  end

  test "only includes transactions within date range" do
    # Transaction within range
    @account.transactions.create!(
      description: "In Range",
      amount: -100.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    # Transaction outside range
    @account.transactions.create!(
      description: "Out of Range",
      amount: -200.0,
      transaction_date: @date - 1.month,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = CalendarStatsCalculator.call(@account, @date, @start_date, @end_date, "month")

    assert_equal 100.0, stats[:actual_expenses]
    assert_equal 1, stats[:transaction_count]
  end

  test "handles empty transaction set" do
    stats = CalendarStatsCalculator.call(@account, @date, @start_date, @end_date, "month")

    assert_equal 0, stats[:hypothetical_income]
    assert_equal 0, stats[:hypothetical_expenses]
    assert_equal 0, stats[:actual_income]
    assert_equal 0, stats[:actual_expenses]
    assert_equal 0, stats[:transaction_count]
  end
end
