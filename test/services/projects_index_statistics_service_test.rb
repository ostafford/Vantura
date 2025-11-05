require "test_helper"

class ProjectsIndexStatisticsServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @user2 = users(:two)

    # Clear existing projects to avoid fixture interference
    Project.where(owner: @user).destroy_all
    Project.where(owner: @user2).destroy_all

    # Create projects owned by user
    @project1 = Project.create!(owner: @user, name: "Project 1")
    @project2 = Project.create!(owner: @user, name: "Project 2")

    # Create project owned by user2 (should not be included)
    @other_project = Project.create!(owner: @user2, name: "Other Project")
  end

  test "returns expected structure" do
    stats = ProjectsIndexStatisticsService.call(@user)

    assert_instance_of Hash, stats
    assert_includes stats, :projects
    assert_includes stats, :total_projects
    assert_includes stats, :total_expenses_cents
    assert_includes stats, :total_expenses
    assert_includes stats, :total_participants
    assert_includes stats, :active_projects
    assert_includes stats, :largest_expense
    assert_includes stats, :most_active_project
  end

  test "returns only user's projects" do
    stats = ProjectsIndexStatisticsService.call(@user)

    assert_equal 2, stats[:total_projects]
    assert_equal 2, stats[:projects].count
    assert_includes stats[:projects].map(&:id), @project1.id
    assert_includes stats[:projects].map(&:id), @project2.id
    assert_not_includes stats[:projects].map(&:id), @other_project.id
  end

  test "includes projects where user is member" do
    # Create project owned by user2, add user1 as member
    member_project = Project.create!(owner: @user2, name: "Member Project")
    member_project.project_memberships.create!(user: @user, access_level: :limited)

    stats = ProjectsIndexStatisticsService.call(@user)

    assert_equal 3, stats[:total_projects]
    assert_includes stats[:projects].map(&:id), member_project.id
  end

  test "orders projects by created_at descending" do
    # Create newer project
    newer_project = Project.create!(owner: @user, name: "Newer Project")

    stats = ProjectsIndexStatisticsService.call(@user)
    project_ids = stats[:projects].map(&:id)

    assert_equal newer_project.id, project_ids.first
  end

  test "calculates total expenses correctly" do
    @project1.project_expenses.create!(
      merchant: "Merchant 1",
      total_cents: 10000,
      due_on: Date.today
    )
    @project2.project_expenses.create!(
      merchant: "Merchant 2",
      total_cents: 5000,
      due_on: Date.today
    )

    stats = ProjectsIndexStatisticsService.call(@user)
    assert_equal 15000, stats[:total_expenses_cents]
    assert_equal 150.0, stats[:total_expenses]
  end

  test "calculates total expenses for projects where user is member" do
    member_project = Project.create!(owner: @user2, name: "Member Project")
    member_project.project_memberships.create!(user: @user)
    member_project.project_expenses.create!(
      merchant: "Member Expense",
      total_cents: 7500,
      due_on: Date.today
    )

    stats = ProjectsIndexStatisticsService.call(@user)
    assert_equal 7500, stats[:total_expenses_cents]
  end

  test "calculates total participants correctly" do
    # Add members to project1
    @project1.project_memberships.create!(user: @user2)

    stats = ProjectsIndexStatisticsService.call(@user)
    # Owner (@user) + member (@user2) = 2 unique participants
    assert_equal 2, stats[:total_participants]
  end

  test "counts unique participants across all projects" do
    # Add same user as member to multiple projects
    @project1.project_memberships.create!(user: @user2)
    @project2.project_memberships.create!(user: @user2)

    stats = ProjectsIndexStatisticsService.call(@user)
    # Owner (@user) + member (@user2, counted once) = 2 unique
    assert_equal 2, stats[:total_participants]
  end

  test "calculates active projects correctly" do
    # Project with expenses
    @project1.project_expenses.create!(
      merchant: "Merchant",
      total_cents: 1000,
      due_on: Date.today
    )

    stats = ProjectsIndexStatisticsService.call(@user)
    assert_equal 1, stats[:active_projects]
  end

  test "returns zero active projects when no expenses" do
    stats = ProjectsIndexStatisticsService.call(@user)
    assert_equal 0, stats[:active_projects]
  end

  test "finds largest expense" do
    small_expense = @project1.project_expenses.create!(
      merchant: "Small",
      total_cents: 1000,
      due_on: Date.today
    )
    large_expense = @project2.project_expenses.create!(
      merchant: "Large",
      total_cents: 5000,
      due_on: Date.today
    )

    stats = ProjectsIndexStatisticsService.call(@user)
    assert_equal large_expense.id, stats[:largest_expense].id
  end

  test "finds most active project" do
    # Project1 with 3 expenses
    3.times do |i|
      @project1.project_expenses.create!(
        merchant: "Merchant #{i}",
        total_cents: 1000,
        due_on: Date.today
      )
    end

    # Project2 with 1 expense
    @project2.project_expenses.create!(
      merchant: "Merchant",
      total_cents: 1000,
      due_on: Date.today
    )

    stats = ProjectsIndexStatisticsService.call(@user)
    assert_equal @project1.id, stats[:most_active_project].id
  end

  test "returns nil for most_active_project when no expenses" do
    stats = ProjectsIndexStatisticsService.call(@user)
    assert_nil stats[:most_active_project]
  end

  test "handles empty projects list" do
    user_without_projects = users(:two)
    # Clear any existing projects
    Project.where(owner: user_without_projects).destroy_all

    stats = ProjectsIndexStatisticsService.call(user_without_projects)

    assert_equal 0, stats[:total_projects]
    assert_equal 0, stats[:total_expenses_cents]
    assert_equal 0.0, stats[:total_expenses]
    assert_equal 0, stats[:total_participants] # No projects = no participants
    assert_equal 0, stats[:active_projects]
    assert_nil stats[:largest_expense]
    assert_nil stats[:most_active_project]
  end
end
