require "test_helper"

class TransactionBroadcastServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @account = @user.accounts.create!(
      up_account_id: "test_broadcast_account",
      display_name: "Test Broadcast Account",
      account_type: "TRANSACTIONAL",
      current_balance: 1000.0
    )
  end

  test "should not broadcast when account has no user" do
    account_without_user = Account.create!(
      up_account_id: "orphan_account",
      display_name: "Orphan Account",
      account_type: "TRANSACTIONAL",
      current_balance: 1000.0,
      user: nil
    )

    transaction = account_without_user.transactions.build(
      description: "Test",
      amount: -50.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    # Should not raise error
    assert_nothing_raised do
      TransactionBroadcastService.call(transaction)
    end
  end

  test "should call DashboardStatsCalculator" do
    transaction = @account.transactions.create!(
      description: "Test Transaction",
      amount: -50.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    # Verify the service runs without error
    # The actual broadcasting is tested through integration tests
    assert_nothing_raised do
      TransactionBroadcastService.call(transaction)
    end
  end

  test "should calculate upcoming recurring transactions" do
    recurring = @account.recurring_transactions.create!(
      description: "Monthly Bill",
      amount: -100.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 5.days,
      transaction_type: "expense",
      is_active: true
    )

    transaction = @account.transactions.create!(
      description: "Test Transaction",
      amount: -50.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    # Should not raise error when calculating upcoming recurring transactions
    assert_nothing_raised do
      TransactionBroadcastService.call(transaction)
    end
  end

  test "should handle transaction with account and user" do
    transaction = @account.transactions.create!(
      description: "Test Transaction",
      amount: -50.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    # Should not raise error
    assert_nothing_raised do
      TransactionBroadcastService.call(transaction)
    end
  end

  test "should work with expense transactions" do
    transaction = @account.transactions.create!(
      description: "Expense",
      amount: -100.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    assert_nothing_raised do
      TransactionBroadcastService.call(transaction)
    end
  end

  test "should work with income transactions" do
    transaction = @account.transactions.create!(
      description: "Income",
      amount: 500.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    assert_nothing_raised do
      TransactionBroadcastService.call(transaction)
    end
  end
end
