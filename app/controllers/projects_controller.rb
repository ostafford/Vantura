class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :edit, :update, :destroy]
  before_action :authorize_member!, only: [:show]
  before_action :authorize_owner!, only: [:edit, :update, :destroy]

  def index
    @projects = Project
      .joins("LEFT JOIN project_memberships ON project_memberships.project_id = projects.id")
      .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: Current.user.id)
      .distinct
      .order(created_at: :desc)
  end

  def show
    @expenses = @project.project_expenses.order(due_on: :asc, created_at: :desc)
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)
    @project.owner = Current.user

    if @project.save
      # Attach memberships for selected user_ids (excluding owner if included)
      Array(params[:member_user_ids]).map(&:to_i).uniq.each do |uid|
        next if uid == Current.user.id
        @project.project_memberships.create(user_id: uid)
      end
      redirect_to @project, notice: "Project created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Project updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_path, notice: "Project deleted"
  end

  private
    def set_project
      @project = Project.find(params[:id])
    end

    def authorize_member!
      return if @project.owner_id == Current.user.id || @project.members.exists?(id: Current.user.id)
      head :forbidden
    end

    def authorize_owner!
      return if @project.owner_id == Current.user.id
      head :forbidden
    end

    def project_params
      params.require(:project).permit(:name)
    end
end


