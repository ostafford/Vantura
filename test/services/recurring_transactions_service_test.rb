require "test_helper"

class RecurringTransactionsServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    # Create a fresh account to avoid fixture interference
    @account = @user.accounts.create!(
      up_account_id: "test_recurring_service_account",
      display_name: "Test Recurring Service Account",
      account_type: "TRANSACTIONAL",
      current_balance: 1000.0
    )
    @end_date = Date.today + 30.days
  end

  test "returns expected structure" do
    data = RecurringTransactionsService.upcoming(@account, @end_date)

    assert_instance_of Hash, data
    assert_includes data, :expenses
    assert_includes data, :income
    assert_includes data, :expense_total
    assert_includes data, :income_total
  end

  test "returns only active recurring transactions" do
    recurring = @account.recurring_transactions.create!(
      description: "Monthly Expense",
      amount: -100.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 5.days,
      is_active: true,
      transaction_type: "expense"
    )

    data = RecurringTransactionsService.upcoming(@account, @end_date)

    assert_includes data[:expenses].map(&:id), recurring.id
  end

  test "excludes inactive recurring transactions" do
    recurring = @account.recurring_transactions.create!(
      description: "Inactive",
      amount: -100.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 5.days,
      is_active: false,
      transaction_type: "expense"
    )

    data = RecurringTransactionsService.upcoming(@account, @end_date)

    assert_not_includes data[:expenses].map(&:id), recurring.id
  end

  test "filters by next_occurrence_date" do
    upcoming = @account.recurring_transactions.create!(
      description: "Upcoming",
      amount: -100.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 10.days,
      is_active: true,
      transaction_type: "expense"
    )
    far_future = @account.recurring_transactions.create!(
      description: "Far Future",
      amount: -100.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 60.days,
      is_active: true,
      transaction_type: "expense"
    )

    data = RecurringTransactionsService.upcoming(@account, @end_date)

    assert_includes data[:expenses].map(&:id), upcoming.id
    assert_not_includes data[:expenses].map(&:id), far_future.id
  end

  test "separates expenses and income" do
    expense = @account.recurring_transactions.create!(
      description: "Expense",
      amount: -100.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 5.days,
      is_active: true,
      transaction_type: "expense"
    )
    income = @account.recurring_transactions.create!(
      description: "Income",
      amount: 1000.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 5.days,
      is_active: true,
      transaction_type: "income"
    )

    data = RecurringTransactionsService.upcoming(@account, @end_date)

    assert_includes data[:expenses].map(&:id), expense.id
    assert_includes data[:income].map(&:id), income.id
  end

  test "calculates expense total" do
    @account.recurring_transactions.create!(
      description: "Expense 1",
      amount: -100.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 5.days,
      is_active: true,
      transaction_type: "expense"
    )
    @account.recurring_transactions.create!(
      description: "Expense 2",
      amount: -200.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 5.days,
      is_active: true,
      transaction_type: "expense"
    )

    data = RecurringTransactionsService.upcoming(@account, @end_date)

    assert_equal 300.0, data[:expense_total]
  end

  test "calculates income total" do
    @account.recurring_transactions.create!(
      description: "Income 1",
      amount: 1000.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 5.days,
      is_active: true,
      transaction_type: "income"
    )

    data = RecurringTransactionsService.upcoming(@account, @end_date)

    assert_equal 1000.0, data[:income_total]
  end

  test "orders by next_occurrence_date" do
    later = @account.recurring_transactions.create!(
      description: "Later",
      amount: -100.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 15.days,
      is_active: true,
      transaction_type: "expense"
    )
    earlier = @account.recurring_transactions.create!(
      description: "Earlier",
      amount: -200.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 5.days,
      is_active: true,
      transaction_type: "expense"
    )

    data = RecurringTransactionsService.upcoming(@account, @end_date)

    assert_equal earlier.id, data[:expenses].first.id
    assert_equal later.id, data[:expenses].last.id
  end

  test "handles empty results" do
    data = RecurringTransactionsService.upcoming(@account, @end_date)

    assert_equal [], data[:expenses]
    assert_equal [], data[:income]
    assert_equal 0, data[:expense_total]
    assert_equal 0, data[:income_total]
  end
end
