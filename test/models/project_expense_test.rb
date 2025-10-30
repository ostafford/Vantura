require "test_helper"

class ProjectExpenseTest < ActiveSupport::TestCase
  setup do
    @owner = users(:one)
    @member = users(:two)

    @project = Project.create!(name: "House Bills", owner: @owner)
    ProjectMembership.create!(project: @project, user: @member)
  end

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
end


