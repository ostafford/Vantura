require "test_helper"

class ProjectsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @member = users(:two)
    # Sign in as owner to create the project
    post session_url, params: { email_address: @owner.email_address, password: "password" }
  end

  test "member can view project but cannot edit" do
    project = Project.create!(name: "Shared House", owner: @owner)
    ProjectMembership.create!(project: project, user: @member)

    # Owner can access
    get project_url(project)
    assert_response :success

    # Member can view
    delete session_url
    post session_url, params: { email_address: @member.email_address, password: "password" }
    get project_url(project)
    assert_response :success

    # Member cannot create expense
    get new_project_expense_url(project)
    assert_response :forbidden
  end

  test "member can toggle only their own contribution" do
    project = Project.create!(name: "Bills", owner: @owner)
    ProjectMembership.create!(project: project, user: @member)
    expense = project.project_expenses.create!(merchant: "Water", total_cents: 100)
    expense.rebuild_contributions!

    owner_contrib = expense.expense_contributions.find_by!(user_id: @owner.id)
    member_contrib = expense.expense_contributions.find_by!(user_id: @member.id)

    # As member: can update own
    delete session_url
    post session_url, params: { email_address: @member.email_address, password: "password" }
    patch project_expense_contribution_url(project, expense, member_contrib), params: { expense_contribution: { paid: true } }
    assert_response :redirect
    assert member_contrib.reload.paid

    # Cannot update owner's
    patch project_expense_contribution_url(project, expense, owner_contrib), params: { expense_contribution: { paid: true } }
    assert_response :forbidden
  end
end
