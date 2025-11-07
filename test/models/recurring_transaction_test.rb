require "test_helper"

class RecurringTransactionTest < ActiveSupport::TestCase
  def setup
    @account = accounts(:one)
    @recurring = recurring_transactions(:monthly_rent)
  end

  # Association tests
  test "should belong to account" do
    assert_respond_to @recurring, :account
    assert_instance_of Account, @recurring.account
  end

  test "should optionally belong to template_transaction" do
    assert_respond_to @recurring, :template_transaction
    assert_nil @recurring.template_transaction
  end

  test "should have many generated_transactions" do
    assert_respond_to @recurring, :generated_transactions
  end

  test "should destroy dependent generated_transactions when destroyed" do
    recurring = @account.recurring_transactions.create!(
      description: "Test Recurring",
      amount: -100.0,
      frequency: "monthly",
      next_occurrence_date: Date.today,
      transaction_type: "expense",
      is_active: true
    )

    transaction = @account.transactions.create!(
      description: "Generated Transaction",
      amount: -100.0,
      transaction_date: Date.today,
      status: "HYPOTHETICAL",
      is_hypothetical: true,
      recurring_transaction: recurring
    )

    assert_difference "Transaction.count", -1 do
      recurring.destroy
    end
  end

  # Validation tests
  test "should be valid with valid attributes" do
    recurring = RecurringTransaction.new(
      account: @account,
      description: "Test Recurring",
      amount: -50.0,
      frequency: "monthly",
      next_occurrence_date: Date.today,
      transaction_type: "expense",
      is_active: true
    )
    assert recurring.valid?
  end

  test "should require description" do
    @recurring.description = nil
    assert_not @recurring.valid?
    assert_includes @recurring.errors[:description], "can't be blank"
  end

  test "should require amount" do
    @recurring.amount = nil
    assert_not @recurring.valid?
    assert_includes @recurring.errors[:amount], "can't be blank"
  end

  test "should require numeric amount" do
    @recurring.amount = "not a number"
    assert_not @recurring.valid?
    assert_includes @recurring.errors[:amount], "is not a number"
  end

  test "should require frequency" do
    @recurring.frequency = nil
    assert_not @recurring.valid?
    assert_includes @recurring.errors[:frequency], "can't be blank"
  end

  test "should require next_occurrence_date" do
    @recurring.next_occurrence_date = nil
    assert_not @recurring.valid?
    assert_includes @recurring.errors[:next_occurrence_date], "can't be blank"
  end

  test "should require transaction_type" do
    @recurring.transaction_type = nil
    assert_not @recurring.valid?
    assert_includes @recurring.errors[:transaction_type], "can't be blank"
  end

  test "should require is_active to be boolean" do
    @recurring.is_active = nil
    assert_not @recurring.valid?
    assert_includes @recurring.errors[:is_active], "is not included in the list"
  end

  # Enum tests - frequency
  test "should define frequency enum" do
    assert_respond_to RecurringTransaction, :frequencies
  end

  test "should have weekly frequency" do
    @recurring.frequency = "weekly"
    assert @recurring.frequency_weekly?
  end

  test "should have fortnightly frequency" do
    @recurring.frequency = "fortnightly"
    assert @recurring.frequency_fortnightly?
  end

  test "should have monthly frequency" do
    @recurring.frequency = "monthly"
    assert @recurring.frequency_monthly?
  end

  test "should have quarterly frequency" do
    @recurring.frequency = "quarterly"
    assert @recurring.frequency_quarterly?
  end

  test "should have yearly frequency" do
    @recurring.frequency = "yearly"
    assert @recurring.frequency_yearly?
  end

  # Enum tests - transaction_type
  test "should define transaction_type enum" do
    assert_respond_to RecurringTransaction, :transaction_types
  end

  test "should have income transaction_type" do
    @recurring.transaction_type = "income"
    assert @recurring.transaction_type_income?
  end

  test "should have expense transaction_type" do
    @recurring.transaction_type = "expense"
    assert @recurring.transaction_type_expense?
  end

  # Scope tests
  test "active scope should return only active recurring transactions" do
    active_transactions = RecurringTransaction.active
    assert active_transactions.all?(&:is_active)
  end

  test "inactive scope should return only inactive recurring transactions" do
    inactive_transactions = RecurringTransaction.inactive
    assert inactive_transactions.all? { |t| !t.is_active }
  end

  test "income_transactions scope should return only income type" do
    income_transactions = RecurringTransaction.income_transactions
    assert income_transactions.all?(&:transaction_type_income?)
  end

  test "expense_transactions scope should return only expense type" do
    expense_transactions = RecurringTransaction.expense_transactions
    assert expense_transactions.all?(&:transaction_type_expense?)
  end

  test "due_soon scope should return transactions due within specified days" do
    # Create one due soon and one not due soon
    due_soon = @account.recurring_transactions.create!(
      description: "Due Soon",
      amount: -50.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 3.days,
      transaction_type: "expense",
      is_active: true
    )

    not_due = @account.recurring_transactions.create!(
      description: "Not Due",
      amount: -50.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 30.days,
      transaction_type: "expense",
      is_active: true
    )

    results = RecurringTransaction.due_soon(7)
    assert_includes results, due_soon
    assert_not_includes results, not_due
  end

  # Custom method tests - calculate_next_occurrence
  test "calculate_next_occurrence should add 1 week for weekly frequency" do
    @recurring.frequency = "weekly"
    @recurring.next_occurrence_date = Date.today

    next_date = @recurring.calculate_next_occurrence
    assert_equal Date.today + 1.week, next_date
  end

  test "calculate_next_occurrence should add 2 weeks for fortnightly frequency" do
    @recurring.frequency = "fortnightly"
    @recurring.next_occurrence_date = Date.today

    next_date = @recurring.calculate_next_occurrence
    assert_equal Date.today + 2.weeks, next_date
  end

  test "calculate_next_occurrence should add 1 month for monthly frequency" do
    @recurring.frequency = "monthly"
    @recurring.next_occurrence_date = Date.today

    next_date = @recurring.calculate_next_occurrence
    assert_equal Date.today + 1.month, next_date
  end

  test "calculate_next_occurrence should add 3 months for quarterly frequency" do
    @recurring.frequency = "quarterly"
    @recurring.next_occurrence_date = Date.today

    next_date = @recurring.calculate_next_occurrence
    assert_equal Date.today + 3.months, next_date
  end

  test "calculate_next_occurrence should add 1 year for yearly frequency" do
    @recurring.frequency = "yearly"
    @recurring.next_occurrence_date = Date.today

    next_date = @recurring.calculate_next_occurrence
    assert_equal Date.today + 1.year, next_date
  end

  test "calculate_next_occurrence should accept custom from_date" do
    @recurring.frequency = "monthly"
    custom_date = Date.new(2025, 1, 15)

    next_date = @recurring.calculate_next_occurrence(custom_date)
    assert_equal Date.new(2025, 2, 15), next_date
  end

  # Custom method tests - matches_transaction?
  test "matches_transaction? should return false when merchant_pattern is blank" do
    @recurring.merchant_pattern = nil
    transaction = @account.transactions.build(
      description: "Random Transaction",
      amount: -1500.0
    )

    assert_not @recurring.matches_transaction?(transaction)
  end

  test "matches_transaction? should match by description (case insensitive)" do
    @recurring.merchant_pattern = "landlord"
    @recurring.amount = -1500.0
    @recurring.amount_tolerance = 10.0

    transaction = @account.transactions.build(
      description: "Payment to LANDLORD for rent",
      amount: -1505.0
    )

    assert @recurring.matches_transaction?(transaction)
  end

  test "matches_transaction? should not match if description doesn't contain pattern" do
    @recurring.merchant_pattern = "landlord"
    @recurring.amount = -1500.0

    transaction = @account.transactions.build(
      description: "Different merchant",
      amount: -1500.0
    )

    assert_not @recurring.matches_transaction?(transaction)
  end

  test "matches_transaction? should match within amount tolerance" do
    @recurring.merchant_pattern = "grocery"
    @recurring.amount = -100.0
    @recurring.amount_tolerance = 5.0

    # Within tolerance
    transaction1 = @account.transactions.build(
      description: "Grocery Store",
      amount: -103.0
    )
    assert @recurring.matches_transaction?(transaction1)

    # Outside tolerance
    transaction2 = @account.transactions.build(
      description: "Grocery Store",
      amount: -110.0
    )
    assert_not @recurring.matches_transaction?(transaction2)
  end

  test "matches_transaction? should use default tolerance of 1.0 when not set" do
    @recurring.merchant_pattern = "coffee"
    @recurring.amount = -5.0
    @recurring.amount_tolerance = nil

    transaction = @account.transactions.build(
      description: "Coffee Shop",
      amount: -5.50
    )

    assert @recurring.matches_transaction?(transaction)
  end

  test "matches_transaction? should handle absolute value comparison" do
    @recurring.merchant_pattern = "salary"
    @recurring.amount = 2500.0  # positive
    @recurring.amount_tolerance = 10.0

    transaction = @account.transactions.build(
      description: "Monthly SALARY payment",
      amount: 2505.0
    )

    assert @recurring.matches_transaction?(transaction)
  end

  # Class method tests - extract_merchant_pattern
  test "extract_merchant_pattern should remove long numbers" do
    pattern = RecurringTransaction.extract_merchant_pattern("Woolworths 123456 Store")
    assert_equal "Woolworths Store", pattern
  end

  test "extract_merchant_pattern should remove trailing numbers" do
    pattern = RecurringTransaction.extract_merchant_pattern("Coffee Shop 42")
    assert_equal "Coffee Shop", pattern
  end

  test "extract_merchant_pattern should take first 2 words" do
    pattern = RecurringTransaction.extract_merchant_pattern("My Long Merchant Name Here")
    assert_equal "My Long", pattern
  end

  test "extract_merchant_pattern should handle single word" do
    pattern = RecurringTransaction.extract_merchant_pattern("Woolworths")
    assert_equal "Woolworths", pattern
  end

  test "extract_merchant_pattern should strip whitespace" do
    pattern = RecurringTransaction.extract_merchant_pattern("  Grocery Store  ")
    assert_equal "Grocery Store", pattern
  end

  test "extract_merchant_pattern should handle blank description" do
    pattern = RecurringTransaction.extract_merchant_pattern("")
    assert_equal "", pattern
  end

  test "extract_merchant_pattern should handle nil description" do
    pattern = RecurringTransaction.extract_merchant_pattern(nil)
    assert_equal "", pattern
  end

  test "extract_merchant_pattern should handle complex description" do
    pattern = RecurringTransaction.extract_merchant_pattern("Amazon Purchase 9876543210 Invoice#123")
    assert_equal "Amazon Purchase", pattern
  end

  test "extract_merchant_pattern should handle description with only numbers" do
    pattern = RecurringTransaction.extract_merchant_pattern("12345")
    assert_equal "", pattern
  end

  # Fuzzy matching tests
  test "fuzzy_match? should match with 1 character difference" do
    @recurring.merchant_pattern = "Netflix"
    @recurring.amount = -15.0
    @recurring.amount_tolerance = 1.0

    transaction = @account.transactions.build(
      description: "Netflx subscription",
      amount: -15.0
    )

    assert @recurring.fuzzy_match?(transaction.description)
  end

  test "fuzzy_match? should match with 2 character differences" do
    @recurring.merchant_pattern = "Amazon"
    @recurring.amount = -50.0

    transaction = @account.transactions.build(
      description: "Amazn purchase",
      amount: -50.0
    )

    assert @recurring.fuzzy_match?(transaction.description)
  end

  test "fuzzy_match? should not match with too many differences" do
    @recurring.merchant_pattern = "Netflix"
    @recurring.amount = -15.0

    transaction = @account.transactions.build(
      description: "Hulu subscription",
      amount: -15.0
    )

    assert_not @recurring.fuzzy_match?(transaction.description)
  end

  test "matches_transaction? should use fuzzy matching as fallback" do
    @recurring.merchant_pattern = "Netflix"
    @recurring.amount = -15.0
    @recurring.amount_tolerance = 1.0

    transaction = @account.transactions.build(
      description: "Netflx subscription payment",
      amount: -15.0
    )

    assert @recurring.matches_transaction?(transaction)
  end

  # Percentage tolerance tests
  test "amount_within_tolerance? should use percentage tolerance when tolerance_type is percentage" do
    @recurring.amount = 100.0
    @recurring.tolerance_type = "percentage"
    @recurring.tolerance_percentage = 5.0

    # 5% of $100 = $5 tolerance, so $95-$105 should match
    assert @recurring.amount_within_tolerance?(105.0)
    assert @recurring.amount_within_tolerance?(95.0)
    assert_not @recurring.amount_within_tolerance?(106.0)
    assert_not @recurring.amount_within_tolerance?(94.0)
  end

  test "amount_within_tolerance? should use fixed tolerance when tolerance_type is fixed" do
    @recurring.amount = 100.0
    @recurring.tolerance_type = "fixed"
    @recurring.amount_tolerance = 5.0

    assert @recurring.amount_within_tolerance?(105.0)
    assert @recurring.amount_within_tolerance?(95.0)
    assert_not @recurring.amount_within_tolerance?(106.0)
  end

  test "matches_transaction? should work with percentage tolerance" do
    @recurring.merchant_pattern = "subscription"
    @recurring.amount = 100.0
    @recurring.tolerance_type = "percentage"
    @recurring.tolerance_percentage = 5.0

    transaction = @account.transactions.build(
      description: "Monthly subscription",
      amount: 103.0
    )

    assert @recurring.matches_transaction?(transaction)
  end

  # Category matching tests
  test "matches_transaction? should accept optional category parameter" do
    @recurring.merchant_pattern = "grocery"
    @recurring.amount = -50.0
    @recurring.amount_tolerance = 5.0
    @recurring.category = "groceries"

    transaction = @account.transactions.build(
      description: "Grocery Store",
      amount: -50.0
    )

    # Should match even without category (merchant pattern is primary)
    assert @recurring.matches_transaction?(transaction)
    # Should also match with matching category
    assert @recurring.matches_transaction?(transaction, category: "groceries")
  end

  test "matches_transaction? should not require category match" do
    @recurring.merchant_pattern = "grocery"
    @recurring.amount = -50.0
    @recurring.amount_tolerance = 5.0
    @recurring.category = "groceries"

    transaction = @account.transactions.build(
      description: "Grocery Store",
      amount: -50.0
    )

    # Should match even with different category (merchant pattern is primary)
    assert @recurring.matches_transaction?(transaction, category: "food")
  end

  # Date tolerance tests
  test "should validate date_tolerance_days is between 1 and 14" do
    @recurring.date_tolerance_days = 0
    assert_not @recurring.valid?
    assert_includes @recurring.errors[:date_tolerance_days], "must be greater than 0"

    @recurring.date_tolerance_days = 15
    assert_not @recurring.valid?
    assert_includes @recurring.errors[:date_tolerance_days], "must be less than or equal to 14"

    @recurring.date_tolerance_days = 7
    assert @recurring.valid?
  end

  # Recurring category validation tests
  test "should allow predefined recurring_category for income transactions" do
    @recurring.transaction_type = "income"
    @recurring.recurring_category = "salary"
    assert @recurring.valid?
  end

  test "should allow predefined recurring_category for expense transactions" do
    @recurring.transaction_type = "expense"
    @recurring.recurring_category = "subscription"
    assert @recurring.valid?
  end

  test "should allow custom recurring_category that exists for account" do
    custom_category = RecurringCategory.create!(
      account: @account,
      name: "Gym Membership",
      transaction_type: "expense"
    )
    
    @recurring.transaction_type = "expense"
    @recurring.recurring_category = "Gym Membership"
    assert @recurring.valid?
  end

  test "should not allow recurring_category that doesn't match transaction_type" do
    @recurring.transaction_type = "expense"
    @recurring.recurring_category = "salary"  # salary is for income
    assert_not @recurring.valid?
    assert_includes @recurring.errors[:recurring_category], "must be a valid category for expense transactions"
  end

  test "should not allow recurring_category that doesn't exist" do
    @recurring.transaction_type = "expense"
    @recurring.recurring_category = "Non-existent Category"
    assert_not @recurring.valid?
    assert_includes @recurring.errors[:recurring_category], "must be a valid category for expense transactions"
  end

  test "recurring_category_name should return humanized predefined category" do
    @recurring.recurring_category = "salary"
    assert_equal "Salary", @recurring.recurring_category_name
  end

  test "recurring_category_name should return custom category name" do
    custom_category = RecurringCategory.create!(
      account: @account,
      name: "Gym Membership",
      transaction_type: "expense"
    )
    
    @recurring.transaction_type = "expense"
    @recurring.recurring_category = "Gym Membership"
    assert_equal "Gym Membership", @recurring.recurring_category_name
  end

  test "available_categories should include predefined and custom categories" do
    custom_category = RecurringCategory.create!(
      account: @account,
      name: "Custom Category",
      transaction_type: "expense"
    )
    
    @recurring.transaction_type = "expense"
    categories = @recurring.available_categories
    
    assert_includes categories, "subscription"  # predefined
    assert_includes categories, "Custom Category"  # custom
  end

  # Tolerance type validation tests
  test "should validate tolerance_type is fixed or percentage" do
    @recurring.tolerance_type = "invalid"
    assert_not @recurring.valid?
    assert_includes @recurring.errors[:tolerance_type], "is not included in the list"

    @recurring.tolerance_type = "fixed"
    assert @recurring.valid?

    @recurring.tolerance_type = "percentage"
    @recurring.tolerance_percentage = 5.0
    assert @recurring.valid?
  end
end
