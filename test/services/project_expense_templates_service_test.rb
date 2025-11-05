require "test_helper"

class ProjectExpenseTemplatesServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @project = Project.create!(owner: @user, name: "Test Project")
  end

  test "returns array of templates" do
    @project.project_expenses.create!(
      merchant: "Grocery Store",
      category: "groceries",
      total_cents: 10000,
      due_on: Date.today
    )

    templates = ProjectExpenseTemplatesService.call(@project)

    assert_instance_of Array, templates
    assert_equal 1, templates.length
  end

  test "returns expected template structure" do
    @project.project_expenses.create!(
      merchant: "Store",
      category: "shopping",
      notes: "Test notes",
      total_cents: 5000,
      due_on: Date.today
    )

    templates = ProjectExpenseTemplatesService.call(@project)
    template = templates.first

    assert_includes template, :merchant
    assert_includes template, :category
    assert_includes template, :notes
    assert_includes template, :last_amount
    assert_not_includes template, :last_created_at
  end

  test "groups templates by merchant and category" do
    @project.project_expenses.create!(
      merchant: "Store",
      category: "groceries",
      total_cents: 10000,
      due_on: Date.today
    )
    @project.project_expenses.create!(
      merchant: "Store",
      category: "groceries",
      total_cents: 15000,
      due_on: Date.today
    )

    templates = ProjectExpenseTemplatesService.call(@project)

    assert_equal 1, templates.length
    assert_equal 15000, templates.first[:last_amount] # Uses most recent
  end

  test "creates separate templates for different merchants" do
    @project.project_expenses.create!(
      merchant: "Store A",
      category: "groceries",
      total_cents: 10000,
      due_on: Date.today
    )
    @project.project_expenses.create!(
      merchant: "Store B",
      category: "groceries",
      total_cents: 20000,
      due_on: Date.today
    )

    templates = ProjectExpenseTemplatesService.call(@project)

    assert_equal 2, templates.length
  end

  test "filters by search term" do
    @project.project_expenses.create!(
      merchant: "Grocery Store",
      category: "groceries",
      total_cents: 10000,
      due_on: Date.today
    )
    @project.project_expenses.create!(
      merchant: "Gas Station",
      category: "transport",
      total_cents: 5000,
      due_on: Date.today
    )

    templates = ProjectExpenseTemplatesService.call(@project, search_term: "grocery")

    assert_equal 1, templates.length
    assert_equal "Grocery Store", templates.first[:merchant]
  end

  test "search is case insensitive" do
    @project.project_expenses.create!(
      merchant: "Grocery Store",
      category: "groceries",
      total_cents: 10000,
      due_on: Date.today
    )

    templates = ProjectExpenseTemplatesService.call(@project, search_term: "GROCERY")

    assert_equal 1, templates.length
  end

  test "searches by category" do
    @project.project_expenses.create!(
      merchant: "Store",
      category: "groceries",
      total_cents: 10000,
      due_on: Date.today
    )

    templates = ProjectExpenseTemplatesService.call(@project, search_term: "groceries")

    assert_equal 1, templates.length
  end

  test "limits results to 20" do
    25.times do |i|
      @project.project_expenses.create!(
        merchant: "Store #{i}",
        category: "category",
        total_cents: 1000,
        due_on: Date.today
      )
    end

    templates = ProjectExpenseTemplatesService.call(@project)

    assert templates.length <= 20
  end

  test "orders by most recent first" do
    old_expense = @project.project_expenses.create!(
      merchant: "Old Store",
      category: "shopping",
      total_cents: 1000,
      due_on: Date.today
    )
    new_expense = @project.project_expenses.create!(
      merchant: "New Store",
      category: "shopping",
      total_cents: 2000,
      due_on: Date.today
    )

    templates = ProjectExpenseTemplatesService.call(@project)

    assert_equal "New Store", templates.first[:merchant]
  end

  test "handles nil category" do
    @project.project_expenses.create!(
      merchant: "Store",
      category: nil,
      total_cents: 10000,
      due_on: Date.today
    )

    templates = ProjectExpenseTemplatesService.call(@project)

    assert_equal 1, templates.length
    assert_nil templates.first[:category]
  end
end
