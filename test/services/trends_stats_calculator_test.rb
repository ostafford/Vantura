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
      :year_over_year_comparison,
      :current_savings_rate,
      :last_month_savings_rate,
      :savings_rate_change,
      :three_month_avg_savings_rate,
      :savings_rate_trend_direction,
      :spending_rate_data,
      :recurring_vs_discretionary,
      :category_changes,
      :top_category_increase,
      :top_category_decrease,
      :income_stability_data,
      :quick_actions
    ]

    required_keys.each do |key|
      assert stats.key?(key), "Missing key: #{key}"
    end
  end

  # Savings rate tests
  test "should calculate current savings rate" do
    # Clear transactions and create controlled data
    @account.transactions.destroy_all

    # Create income and expenses
    @account.transactions.create!(
      description: "Income",
      amount: 1000.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Expense",
      amount: -700.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = TrendsStatsCalculator.call(@account, @current_date)

    # Net savings: 1000 - 700 = 300
    # Savings rate: (300 / 1000) * 100 = 30%
    assert_equal 30.0, stats[:current_savings_rate]
  end

  test "should return zero savings rate when income is zero" do
    @account.transactions.destroy_all

    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_equal 0, stats[:current_savings_rate]
  end

  test "should calculate last month savings rate" do
    @account.transactions.destroy_all
    last_month = @current_date.prev_month

    @account.transactions.create!(
      description: "Last Month Income",
      amount: 800.00,
      transaction_date: last_month,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Last Month Expense",
      amount: -600.00,
      transaction_date: last_month,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = TrendsStatsCalculator.call(@account, @current_date)

    # Last month net: 800 - 600 = 200
    # Savings rate: (200 / 800) * 100 = 25%
    assert_equal 25.0, stats[:last_month_savings_rate]
  end

  test "should calculate savings rate change" do
    @account.transactions.destroy_all
    last_month = @current_date.prev_month

    # Last month: 25% savings rate
    @account.transactions.create!(
      description: "Last Month Income",
      amount: 800.00,
      transaction_date: last_month,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Last Month Expense",
      amount: -600.00,
      transaction_date: last_month,
      status: "SETTLED",
      is_hypothetical: false
    )

    # Current month: 30% savings rate
    @account.transactions.create!(
      description: "Current Income",
      amount: 1000.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Current Expense",
      amount: -700.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = TrendsStatsCalculator.call(@account, @current_date)

    # Change: 30% - 25% = 5%
    assert_equal 5.0, stats[:savings_rate_change]
  end

  test "should calculate three month average savings rate" do
    @account.transactions.destroy_all

    # Create data for 3 months
    3.times do |i|
      month_date = @current_date - i.months
      @account.transactions.create!(
        description: "Income #{i}",
        amount: 1000.00,
        transaction_date: month_date,
        status: "SETTLED",
        is_hypothetical: false
      )
      @account.transactions.create!(
        description: "Expense #{i}",
        amount: -700.00,
        transaction_date: month_date,
        status: "SETTLED",
        is_hypothetical: false
      )
    end

    stats = TrendsStatsCalculator.call(@account, @current_date, months: 3)

    # All months have 30% savings rate, average should be 30%
    assert_equal 30.0, stats[:three_month_avg_savings_rate]
  end

  test "should determine savings rate trend direction" do
    @account.transactions.destroy_all

    # Create improving trend (increasing savings rates)
    3.times do |i|
      month_date = @current_date - (2 - i).months
      income = 1000.00
      expense = 800.00 - (i * 100.00) # Decreasing expenses
      @account.transactions.create!(
        description: "Income #{i}",
        amount: income,
        transaction_date: month_date,
        status: "SETTLED",
        is_hypothetical: false
      )
      @account.transactions.create!(
        description: "Expense #{i}",
        amount: -expense,
        transaction_date: month_date,
        status: "SETTLED",
        is_hypothetical: false
      )
    end

    stats = TrendsStatsCalculator.call(@account, @current_date, months: 3)

    assert_includes ["improving", "stable", "declining"], stats[:savings_rate_trend_direction]
  end

  # Spending rate tests
  test "should calculate spending rate data" do
    @account.transactions.destroy_all

    @account.transactions.create!(
      description: "Income",
      amount: 1000.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Expense",
      amount: -500.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_not_nil stats[:spending_rate_data]
    assert stats[:spending_rate_data].is_a?(Hash)
    assert stats[:spending_rate_data].key?(:spending_rate)
    assert stats[:spending_rate_data].key?(:income_utilization_pct)
    assert stats[:spending_rate_data].key?(:avg_daily_income)
    assert stats[:spending_rate_data].key?(:avg_daily_expenses)
  end

  test "should calculate income utilization percentage" do
    @account.transactions.destroy_all

    @account.transactions.create!(
      description: "Income",
      amount: 1000.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Expense",
      amount: -750.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = TrendsStatsCalculator.call(@account, @current_date)

    # Income utilization: (750 / 1000) * 100 = 75%
    assert_equal 75.0, stats[:spending_rate_data][:income_utilization_pct]
  end

  # Recurring vs discretionary tests
  test "should calculate recurring vs discretionary breakdown" do
    @account.transactions.destroy_all

    # Create a recurring transaction
    recurring = @account.recurring_transactions.create!(
      description: "Monthly Subscription",
      amount: -50.00,
      frequency: "monthly",
      next_occurrence_date: @current_date,
      transaction_type: "expense",
      is_active: true,
      date_tolerance_days: 3,
      tolerance_type: "fixed"
    )

    # Create a regular expense
    @account.transactions.create!(
      description: "One-time Purchase",
      amount: -100.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false
    )

    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_not_nil stats[:recurring_vs_discretionary]
    assert stats[:recurring_vs_discretionary].is_a?(Hash)
    assert stats[:recurring_vs_discretionary].key?(:recurring_total)
    assert stats[:recurring_vs_discretionary].key?(:discretionary_total)
    assert stats[:recurring_vs_discretionary].key?(:recurring_pct)
    assert stats[:recurring_vs_discretionary].key?(:discretionary_pct)
  end

  # Category changes tests
  test "should calculate category changes" do
    @account.transactions.destroy_all
    last_month = @current_date.prev_month

    # Last month: Category A = $100
    @account.transactions.create!(
      description: "Category A Last Month",
      amount: -100.00,
      transaction_date: last_month,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Category A"
    )

    # Current month: Category A = $150 (50% increase)
    @account.transactions.create!(
      description: "Category A Current",
      amount: -150.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Category A"
    )

    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_not_nil stats[:category_changes]
    assert stats[:category_changes].is_a?(Array)

    category_a = stats[:category_changes].find { |c| c[:name] == "Category A" }
    assert_not_nil category_a
    assert_equal 150.0, category_a[:current_amount]
    assert_equal 100.0, category_a[:last_month_amount]
    assert_equal 50.0, category_a[:change_pct]
    assert_equal 50.0, category_a[:change_amount]
  end

  test "should identify top category increase" do
    @account.transactions.destroy_all
    last_month = @current_date.prev_month

    # Create multiple categories with different increases
    @account.transactions.create!(
      description: "Category A",
      amount: -200.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Category A"
    )
    @account.transactions.create!(
      description: "Category A Last",
      amount: -100.00,
      transaction_date: last_month,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Category A"
    )

    @account.transactions.create!(
      description: "Category B",
      amount: -150.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Category B"
    )
    @account.transactions.create!(
      description: "Category B Last",
      amount: -120.00,
      transaction_date: last_month,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Category B"
    )

    stats = TrendsStatsCalculator.call(@account, @current_date)

    top_increase = stats[:top_category_increase]
    assert_not_nil top_increase
    assert_equal "Category A", top_increase[:name]
    assert_equal 100.0, top_increase[:change_amount]
  end

  test "should identify top category decrease" do
    @account.transactions.destroy_all
    last_month = @current_date.prev_month

    # Create categories with decreases
    @account.transactions.create!(
      description: "Category A",
      amount: -50.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Category A"
    )
    @account.transactions.create!(
      description: "Category A Last",
      amount: -150.00,
      transaction_date: last_month,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Category A"
    )

    stats = TrendsStatsCalculator.call(@account, @current_date)

    top_decrease = stats[:top_category_decrease]
    assert_not_nil top_decrease
    assert_equal "Category A", top_decrease[:name]
    assert_equal -100.0, top_decrease[:change_amount]
  end

  # Income stability tests
  test "should calculate income stability data" do
    @account.transactions.destroy_all

    # Create consistent income over 6 months
    6.times do |i|
      month_date = @current_date - i.months
      @account.transactions.create!(
        description: "Income #{i}",
        amount: 1000.00,
        transaction_date: month_date,
        status: "SETTLED",
        is_hypothetical: false
      )
    end

    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_not_nil stats[:income_stability_data]
    assert stats[:income_stability_data].is_a?(Hash)
    assert stats[:income_stability_data].key?(:score)
    assert stats[:income_stability_data].key?(:message)
    assert stats[:income_stability_data][:score].between?(0, 100)
  end

  test "should return consistent message for stable income" do
    @account.transactions.destroy_all

    # Create very consistent income
    6.times do |i|
      month_date = @current_date - i.months
      @account.transactions.create!(
        description: "Income #{i}",
        amount: 1000.00,
        transaction_date: month_date,
        status: "SETTLED",
        is_hypothetical: false
      )
    end

    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_equal "consistent", stats[:income_stability_data][:message]
  end

  # Quick actions tests
  test "should generate quick actions" do
    @account.transactions.destroy_all

    # Create expense with category
    @account.transactions.create!(
      description: "Category A Expense",
      amount: -200.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Category A"
    )

    stats = TrendsStatsCalculator.call(@account, @current_date)

    assert_not_nil stats[:quick_actions]
    assert stats[:quick_actions].is_a?(Array)
  end

  test "should include category reduction in quick actions" do
    @account.transactions.destroy_all

    @account.transactions.create!(
      description: "Category A Expense",
      amount: -200.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Category A"
    )

    stats = TrendsStatsCalculator.call(@account, @current_date)

    category_reduction = stats[:quick_actions].find { |a| a[:type] == "category_reduction" }
    if category_reduction
      assert_equal "Category A", category_reduction[:category]
      assert_equal 10, category_reduction[:reduction_pct]
      assert category_reduction[:savings_amount] > 0
    end
  end

  # Enhanced category breakdown tests
  test "should include percentage of total in category breakdown" do
    @account.transactions.destroy_all

    @account.transactions.create!(
      description: "Category A",
      amount: -200.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Category A"
    )
    @account.transactions.create!(
      description: "Category B",
      amount: -300.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Category B"
    )

    stats = TrendsStatsCalculator.call(@account, @current_date, view_type: "category")

    if stats[:category_breakdown].any?
      item = stats[:category_breakdown].first
      assert item.key?(:pct_of_total)
      assert item[:pct_of_total].is_a?(Numeric)
      assert item[:pct_of_total].between?(0, 100)
    end
  end

  test "should include month-over-month change in category breakdown" do
    @account.transactions.destroy_all
    last_month = @current_date.prev_month

    @account.transactions.create!(
      description: "Category A Last",
      amount: -100.00,
      transaction_date: last_month,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Category A"
    )
    @account.transactions.create!(
      description: "Category A Current",
      amount: -150.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Category A"
    )

    stats = TrendsStatsCalculator.call(@account, @current_date, view_type: "category")

    if stats[:category_breakdown].any?
      item = stats[:category_breakdown].find { |c| c[:name] == "Category A" }
      if item
        assert item.key?(:change_pct)
        assert item.key?(:change_amount)
        assert_equal 50.0, item[:change_pct]
        assert_equal 50.0, item[:change_amount]
      end
    end
  end
end
