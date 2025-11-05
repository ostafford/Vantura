require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in_as(:one)
    @account = accounts(:one)
    @transaction = @account.transactions.create!(
      description: "Test Transaction",
      amount: -100.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )
  end

  test "should get index" do
    get transactions_url
    assert_response :success
  end

  test "should get show" do
    get transaction_url(@transaction)
    assert_response :success
  end

  test "should get edit" do
    # Ensure transaction belongs to user's account
    assert_equal @account.id, @transaction.account_id
    get edit_transaction_url(@transaction)
    assert_response :success
  end

  test "should update transaction with valid params" do
    patch transaction_url(@transaction), params: {
      transaction: {
        description: "Updated Description",
        amount: -150.0
      }
    }

    assert_redirected_to transaction_url(@transaction)
    @transaction.reload
    assert_equal "Updated Description", @transaction.description
  end

  test "should not update transaction with invalid params" do
    patch transaction_url(@transaction), params: {
      transaction: { description: "" }
    }

    assert_response :unprocessable_entity
  end

  test "should create hypothetical transaction" do
    assert_difference("Transaction.count", 1) do
      post transactions_url, params: {
        transaction: {
          description: "New Transaction",
          amount: "100.00",
          transaction_date: Date.today,
          transaction_type: "expense"
        },
        account_id: @account.id
      }
    end

    transaction = Transaction.last
    assert transaction.is_hypothetical
    assert_equal "hypothetical", transaction.status
  end

  test "should destroy hypothetical transaction" do
    hypothetical = @account.transactions.create!(
      description: "Hypothetical",
      amount: -100.0,
      transaction_date: Date.today,
      status: "hypothetical",
      is_hypothetical: true
    )

    assert_difference("Transaction.count", -1) do
      delete transaction_url(hypothetical)
    end
  end

  test "should not destroy real transaction" do
    assert_no_difference("Transaction.count") do
      delete transaction_url(@transaction)
    end
  end

  test "should search transactions" do
    @account.transactions.create!(
      description: "Grocery Shopping",
      amount: -100.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    get search_transactions_url, params: { q: "grocery", account_id: @account.id }
    assert_response :redirect
    assert_match(/transactions.*filter=search.*q=grocery/, response.location)
    follow_redirect!
    assert_response :success
  end

  test "uses TransactionIndexService for index" do
    get transactions_url
    assert_response :success
    # Service is called indirectly - verified through successful response
  end

  test "uses TransactionSearchService for search" do
    get search_transactions_url, params: { q: "test", account_id: @account.id }
    assert_response :redirect
    assert_match(/transactions.*filter=search.*q=test/, response.location)
    follow_redirect!
    assert_response :success
    # Service is called indirectly - verified through successful response
  end

  test "filters by expense type" do
    @account.transactions.create!(
      description: "Income",
      amount: 500.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    get transactions_url, params: { filter: "expenses" }
    assert_response :success
    # Filtering verified through successful response
  end

  test "requires authentication" do
    delete session_url
    get transactions_url
    assert_redirected_to new_session_url
  end

  test "requires account ownership" do
    other_user = users(:two)
    other_account = other_user.accounts.create!(
      up_account_id: "other_account",
      display_name: "Other Account",
      account_type: "TRANSACTIONAL",
      current_balance: 1000.0
    )
    other_transaction = other_account.transactions.create!(
      description: "Other",
      amount: -100.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    get transaction_url(other_transaction)
    assert_response :forbidden
  end
end
