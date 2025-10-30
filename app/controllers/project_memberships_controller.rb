class ProjectMembershipsController < ApplicationController
  before_action :set_project
  before_action :authorize_owner!

  def create
    user = User.find(params[:user_id])
    if user.id == @project.owner_id
      redirect_to @project, alert: "Owner is already part of the project"
      return
    end

    membership = @project.project_memberships.find_or_initialize_by(user: user)
    if membership.persisted? || membership.save
      redirect_to @project, notice: "Member added"
    else
      redirect_to @project, alert: membership.errors.full_messages.join(", ")
    end
  end

  def destroy
    membership = @project.project_memberships.find_by!(id: params[:id])
    membership.destroy
    redirect_to @project, notice: "Member removed"
  end

  private
    def set_project
      @project = Project.find(params[:project_id])
    end

    def authorize_owner!
      return if @project.owner_id == Current.user.id
      head :forbidden
    end
end
