class ProjectMembershipsController < ApplicationController
  include ProjectAuthorization

  before_action :set_project
  before_action :authorize_owner_or_editor!

  def create
    user = User.find_by(id: membership_params[:user_id])

    unless user
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("add-member-form", partial: "projects/add_member_form", locals: { project: @project, error: "User not found" }) }
        format.html { redirect_to @project, alert: "User not found" }
      end
      return
    end

    if user.id == @project.owner_id
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("add-member-form", partial: "projects/add_member_form", locals: { project: @project, error: "Owner is already part of the project" }) }
        format.html { redirect_to @project, alert: "Owner is already part of the project" }
      end
      return
    end

    @membership = @project.project_memberships.find_or_initialize_by(user: user)

    if membership_params[:access_level].present?
      level = membership_params[:access_level]
      @membership.access_level = %w[full limited].include?(level) ? level : "limited"
    end

    if @membership.persisted? || @membership.save
      @project.reload
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @project, notice: "Member added" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("add-member-form", partial: "projects/add_member_form", locals: { project: @project, membership: @membership }) }
        format.html { redirect_to @project, alert: @membership.errors.full_messages.join(", ") }
      end
    end
  end

  def destroy
    @membership = @project.project_memberships.find_by(id: params[:id])

    unless @membership
      respond_to do |format|
        format.turbo_stream { head :not_found }
        format.html { redirect_to @project, alert: "Membership not found" }
      end
      return
    end

    @membership.destroy
    @project.reload

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @project, notice: "Member removed" }
    end
  end

  private

    def set_project
      @project = Project.find(params[:project_id])
    end

    def membership_params
      params.permit(:user_id, :access_level)
    end
end
