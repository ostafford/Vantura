class ProjectsController < ApplicationController
  include ProjectAuthorization

  before_action :set_project, only: [ :show, :edit, :update, :destroy ]
  before_action :authorize_member!, only: [ :show ]
  before_action :authorize_owner_or_editor!, only: [ :edit, :update ]
  before_action :authorize_owner!, only: [ :destroy ]

  def index
    @projects_data = ProjectsIndexStatisticsService.call(Current.user)
  end

  def show
    @project_show_data = ProjectShowDataService.call(@project, params.slice(:year, :month))
    respond_to { |format| format.html; format.turbo_stream }
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)
    @project.owner = Current.user
    if @project.save
      ProjectMembershipSyncService.call(@project, params[:member_user_ids], params[:member_access_levels] || {})
      @projects_data = ProjectsIndexStatisticsService.call(Current.user)
      respond_to { |format| format.turbo_stream; format.html { redirect_to @project, notice: "Project created successfully" } }
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      ProjectMembershipSyncService.call(@project, params[:member_user_ids], params[:member_access_levels] || {})
      respond_to { |format| format.turbo_stream { redirect_to @project, status: :see_other }; format.html { redirect_to @project, notice: "Project updated successfully" } }
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    @projects_data = ProjectsIndexStatisticsService.call(Current.user)
    respond_to { |format| format.turbo_stream; format.html { redirect_to projects_path, notice: "Project deleted" } }
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name)
  end
end
