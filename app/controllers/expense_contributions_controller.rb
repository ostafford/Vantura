class ExpenseContributionsController < ApplicationController
  before_action :set_project_and_expense
  before_action :authorize_member!

  # Members can only update their own contribution paid state
  def update
    contribution = @expense.expense_contributions.find(params[:id])
    unless contribution.user_id == Current.user.id
      head :forbidden and return
    end

    permitted = params.require(:expense_contribution).permit(:paid)
    paid = ActiveModel::Type::Boolean.new.cast(permitted[:paid])

    if contribution.update(paid: paid, paid_at: paid ? Time.current : nil)
      respond_to do |format|
        format.html { redirect_to project_path(@project), notice: "Updated" }
        format.turbo_stream
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to project_path(@project), alert: contribution.errors.full_messages.join(", ") }
        format.json { render json: { success: false, errors: contribution.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  private
    def set_project_and_expense
      @project = Project.find(params[:project_id])
      @expense = @project.project_expenses.find(params[:expense_id])
    end

    def authorize_member!
      return if @project.owner_id == Current.user.id || @project.members.exists?(id: Current.user.id)
      head :forbidden
    end
end


