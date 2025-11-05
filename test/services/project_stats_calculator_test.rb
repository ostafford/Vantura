require "test_helper"

class ProjectStatsCalculatorTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @project = Project.create!(
      owner: @user,
      name: "Test Project"
    )
    @today = Date.new(2025, 11, 15)
  end

  test "returns expected structure" do
    stats = ProjectStatsCalculator.call(@project, @today)

    assert_instance_of Hash, stats
    assert_includes stats, :current_month_total_cents
    assert_includes stats, :last_month_total_cents
    assert_includes stats, :mom_change_cents
    assert_includes stats, :mom_change_pct
    assert_includes stats, :ytd_this_year_cents
    assert_includes stats, :ytd_last_year_cents
    assert_includes stats, :yoy_change_cents
    assert_includes stats, :yoy_change_pct
    assert_includes stats, :projected_next_month_cents
    assert_includes stats, :top_categories_current_month
    assert_includes stats, :top_categories_ytd_this_year
    assert_includes stats, :top_categories_last_month
  end

  test "uses today as default date" do
    stats = ProjectStatsCalculator.call(@project)
    # The stats should be calculated for today
    assert stats[:current_month_total_cents].is_a?(Integer)
  end

  test "calculates current month total correctly" do
    # Add expenses for current month
    @project.project_expenses.create!(
      merchant: "Merchant 1",
      total_cents: 10000,
      due_on: @today
    )
    @project.project_expenses.create!(
      merchant: "Merchant 2",
      total_cents: 5000,
      due_on: @today - 10.days
    )

    stats = ProjectStatsCalculator.call(@project, @today)
    assert_equal 15000, stats[:current_month_total_cents]
  end

  test "calculates last month total correctly" do
    last_month = @today.prev_month

    @project.project_expenses.create!(
      merchant: "Last Month Merchant",
      total_cents: 20000,
      due_on: last_month
    )

    stats = ProjectStatsCalculator.call(@project, @today)
    assert_equal 20000, stats[:last_month_total_cents]
  end

  test "calculates MoM change correctly" do
    # Current month expenses
    @project.project_expenses.create!(
      merchant: "Current",
      total_cents: 15000,
      due_on: @today
    )

    # Last month expenses
    last_month = @today.prev_month
    @project.project_expenses.create!(
      merchant: "Last",
      total_cents: 10000,
      due_on: last_month
    )

    stats = ProjectStatsCalculator.call(@project, @today)
    assert_equal 5000, stats[:mom_change_cents]
    assert_equal 50.0, stats[:mom_change_pct]
  end

  test "handles zero MoM percentage change" do
    stats = ProjectStatsCalculator.call(@project, @today)
    assert_equal 0.0, stats[:mom_change_pct]
  end

  test "calculates YTD this year correctly" do
    # Add expenses from January through current month
    @project.project_expenses.create!(
      merchant: "Jan",
      total_cents: 5000,
      due_on: Date.new(2025, 1, 15)
    )
    @project.project_expenses.create!(
      merchant: "Nov",
      total_cents: 3000,
      due_on: @today
    )

    stats = ProjectStatsCalculator.call(@project, @today)
    assert_equal 8000, stats[:ytd_this_year_cents]
  end

  test "calculates YTD last year correctly" do
    # Add expenses from last year same period
    @project.project_expenses.create!(
      merchant: "Last Year Jan",
      total_cents: 4000,
      due_on: Date.new(2024, 1, 15)
    )
    @project.project_expenses.create!(
      merchant: "Last Year Nov",
      total_cents: 2000,
      due_on: Date.new(2024, 11, 15)
    )

    stats = ProjectStatsCalculator.call(@project, @today)
    assert_equal 6000, stats[:ytd_last_year_cents]
  end

  test "calculates YoY change correctly" do
    # This year YTD
    @project.project_expenses.create!(
      merchant: "This Year",
      total_cents: 10000,
      due_on: @today
    )

    # Last year YTD
    @project.project_expenses.create!(
      merchant: "Last Year",
      total_cents: 5000,
      due_on: Date.new(2024, 11, 15)
    )

    stats = ProjectStatsCalculator.call(@project, @today)
    assert_equal 5000, stats[:yoy_change_cents]
    assert_equal 100.0, stats[:yoy_change_pct]
  end

  test "handles zero YoY percentage change" do
    stats = ProjectStatsCalculator.call(@project, @today)
    assert_equal 0.0, stats[:yoy_change_pct]
  end

  test "calculates projection with 3 months of data" do
    # Last month
    @project.project_expenses.create!(
      merchant: "Month 1",
      total_cents: 10000,
      due_on: @today.prev_month
    )

    # 2 months ago
    @project.project_expenses.create!(
      merchant: "Month 2",
      total_cents: 8000,
      due_on: @today.prev_month(2)
    )

    # 3 months ago
    @project.project_expenses.create!(
      merchant: "Month 3",
      total_cents: 6000,
      due_on: @today.prev_month(3)
    )

    stats = ProjectStatsCalculator.call(@project, @today)
    # Weighted: 50% * 10000 + 30% * 8000 + 20% * 6000 = 8600
    expected = (10000 * 0.5 + 8000 * 0.3 + 6000 * 0.2).round
    assert_equal expected, stats[:projected_next_month_cents]
  end

  test "calculates projection with 2 months of data" do
    @project.project_expenses.create!(
      merchant: "Month 1",
      total_cents: 10000,
      due_on: @today.prev_month
    )

    @project.project_expenses.create!(
      merchant: "Month 2",
      total_cents: 8000,
      due_on: @today.prev_month(2)
    )

    stats = ProjectStatsCalculator.call(@project, @today)
    # Weighted: 70% * 10000 + 30% * 8000 = 9400
    expected = (10000 * 0.7 + 8000 * 0.3).round
    assert_equal expected, stats[:projected_next_month_cents]
  end

  test "calculates projection with 1 month of data" do
    @project.project_expenses.create!(
      merchant: "Month 1",
      total_cents: 10000,
      due_on: @today.prev_month
    )

    stats = ProjectStatsCalculator.call(@project, @today)
    assert_equal 10000, stats[:projected_next_month_cents]
  end

  test "returns zero projection when no data" do
    stats = ProjectStatsCalculator.call(@project, @today)
    assert_equal 0, stats[:projected_next_month_cents]
  end

  test "calculates top categories for current month" do
    @project.project_expenses.create!(
      merchant: "Groceries",
      category: "groceries",
      total_cents: 10000,
      due_on: @today
    )
    @project.project_expenses.create!(
      merchant: "Restaurant",
      category: "dining",
      total_cents: 5000,
      due_on: @today
    )
    @project.project_expenses.create!(
      merchant: "Gas",
      category: "transport",
      total_cents: 3000,
      due_on: @today
    )

    stats = ProjectStatsCalculator.call(@project, @today)
    top_categories = stats[:top_categories_current_month]

    assert_equal 3, top_categories.length
    assert_equal "groceries", top_categories.first[:category]
    assert_equal 10000, top_categories.first[:total_cents]
  end

  test "handles nil categories as Uncategorized" do
    @project.project_expenses.create!(
      merchant: "No Category",
      category: nil,
      total_cents: 5000,
      due_on: @today
    )

    stats = ProjectStatsCalculator.call(@project, @today)
    top_categories = stats[:top_categories_current_month]

    assert_equal 1, top_categories.length
    assert_equal "Uncategorized", top_categories.first[:category]
  end

  test "only includes expenses with due_on date" do
    # Expense with due_on (should be included)
    @project.project_expenses.create!(
      merchant: "With Date",
      total_cents: 10000,
      due_on: @today
    )

    # Expense without due_on (should be excluded)
    @project.project_expenses.create!(
      merchant: "No Date",
      total_cents: 5000,
      due_on: nil
    )

    stats = ProjectStatsCalculator.call(@project, @today)
    assert_equal 10000, stats[:current_month_total_cents]
  end
end
