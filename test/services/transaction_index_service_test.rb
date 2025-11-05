require "test_helper"

class TransactionIndexServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @account = accounts(:one)
    @date = Date.new(2025, 11, 15)
    @start_date = @date.beginning_of_month
    @end_date = @date.end_of_month
  end

  test "returns expected structure" do
    data = TransactionIndexService.call(@account, "all", {})

    assert_instance_of Hash, data
    assert_includes data, :transactions
    assert_includes data, :date
    assert_includes data, :year
    assert_includes data, :month
    assert_includes data, :filter_type
    assert_includes data, :expense_total
    assert_includes data, :income_total
    assert_includes data, :expense_count
    assert_includes data, :income_count
    assert_includes data, :net_cash_flow
    assert_includes data, :transaction_count
    assert_includes data, :top_category
    assert_includes data, :top_category_amount
    assert_includes data, :top_expense_merchants
    assert_includes data, :top_income_merchants
  end

  test "uses today as default date" do
    data = TransactionIndexService.call(@account, "all", {})
    assert_equal Date.today, data[:date]
  end

  test "parses date from params" do
    data = TransactionIndexService.call(@account, "all", { year: 2025, month: 10 })
    assert_equal Date.new(2025, 10, 1), data[:date]
    assert_equal 2025, data[:year]
    assert_equal 10, data[:month]
  end

  test "filters by expenses" do
    # Clear existing transactions for this account
    @account.transactions.destroy_all

    @account.transactions.create!(
      description: "Expense",
      amount: -100.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Income",
      amount: 500.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    data = TransactionIndexService.call(@account, "expenses", { year: 2025, month: 11 })

    assert_equal "expenses", data[:filter_type]
    assert_equal 1, data[:transactions].count
    assert data[:transactions].all? { |t| t.amount < 0 }
  end

  test "filters by income" do
    @account.transactions.create!(
      description: "Income",
      amount: 500.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    data = TransactionIndexService.call(@account, "income", { year: 2025, month: 11 })

    assert_equal "income", data[:filter_type]
    assert data[:transactions].all? { |t| t.amount > 0 }
  end

  test "filters by hypothetical" do
    @account.transactions.create!(
      description: "Hypothetical",
      amount: -200.0,
      transaction_date: @date,
      status: "HYPOTHETICAL",
      is_hypothetical: true
    )

    data = TransactionIndexService.call(@account, "hypothetical", { year: 2025, month: 11 })

    assert_equal "hypothetical", data[:filter_type]
    assert data[:transactions].all? { |t| t.is_hypothetical }
  end

  test "includes all transactions when filter_type is all" do
    # Clear existing transactions for this account
    @account.transactions.destroy_all

    @account.transactions.create!(
      description: "Expense",
      amount: -100.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Income",
      amount: 500.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    data = TransactionIndexService.call(@account, "all", { year: 2025, month: 11 })

    assert_equal "all", data[:filter_type]
    assert_equal 2, data[:transactions].count
  end

  test "uses TransactionStatsCalculator for stats" do
    data = TransactionIndexService.call(@account, "all", { year: 2025, month: 11 })

    assert data[:expense_total].is_a?(Numeric)
    assert data[:income_total].is_a?(Numeric)
    assert data[:expense_count].is_a?(Integer)
    assert data[:income_count].is_a?(Integer)
  end

  test "uses TransactionMerchantService for top merchants" do
    @account.transactions.create!(
      description: "Merchant",
      amount: -100.0,
      merchant: "Test Merchant",
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    data = TransactionIndexService.call(@account, "all", { year: 2025, month: 11 })

    assert_instance_of Array, data[:top_expense_merchants]
    assert_instance_of Array, data[:top_income_merchants]
  end

  test "only includes transactions within date range" do
    # Clear existing transactions for this account
    @account.transactions.destroy_all

    @account.transactions.create!(
      description: "In Range",
      amount: -100.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Out of Range",
      amount: -200.0,
      transaction_date: @date.prev_month,
      status: "SETTLED",
      is_hypothetical: false
    )

    data = TransactionIndexService.call(@account, "all", { year: 2025, month: 11 })

    assert_equal 1, data[:transactions].count
  end

  test "orders transactions by date descending" do
    # Clear existing transactions for this account
    @account.transactions.destroy_all

    old_txn = @account.transactions.create!(
      description: "Old",
      amount: -100.0,
      transaction_date: @date - 5.days,
      status: "SETTLED",
      is_hypothetical: false
    )
    new_txn = @account.transactions.create!(
      description: "New",
      amount: -200.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    data = TransactionIndexService.call(@account, "all", { year: 2025, month: 11 })

    transaction_ids = data[:transactions].map(&:id)
    assert_equal new_txn.id, transaction_ids.first
    assert_equal old_txn.id, transaction_ids.last
  end
end
