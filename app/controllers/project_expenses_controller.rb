class ProjectExpensesController < ApplicationController
  before_action :set_project
  before_action :authorize_member!
  before_action :authorize_owner_or_editor!, only: [ :new, :create, :edit, :update, :destroy ]
  before_action :set_expense, only: [ :edit, :update, :destroy ]

  def new
    @expense = @project.project_expenses.new
  end

  def create
    @expense = @project.project_expenses.new(expense_params)
    if @expense.save
      contributor_ids = params[:contributor_user_ids].presence || @project.participants.pluck(:id)
      @expense.rebuild_contributions_for_participants!(contributor_ids) && assign_projects_index_stats
      respond_to { |format| format.turbo_stream { redirect_to project_path(@project), status: :see_other if should_redirect_to_project? }; format.html { redirect_to project_path(@project), notice: "Expense added" } }
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @expense.update(expense_params)
      contributor_ids = params[:contributor_user_ids].presence || @project.participants.pluck(:id)
      @expense.rebuild_contributions_for_participants!(contributor_ids)
      respond_to { |format| format.turbo_stream { redirect_to project_path(@project), notice: "Expense updated successfully!" }; format.html { redirect_to project_path(@project), notice: "Expense updated" } }
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @expense.destroy
    assign_projects_index_stats
    respond_to { |format| format.turbo_stream { redirect_to project_path(@project), status: :see_other if should_redirect_to_project? }; format.html { redirect_to project_path(@project), notice: "Expense deleted" } }
  end

  def templates
    templates = ProjectExpenseTemplatesService.call(@project, search_term: params[:q])
    render json: templates
  end

  private
    def set_project
      # For nested routes (index, new, create), project_id is in params
      # For shallow routes (show, edit, update, destroy), get project from expense
      if params[:project_id]
        @project = Project.find(params[:project_id])
      elsif params[:id]
        @expense = ProjectExpense.find(params[:id])
        @project = @expense.project
      end
    end

    def set_expense
      # For nested routes, find expense within project scope
      # For shallow routes, find expense directly by ID
      if params[:project_id]
        @expense = @project.project_expenses.find(params[:id])
      else
        @expense = ProjectExpense.find(params[:id])
        @project ||= @expense.project
      end
    end

    def authorize_member!
      return if @project.owner_id == Current.user.id || @project.members.exists?(id: Current.user.id)
      head :forbidden
    end

    def authorize_owner_or_editor!
      return if @project.owner_id == Current.user.id
      if @project.project_memberships.where(user_id: Current.user.id, access_level: ProjectMembership.access_levels[:full]).exists?
        return
      end
      head :forbidden
    end

    def expense_params
      permitted = params.require(:project_expense).permit(:merchant, :category, :total_dollars, :due_on, :notes)

      # Convert dollars to cents if total_dollars is provided and not blank
      # Always remove total_dollars from permitted params since model doesn't have this attribute
      if permitted.key?(:total_dollars)
        if permitted[:total_dollars].present? && permitted[:total_dollars].to_s.strip.present?
          dollars = permitted[:total_dollars].to_f
          permitted[:total_cents] = (dollars * 100).round.to_i
        end
        permitted.delete(:total_dollars)
      end

      permitted
    end

    def referer_path
      @referer_path ||= begin
        request.referer.present? ? URI.parse(request.referer).path : nil
      rescue
        nil
      end
    end

    def should_redirect_to_project?
      referer_path != projects_path && referer_path != "/projects"
    end

    def assign_projects_index_stats
      stats = ProjectsIndexStatisticsService.call(Current.user)
      @projects, @total_projects, @total_expenses_cents, @total_expenses, @total_participants, @active_projects, @largest_expense, @most_active_project = stats.values_at(:projects, :total_projects, :total_expenses_cents, :total_expenses, :total_participants, :active_projects, :largest_expense, :most_active_project)
    end
end
