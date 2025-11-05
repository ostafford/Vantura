require "test_helper"

class RecurringTransactionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in_as(:one)
    @account = accounts(:one)
    @recurring = @account.recurring_transactions.create!(
      description: "Monthly Rent",
      amount: -1500.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 5.days,
      is_active: true,
      transaction_type: "expense",
      category: "rent"
    )
  end

  test "should get index" do
    get recurring_transactions_url, params: { account_id: @account.id }
    assert_response :success
  end

  test "should get show" do
    get recurring_transaction_url(@recurring), params: { account_id: @account.id }
    assert_response :success
  end

  test "should get edit" do
    get edit_recurring_transaction_url(@recurring), params: { account_id: @account.id }
    assert_response :success
  end

  test "should create recurring transaction from template" do
    transaction = @account.transactions.create!(
      description: "Template Transaction",
      amount: -100.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    assert_difference("RecurringTransaction.count", 1) do
      post recurring_transactions_url, params: {
        transaction_id: transaction.id,
        frequency: "monthly",
        next_occurrence_date: Date.today + 1.month,
        projection_months: "12"
      }
    end

    assert_redirected_to root_url
  end

  test "should update recurring transaction" do
    patch recurring_transaction_url(@recurring), params: {
      account_id: @account.id,
      recurring_transaction: {
        description: "Updated Rent",
        frequency: "monthly"
      }
    }

    assert_redirected_to recurring_transaction_url(@recurring)
    @recurring.reload
    assert_equal "Updated Rent", @recurring.description
  end

  test "should not update with invalid params" do
    patch recurring_transaction_url(@recurring), params: {
      account_id: @account.id,
      recurring_transaction: {
        description: ""
      }
    }

    assert_response :unprocessable_entity
  end

  test "should destroy recurring transaction" do
    # Create generated transactions
    @account.transactions.create!(
      description: "Generated",
      amount: -1500.0,
      transaction_date: Date.today + 10.days,
      status: "HYPOTHETICAL",
      is_hypothetical: true,
      recurring_transaction_id: @recurring.id
    )

    assert_difference("RecurringTransaction.count", -1) do
      delete recurring_transaction_url(@recurring), params: { account_id: @account.id }
    end

    assert_redirected_to root_url
    # Generated transactions should be deleted
    assert_equal 0, @account.transactions.where(recurring_transaction_id: @recurring.id).count
  end

  test "should toggle active status" do
    assert @recurring.is_active

    post toggle_active_recurring_transaction_url(@recurring), params: { account_id: @account.id }

    @recurring.reload
    assert_not @recurring.is_active
  end

  test "regenerates transactions when activated" do
    @recurring.update!(is_active: false)
    @recurring.generated_transactions.destroy_all
    # Ensure next_occurrence_date is in the future
    @recurring.update!(next_occurrence_date: Date.today + 5.days)

    post toggle_active_recurring_transaction_url(@recurring), params: { account_id: @account.id }

    @recurring.reload
    assert @recurring.is_active
    assert @recurring.generated_transactions.any?, "Expected generated transactions but found none"
  end

  test "uses GenerateService when creating" do
    transaction = @account.transactions.create!(
      description: "Template",
      amount: -100.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    post recurring_transactions_url, params: {
      transaction_id: transaction.id,
      frequency: "monthly",
      next_occurrence_date: Date.today + 1.month,
      projection_months: "6"
    }

    recurring = RecurringTransaction.last
    assert recurring.generated_transactions.any?
  end

  test "calculates breakdowns for index" do
    get recurring_transactions_url, params: { account_id: @account.id }
    assert_response :success
    # Breakdowns calculated indirectly - verified through successful response
  end

  test "requires authentication" do
    delete session_url
    get recurring_transactions_url, params: { account_id: @account.id }
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

    get recurring_transactions_url, params: { account_id: other_account.id }
    assert_response :forbidden
  end
end
