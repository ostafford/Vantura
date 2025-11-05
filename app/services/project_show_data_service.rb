# Service Object: Prepare all data needed for project show page
#
# Usage:
#   data = ProjectShowDataService.call(@project, params.slice(:year, :month))
#
# Returns hash with:
#   - date: Parsed date from params or today
#   - expenses: Month-filtered expenses ordered by due_on
#   - expenses_in_month: Month-filtered expenses relation (for stats)
#   - all_expenses: All expenses for the project (for table)
#   - total_expenses_cents: Total expenses for the month
#   - expense_count: Count of expenses in month
#   - total_participants: Count of participants
#   - largest_expense: Largest expense in month
#   - unpaid_contributions_count: Count of unpaid contributions in month
#   - project_stats: MoM/YoY stats from ProjectStatsCalculator
#
class ProjectShowDataService < ApplicationService
  def initialize(project, date_params = {})
    @project = project
    @date_params = date_params
  end

  def call
    {
      date: date,
      expenses: expenses,
      expenses_in_month: expenses_in_month,
      all_expenses: all_expenses,
      total_expenses_cents: total_expenses_cents,
      expense_count: expense_count,
      total_participants: total_participants,
      largest_expense: largest_expense,
      unpaid_contributions_count: unpaid_contributions_count,
      project_stats: project_stats
    }
  end

  private

  def date
    @date ||= begin
      if @date_params[:year].present? && @date_params[:month].present?
        y = @date_params[:year].to_i
        m = @date_params[:month].to_i
        (m >= 1 && m <= 12) ? (Date.new(y, m, 1) rescue Date.today) : Date.today
      else
        Date.today
      end
    end
  end

  def month_start
    @month_start ||= date.beginning_of_month
  end

  def month_end
    @month_end ||= date.end_of_month
  end

  def all_expenses
    @all_expenses ||= @project.project_expenses
                              .order(due_on: :asc, created_at: :desc)
                              .includes(expense_contributions: :user)
  end

  def expenses_in_month
    @expenses_in_month ||= @project.project_expenses.where(due_on: month_start..month_end)
  end

  def expenses
    @expenses ||= expenses_in_month.order(due_on: :asc, created_at: :desc).includes(expense_contributions: :user)
  end

  def total_expenses_cents
    @total_expenses_cents ||= expenses_in_month.sum(:total_cents)
  end

  def expense_count
    @expense_count ||= expenses_in_month.count
  end

  def total_participants
    @total_participants ||= @project.participants.count
  end

  def largest_expense
    @largest_expense ||= expenses_in_month.order(total_cents: :desc).first
  end

  def unpaid_contributions_count
    @unpaid_contributions_count ||= ExpenseContribution
      .joins(:project_expense)
      .where(project_expenses: { project_id: @project.id, due_on: month_start..month_end }, paid: false)
      .count
  end

  def project_stats
    @project_stats ||= ProjectStatsCalculator.call(@project, date)
  end
end
