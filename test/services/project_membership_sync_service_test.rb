require "test_helper"

class ProjectMembershipSyncServiceTest < ActiveSupport::TestCase
  def setup
    @owner = users(:one)
    @member1 = users(:two)
    @member2 = User.create!(email_address: "member2@example.com", password: "password123")
    @project = Project.create!(owner: @owner, name: "Test Project")
  end

  test "deletes all existing memberships" do
    # Create existing memberships
    @project.project_memberships.create!(user: @member1, access_level: :limited)
    @project.project_memberships.create!(user: @member2, access_level: :full)

    assert_equal 2, @project.project_memberships.count

    ProjectMembershipSyncService.call(@project, [], {})

    assert_equal 0, @project.project_memberships.count
  end

  test "creates new memberships from user ids" do
    member_user_ids = [ @member1.id, @member2.id ]

    ProjectMembershipSyncService.call(@project, member_user_ids, {})

    assert_equal 2, @project.project_memberships.count
    assert_includes @project.project_memberships.pluck(:user_id), @member1.id
    assert_includes @project.project_memberships.pluck(:user_id), @member2.id
  end

  test "excludes owner from memberships" do
    member_user_ids = [ @owner.id, @member1.id ]

    ProjectMembershipSyncService.call(@project, member_user_ids, {})

    assert_equal 1, @project.project_memberships.count
    assert_includes @project.project_memberships.pluck(:user_id), @member1.id
    assert_not_includes @project.project_memberships.pluck(:user_id), @owner.id
  end

  test "sets access level from access_levels hash" do
    member_user_ids = [ @member1.id, @member2.id ]
    access_levels = {
      @member1.id.to_s => "full",
      @member2.id.to_s => "limited"
    }

    ProjectMembershipSyncService.call(@project, member_user_ids, access_levels)

    membership1 = @project.project_memberships.find_by(user_id: @member1.id)
    membership2 = @project.project_memberships.find_by(user_id: @member2.id)

    assert_equal "full", membership1.access_level
    assert_equal "limited", membership2.access_level
  end

  test "defaults to limited access when access level not provided" do
    member_user_ids = [ @member1.id ]
    access_levels = {}

    ProjectMembershipSyncService.call(@project, member_user_ids, access_levels)

    membership = @project.project_memberships.find_by(user_id: @member1.id)
    assert_equal "limited", membership.access_level
  end

  test "defaults to limited access when invalid access level provided" do
    member_user_ids = [ @member1.id ]
    access_levels = {
      @member1.id.to_s => "invalid_level"
    }

    ProjectMembershipSyncService.call(@project, member_user_ids, access_levels)

    membership = @project.project_memberships.find_by(user_id: @member1.id)
    assert_equal "limited", membership.access_level
  end

  test "handles nil member_user_ids" do
    ProjectMembershipSyncService.call(@project, nil, {})

    assert_equal 0, @project.project_memberships.count
  end

  test "handles empty member_user_ids array" do
    @project.project_memberships.create!(user: @member1, access_level: :limited)

    ProjectMembershipSyncService.call(@project, [], {})

    assert_equal 0, @project.project_memberships.count
  end

  test "removes duplicates from member_user_ids" do
    member_user_ids = [ @member1.id, @member1.id, @member2.id ]

    ProjectMembershipSyncService.call(@project, member_user_ids, {})

    assert_equal 2, @project.project_memberships.count
    assert_equal 1, @project.project_memberships.where(user_id: @member1.id).count
  end

  test "handles string user ids" do
    member_user_ids = [ @member1.id.to_s, @member2.id.to_s ]

    ProjectMembershipSyncService.call(@project, member_user_ids, {})

    assert_equal 2, @project.project_memberships.count
    assert_includes @project.project_memberships.pluck(:user_id), @member1.id
    assert_includes @project.project_memberships.pluck(:user_id), @member2.id
  end

  test "replaces existing memberships with new ones" do
    # Create initial membership
    @project.project_memberships.create!(user: @member1, access_level: :limited)

    # Sync with different members
    ProjectMembershipSyncService.call(@project, [ @member2.id ], {})

    assert_equal 1, @project.project_memberships.count
    assert_includes @project.project_memberships.pluck(:user_id), @member2.id
    assert_not_includes @project.project_memberships.pluck(:user_id), @member1.id
  end

  test "returns true on success" do
    result = ProjectMembershipSyncService.call(@project, [ @member1.id ], {})
    assert_equal true, result
  end
end
