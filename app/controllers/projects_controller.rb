class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [ :show, :edit, :update, :destroy ]
  before_action :authorize_project_access, only: [ :show ]
  before_action :authorize_project_edit, only: [ :edit, :update ]
  before_action :authorize_project_delete, only: [ :destroy ]

  def index
    # Get all projects user owns or is a member of
    owned_ids = current_user.owned_projects.pluck(:id)
    member_ids = current_user.projects.pluck(:id)
    all_project_ids = (owned_ids + member_ids).uniq

    @projects = Project.where(id: all_project_ids)
                      .includes(:owner, :members)
                      .order(created_at: :desc)
  end

  def show
  end

  def new
    @project = Project.new
  end

  def create
    @project = current_user.owned_projects.build(project_params)

    if @project.save
      redirect_to @project, notice: "Project created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Project updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_path, notice: "Project deleted successfully."
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def authorize_project_access
    unless @project.member?(current_user)
      redirect_to projects_path, alert: "You don't have access to this project."
    end
  end

  def authorize_project_edit
    unless @project.can_edit?(current_user)
      redirect_to @project, alert: "You don't have permission to edit this project."
    end
  end

  def authorize_project_delete
    unless @project.can_delete?(current_user)
      redirect_to @project, alert: "You don't have permission to delete this project."
    end
  end

  def project_params
    params.require(:project).permit(:name, :description, :color)
  end
end
