require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  def setup
    @account = accounts(:one)
    @transaction = transactions(:expense_one)
  end

  # Association tests
  test "should belong to account" do
    assert_respond_to @transaction, :account
    assert_instance_of Account, @transaction.account
  end

  test "should optionally belong to recurring_transaction" do
    assert_respond_to @transaction, :recurring_transaction
    assert_nil @transaction.recurring_transaction
  end

  # Validation tests
  test "should be valid with valid attributes" do
    transaction = Transaction.new(
      account: @account,
      description: "Test Transaction",
      amount: -50.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )
    assert transaction.valid?
  end

  test "should require description" do
    @transaction.description = nil
    assert_not @transaction.valid?
    assert_includes @transaction.errors[:description], "can't be blank"
  end

  test "should require amount" do
    @transaction.amount = nil
    assert_not @transaction.valid?
    assert_includes @transaction.errors[:amount], "can't be blank"
  end

  test "should require numeric amount" do
    @transaction.amount = "not a number"
    assert_not @transaction.valid?
    assert_includes @transaction.errors[:amount], "is not a number"
  end

  test "should require transaction_date" do
    @transaction.transaction_date = nil
    assert_not @transaction.valid?
    assert_includes @transaction.errors[:transaction_date], "can't be blank"
  end

  test "should require status" do
    @transaction.status = nil
    assert_not @transaction.valid?
    assert_includes @transaction.errors[:status], "can't be blank"
  end

  test "should require is_hypothetical to be boolean" do
    @transaction.is_hypothetical = nil
    assert_not @transaction.valid?
    assert_includes @transaction.errors[:is_hypothetical], "is not included in the list"
  end

  # Enum tests
  test "should define status enum" do
    assert_respond_to Transaction, :statuses
  end

  test "should have held status" do
    @transaction.status = "HELD"
    assert @transaction.status_held?
  end

  test "should have settled status" do
    @transaction.status = "SETTLED"
    assert @transaction.status_settled?
  end

  test "should have hypothetical status" do
    @transaction.status = "HYPOTHETICAL"
    assert @transaction.status_hypothetical?
  end

  # Scope tests
  test "real scope should return only real transactions" do
    real_transactions = Transaction.real
    assert real_transactions.all? { |t| !t.is_hypothetical }
  end

  test "hypothetical scope should return only hypothetical transactions" do
    hypothetical_transactions = Transaction.hypothetical
    assert hypothetical_transactions.all?(&:is_hypothetical)
  end

  test "expenses scope should return only negative amounts" do
    expenses = Transaction.expenses
    assert expenses.all? { |t| t.amount < 0 }
  end

  test "income scope should return only positive amounts" do
    income = Transaction.income
    assert income.all? { |t| t.amount > 0 }
  end

  test "for_date scope should return transactions for specific date" do
    date = Date.today
    transaction = @account.transactions.create!(
      description: "Today's Transaction",
      amount: -25.0,
      transaction_date: date,
      status: "SETTLED",
      is_hypothetical: false
    )

    results = Transaction.for_date(date)
    assert_includes results, transaction
  end

  test "for_month scope should return transactions for date range" do
    date = Date.today
    transaction = @account.transactions.create!(
      description: "This Month Transaction",
      amount: -100.0,
      transaction_date: date,
      status: "SETTLED",
      is_hypothetical: false
    )

    results = Transaction.for_month(date)
    assert_includes results, transaction
  end

  test "from_recurring scope should return transactions with recurring_transaction_id" do
    recurring = @account.recurring_transactions.create!(
      description: "Monthly Bill",
      amount: -50.0,
      frequency: "monthly",
      next_occurrence_date: Date.today,
      transaction_type: "expense",
      is_active: true
    )

    transaction = @account.transactions.create!(
      description: "Monthly Bill Instance",
      amount: -50.0,
      transaction_date: Date.today,
      status: "HYPOTHETICAL",
      is_hypothetical: true,
      recurring_transaction: recurring
    )

    results = Transaction.from_recurring
    assert_includes results, transaction
  end

  # Custom method tests
  test "recurring? should return true when recurring_transaction_id present" do
    recurring = @account.recurring_transactions.create!(
      description: "Monthly Bill",
      amount: -50.0,
      frequency: "monthly",
      next_occurrence_date: Date.today,
      transaction_type: "expense",
      is_active: true
    )

    transaction = @account.transactions.create!(
      description: "Monthly Bill Instance",
      amount: -50.0,
      transaction_date: Date.today,
      status: "HYPOTHETICAL",
      is_hypothetical: true,
      recurring_transaction: recurring
    )

    assert transaction.recurring?
  end

  test "recurring? should return false when recurring_transaction_id not present" do
    assert_not @transaction.recurring?
  end

  test "transaction_type should return expense for negative amount" do
    @transaction.amount = -100.0
    assert_equal "expense", @transaction.transaction_type
  end

  test "transaction_type should return income for positive amount" do
    @transaction.amount = 500.0
    assert_equal "income", @transaction.transaction_type
  end

  test "transaction_type should return expense for nil amount" do
    @transaction.amount = nil
    assert_equal "expense", @transaction.transaction_type
  end

  # Callback tests - simplified
  # Note: Testing callbacks directly would require ActionCable setup and mocking
  # Instead, we verify the callbacks don't raise errors in normal operation

  # Integration tests for broadcast (simplified)
  test "broadcast_dashboard_update should not fail when account has no user" do
    account = Account.create!(
      up_account_id: "orphan_account",
      display_name: "Orphan Account",
      account_type: "TRANSACTIONAL",
      current_balance: 100.0,
      user: nil
    )

    transaction = account.transactions.build(
      description: "Test",
      amount: -50.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    # Should not raise an error
    assert_nothing_raised do
      transaction.save!
    end
  end
end
