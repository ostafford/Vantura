require "test_helper"

class TransactionFlowTest < ActionDispatch::IntegrationTest
  def setup
    sign_in_as :one
    @account = accounts(:one)
  end

  test "create and view hypothetical transaction" do
    # Count before
    initial_count = @account.transactions.count

    # Create transaction (Turbo Stream request)
    post transactions_path, params: {
      transaction: {
        description: "Test Purchase",
        amount: 100,
        transaction_date: Date.today,
        transaction_type: "expense"
      }
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    # Turbo Stream returns 200 OK
    assert_response :success

    # Verify transaction was created
    assert_equal initial_count + 1, @account.transactions.reload.count
    transaction = @account.transactions.last
    assert_equal "Test Purchase", transaction.description
    assert_equal -100.0, transaction.amount  # Negative for expense
    assert transaction.is_hypothetical
  end

  test "delete hypothetical transaction" do
    # Create a hypothetical transaction
    transaction = @account.transactions.create!(
      description: "Temporary Transaction",
      amount: -50.0,
      transaction_date: Date.today,
      status: "HYPOTHETICAL",
      is_hypothetical: true
    )

    # Delete it
    delete transaction_path(transaction)

    assert_redirected_to root_path
    follow_redirect!

    # Verify transaction was deleted
    assert_not Transaction.exists?(transaction.id)
  end

  test "cannot delete real transaction from Up Bank" do
    # Create a real transaction
    transaction = @account.transactions.create!(
      description: "Real Transaction",
      amount: -50.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    # Attempt to delete
    delete transaction_path(transaction)

    assert_redirected_to root_path
    follow_redirect!

    # Should still exist
    assert Transaction.exists?(transaction.id)
  end

  test "view all transactions page" do
    get transactions_path

    assert_response :success
    assert_select "h1", "Your Transactions"
    assert_select "table"
  end

  test "view expenses only" do
    get transactions_path, params: { filter: "expenses" }

    assert_response :success
    assert_select "h1", "Your Transactions"
  end

  test "view income only" do
    get transactions_path, params: { filter: "income" }

    assert_response :success
    assert_select "h1", "Your Transactions"
  end

  test "navigate calendar with month parameters" do
    # Visit specific month
    get calendar_month_path(2025, 10)

    assert_response :success
    assert_select "h1", "Vantura Calendar"
  end

  test "search uses ILIKE for case-insensitive query" do
    # Create transactions with mixed-case fields
    @account.transactions.create!(
      description: "Coffee at Local Shop",
      amount: -5.50,
      transaction_date: Date.today.beginning_of_month + 1.day,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Food & Drink",
      merchant: "Local Cafe"
    )

    # Lowercase query should match mixed-case description/merchant via ILIKE
    get search_transactions_path, params: { q: "coffee", month: Date.today.month, year: Date.today.year }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    # Ensure at least one matching transaction rendered (soft assertion on content)
    assert_select "body", /Coffee at Local Shop|
Local Cafe/
  end
end
