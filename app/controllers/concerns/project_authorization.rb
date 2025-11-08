module ProjectAuthorization
  extend ActiveSupport::Concern

  private

  def authorize_member!
    return if @project.owner_id == Current.user.id || @project.members.exists?(id: Current.user.id)
    head :forbidden
  end

  def authorize_owner!
    return if @project.owner_id == Current.user.id
    head :forbidden
  end

  def authorize_owner_or_editor!
    return if @project.owner_id == Current.user.id
    if @project.project_memberships.where(user_id: Current.user.id, access_level: ProjectMembership.access_levels[:full]).exists?
      return
    end
    head :forbidden
  end
end
