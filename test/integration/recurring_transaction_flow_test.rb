require "test_helper"

class RecurringTransactionFlowTest < ActionDispatch::IntegrationTest
  def setup
    sign_in_as :one
    @account = accounts(:one)
    @transaction = transactions(:expense_one)
  end

  test "view recurring transactions index" do
    get recurring_transactions_path

    assert_response :success
    assert_select "h1", "Manage Recurring Transactions"
  end

  test "create recurring transaction from existing transaction" do
    post recurring_transactions_path, params: {
      transaction_id: @transaction.id,
      frequency: "monthly",
      next_occurrence_date: Date.today + 1.month,
      amount_tolerance: 5.0,
      projection_months: "3"
    }

    assert_redirected_to root_path
    follow_redirect!

    # Verify recurring transaction was created
    recurring = RecurringTransaction.last
    assert_equal @transaction.description, recurring.description
    assert_equal @transaction.amount, recurring.amount
    assert_equal "monthly", recurring.frequency
    assert recurring.is_active
  end

  test "toggle recurring transaction active status" do
    recurring = @account.recurring_transactions.create!(
      description: "Monthly Bill",
      amount: -100.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 1.month,
      transaction_type: "expense",
      is_active: true
    )

    # Toggle to inactive (Turbo Stream request)
    post toggle_active_recurring_transaction_path(recurring),
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    # Turbo Stream returns 200 OK
    assert_response :success

    # Verify status changed
    assert_not recurring.reload.is_active
  end

  test "delete recurring transaction" do
    recurring = @account.recurring_transactions.create!(
      description: "Test Pattern",
      amount: -50.0,
      frequency: "weekly",
      next_occurrence_date: Date.today + 1.week,
      transaction_type: "expense",
      is_active: true
    )

    # Delete
    delete recurring_transaction_path(recurring)

    assert_redirected_to root_path

    # Verify deleted
    assert_not RecurringTransaction.exists?(recurring.id)
  end
end
