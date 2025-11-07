require "test_helper"

class RecurringCategoriesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in_as(:one)
    @account = accounts(:one)
  end

  test "should get index" do
    get recurring_categories_url, params: { account_id: @account.id }
    assert_response :success
  end

  test "should create custom category" do
    assert_difference("RecurringCategory.count", 1) do
      post recurring_categories_url, params: {
        account_id: @account.id,
        recurring_category: {
          name: "Gym Membership",
          transaction_type: "expense"
        }
      }
    end

    assert_redirected_to root_url
    category = RecurringCategory.last
    assert_equal "Gym Membership", category.name
    assert_equal "expense", category.transaction_type
    assert_equal @account.id, category.account_id
  end

  test "should not create duplicate category for same account and transaction type" do
    RecurringCategory.create!(
      account: @account,
      name: "Gym Membership",
      transaction_type: "expense"
    )

    assert_no_difference("RecurringCategory.count") do
      post recurring_categories_url, params: {
        account_id: @account.id,
        recurring_category: {
          name: "Gym Membership",
          transaction_type: "expense"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should allow same category name for different transaction types" do
    RecurringCategory.create!(
      account: @account,
      name: "Other",
      transaction_type: "income"
    )

    assert_difference("RecurringCategory.count", 1) do
      post recurring_categories_url, params: {
        account_id: @account.id,
        recurring_category: {
          name: "Other",
          transaction_type: "expense"
        }
      }
    end
  end

  test "should destroy category when not in use" do
    category = RecurringCategory.create!(
      account: @account,
      name: "Unused Category",
      transaction_type: "expense"
    )

    assert_difference("RecurringCategory.count", -1) do
      delete recurring_category_url(category), params: { account_id: @account.id }
    end

    assert_redirected_to root_url
  end

  test "should not destroy category when in use" do
    category = RecurringCategory.create!(
      account: @account,
      name: "Used Category",
      transaction_type: "expense"
    )

    @account.recurring_transactions.create!(
      description: "Test",
      amount: -50.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 5.days,
      is_active: true,
      transaction_type: "expense",
      recurring_category: "Used Category",
      date_tolerance_days: 3,
      tolerance_type: "fixed",
      amount_tolerance: 5.0
    )

    assert_no_difference("RecurringCategory.count") do
      delete recurring_category_url(category), params: { account_id: @account.id }
    end

    assert_response :unprocessable_entity
  end

  test "requires authentication" do
    delete session_url
    get recurring_categories_url, params: { account_id: @account.id }
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

    get recurring_categories_url, params: { account_id: other_account.id }
    assert_response :forbidden
  end
end

