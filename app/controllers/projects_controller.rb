class ProjectsController < ApplicationController
  before_action :set_project, only: [ :show, :edit, :update, :destroy ]
  before_action :authorize_member!, only: [ :show ]
  before_action :authorize_owner_or_editor!, only: [ :edit, :update ]
  before_action :authorize_owner!, only: [ :destroy ]

  def index
    calculate_project_statistics
  end

  def show
    # Date context for global month navigation
    if params[:year].present? && params[:month].present?
      y = params[:year].to_i
      m = params[:month].to_i
      @date = (m >= 1 && m <= 12) ? (Date.new(y, m, 1) rescue Date.today) : Date.today
    else
      @date = Date.today
    end

    # Date range for filtering (selected month)
    month_start = @date.beginning_of_month
    month_end = @date.end_of_month

    # All expenses (for table, can be filtered later)
    @all_expenses = @project.project_expenses.order(due_on: :asc, created_at: :desc).includes(:expense_contributions)
    # Month-filtered expenses for stats
    @expenses_in_month = @project.project_expenses.where(due_on: month_start..month_end)
    @expenses = @expenses_in_month.order(due_on: :asc, created_at: :desc).includes(:expense_contributions)
    
    # Calculate project-specific statistics (month-filtered)
    @total_expenses_cents = @expenses_in_month.sum(:total_cents)
    @expense_count = @expenses_in_month.count
    @total_participants = @project.participants.count
    
    # Find largest expense (month-filtered)
    @largest_expense = @expenses_in_month.order(total_cents: :desc).first
    
    # Calculate unpaid contributions count (month-filtered)
    @unpaid_contributions_count = ExpenseContribution
      .joins(:project_expense)
      .where(project_expenses: { project_id: @project.id, due_on: month_start..month_end }, paid: false)
      .count
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)
    @project.owner = Current.user

    if @project.save
      sync_project_memberships(params[:member_user_ids])
      calculate_project_statistics
      
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @project, notice: "Project created successfully" }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      sync_project_memberships(params[:member_user_ids])
      calculate_project_statistics
      
      respond_to do |format|
        # For Turbo Stream requests, send an HTTP redirect that Turbo will follow
        format.turbo_stream { redirect_to @project, status: :see_other }
        format.html { redirect_to @project, notice: "Project updated successfully" }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    calculate_project_statistics
    
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to projects_path, notice: "Project deleted" }
    end
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

    def authorize_owner_or_editor!
      return if @project.owner_id == Current.user.id
      if @project.project_memberships.where(user_id: Current.user.id, access_level: ProjectMembership.access_levels[:full]).exists?
        return
      end
      head :forbidden
    end

    def project_params
      params.require(:project).permit(:name)
    end

    def sync_project_memberships(member_user_ids)
      # Delete all existing memberships
      @project.project_memberships.destroy_all

      # Create new memberships from submitted list (excluding owner if included)
      access_levels = params[:member_access_levels] || {}
      Array(member_user_ids).map(&:to_i).uniq.each do |uid|
        next if uid == Current.user.id
        raw_level = access_levels[uid.to_s]
        level = %w[full limited].include?(raw_level) ? raw_level : 'limited'
        @project.project_memberships.create(user_id: uid, access_level: ProjectMembership.access_levels[level])
      end
    end

    def calculate_project_statistics
      # Get all projects for the current user (same query as index)
      projects = Project
        .joins("LEFT JOIN project_memberships ON project_memberships.project_id = projects.id")
        .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: Current.user.id)
        .distinct
        .includes(:project_expenses, :owner, :members, project_memberships: :user)
      
      @projects = projects.order(created_at: :desc)
      
      # Calculate total projects
      @total_projects = projects.count
      
      # Calculate total expenses (sum of all project_expenses.total_cents across all projects)
      @total_expenses_cents = ProjectExpense
        .joins(:project)
        .joins("LEFT JOIN project_memberships ON project_memberships.project_id = projects.id")
        .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: Current.user.id)
        .distinct
        .sum(:total_cents)
      @total_expenses = @total_expenses_cents / 100.0
      
      # Calculate unique participants across all projects
      owner_ids = projects.pluck(:owner_id)
      member_ids = ProjectMembership
        .joins(:project)
        .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: Current.user.id)
        .distinct
        .pluck(:user_id)
      @total_participants = (owner_ids + member_ids).uniq.count
      
      # Calculate active projects (projects with at least one expense)
      project_ids_with_expenses = ProjectExpense
        .joins(:project)
        .joins("LEFT JOIN project_memberships ON project_memberships.project_id = projects.id")
        .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: Current.user.id)
        .distinct
        .pluck(:project_id)
      @active_projects = project_ids_with_expenses.uniq.count
      
      # Find largest expense (for hero card)
      @largest_expense = ProjectExpense
        .joins(:project)
        .joins("LEFT JOIN project_memberships ON project_memberships.project_id = projects.id")
        .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: Current.user.id)
        .distinct
        .order(total_cents: :desc)
        .first
      
      # Find most active project (project with most expenses)
      project_expense_counts = ProjectExpense
        .joins(:project)
        .joins("LEFT JOIN project_memberships ON project_memberships.project_id = projects.id")
        .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: Current.user.id)
        .distinct
        .group(:project_id)
        .count
      
      if project_expense_counts.any?
        most_active_project_id = project_expense_counts.max_by { |_, count| count }[0]
        @most_active_project = projects.find_by(id: most_active_project_id)
      else
        @most_active_project = nil
      end
    end
end
