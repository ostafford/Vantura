require "test_helper"

class ProjectBarsAggregatorTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @project = Project.create!(owner: @user, name: "Test Project")
    @year = 2025
    @month = 11
  end

  test "returns expected structure" do
    data = ProjectBarsAggregator.call(
      project: @project,
      period: "month",
      year: @year,
      month: @month,
      group_by: "total"
    )

    assert_instance_of Hash, data
    assert_includes data, :labels
    assert_includes data, :datasets
    assert_includes data, :totals
  end

  test "builds labels for month period" do
    data = ProjectBarsAggregator.call(
      project: @project,
      period: "month",
      year: @year,
      month: @month,
      group_by: "total"
    )

    assert_instance_of Array, data[:labels]
    assert_equal 1, data[:labels].length
  end

  test "builds labels for year period" do
    data = ProjectBarsAggregator.call(
      project: @project,
      period: "year",
      year: @year,
      month: @month,
      group_by: "total"
    )

    assert_instance_of Array, data[:labels]
    assert_equal 12, data[:labels].length
  end

  test "builds total dataset" do
    @project.project_expenses.create!(
      merchant: "Store",
      total_cents: 10000,
      due_on: Date.new(@year, @month, 15)
    )

    data = ProjectBarsAggregator.call(
      project: @project,
      period: "month",
      year: @year,
      month: @month,
      group_by: "total"
    )

    assert_equal 1, data[:datasets].length
    assert_equal "Expenses", data[:datasets].first[:name]
    assert_equal 10000, data[:datasets].first[:data].first
  end

  test "groups by category" do
    @project.project_expenses.create!(
      merchant: "Store A",
      category: "groceries",
      total_cents: 10000,
      due_on: Date.new(@year, @month, 15)
    )
    @project.project_expenses.create!(
      merchant: "Store B",
      category: "dining",
      total_cents: 5000,
      due_on: Date.new(@year, @month, 16)
    )

    data = ProjectBarsAggregator.call(
      project: @project,
      period: "month",
      year: @year,
      month: @month,
      group_by: "category"
    )

    assert data[:datasets].length >= 2
    category_names = data[:datasets].map { |ds| ds[:name] }
    assert_includes category_names, "groceries"
    assert_includes category_names, "dining"
  end

  test "groups by merchant" do
    @project.project_expenses.create!(
      merchant: "Store A",
      total_cents: 10000,
      due_on: Date.new(@year, @month, 15)
    )
    @project.project_expenses.create!(
      merchant: "Store B",
      total_cents: 5000,
      due_on: Date.new(@year, @month, 16)
    )

    data = ProjectBarsAggregator.call(
      project: @project,
      period: "month",
      year: @year,
      month: @month,
      group_by: "merchant"
    )

    assert data[:datasets].length >= 2
    merchant_names = data[:datasets].map { |ds| ds[:name] }
    assert_includes merchant_names, "Store A"
    assert_includes merchant_names, "Store B"
  end

  test "filters by ids when provided" do
    @project.project_expenses.create!(
      merchant: "Store A",
      category: "groceries",
      total_cents: 10000,
      due_on: Date.new(@year, @month, 15)
    )
    @project.project_expenses.create!(
      merchant: "Store B",
      category: "dining",
      total_cents: 5000,
      due_on: Date.new(@year, @month, 16)
    )

    data = ProjectBarsAggregator.call(
      project: @project,
      period: "month",
      year: @year,
      month: @month,
      group_by: "category",
      ids: [ "groceries" ]
    )

    assert_equal 1, data[:datasets].length
    assert_equal "groceries", data[:datasets].first[:name]
  end

  test "calculates period total" do
    @project.project_expenses.create!(
      merchant: "Store",
      total_cents: 10000,
      due_on: Date.new(@year, @month, 15)
    )
    @project.project_expenses.create!(
      merchant: "Store",
      total_cents: 5000,
      due_on: Date.new(@year, @month, 16)
    )

    data = ProjectBarsAggregator.call(
      project: @project,
      period: "month",
      year: @year,
      month: @month,
      group_by: "total"
    )

    assert_equal 15000, data[:totals][:period_total_cents]
  end

  test "excludes expenses without due_on" do
    @project.project_expenses.create!(
      merchant: "With Date",
      total_cents: 10000,
      due_on: Date.new(@year, @month, 15)
    )
    @project.project_expenses.create!(
      merchant: "No Date",
      total_cents: 5000,
      due_on: nil
    )

    data = ProjectBarsAggregator.call(
      project: @project,
      period: "month",
      year: @year,
      month: @month,
      group_by: "total"
    )

    assert_equal 10000, data[:totals][:period_total_cents]
  end
end
