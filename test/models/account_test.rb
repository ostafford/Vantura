require "test_helper"

class AccountTest < ActiveSupport::TestCase
  def setup
    @account = accounts(:one)
    @user = users(:one)
  end

  # Association tests
  test "should belong to user" do
    assert_respond_to @account, :user
    assert_instance_of User, @account.user
  end

  test "should have many transactions" do
    assert_respond_to @account, :transactions
  end

  test "should have many recurring_transactions" do
    assert_respond_to @account, :recurring_transactions
  end

  test "should destroy dependent transactions when account is destroyed" do
    account = @user.accounts.create!(
      up_account_id: "test_acc_789",
      display_name: "Test Account",
      account_type: "TRANSACTIONAL",
      current_balance: 100.0
    )
    transaction = account.transactions.create!(
      description: "Test Transaction",
      amount: -50.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    assert_difference "Transaction.count", -1 do
      account.destroy
    end
  end

  test "should destroy dependent recurring_transactions when account is destroyed" do
    account = @user.accounts.create!(
      up_account_id: "test_acc_789",
      display_name: "Test Account",
      account_type: "TRANSACTIONAL",
      current_balance: 100.0
    )
    recurring = account.recurring_transactions.create!(
      description: "Monthly Rent",
      amount: -1500.0,
      frequency: "monthly",
      next_occurrence_date: Date.today,
      transaction_type: "expense",
      is_active: true
    )

    assert_difference "RecurringTransaction.count", -1 do
      account.destroy
    end
  end

  # Validation tests
  test "should be valid with valid attributes" do
    account = Account.new(
      up_account_id: "new_account_123",
      display_name: "New Account",
      account_type: "TRANSACTIONAL",
      current_balance: 500.0,
      user: @user
    )
    assert account.valid?
  end

  test "should require up_account_id" do
    @account.up_account_id = nil
    assert_not @account.valid?
    assert_includes @account.errors[:up_account_id], "can't be blank"
  end

  test "should require unique up_account_id" do
    duplicate_account = Account.new(
      up_account_id: @account.up_account_id,
      display_name: "Duplicate",
      account_type: "TRANSACTIONAL",
      current_balance: 100.0,
      user: @user
    )
    assert_not duplicate_account.valid?
    assert_includes duplicate_account.errors[:up_account_id], "has already been taken"
  end

  test "should require display_name" do
    @account.display_name = nil
    assert_not @account.valid?
    assert_includes @account.errors[:display_name], "can't be blank"
  end

  test "should require account_type" do
    @account.account_type = nil
    assert_not @account.valid?
    assert_includes @account.errors[:account_type], "can't be blank"
  end

  test "should require current_balance" do
    @account.current_balance = nil
    assert_not @account.valid?
    assert_includes @account.errors[:current_balance], "can't be blank"
  end

  test "should require numeric current_balance" do
    @account.current_balance = "not a number"
    assert_not @account.valid?
    assert_includes @account.errors[:current_balance], "is not a number"
  end

  test "should allow negative current_balance within permitted range" do
    account = Account.new(
      up_account_id: "loan_account_123",
      display_name: "Loan Account",
      account_type: "HOME_LOAN",
      current_balance: -50_000.25,
      user: @user
    )

    assert account.valid?
  end

  test "should not allow current_balance beyond permitted range" do
    account = Account.new(
      up_account_id: "overflow_account_123",
      display_name: "Overflow Account",
      account_type: "TRANSACTIONAL",
      current_balance: Account::MAX_BALANCE + BigDecimal("1.00"),
      user: @user
    )

    assert_not account.valid?
    assert account.errors[:current_balance].any? { |error| error.include?("must be less than or equal to") }
  end

  test "target_savings_rate clamps to maximum of 30 percent" do
    @account.update!(target_savings_rate: 0.5)
    assert_in_delta 0.3, @account.target_savings_rate.to_f, 0.0001
  end

  test "target_savings_amount normalizes negative and blank values" do
    @account.update!(target_savings_amount: -150)
    assert_equal 0.0, @account.target_savings_amount.to_f

    @account.update!(target_savings_amount: "")
    assert_nil @account.target_savings_amount
  end

  test "goal timestamp updates when savings goal changes" do
    assert_nil @account.goal_last_set_at

    @account.update!(target_savings_rate: 0.12)
    assert_not_nil @account.goal_last_set_at

    original_timestamp = @account.goal_last_set_at

    @account.update!(target_savings_amount: 0)
    assert_not_nil @account.goal_last_set_at
    assert @account.goal_last_set_at >= original_timestamp
  end

  test "user can be optional for backward compatibility" do
    account = Account.new(
      up_account_id: "legacy_account_123",
      display_name: "Legacy Account",
      account_type: "TRANSACTIONAL",
      current_balance: 100.0,
      user: nil
    )
    assert account.valid?
  end

  # Enum tests
  test "should define account_type enum" do
    assert_respond_to Account, :account_types
  end

  test "should have transactional account_type" do
    @account.account_type = "TRANSACTIONAL"
    assert @account.account_type_transactional?
  end

  test "should have saver account_type" do
    @account.account_type = "SAVER"
    assert @account.account_type_saver?
  end

  test "should have home_loan account_type" do
    @account.account_type = "HOME_LOAN"
    assert @account.account_type_home_loan?
  end

  # Custom method tests - end_of_month_balance
  test "end_of_month_balance should return current balance for current month with no transactions" do
    account = @user.accounts.create!(
      up_account_id: "test_balance_acc",
      display_name: "Test Balance Account",
      account_type: "TRANSACTIONAL",
      current_balance: 1000.0
    )

    balance = account.end_of_month_balance(Date.today)
    assert_equal 1000.0, balance
  end

  test "end_of_month_balance should include future transactions for current month" do
    account = @user.accounts.create!(
      up_account_id: "test_balance_acc",
      display_name: "Test Balance Account",
      account_type: "TRANSACTIONAL",
      current_balance: 1000.0
    )

    # Add a future transaction (after today, before end of month)
    future_date = [ Date.today + 5.days, Date.today.end_of_month ].min # Ensure it's within the month
    account.transactions.create!(
      description: "Future Income",
      amount: 500.0,
      transaction_date: future_date,
      status: "HYPOTHETICAL",
      is_hypothetical: true
    )

    balance = account.end_of_month_balance(Date.today)
    # Balance should be current_balance + sum of future transactions (1000 + 500 = 1500)
    assert_equal 1500.0, balance
  end

  test "end_of_month_balance should calculate past month balances correctly" do
    account = @user.accounts.create!(
      up_account_id: "test_balance_acc",
      display_name: "Test Balance Account",
      account_type: "TRANSACTIONAL",
      current_balance: 1000.0
    )

    # Use fixed dates to avoid flakiness: target month is October 15, transaction is on Nov 1
    # This ensures the transaction is always "after" the target month and <= today
    # We use a date that's in the past relative to when the test runs, but after the target month
    target_month = Date.new(2025, 9, 15) # September 15 (past month)
    # Transaction must be after Sep 30 but <= today. Use today's date or a date in current month
    # that's definitely after September
    today = Date.today
    transaction_date = [ today, target_month.end_of_month + 1.day ].min # First day after month or today, whichever is earlier

    # Add transaction after the past month we're checking
    account.transactions.create!(
      description: "Recent Income",
      amount: 200.0,
      transaction_date: transaction_date,
      status: "SETTLED",
      is_hypothetical: false
    )

    balance = account.end_of_month_balance(target_month)
    # Should be current balance (1000) minus transactions after last month (200)
    assert_equal 800.0, balance
  end

  test "end_of_month_balance should handle negative transactions" do
    account = @user.accounts.create!(
      up_account_id: "test_balance_acc",
      display_name: "Test Balance Account",
      account_type: "TRANSACTIONAL",
      current_balance: 1000.0
    )

    # Add future expense
    future_date = Date.today + 3.days
    account.transactions.create!(
      description: "Future Expense",
      amount: -250.0,
      transaction_date: future_date,
      status: "HYPOTHETICAL",
      is_hypothetical: true
    )

    balance = account.end_of_month_balance(Date.today)
    assert_equal 750.0, balance
  end

  test "end_of_month_balance accepts string date input" do
    account = @user.accounts.create!(
      up_account_id: "string_date_account",
      display_name: "String Date Account",
      account_type: "TRANSACTIONAL",
      current_balance: 320.0
    )

    balance = account.end_of_month_balance(Date.today.to_s)
    assert_equal 320.0, balance
  end

  test "end_of_month_balance raises helpful error for invalid input" do
    account = @user.accounts.create!(
      up_account_id: "invalid_date_account",
      display_name: "Invalid Date Account",
      account_type: "TRANSACTIONAL",
      current_balance: 120.0
    )

    error = assert_raises(ArgumentError) do
      account.end_of_month_balance(:not_a_date)
    end

    assert_match "Date-compatible", error.message
  end
end
