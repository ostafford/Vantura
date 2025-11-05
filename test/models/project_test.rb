require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @project = Project.create!(owner: @user, name: "Test Project")
  end

  # Association tests
  test "should belong to owner" do
    assert_respond_to @project, :owner
    assert_instance_of User, @project.owner
  end

  test "should have many project_memberships" do
    assert_respond_to @project, :project_memberships
    @project.project_memberships.create!(user: users(:two), access_level: :limited)
    assert_equal 1, @project.project_memberships.count
  end

  test "should have many members through project_memberships" do
    assert_respond_to @project, :members
    member = users(:two)
    @project.project_memberships.create!(user: member, access_level: :limited)
    assert_includes @project.members, member
  end

  test "should have many project_expenses" do
    assert_respond_to @project, :project_expenses
    @project.project_expenses.create!(
      merchant: "Test Merchant",
      total_cents: 10000,
      due_on: Date.today
    )
    assert_equal 1, @project.project_expenses.count
  end

  test "should destroy dependent project_memberships" do
    @project.project_memberships.create!(user: users(:two), access_level: :limited)
    assert_difference("ProjectMembership.count", -1) do
      @project.destroy
    end
  end

  test "should destroy dependent project_expenses" do
    @project.project_expenses.create!(
      merchant: "Test Merchant",
      total_cents: 10000,
      due_on: Date.today
    )
    assert_difference("ProjectExpense.count", -1) do
      @project.destroy
    end
  end

  # Validation tests
  test "should be valid with valid attributes" do
    project = Project.new(owner: @user, name: "Valid Project")
    assert project.valid?
  end

  test "should require name" do
    @project.name = nil
    assert_not @project.valid?
    assert_includes @project.errors[:name], "can't be blank"
  end

  test "should require name to be present" do
    @project.name = ""
    assert_not @project.valid?
    assert_includes @project.errors[:name], "can't be blank"
  end

  # Instance method tests
  test "participants should return owner and members" do
    member = users(:two)
    @project.project_memberships.create!(user: member, access_level: :limited)

    participants = @project.participants
    assert_includes participants, @user
    assert_includes participants, member
    assert_equal 2, participants.length
  end

  test "participants should return unique list" do
    # Add owner as member (shouldn't happen but test uniqueness)
    @project.project_memberships.create!(user: @user, access_level: :limited)

    participants = @project.participants
    # Owner should only appear once
    assert_equal 1, participants.count { |p| p.id == @user.id }
  end

  test "participants should return empty array when no members" do
    participants = @project.participants
    assert_equal [ @user ], participants
  end
end
