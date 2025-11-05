require "test_helper"

class TransactionFilterServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @account = @user.accounts.create!(
      up_account_id: "test_filter_account",
      display_name: "Test Filter Account",
      account_type: "TRANSACTIONAL",
      current_balance: 1000.0
    )

    # Create test transactions
    @transaction1 = @account.transactions.create!(
      description: "Grocery Store",
      amount: -100.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Food",
      merchant: "Grocery Store"
    )
    @transaction2 = @account.transactions.create!(
      description: "Gas Station",
      amount: -50.0,
      transaction_date: Date.today,
      status: "HELD",
      is_hypothetical: false,
      category: "Transport",
      merchant: "Gas Station"
    )
    @transaction3 = @account.transactions.create!(
      description: "Salary",
      amount: 3000.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false,
      category: "Income",
      merchant: "Employer"
    )
  end

  test "should return all transactions when filter has no criteria" do
    filter = @user.filters.create!(
      name: "Empty Filter",
      filter_types: [ "category" ], # Filter requires at least one filter_type
      filter_params: { "categories" => [] } # But no actual categories selected
    )

    result = TransactionFilterService.call(@account, filter)

    assert result.any?
    assert_includes result, @transaction1
    assert_includes result, @transaction2
    assert_includes result, @transaction3
  end

  test "should filter by category" do
    filter = @user.filters.create!(
      name: "Food Filter",
      filter_types: [ "category" ],
      filter_params: { "categories" => [ "Food" ] }
    )

    result = TransactionFilterService.call(@account, filter)

    assert_includes result, @transaction1
    assert_not_includes result, @transaction2
    assert_not_includes result, @transaction3
  end

  test "should filter by merchant" do
    filter = @user.filters.create!(
      name: "Grocery Filter",
      filter_types: [ "merchant" ],
      filter_params: { "merchants" => [ "Grocery Store" ] }
    )

    result = TransactionFilterService.call(@account, filter)

    assert_includes result, @transaction1
    assert_not_includes result, @transaction2
    assert_not_includes result, @transaction3
  end

  test "should filter by status" do
    filter = @user.filters.create!(
      name: "Settled Filter",
      filter_types: [ "status" ],
      filter_params: { "statuses" => [ "SETTLED" ] }
    )

    result = TransactionFilterService.call(@account, filter)

    assert_includes result, @transaction1
    assert_not_includes result, @transaction2
    assert_includes result, @transaction3
  end

  test "should filter by date range" do
    start_date = Date.today - 5.days
    end_date = Date.today + 5.days

    filter = @user.filters.create!(
      name: "Date Range Filter",
      filter_types: [ "category" ], # Filter requires at least one filter_type
      filter_params: { "categories" => [] }, # But no actual categories selected
      date_range: { "start_date" => start_date.to_s, "end_date" => end_date.to_s }
    )

    result = TransactionFilterService.call(@account, filter)

    assert_includes result, @transaction1
    assert_includes result, @transaction2
    assert_includes result, @transaction3
  end

  test "should filter by recurring transactions" do
    recurring = @account.recurring_transactions.create!(
      description: "Monthly Bill",
      amount: -100.0,
      frequency: "monthly",
      next_occurrence_date: Date.today,
      transaction_type: "expense",
      is_active: true
    )

    recurring_transaction = @account.transactions.create!(
      description: "Monthly Bill",
      amount: -100.0,
      transaction_date: Date.today,
      status: "HYPOTHETICAL",
      is_hypothetical: true,
      recurring_transaction: recurring
    )

    filter = @user.filters.create!(
      name: "Recurring Filter",
      filter_types: [ "recurring_transactions" ],
      filter_params: { "recurring_transactions" => "true" }
    )

    result = TransactionFilterService.call(@account, filter)

    assert_includes result, recurring_transaction
  end

  test "should apply multiple filter criteria" do
    filter = @user.filters.create!(
      name: "Multi Filter",
      filter_types: [ "category", "status" ],
      filter_params: {
        "categories" => [ "Food" ],
        "statuses" => [ "SETTLED" ]
      }
    )

    result = TransactionFilterService.call(@account, filter)

    assert_includes result, @transaction1
    assert_not_includes result, @transaction2
    assert_not_includes result, @transaction3
  end

  test "should return account transactions relation" do
    filter = @user.filters.create!(
      name: "Test Filter",
      filter_types: [ "category" ],
      filter_params: { "categories" => [] }
    )

    result = TransactionFilterService.call(@account, filter)

    # Result should be a queryable ActiveRecord relation
    assert result.respond_to?(:where)
    assert result.respond_to?(:select)
    assert result.respond_to?(:limit)
  end
end
