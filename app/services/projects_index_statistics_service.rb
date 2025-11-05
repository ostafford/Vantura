# Service Object: Calculate statistics for all projects (projects index page)
#
# Usage:
#   stats = ProjectsIndexStatisticsService.call(Current.user)
#
# Returns hash with:
#   - projects: Ordered collection of projects
#   - total_projects: Count of all projects
#   - total_expenses_cents: Total expenses across all projects (in cents)
#   - total_expenses: Total expenses in dollars
#   - total_participants: Unique count of all participants (owners + members)
#   - active_projects: Count of projects with at least one expense
#   - largest_expense: The largest expense across all projects
#   - most_active_project: Project with the most expenses
#
class ProjectsIndexStatisticsService < ApplicationService
  def initialize(user)
    @user = user
  end

  def call
    {
      projects: projects,
      total_projects: total_projects,
      total_expenses_cents: total_expenses_cents,
      total_expenses: total_expenses,
      total_participants: total_participants,
      active_projects: active_projects,
      largest_expense: largest_expense,
      most_active_project: most_active_project
    }
  end

  private

  def projects
    @projects ||= user_projects.order(created_at: :desc)
  end

  def user_projects
    @user_projects ||= Project
      .joins("LEFT JOIN project_memberships ON project_memberships.project_id = projects.id")
      .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: @user.id)
      .distinct
      .includes(:project_expenses, :owner, :members, project_memberships: :user)
  end

  def total_projects
    @total_projects ||= user_projects.count
  end

  def total_expenses_cents
    @total_expenses_cents ||= ProjectExpense
      .joins(:project)
      .joins("LEFT JOIN project_memberships ON project_memberships.project_id = projects.id")
      .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: @user.id)
      .distinct
      .sum(:total_cents)
  end

  def total_expenses
    @total_expenses ||= total_expenses_cents / 100.0
  end

  def total_participants
    @total_participants ||= begin
      owner_ids = user_projects.pluck(:owner_id)
      member_ids = ProjectMembership
        .joins(:project)
        .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: @user.id)
        .distinct
        .pluck(:user_id)
      (owner_ids + member_ids).uniq.count
    end
  end

  def active_projects
    @active_projects ||= begin
      project_ids_with_expenses = ProjectExpense
        .joins(:project)
        .joins("LEFT JOIN project_memberships ON project_memberships.project_id = projects.id")
        .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: @user.id)
        .distinct
        .pluck(:project_id)
      project_ids_with_expenses.uniq.count
    end
  end

  def largest_expense
    @largest_expense ||= ProjectExpense
      .joins(:project)
      .joins("LEFT JOIN project_memberships ON project_memberships.project_id = projects.id")
      .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: @user.id)
      .distinct
      .order(total_cents: :desc)
      .first
  end

  def most_active_project
    @most_active_project ||= begin
      project_expense_counts = ProjectExpense
        .joins(:project)
        .joins("LEFT JOIN project_memberships ON project_memberships.project_id = projects.id")
        .where("projects.owner_id = :uid OR project_memberships.user_id = :uid", uid: @user.id)
        .distinct
        .group(:project_id)
        .count

      if project_expense_counts.any?
        most_active_project_id = project_expense_counts.max_by { |_, count| count }[0]
        user_projects.find_by(id: most_active_project_id)
      else
        nil
      end
    end
  end
end
