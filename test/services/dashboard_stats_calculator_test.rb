require "test_helper"

class DashboardStatsCalculatorTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @account = @user.accounts.create!(
      up_account_id: "test_stats_account",
      display_name: "Test Stats Account",
      account_type: "TRANSACTIONAL",
      current_balance: 5000.0
    )
    @today = Date.today
  end

  test "should return hash with all required keys" do
    stats = DashboardStatsCalculator.call(@account)

    assert_instance_of Hash, stats
    assert_includes stats, :current_date
    assert_includes stats, :recent_transactions
    assert_includes stats, :expense_count
    assert_includes stats, :expense_total
    assert_includes stats, :income_count
    assert_includes stats, :income_total
    assert_includes stats, :end_of_month_balance
  end

  test "should use today as default date" do
    stats = DashboardStatsCalculator.call(@account)
    assert_equal Date.today, stats[:current_date]
  end

  test "should use provided date" do
    custom_date = Date.new(2025, 6, 15)
    stats = DashboardStatsCalculator.call(@account, custom_date)
    assert_equal custom_date, stats[:current_date]
  end

  test "should calculate expense count correctly" do
    # Add expenses for current month
    @account.transactions.create!(
      description: "Expense 1",
      amount: -100.0,
      transaction_date: @today,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Expense 2",
      amount: -50.0,
      transaction_date: @today,
      status: "SETTLED",
      is_hypothetical: false
    )

    # Add expense for different month (should not be counted)
    @account.transactions.create!(
      description: "Different Month",
      amount: -200.0,
      transaction_date: @today - 2.months,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = DashboardStatsCalculator.call(@account, @today)
    assert_equal 2, stats[:expense_count]
  end

  test "should calculate expense total correctly" do
    @account.transactions.create!(
      description: "Expense 1",
      amount: -100.0,
      transaction_date: @today,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Expense 2",
      amount: -50.0,
      transaction_date: @today,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = DashboardStatsCalculator.call(@account, @today)
    assert_equal 150.0, stats[:expense_total]
  end

  test "should calculate income count correctly" do
    @account.transactions.create!(
      description: "Salary",
      amount: 3000.0,
      transaction_date: @today,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Bonus",
      amount: 500.0,
      transaction_date: @today,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = DashboardStatsCalculator.call(@account, @today)
    assert_equal 2, stats[:income_count]
  end

  test "should calculate income total correctly" do
    @account.transactions.create!(
      description: "Salary",
      amount: 3000.0,
      transaction_date: @today,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Bonus",
      amount: 500.0,
      transaction_date: @today,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = DashboardStatsCalculator.call(@account, @today)
    assert_equal 3500.0, stats[:income_total]
  end

  test "should return zero counts and totals when no transactions" do
    stats = DashboardStatsCalculator.call(@account, @today)

    assert_equal 0, stats[:expense_count]
    assert_equal 0, stats[:expense_total]
    assert_equal 0, stats[:income_count]
    assert_equal 0, stats[:income_total]
  end

  test "should return recent transactions limited to 10" do
    # Create 15 transactions
    15.times do |i|
      @account.transactions.create!(
        description: "Transaction #{i}",
        amount: -10.0 * (i + 1),
        transaction_date: @today - i.days,
        status: "SETTLED",
        is_hypothetical: false
      )
    end

    stats = DashboardStatsCalculator.call(@account, @today)
    assert_equal 10, stats[:recent_transactions].length
  end

  test "should order recent transactions by date descending" do
    # Create transactions with different dates
    old_txn = @account.transactions.create!(
      description: "Old",
      amount: -100.0,
      transaction_date: @today - 5.days,
      status: "SETTLED",
      is_hypothetical: false
    )

    new_txn = @account.transactions.create!(
      description: "New",
      amount: -50.0,
      transaction_date: @today,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = DashboardStatsCalculator.call(@account, @today)
    assert_equal new_txn.id, stats[:recent_transactions].first.id
    assert_equal old_txn.id, stats[:recent_transactions].last.id
  end

  test "should only include transactions from specified month" do
    # Current month transaction
    @account.transactions.create!(
      description: "Current Month",
      amount: -100.0,
      transaction_date: @today,
      status: "SETTLED",
      is_hypothetical: false
    )

    # Last month transaction
    @account.transactions.create!(
      description: "Last Month",
      amount: -200.0,
      transaction_date: @today - 1.month,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = DashboardStatsCalculator.call(@account, @today)

    assert_equal 1, stats[:expense_count]
    assert_equal 100.0, stats[:expense_total]
  end

  test "should calculate end of month balance" do
    @account.update!(current_balance: 1000.0)

    # Add future transaction
    @account.transactions.create!(
      description: "Future Expense",
      amount: -200.0,
      transaction_date: @today + 5.days,
      status: "HYPOTHETICAL",
      is_hypothetical: true
    )

    stats = DashboardStatsCalculator.call(@account, @today)
    assert_equal 800.0, stats[:end_of_month_balance]
  end

  test "should handle mixed expense and income transactions" do
    @account.transactions.create!(
      description: "Expense",
      amount: -100.0,
      transaction_date: @today,
      status: "SETTLED",
      is_hypothetical: false
    )

    @account.transactions.create!(
      description: "Income",
      amount: 500.0,
      transaction_date: @today,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = DashboardStatsCalculator.call(@account, @today)

    assert_equal 1, stats[:expense_count]
    assert_equal 100.0, stats[:expense_total]
    assert_equal 1, stats[:income_count]
    assert_equal 500.0, stats[:income_total]
  end
end
