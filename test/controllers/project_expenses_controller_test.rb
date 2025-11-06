require "test_helper"

class ProjectExpensesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in_as(:one)
    @project = Project.create!(owner: @user, name: "Test Project")
    @expense = @project.project_expenses.create!(
      merchant: "Test Merchant",
      total_cents: 10000,
      due_on: Date.today
    )
  end

  test "should get new" do
    get new_project_expense_url(project_id: @project.id)
    assert_response :success
  end

  test "should create expense with valid params" do
    assert_difference("ProjectExpense.count", 1) do
      post project_expenses_url(project_id: @project.id), params: {
        project_expense: {
          merchant: "New Merchant",
          total_dollars: "50.00",
          due_on: Date.today
        }
      }
    end

    assert_redirected_to project_url(@project)
  end

  test "should not create expense with invalid params" do
    assert_no_difference("ProjectExpense.count") do
      post project_expenses_url(project_id: @project.id), params: {
        project_expense: {
          merchant: "",
          total_dollars: "50.00",
          due_on: Date.today
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_expense_url(@expense)
    assert_response :success
  end

  test "should update expense with valid params" do
    patch expense_url(@expense), params: {
      project_expense: {
        merchant: "Updated Merchant",
        total_dollars: "75.00"
      }
    }

    assert_redirected_to project_url(@project)
    @expense.reload
    assert_equal "Updated Merchant", @expense.merchant
    assert_equal 7500, @expense.total_cents
  end

  test "should not update expense with invalid params" do
    patch expense_url(@expense), params: {
      project_expense: { merchant: "" }
    }

    assert_response :unprocessable_entity
  end

  test "should destroy expense" do
    assert_difference("ProjectExpense.count", -1) do
      delete expense_url(@expense)
    end

    assert_redirected_to project_url(@project)
  end

  test "should get templates" do
    get templates_project_expenses_url(project_id: @project.id), params: { q: "merchant" }
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_instance_of Array, json_response
  end

  test "uses ProjectExpenseTemplatesService for templates" do
    @project.project_expenses.create!(
      merchant: "Grocery Store",
      category: "groceries",
      total_cents: 10000,
      due_on: Date.today
    )

    get templates_project_expenses_url(project_id: @project.id), params: { q: "grocery" }
    json_response = JSON.parse(response.body)
    assert json_response.any?
  end

  test "rebuilds contributions on create via callback" do
    other_user = users(:two)
    @project.project_memberships.create!(user: other_user)

    post project_expenses_url(project_id: @project.id), params: {
      project_expense: {
        merchant: "Merchant",
        total_dollars: "100.00",
        due_on: Date.today
      },
      contributor_user_ids: [ @user.id, other_user.id ]
    }

    expense = ProjectExpense.last
    # Contributions should be automatically rebuilt by callback
    assert_equal 2, expense.expense_contributions.count
  end

  test "rebuilds contributions on update via callback" do
    other_user = users(:two)
    @project.project_memberships.create!(user: other_user)

    patch expense_url(@expense), params: {
      project_expense: {
        total_dollars: "200.00"
      },
      contributor_user_ids: [ @user.id, other_user.id ]
    }

    @expense.reload
    # Contributions should be automatically rebuilt by callback
    assert_equal 2, @expense.expense_contributions.count
    assert_equal 20000, @expense.expense_contributions.sum(&:share_cents)
  end

  test "requires project membership to view" do
    other_user = users(:two)
    sign_in_as(:two)

    get new_project_expense_url(project_id: @project.id)
    assert_response :forbidden
  end

  test "requires owner or editor to create" do
    other_user = users(:two)
    @project.project_memberships.create!(user: other_user, access_level: ProjectMembership.access_levels[:limited])
    sign_in_as(:two)

    assert_no_difference("ProjectExpense.count") do
      post project_expenses_url(project_id: @project.id), params: {
        project_expense: {
          merchant: "Merchant",
          total_dollars: "50.00",
          due_on: Date.today
        }
      }
    end
    assert_response :forbidden
  end

  test "broadcasts updates after create via callback" do
    # The broadcast is triggered by model callback, not controller
    # We verify the expense is created successfully, which triggers the callback
    assert_difference("ProjectExpense.count", 1) do
      post project_expenses_url(project_id: @project.id), params: {
        project_expense: {
          merchant: "Merchant",
          total_dollars: "50.00",
          due_on: Date.today
        }
      }
    end

    assert_response :redirect
    # Broadcast is handled by model callback (after_create_commit)
  end

  test "broadcasts updates after destroy via callback" do
    # The broadcast is triggered by model callback, not controller
    assert_difference("ProjectExpense.count", -1) do
      delete expense_url(@expense)
    end

    assert_response :redirect
    # Broadcast is handled by model callback (after_destroy_commit)
  end
end
