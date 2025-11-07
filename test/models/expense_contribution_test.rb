require "test_helper"

class ExpenseContributionTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @project = Project.create!(owner: @user, name: "Test Project")
    @expense = @project.project_expenses.create!(
      merchant: "Test Merchant",
      total_cents: 10000,
      due_on: Date.today
    )
    @contribution = @expense.expense_contributions.first || @expense.expense_contributions.create!(
      user: @user,
      share_cents: 5000,
      paid: false
    )
  end

  # Association tests
  test "should belong to project_expense" do
    assert_respond_to @contribution, :project_expense
    assert_instance_of ProjectExpense, @contribution.project_expense
  end

  test "should belong to user" do
    assert_respond_to @contribution, :user
    assert_instance_of User, @contribution.user
  end

  # Validation tests
  test "should be valid with valid attributes" do
    contribution = ExpenseContribution.new(
      project_expense: @expense,
      user: users(:two),
      share_cents: 5000,
      paid: false
    )
    assert contribution.valid?
  end

  test "should require share_cents" do
    @contribution.share_cents = nil
    assert_not @contribution.valid?
    assert_includes @contribution.errors[:share_cents], "can't be blank"
  end

  test "should require share_cents to be integer" do
    @contribution.share_cents = 50.5
    assert_not @contribution.valid?
    assert_includes @contribution.errors[:share_cents], "must be an integer"
  end

  test "should require share_cents to be greater than or equal to zero" do
    @contribution.share_cents = -1
    assert_not @contribution.valid?
    assert_includes @contribution.errors[:share_cents], "must be greater than or equal to 0"
  end

  test "should allow zero share_cents" do
    @contribution.share_cents = 0
    assert @contribution.valid?
  end

  test "should allow positive share_cents" do
    @contribution.share_cents = 10000
    assert @contribution.valid?
  end
end
