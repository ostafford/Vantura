require "test_helper"

class RecurringCategoryTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
  end

  test "should be valid with valid attributes" do
    category = RecurringCategory.new(
      account: @account,
      name: "Gym Membership",
      transaction_type: "expense"
    )
    assert category.valid?
  end

  test "should require name" do
    category = RecurringCategory.new(
      account: @account,
      transaction_type: "expense"
    )
    assert_not category.valid?
    assert_includes category.errors[:name], "can't be blank"
  end

  test "should require transaction_type" do
    category = RecurringCategory.new(
      account: @account,
      name: "Gym Membership"
    )
    assert_not category.valid?
    assert_includes category.errors[:transaction_type], "can't be blank"
  end

  test "should require transaction_type to be income or expense" do
    category = RecurringCategory.new(
      account: @account,
      name: "Gym Membership",
      transaction_type: "invalid"
    )
    assert_not category.valid?
    assert_includes category.errors[:transaction_type], "is not included in the list"
  end

  test "should enforce uniqueness scoped to account and transaction_type" do
    RecurringCategory.create!(
      account: @account,
      name: "Gym Membership",
      transaction_type: "expense"
    )

    duplicate = RecurringCategory.new(
      account: @account,
      name: "Gym Membership",
      transaction_type: "expense"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should allow same name for different transaction types" do
    RecurringCategory.create!(
      account: @account,
      name: "Other",
      transaction_type: "income"
    )

    different_type = RecurringCategory.new(
      account: @account,
      name: "Other",
      transaction_type: "expense"
    )
    assert different_type.valid?
  end

  test "should allow same name for different accounts" do
    other_account = accounts(:two)
    
    RecurringCategory.create!(
      account: @account,
      name: "Gym Membership",
      transaction_type: "expense"
    )

    different_account = RecurringCategory.new(
      account: other_account,
      name: "Gym Membership",
      transaction_type: "expense"
    )
    assert different_account.valid?
  end

  test "predefined? should return true for predefined income categories" do
    category = RecurringCategory.new(
      account: @account,
      name: "salary",
      transaction_type: "income"
    )
    assert category.predefined?
  end

  test "predefined? should return true for predefined expense categories" do
    category = RecurringCategory.new(
      account: @account,
      name: "subscription",
      transaction_type: "expense"
    )
    assert category.predefined?
  end

  test "predefined? should return false for custom categories" do
    category = RecurringCategory.new(
      account: @account,
      name: "Gym Membership",
      transaction_type: "expense"
    )
    assert_not category.predefined?
  end

  test "predefined_for_type should return income categories for income" do
    categories = RecurringCategory.predefined_for_type("income")
    assert_equal RecurringCategory::PREDEFINED_INCOME, categories
  end

  test "predefined_for_type should return expense categories for expense" do
    categories = RecurringCategory.predefined_for_type("expense")
    assert_equal RecurringCategory::PREDEFINED_EXPENSE, categories
  end

  test "for_account scope should filter by account" do
    other_account = accounts(:two)
    
    category1 = RecurringCategory.create!(
      account: @account,
      name: "Category 1",
      transaction_type: "expense"
    )
    
    category2 = RecurringCategory.create!(
      account: other_account,
      name: "Category 2",
      transaction_type: "expense"
    )

    result = RecurringCategory.for_account(@account)
    assert_includes result, category1
    assert_not_includes result, category2
  end

  test "for_transaction_type scope should filter by transaction type" do
    income_category = RecurringCategory.create!(
      account: @account,
      name: "Salary",
      transaction_type: "income"
    )
    
    expense_category = RecurringCategory.create!(
      account: @account,
      name: "Subscription",
      transaction_type: "expense"
    )

    income_result = RecurringCategory.for_transaction_type("income")
    assert_includes income_result, income_category
    assert_not_includes income_result, expense_category

    expense_result = RecurringCategory.for_transaction_type("expense")
    assert_includes expense_result, expense_category
    assert_not_includes expense_result, income_category
  end
end

