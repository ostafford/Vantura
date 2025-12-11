class ExpenseContributionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_expense_contribution

  def mark_paid
    authorize @expense_contribution.project_expense

    if @expense_contribution.update(status: "paid", paid_at: Time.current)
      # Broadcast Turbo Stream updates to project channel
      broadcast_project_updates(@expense_contribution.project_expense.project)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to [ @expense_contribution.project_expense.project, @expense_contribution.project_expense ], notice: I18n.t("flash.expense_contributions.marked_paid") }
      end
    else
      respond_to do |format|
        format.turbo_stream { render status: :unprocessable_entity }
        format.html { redirect_to [ @expense_contribution.project_expense.project, @expense_contribution.project_expense ], alert: I18n.t("flash.expense_contributions.mark_paid_failed") }
      end
    end
  end

  private

  def set_expense_contribution
    @expense_contribution = ExpenseContribution.find(params[:id])
  end

  def broadcast_project_updates(project)
    # Broadcast update to expense list
    Turbo::StreamsChannel.broadcast_replace_to(
      "project_#{project.id}",
      target: "project-#{project.id}-expenses",
      partial: "project_expenses/list",
      locals: { project: project, project_expenses: project.project_expenses.includes(:category, :paid_by_user, :expense_contributions).order(expense_date: :desc, created_at: :desc) }
    )

    # Broadcast update to summary stats
    Turbo::StreamsChannel.broadcast_replace_to(
      "project_#{project.id}",
      target: "project-#{project.id}-summary",
      partial: "projects/summary",
      locals: { project: project }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast project updates: #{e.message}"
  end
end

