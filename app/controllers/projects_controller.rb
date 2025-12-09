class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [ :show, :edit, :update, :destroy ]

  def index
    @projects = policy_scope(Project)
                      .includes(:owner, :members)
                      .order(created_at: :desc)
  end

  def show
    authorize @project
  end

  def new
    @project = Project.new
    authorize @project
  end

  def create
    @project = current_user.owned_projects.build(project_params)
    authorize @project

    if @project.save
      redirect_to @project, notice: I18n.t("flash.projects.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @project
  end

  def update
    authorize @project
    if @project.update(project_params)
      redirect_to @project, notice: I18n.t("flash.projects.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @project
    @project.destroy
    redirect_to projects_path, notice: I18n.t("flash.projects.deleted")
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :description, :color)
  end
end
