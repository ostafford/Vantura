require "test_helper"

class ProjectExpenseTest < ActiveSupport::TestCase
  setup do
    @owner = users(:one)
    @member = users(:two)

    @project = Project.create!(name: "House Bills", owner: @owner)
    ProjectMembership.create!(project: @project, user: @member)
  end

  # Association tests
  test "should belong to project" do
    expense = @project.project_expenses.create!(
      merchant: "Test Merchant",
      total_cents: 10000,
      due_on: Date.today
    )
    assert_respond_to expense, :project
    assert_instance_of Project, expense.project
  end

  test "should have many expense_contributions" do
    expense = @project.project_expenses.create!(
      merchant: "Test Merchant",
      total_cents: 10000,
      due_on: Date.today
    )
    assert_respond_to expense, :expense_contributions
    expense.expense_contributions.create!(
      user: @owner,
      share_cents: 5000,
      paid: false
    )
    assert_equal 1, expense.expense_contributions.count
  end

  test "should destroy dependent expense_contributions" do
    expense = @project.project_expenses.create!(
      merchant: "Test Merchant",
      total_cents: 10000,
      due_on: Date.today
    )
    expense.expense_contributions.create!(
      user: @owner,
      share_cents: 5000,
      paid: false
    )
    assert_difference("ExpenseContribution.count", -1) do
      expense.destroy
    end
  end

  # Validation tests
  test "should require merchant" do
    expense = ProjectExpense.new(
      project: @project,
      total_cents: 10000,
      due_on: Date.today
    )
    assert_not expense.valid?
    assert_includes expense.errors[:merchant], "can't be blank"
  end

  test "should require total_cents" do
    expense = ProjectExpense.new(
      project: @project,
      merchant: "Test Merchant",
      due_on: Date.today,
      total_cents: nil
    )
    assert_not expense.valid?
    assert_includes expense.errors[:total_cents], "can't be blank"
  end

  test "should require total_cents to be integer" do
    expense = ProjectExpense.new(
      project: @project,
      merchant: "Test Merchant",
      total_cents: 1000.5,
      due_on: Date.today
    )
    assert_not expense.valid?
    assert_includes expense.errors[:total_cents], "must be an integer"
  end

  test "should require total_cents to be greater than or equal to zero" do
    expense = ProjectExpense.new(
      project: @project,
      merchant: "Test Merchant",
      total_cents: -1,
      due_on: Date.today
    )
    assert_not expense.valid?
    assert_includes expense.errors[:total_cents], "must be greater than or equal to 0"
  end

  # Instance method tests
  test "rebuild_contributions! splits equally and assigns remainder to owner" do
    expense = @project.project_expenses.create!(merchant: "PowerCo", category: "Utilities", total_cents: 101, due_on: Date.today)

    expense.rebuild_contributions!

    contributions = expense.expense_contributions.includes(:user).order(:user_id)
    assert_equal 2, contributions.size
    assert_equal 101, contributions.sum(&:share_cents)

    owner_contrib = contributions.find { |c| c.user_id == @owner.id }
    member_contrib = contributions.find { |c| c.user_id == @member.id }

    assert_equal 51, owner_contrib.share_cents
    assert_equal 50, member_contrib.share_cents
  end

  test "rebuild_contributions! handles empty participants" do
    project = Project.create!(name: "Solo Project", owner: @owner)
    expense = project.project_expenses.create!(
      merchant: "Test Merchant",
      total_cents: 10000,
      due_on: Date.today
    )

    # Should not raise error even with only owner
    assert_nothing_raised do
      expense.rebuild_contributions!
    end
  end

  test "rebuild_contributions_for_participants! splits across selected participants" do
    expense = @project.project_expenses.create!(
      merchant: "Test Merchant",
      total_cents: 100,
      due_on: Date.today
    )

    expense.rebuild_contributions_for_participants!([ @owner.id, @member.id ])

    contributions = expense.expense_contributions
    assert_equal 2, contributions.size
    assert_equal 100, contributions.sum(&:share_cents)
  end

  test "rebuild_contributions_for_participants! handles single participant" do
    expense = @project.project_expenses.create!(
      merchant: "Test Merchant",
      total_cents: 100,
      due_on: Date.today
    )

    expense.rebuild_contributions_for_participants!([ @owner.id ])

    contributions = expense.expense_contributions
    assert_equal 1, contributions.size
    assert_equal 100, contributions.first.share_cents
  end

  test "rebuild_contributions_for_participants! ignores invalid participant IDs" do
    expense = @project.project_expenses.create!(
      merchant: "Test Merchant",
      total_cents: 100,
      due_on: Date.today
    )

    expense.rebuild_contributions_for_participants!([ @owner.id, 99999 ])

    contributions = expense.expense_contributions
    assert_equal 1, contributions.size
    assert_equal @owner.id, contributions.first.user_id
  end

  test "rebuild_contributions_for_participants! returns early with blank participant_ids" do
    expense = @project.project_expenses.create!(
      merchant: "Test Merchant",
      total_cents: 100,
      due_on: Date.today
    )

    expense.rebuild_contributions_for_participants!([])

    assert_equal 0, expense.expense_contributions.count
  end

  # Callback tests
  test "after_save callback automatically rebuilds contributions on create" do
    expense = @project.project_expenses.create!(
      merchant: "Test Merchant",
      total_cents: 100,
      due_on: Date.today
    )

    # Contributions should be automatically created by callback
    assert_equal 2, expense.expense_contributions.count
    assert_equal 100, expense.expense_contributions.sum(&:share_cents)
  end

  test "after_save callback automatically rebuilds contributions on update" do
    expense = @project.project_expenses.create!(
      merchant: "Test Merchant",
      total_cents: 100,
      due_on: Date.today
    )

    # Update total_cents
    expense.update!(total_cents: 200)

    # Contributions should be automatically rebuilt
    assert_equal 2, expense.expense_contributions.count
    assert_equal 200, expense.expense_contributions.sum(&:share_cents)
  end

  test "after_save callback uses contributor_user_ids when provided" do
    expense = @project.project_expenses.new(
      merchant: "Test Merchant",
      total_cents: 100,
      due_on: Date.today
    )
    expense.contributor_user_ids = [ @owner.id ]

    expense.save!

    # Should only create contribution for owner
    assert_equal 1, expense.expense_contributions.count
    assert_equal @owner.id, expense.expense_contributions.first.user_id
    assert_equal 100, expense.expense_contributions.first.share_cents
  end

  test "after_save callback defaults to all participants when contributor_user_ids not set" do
    expense = @project.project_expenses.create!(
      merchant: "Test Merchant",
      total_cents: 100,
      due_on: Date.today
    )

    # Should create contributions for all participants (owner + member)
    assert_equal 2, expense.expense_contributions.count
    participant_ids = expense.expense_contributions.pluck(:user_id)
    assert_includes participant_ids, @owner.id
    assert_includes participant_ids, @member.id
  end

  test "includes Turbo::Broadcastable" do
    expense = @project.project_expenses.new(
      merchant: "Test Merchant",
      total_cents: 100,
      due_on: Date.today
    )
    assert_includes expense.class.included_modules, Turbo::Broadcastable
  end
end
