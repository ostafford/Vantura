require "test_helper"

class RecurringDeletionTest < ActionDispatch::IntegrationTest
  def setup
    sign_in_as :one
    @account = accounts(:one)
  end

  test "deletes a recurring transaction successfully" do
    recurring = @account.recurring_transactions.create!(
      description: "Test Pattern",
      amount: -50.0,
      frequency: "weekly",
      next_occurrence_date: Date.today + 1.week,
      transaction_type: "expense",
      is_active: true
    )

    delete recurring_transaction_path(recurring)

    assert_redirected_to root_path
    assert_not RecurringTransaction.exists?(recurring.id)
  end
end
