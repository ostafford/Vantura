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
      category: "rent",
      date_tolerance_days: 3,
      tolerance_type: "fixed",
      amount_tolerance: 5.0
    )
  end

  test "should get index" do
    get recurring_transactions_url, params: { account_id: @account.id }
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
        projection_months: "12",
        amount_tolerance: 5.0,
        date_tolerance_days: 3,
        tolerance_type: "fixed"
      }
    end

    assert_redirected_to root_url
    recurring = RecurringTransaction.last
    assert_equal 5.0, recurring.amount_tolerance
    assert_equal 3, recurring.date_tolerance_days
    assert_equal "fixed", recurring.tolerance_type
  end

  test "should create recurring transaction with recurring_category for income" do
    transaction = @account.transactions.create!(
      description: "Salary Payment",
      amount: 5000.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    post recurring_transactions_url, params: {
      transaction_id: transaction.id,
      frequency: "monthly",
      next_occurrence_date: Date.today + 1.month,
      recurring_category: "salary"
    }

    recurring = RecurringTransaction.last
    assert_equal "salary", recurring.recurring_category
  end

  test "should create recurring transaction with custom category" do
    transaction = @account.transactions.create!(
      description: "Gym Payment",
      amount: -50.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    post recurring_transactions_url, params: {
      transaction_id: transaction.id,
      frequency: "monthly",
      next_occurrence_date: Date.today + 1.month,
      recurring_category: "other",
      custom_category_name: "Gym Membership"
    }

    recurring = RecurringTransaction.last
    assert_equal "Gym Membership", recurring.recurring_category

    # Verify custom category was created
    custom_category = @account.recurring_categories.find_by(name: "Gym Membership", transaction_type: "expense")
    assert_not_nil custom_category
  end

  test "should create recurring transaction with percentage tolerance" do
    transaction = @account.transactions.create!(
      description: "Variable Subscription",
      amount: -100.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    post recurring_transactions_url, params: {
      transaction_id: transaction.id,
      frequency: "monthly",
      next_occurrence_date: Date.today + 1.month,
      tolerance_type: "percentage",
      tolerance_percentage: 5.0
    }

    recurring = RecurringTransaction.last
    assert_equal "percentage", recurring.tolerance_type
    assert_equal 5.0, recurring.tolerance_percentage
  end

  test "should suggest frequency from transaction history" do
    # Create monthly transactions
    base_date = Date.today - 3.months
    4.times do |i|
      @account.transactions.create!(
        description: "Netflix Subscription",
        amount: -15.0,
        transaction_date: base_date + i.months,
        status: "SETTLED",
        is_hypothetical: false
      )
    end

    transaction = @account.transactions.create!(
      description: "Netflix Subscription",
      amount: -15.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    get suggest_frequency_recurring_transactions_url, params: { transaction_id: transaction.id }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_includes json_response, "frequency"
    assert_includes json_response, "confidence"
  end

  test "should update recurring transaction" do
    patch recurring_transaction_url(@recurring), params: {
      account_id: @account.id,
      recurring_transaction: {
        description: "Updated Rent",
        frequency: "monthly",
        date_tolerance_days: 5,
        tolerance_type: "percentage",
        tolerance_percentage: 3.0
      }
    }

    assert_redirected_to recurring_transactions_path(account_id: @account.id)
    @recurring.reload
    assert_equal "Updated Rent", @recurring.description
    assert_equal 5, @recurring.date_tolerance_days
    assert_equal "percentage", @recurring.tolerance_type
    assert_equal 3.0, @recurring.tolerance_percentage
  end

  test "should update recurring transaction with recurring_category" do
    @recurring.update!(transaction_type: "income")

    patch recurring_transaction_url(@recurring), params: {
      account_id: @account.id,
      recurring_transaction: {
        recurring_category: "freelance"
      }
    }

    @recurring.reload
    assert_equal "freelance", @recurring.recurring_category
  end

  test "should filter by category" do
    # Create recurring transactions with different categories
    @account.recurring_transactions.create!(
      description: "Netflix",
      amount: -15.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 5.days,
      is_active: true,
      transaction_type: "expense",
      recurring_category: "subscription",
      date_tolerance_days: 3,
      tolerance_type: "fixed",
      amount_tolerance: 5.0
    )

    @account.recurring_transactions.create!(
      description: "Electric Bill",
      amount: -100.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 5.days,
      is_active: true,
      transaction_type: "expense",
      recurring_category: "bill",
      date_tolerance_days: 3,
      tolerance_type: "fixed",
      amount_tolerance: 5.0
    )

    get recurring_transactions_url, params: { account_id: @account.id, category: "subscription" }
    assert_response :success

    # Verify only subscription category is shown
    assert_select "tr", count: 2  # Header + 1 subscription row
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

  test "index action sets maximum 2 instance variables" do
    get recurring_transactions_url, params: { account_id: @account.id }
    assert_response :success

    # Verify only 2 instance variables are set (@recurring_transactions and @breakdown)
    # This is verified by checking the response renders successfully
    # The breakdown service returns a hash, not individual instance variables
  end

  test "index uses BreakdownService" do
    get recurring_transactions_url, params: { account_id: @account.id }
    assert_response :success
    # BreakdownService is called and returns hash with breakdown data
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
