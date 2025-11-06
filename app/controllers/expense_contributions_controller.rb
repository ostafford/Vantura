class ExpenseContributionsController < ApplicationController
  before_action :set_contribution_and_relations
  before_action :authorize_member!

  # Members can only update their own contribution paid state
  def update
    return head(:forbidden) unless @contribution.user_id == Current.user.id

    if @contribution.update(contribution_params)
      handle_success_response
    else
      handle_error_response
    end
  end

  private
    # With shallow routes, contribution URL is /contributions/:id
    # We need to find contribution by ID and get project/expense from associations
    def set_contribution_and_relations
      @contribution = ExpenseContribution.find(params[:id])
      @expense = @contribution.project_expense
      @project = @expense.project
    end

    def authorize_member!
      return if @project.owner_id == Current.user.id || @project.members.exists?(id: Current.user.id)
      head :forbidden
    end

    def contribution_params
      permitted = params.fetch(:expense_contribution, {}).permit(:paid)
      paid = ActiveModel::Type::Boolean.new.cast(permitted[:paid])
      { paid: paid, paid_at: paid ? Time.current : nil }
    end

    def handle_success_response
      respond_to do |format|
        format.html { redirect_to project_path(@project), notice: "Updated" }
        format.json { render json: { success: true } }
      end
    end

    def handle_error_response
      respond_to do |format|
        format.html { redirect_to project_path(@project), alert: @contribution.errors.full_messages.join(", ") }
        format.json { render json: { success: false, errors: @contribution.errors.full_messages }, status: :unprocessable_entity }
      end
    end
end
