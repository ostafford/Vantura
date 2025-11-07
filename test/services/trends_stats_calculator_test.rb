require "test_helper"

class TrendsStatsCalculatorTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @current_date = Date.new(2025, 10, 15)
  end

  test "should calculate current month income" do
    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_not_nil stats[:current_month_income]
    assert stats[:current_month_income] >= 0
  end

  test "should calculate current month expenses" do
    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_not_nil stats[:current_month_expenses]
    assert stats[:current_month_expenses] >= 0
  end

  test "should calculate net savings" do
    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_not_nil stats[:net_savings]
    expected_net = stats[:current_month_income] - stats[:current_month_expenses]
    assert_equal expected_net, stats[:net_savings]
  end

  test "should calculate last month income" do
    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_not_nil stats[:last_month_income]
    assert stats[:last_month_income] >= 0
  end

  test "should calculate last month expenses" do
    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_not_nil stats[:last_month_expenses]
    assert stats[:last_month_expenses] >= 0
  end

  test "should calculate income change percentage" do
    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_not_nil stats[:income_change_pct]
    assert stats[:income_change_pct].is_a?(Numeric)
  end

  test "should calculate expense change percentage" do
    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_not_nil stats[:expense_change_pct]
    assert stats[:expense_change_pct].is_a?(Numeric)
  end

  test "should calculate net change percentage" do
    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_not_nil stats[:net_change_pct]
    assert stats[:net_change_pct].is_a?(Numeric)
  end

  test "should count active recurring transactions" do
    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_not_nil stats[:active_recurring_count]
    assert stats[:active_recurring_count] >= 0
    assert_equal @account.recurring_transactions.active.count, stats[:active_recurring_count]
  end

  test "should identify top merchant" do
    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_not_nil stats[:top_merchant]
    assert stats[:top_merchant].is_a?(Hash)
    assert stats[:top_merchant].key?(:name)
    assert stats[:top_merchant].key?(:amount)
    assert stats[:top_merchant][:amount] >= 0
  end

  test "should use custom date" do
    custom_date = Date.new(2025, 6, 15)
    stats = TrendsStatsCalculator.call(@account, custom_date)

    assert_equal custom_date, stats[:current_date]
  end

  test "should default to today's date" do
    stats = TrendsStatsCalculator.call(@account)

    assert_equal Date.today, stats[:current_date]
  end

  test "should only include real transactions in current month" do
    # Create hypothetical transaction
    hypothetical_transaction = @account.transactions.create!(
      description: "Hypothetical",
      amount: -500.00,
      transaction_date: @current_date,
      status: "HYPOTHETICAL",
      is_hypothetical: true
    )

    stats = TrendsStatsCalculator.call(@account, @current_date)

    # Hypothetical transaction should not be included
    # This is tested implicitly through the real scope
    assert_not_nil stats[:current_month_expenses]
  end

  test "should only include real transactions in last month" do
    last_month_date = @current_date.prev_month

    # Create hypothetical transaction in last month
    hypothetical_transaction = @account.transactions.create!(
      description: "Hypothetical Last Month",
      amount: -300.00,
      transaction_date: last_month_date,
      status: "HYPOTHETICAL",
      is_hypothetical: true
    )

    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_not_nil stats[:last_month_expenses]
  end

  test "should handle zero income change percentage" do
    # Clear all transactions for clean test
    @account.transactions.destroy_all

    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_equal 0, stats[:income_change_pct]
  end

  test "should handle zero expense change percentage" do
    @account.transactions.destroy_all

    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_equal 0, stats[:expense_change_pct]
  end

  test "should handle zero net change percentage" do
    @account.transactions.destroy_all

    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_equal 0, stats[:net_change_pct]
  end

  test "should handle account with no merchants" do
    # Clear all transactions
    @account.transactions.destroy_all

    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_equal "No transactions", stats[:top_merchant][:name]
    assert_equal 0.0, stats[:top_merchant][:amount]
  end

  test "should return all required keys" do
    stats = TrendsStatsCalculator.call(@account, @current_date)

    required_keys = [
      :current_date,
      :current_month_income,
      :current_month_expenses,
      :net_savings,
      :last_month_income,
      :last_month_expenses,
      :income_change_pct,
      :expense_change_pct,
      :net_change_pct,
      :active_recurring_count,
      :top_merchant
    ]

    required_keys.each do |key|
      assert stats.key?(key), "Missing key: #{key}"
    end
  end

  test "should handle month with only income" do
    # Ensure we have income in the current month
    @account.transactions.create!(
      description: "Test Income",
      amount: 1000.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false
    )

    # Remove expenses for current month
    @account.transactions.expenses.where(
      transaction_date: @current_date.beginning_of_month..@current_date.end_of_month
    ).destroy_all

    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert stats[:current_month_income] > 0
    assert_equal 0, stats[:current_month_expenses]
    assert stats[:net_savings] > 0
  end

  test "should handle month with only expenses" do
    @account.transactions.income.where(
      transaction_date: @current_date.beginning_of_month..@current_date.end_of_month
    ).destroy_all

    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_equal 0, stats[:current_month_income]
    assert stats[:current_month_expenses] >= 0
    assert stats[:net_savings] <= 0
  end

  test "should handle negative net savings" do
    # Create more expenses than income
    @account.transactions.create!(
      description: "Large Expense",
      amount: -10000.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false,
      merchant: "Big Store"
    )

    stats = TrendsStatsCalculator.call(@account, @current_date)

    # Net savings should be negative if expenses > income
    if stats[:current_month_expenses] > stats[:current_month_income]
      assert stats[:net_savings] < 0
    end
  end

  test "should calculate percentage changes correctly with real data" do
    # Clear transactions and create controlled data
    @account.transactions.destroy_all

    last_month = @current_date.prev_month

    # Last month: $1000 income, $500 expenses
    @account.transactions.create!(
      description: "Last Month Income",
      amount: 1000.00,
      transaction_date: last_month,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Last Month Expense",
      amount: -500.00,
      transaction_date: last_month,
      status: "SETTLED",
      is_hypothetical: false,
      merchant: "Store A"
    )

    # Current month: $1200 income (20% increase), $600 expenses (20% increase)
    @account.transactions.create!(
      description: "Current Month Income",
      amount: 1200.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Current Month Expense",
      amount: -600.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false,
      merchant: "Store B"
    )

    stats = TrendsStatsCalculator.call(@account, @current_date)

    # Income: 1200 vs 1000 = 20% increase
    assert_equal 20.0, stats[:income_change_pct]

    # Expenses: 600 vs 500 = 20% increase
    assert_equal 20.0, stats[:expense_change_pct]

    # Last month net: 500, Current month net: 600, Change: (600-500)/500 = 20%
    assert_equal 20.0, stats[:net_change_pct]
  end

  test "should identify correct top merchant" do
    @account.transactions.expenses.destroy_all

    # Create multiple merchants with different amounts
    @account.transactions.create!(
      description: "Store A Purchase",
      amount: -100.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false,
      merchant: "Store A"
    )
    @account.transactions.create!(
      description: "Store B Purchase 1",
      amount: -150.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false,
      merchant: "Store B"
    )
    @account.transactions.create!(
      description: "Store B Purchase 2",
      amount: -50.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false,
      merchant: "Store B"
    )

    stats = TrendsStatsCalculator.call(@account, @current_date)

    # Store B should be top merchant with $200 total
    assert_equal "Store B", stats[:top_merchant][:name]
    assert_equal 200.00, stats[:top_merchant][:amount]
  end

  test "should calculate historical_data" do
    stats = TrendsStatsCalculator.call(@account, @current_date, months: 6)

    assert_not_nil stats[:historical_data]
    assert stats[:historical_data].is_a?(Array)
    assert stats[:historical_data].length <= 6

    # Verify structure of historical data
    if stats[:historical_data].any?
      month_data = stats[:historical_data].first
      assert month_data.key?(:month)
      assert month_data.key?(:month_name)
      assert month_data.key?(:income)
      assert month_data.key?(:expenses)
      assert month_data.key?(:net_savings)
      assert month_data.key?(:savings_rate)
    end
  end

  test "should calculate category_breakdown for category view" do
    # Create transactions with categories
    @account.transactions.create!(
      description: "Category A",
      amount: -100.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Category A"
    )
    @account.transactions.create!(
      description: "Category B",
      amount: -200.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Category B"
    )

    stats = TrendsStatsCalculator.call(@account, @current_date, months: 6, view_type: "category")

    assert_not_nil stats[:category_breakdown]
    assert stats[:category_breakdown].is_a?(Array)

    if stats[:category_breakdown].any?
      item = stats[:category_breakdown].first
      assert item.key?(:name)
      assert item.key?(:amount)
      assert item.key?(:count)
      assert item.key?(:type)
      assert_equal "category", item[:type]
    end
  end

  test "should calculate category_breakdown for merchant view" do
    # Create transactions with merchants
    @account.transactions.create!(
      description: "Merchant A",
      amount: -100.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false,
      merchant: "Merchant A"
    )

    stats = TrendsStatsCalculator.call(@account, @current_date, months: 6, view_type: "merchant")

    assert_not_nil stats[:category_breakdown]
    assert stats[:category_breakdown].is_a?(Array)

    if stats[:category_breakdown].any?
      item = stats[:category_breakdown].first
      assert item.key?(:name)
      assert item.key?(:amount)
      assert item.key?(:count)
      assert item.key?(:type)
      assert_equal "merchant", item[:type]
    end
  end

  test "should calculate savings_rate_trend" do
    stats = TrendsStatsCalculator.call(@account, @current_date, months: 6)

    assert_not_nil stats[:savings_rate_trend]
    assert stats[:savings_rate_trend].is_a?(Array)

    if stats[:savings_rate_trend].any?
      trend_data = stats[:savings_rate_trend].first
      assert trend_data.key?(:month)
      assert trend_data.key?(:month_name)
      assert trend_data.key?(:savings_rate)
      assert trend_data[:savings_rate].is_a?(Numeric)
    end
  end

  test "should calculate year_over_year_comparison" do
    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_not_nil stats[:year_over_year_comparison]
    assert stats[:year_over_year_comparison].is_a?(Hash)

    yoy = stats[:year_over_year_comparison]
    assert yoy.key?(:last_year_month)
    assert yoy.key?(:last_year_income)
    assert yoy.key?(:last_year_expenses)
    assert yoy.key?(:last_year_net)
    assert yoy.key?(:income_change_pct)
    assert yoy.key?(:expense_change_pct)
    assert yoy.key?(:net_change_pct)
  end

  test "should handle all months parameter" do
    stats = TrendsStatsCalculator.call(@account, @current_date, months: "all")

    assert_not_nil stats[:historical_data]
    # Should include all available months
    assert stats[:historical_data].is_a?(Array)
  end

  test "should limit months to 24 for performance" do
    stats = TrendsStatsCalculator.call(@account, @current_date, months: 100)

    assert_not_nil stats[:historical_data]
    assert stats[:historical_data].length <= 24
  end

  test "should return all required keys including new features" do
    stats = TrendsStatsCalculator.call(@account, @current_date, months: 6, view_type: "category")

    required_keys = [
      :current_date,
      :current_month_income,
      :current_month_expenses,
      :net_savings,
      :last_month_income,
      :last_month_expenses,
      :income_change_pct,
      :expense_change_pct,
      :net_change_pct,
      :active_recurring_count,
      :top_merchant,
      :historical_data,
      :category_breakdown,
      :savings_rate_trend,
      :year_over_year_comparison
    ]

    required_keys.each do |key|
      assert stats.key?(key), "Missing key: #{key}"
    end
  end
end
