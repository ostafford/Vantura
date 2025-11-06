class ProjectsController < ApplicationController
  include ProjectAuthorization

  before_action :set_project, only: [ :show, :edit, :update, :destroy ]
  before_action :authorize_member!, only: [ :show ]
  before_action :authorize_owner_or_editor!, only: [ :edit, :update ]
  before_action :authorize_owner!, only: [ :destroy ]

  def index
    assign_projects_index_stats
  end

  def show
    data = ProjectShowDataService.call(@project, params.slice(:year, :month))
    assign_project_show_variables(data)
    respond_to { |format| format.html; format.turbo_stream }
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)
    @project.owner = Current.user
    if @project.save
      sync_project_memberships(params[:member_user_ids]) && assign_projects_index_stats
      respond_to { |format| format.turbo_stream; format.html { redirect_to @project, notice: "Project created successfully" } }
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      sync_project_memberships(params[:member_user_ids])
      respond_to { |format| format.turbo_stream { redirect_to @project, status: :see_other }; format.html { redirect_to @project, notice: "Project updated successfully" } }
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    assign_projects_index_stats
    respond_to { |format| format.turbo_stream; format.html { redirect_to projects_path, notice: "Project deleted" } }
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

    def assign_projects_index_stats
      stats = ProjectsIndexStatisticsService.call(Current.user)
      @projects, @total_projects, @total_expenses_cents, @total_expenses, @total_participants, @active_projects, @largest_expense, @most_active_project = stats.values_at(:projects, :total_projects, :total_expenses_cents, :total_expenses, :total_participants, :active_projects, :largest_expense, :most_active_project)
    end

    def assign_project_show_variables(data)
      @date, @expenses, @expenses_in_month, @all_expenses = data.values_at(:date, :expenses, :expenses_in_month, :all_expenses)
      @total_expenses_cents, @expense_count, @total_participants, @largest_expense = data.values_at(:total_expenses_cents, :expense_count, :total_participants, :largest_expense)
      @unpaid_contributions_count, @project_stats = data.values_at(:unpaid_contributions_count, :project_stats)
    end

    def sync_project_memberships(member_user_ids)
      # Delete all existing memberships
      @project.project_memberships.destroy_all

      # Create new memberships from submitted list (excluding owner if included)
      access_levels = params[:member_access_levels] || {}
      Array(member_user_ids).map(&:to_i).uniq.each do |uid|
        next if uid == Current.user.id
        raw_level = access_levels[uid.to_s]
        level = %w[full limited].include?(raw_level) ? raw_level : "limited"
        @project.project_memberships.create(user_id: uid, access_level: ProjectMembership.access_levels[level])
      end
    end
end
