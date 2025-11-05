require "test_helper"

class TransactionSearchServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    # Create a fresh account to avoid fixture interference
    @account = @user.accounts.create!(
      up_account_id: "test_search_service_account",
      display_name: "Test Search Service Account",
      account_type: "TRANSACTIONAL",
      current_balance: 1000.0
    )
    @date = Date.new(2025, 11, 15)
  end

  test "returns expected structure for search results" do
    @account.transactions.create!(
      description: "Grocery Store",
      amount: -100.0,
      merchant: "Grocery Store",
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    data = TransactionSearchService.call(@account, "grocery", { year: 2025, month: 11 })

    assert_instance_of Hash, data
    assert_equal "search", data[:filter_type]
    assert_includes data, :transactions
    assert_includes data, :date
    assert_includes data, :expense_total
    assert_includes data, :income_total
    assert_includes data, :top_expense_merchants
  end

  test "returns expected structure for month results when query < 3 chars" do
    data = TransactionSearchService.call(@account, "gr", { year: 2025, month: 11 }, "all")

    assert_equal "all", data[:filter_type]
    assert_instance_of Hash, data
    assert_includes data, :transactions
  end

  test "searches by description" do
    @account.transactions.create!(
      description: "Grocery Shopping",
      amount: -100.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    data = TransactionSearchService.call(@account, "grocery", { year: 2025, month: 11 })

    assert_equal 1, data[:transactions].count
    assert_includes data[:transactions].first.description.downcase, "grocery"
  end

  test "searches by category" do
    @account.transactions.create!(
      description: "Shopping",
      category: "groceries",
      amount: -100.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    data = TransactionSearchService.call(@account, "groceries", { year: 2025, month: 11 })

    assert_equal 1, data[:transactions].count
  end

  test "searches by merchant" do
    @account.transactions.create!(
      description: "Purchase",
      merchant: "Grocery Store",
      amount: -100.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    data = TransactionSearchService.call(@account, "grocery", { year: 2025, month: 11 })

    assert_equal 1, data[:transactions].count
  end

  test "case insensitive search" do
    @account.transactions.create!(
      description: "GROCERY SHOPPING",
      amount: -100.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    data = TransactionSearchService.call(@account, "grocery", { year: 2025, month: 11 })

    assert_equal 1, data[:transactions].count
  end

  test "limits search results to 10" do
    15.times do |i|
      @account.transactions.create!(
        description: "Grocery #{i}",
        amount: -100.0,
        transaction_date: @date,
        status: "SETTLED",
        is_hypothetical: false
      )
    end

    data = TransactionSearchService.call(@account, "grocery", { year: 2025, month: 11 })

    assert data[:transactions].count <= 10
  end

  test "calculates search expense total" do
    @account.transactions.create!(
      description: "Grocery 1",
      amount: -100.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Grocery 2",
      amount: -50.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    data = TransactionSearchService.call(@account, "grocery", { year: 2025, month: 11 })

    assert_equal 150.0, data[:expense_total]
  end

  test "calculates search income total" do
    @account.transactions.create!(
      description: "Salary Grocery",
      amount: 1000.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    data = TransactionSearchService.call(@account, "grocery", { year: 2025, month: 11 })

    assert_equal 1000.0, data[:income_total]
  end

  test "returns month results when query too short" do
    data = TransactionSearchService.call(@account, "ab", { year: 2025, month: 11 }, "expenses")

    assert_equal "expenses", data[:filter_type]
    assert_not_equal "search", data[:filter_type]
  end

  test "only searches within date range" do
    @account.transactions.create!(
      description: "Grocery In Range",
      amount: -100.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Grocery Out of Range",
      amount: -200.0,
      transaction_date: @date.prev_month,
      status: "SETTLED",
      is_hypothetical: false
    )

    data = TransactionSearchService.call(@account, "grocery", { year: 2025, month: 11 })

    assert_equal 1, data[:transactions].count
  end

  test "handles empty search results" do
    data = TransactionSearchService.call(@account, "nonexistent", { year: 2025, month: 11 })

    assert_equal 0, data[:transactions].count
    assert_equal 0, data[:expense_total]
    assert_equal 0, data[:income_total]
  end
end
