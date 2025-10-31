class ProjectExpensesController < ApplicationController
  before_action :set_project
  before_action :authorize_member!
  before_action :authorize_owner!, only: [ :new, :create, :edit, :update, :destroy ]
  before_action :set_expense, only: [ :edit, :update, :destroy ]

  def new
    @expense = @project.project_expenses.new
  end

  def create
    @expense = @project.project_expenses.new(expense_params)
    if @expense.save
      # Use selected participants or default to all participants
      contributor_ids = params[:contributor_user_ids].presence || @project.participants.pluck(:id)
      @expense.rebuild_contributions_for_participants!(contributor_ids)
      
      # Calculate fresh project statistics for projects index update
      calculate_projects_statistics
      
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to project_path(@project), notice: "Expense added" }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @expense.update(expense_params)
      # Use selected participants or default to all participants
      contributor_ids = params[:contributor_user_ids].presence || @project.participants.pluck(:id)
      @expense.rebuild_contributions_for_participants!(contributor_ids)
      
      respond_to do |format|
        format.turbo_stream { redirect_to project_path(@project), notice: "Expense updated successfully!" }
        format.html { redirect_to project_path(@project), notice: "Expense updated" }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @expense.destroy
    
    # Calculate fresh project statistics for projects index update
    calculate_projects_statistics
    
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_path(@project), notice: "Expense deleted" }
    end
  end

  private
    def set_project
      @project = Project.find(params[:project_id])
    end

    def set_expense
      @expense = @project.project_expenses.find(params[:id])
    end

    def authorize_member!
      return if @project.owner_id == Current.user.id || @project.members.exists?(id: Current.user.id)
      head :forbidden
    end

    def authorize_owner!
      return if @project.owner_id == Current.user.id
      head :forbidden
    end

    def expense_params
      params.require(:project_expense).permit(:merchant, :category, :total_cents, :due_on, :notes)
    end

    def calculate_projects_statistics
      # Reuse the same logic from ProjectsController
      # Get all projects for the current user
      projects = Project
        .joins("LEFT JOIN project_memberships ON project_memberships.project_id = projects.id")
        .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: Current.user.id)
        .distinct
        .includes(:project_expenses, :owner, :members, project_memberships: :user)
      
      @projects = projects.order(created_at: :desc)
      
      # Calculate total projects
      @total_projects = projects.count
      
      # Calculate total expenses
      @total_expenses_cents = ProjectExpense
        .joins(:project)
        .joins("LEFT JOIN project_memberships ON project_memberships.project_id = projects.id")
        .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: Current.user.id)
        .distinct
        .sum(:total_cents)
      @total_expenses = @total_expenses_cents / 100.0
      
      # Calculate unique participants
      owner_ids = projects.pluck(:owner_id)
      member_ids = ProjectMembership
        .joins(:project)
        .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: Current.user.id)
        .distinct
        .pluck(:user_id)
      @total_participants = (owner_ids + member_ids).uniq.count
      
      # Calculate active projects
      project_ids_with_expenses = ProjectExpense
        .joins(:project)
        .joins("LEFT JOIN project_memberships ON project_memberships.project_id = projects.id")
        .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: Current.user.id)
        .distinct
        .pluck(:project_id)
      @active_projects = project_ids_with_expenses.uniq.count
      
      # Find largest expense
      @largest_expense = ProjectExpense
        .joins(:project)
        .joins("LEFT JOIN project_memberships ON project_memberships.project_id = projects.id")
        .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: Current.user.id)
        .distinct
        .order(total_cents: :desc)
        .first
      
      # Find most active project
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
