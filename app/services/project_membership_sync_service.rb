# Service Object: Sync project memberships (add/remove members with access levels)
#
# Usage:
#   ProjectMembershipSyncService.call(project, member_user_ids, access_levels)
#
# Parameters:
#   project: Project instance
#   member_user_ids: Array of user IDs to add as members (can be nil/empty)
#   access_levels: Hash mapping user_id (string) to access level ("full" or "limited")
#
# Behavior:
#   - Deletes all existing memberships (excluding owner)
#   - Creates new memberships from submitted list
#   - Excludes owner from memberships
#   - Defaults to "limited" access if invalid level provided
#
class ProjectMembershipSyncService < ApplicationService
  def initialize(project, member_user_ids, access_levels = {})
    @project = project
    @member_user_ids = member_user_ids
    @access_levels = access_levels
  end

  def call
    # Delete all existing memberships (owner is not a membership, so safe to delete all)
    @project.project_memberships.destroy_all

    # Create new memberships from submitted list (excluding owner if included)
    Array(@member_user_ids).map(&:to_i).uniq.each do |user_id|
      next if user_id == @project.owner_id

      raw_level = @access_levels[user_id.to_s]
      level = %w[full limited].include?(raw_level) ? raw_level : "limited"
      @project.project_memberships.create(
        user_id: user_id,
        access_level: ProjectMembership.access_levels[level]
      )
    end

    true
  end
end
