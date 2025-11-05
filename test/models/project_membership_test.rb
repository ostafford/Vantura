require "test_helper"

class ProjectMembershipTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @project = Project.create!(owner: @user, name: "Test Project")
    @membership = @project.project_memberships.create!(user: users(:two), access_level: :limited)
  end

  # Association tests
  test "should belong to project" do
    assert_respond_to @membership, :project
    assert_instance_of Project, @membership.project
  end

  test "should belong to user" do
    assert_respond_to @membership, :user
    assert_instance_of User, @membership.user
  end

  # Validation tests
  test "should be valid with valid attributes" do
    other_user = users(:two)
    other_project = Project.create!(owner: @user, name: "Other Project")
    membership = ProjectMembership.new(project: other_project, user: other_user, access_level: :limited)
    assert membership.valid?
  end

  test "should require unique user per project" do
    duplicate = ProjectMembership.new(project: @project, user: @membership.user)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "should allow same user in different projects" do
    other_project = Project.create!(owner: @user, name: "Other Project")
    membership = ProjectMembership.new(project: other_project, user: @membership.user, access_level: :limited)
    assert membership.valid?
  end

  test "should require access_level" do
    @membership.access_level = nil
    assert_not @membership.valid?
    assert_includes @membership.errors[:access_level], "can't be blank"
  end

  # Enum tests
  test "should define access_level enum" do
    assert_respond_to ProjectMembership, :access_levels
  end

  test "should have limited access_level" do
    @membership.access_level = :limited
    assert @membership.limited?
  end

  test "should have full access_level" do
    @membership.access_level = :full
    assert @membership.full?
  end

  test "should default to limited access_level" do
    other_project = Project.create!(owner: @user, name: "Other Project")
    membership = ProjectMembership.new(project: other_project, user: users(:two))
    assert_equal "limited", membership.access_level
  end
end
