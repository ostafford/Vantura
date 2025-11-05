require "test_helper"

class ProjectShowDataServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @project = Project.create!(owner: @user, name: "Test Project")
    @date = Date.new(2025, 11, 15)
  end

  test "returns expected structure" do
    data = ProjectShowDataService.call(@project, {})

    assert_instance_of Hash, data
    assert_includes data, :date
    assert_includes data, :expenses
    assert_includes data, :expenses_in_month
    assert_includes data, :all_expenses
    assert_includes data, :total_expenses_cents
    assert_includes data, :expense_count
    assert_includes data, :total_participants
    assert_includes data, :largest_expense
    assert_includes data, :unpaid_contributions_count
    assert_includes data, :project_stats
  end

  test "uses today as default date" do
    data = ProjectShowDataService.call(@project, {})
    assert_equal Date.today, data[:date]
  end

  test "parses date from params" do
    data = ProjectShowDataService.call(@project, { year: 2025, month: 10 })
    assert_equal Date.new(2025, 10, 1), data[:date]
  end

  test "handles invalid date params" do
    data = ProjectShowDataService.call(@project, { year: 2025, month: 13 })
    assert_equal Date.today, data[:date]
  end

  test "filters expenses by month" do
    # Expense in current month
    expense1 = @project.project_expenses.create!(
      merchant: "Merchant 1",
      total_cents: 10000,
      due_on: @date
    )

    # Expense in different month
    @project.project_expenses.create!(
      merchant: "Merchant 2",
      total_cents: 5000,
      due_on: @date.prev_month
    )

    data = ProjectShowDataService.call(@project, { year: 2025, month: 11 })

    assert_equal 1, data[:expense_count]
    assert_equal 10000, data[:total_expenses_cents]
    assert_includes data[:expenses].map(&:id), expense1.id
  end

  test "orders expenses by due_on" do
    expense1 = @project.project_expenses.create!(
      merchant: "Later",
      total_cents: 1000,
      due_on: @date + 5.days
    )
    expense2 = @project.project_expenses.create!(
      merchant: "Earlier",
      total_cents: 2000,
      due_on: @date
    )

    data = ProjectShowDataService.call(@project, { year: 2025, month: 11 })
    expense_ids = data[:expenses].map(&:id)

    assert_equal expense2.id, expense_ids.first
    assert_equal expense1.id, expense_ids.last
  end

  test "includes all expenses in all_expenses" do
    @project.project_expenses.create!(
      merchant: "Current Month",
      total_cents: 1000,
      due_on: @date
    )
    @project.project_expenses.create!(
      merchant: "Last Month",
      total_cents: 2000,
      due_on: @date.prev_month
    )

    data = ProjectShowDataService.call(@project, { year: 2025, month: 11 })
    assert_equal 2, data[:all_expenses].count
  end

  test "calculates total participants" do
    @project.project_memberships.create!(user: users(:two))

    data = ProjectShowDataService.call(@project, {})
    # Owner + 1 member = 2 participants
    assert_equal 2, data[:total_participants]
  end

  test "finds largest expense in month" do
    small = @project.project_expenses.create!(
      merchant: "Small",
      total_cents: 1000,
      due_on: @date
    )
    large = @project.project_expenses.create!(
      merchant: "Large",
      total_cents: 5000,
      due_on: @date
    )

    data = ProjectShowDataService.call(@project, { year: 2025, month: 11 })
    assert_equal large.id, data[:largest_expense].id
  end

  test "calculates unpaid contributions count" do
    expense = @project.project_expenses.create!(
      merchant: "Merchant",
      total_cents: 10000,
      due_on: @date
    )
    expense.rebuild_contributions!

    # Mark one as unpaid (should be counted)
    contribution = expense.expense_contributions.first
    contribution.update!(paid: false)

    data = ProjectShowDataService.call(@project, { year: 2025, month: 11 })
    assert data[:unpaid_contributions_count] > 0
  end

  test "includes project stats from ProjectStatsCalculator" do
    data = ProjectShowDataService.call(@project, { year: 2025, month: 11 })

    assert_instance_of Hash, data[:project_stats]
    assert_includes data[:project_stats], :current_month_total_cents
    assert_includes data[:project_stats], :mom_change_cents
  end
end
