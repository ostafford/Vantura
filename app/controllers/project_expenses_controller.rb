class ProjectExpensesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project
  before_action :set_project_expense, only: [ :show, :edit, :update, :destroy ]

  def index
    # Authorize access to the project first
    authorize @project, :show?
    @project_expenses = policy_scope(@project.project_expenses)
                                .includes(:category, :paid_by_user, :expense_contributions)
                                .order(expense_date: :desc, created_at: :desc)
  end

  def show
    authorize @project_expense
  end

  def new
    @project_expense = @project.project_expenses.build
    @project_expense.expense_date = Date.current
    authorize @project_expense
  end

  def create
    @project_expense = @project.project_expenses.build(project_expense_params)
    @project_expense.paid_by_user ||= current_user
    authorize @project_expense

    if @project_expense.save
      # Split evenly if requested, otherwise contributions come from nested attributes
      if params[:split_evenly] == "true"
        # Clear any existing contributions from nested attributes before splitting evenly
        @project_expense.expense_contributions.destroy_all
        @project_expense.split_evenly_among_members
      end

      # Broadcast Turbo Stream updates
      broadcast_project_updates(@project)

      # If request is from modal (Turbo Frame), return Turbo Stream response
      if request.headers["Turbo-Frame"] == "project-expense-form"
        respond_to do |format|
          format.turbo_stream
        end
      else
        redirect_to [ @project, @project_expense ], notice: I18n.t("flash.project_expenses.created")
      end
    else
      # Render form with errors within Turbo Frame for inline validation
      if request.headers["Turbo-Frame"] == "project-expense-form"
        render :new, status: :unprocessable_entity
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def edit
    authorize @project_expense
  end

  def update
    authorize @project_expense
    if @project_expense.update(project_expense_params)
      # Broadcast Turbo Stream updates
      broadcast_project_updates(@project)

      # If request is from modal (Turbo Frame), return Turbo Stream response
      if request.headers["Turbo-Frame"] == "project-expense-form"
        respond_to do |format|
          format.turbo_stream
        end
      else
        redirect_to [ @project, @project_expense ], notice: I18n.t("flash.project_expenses.updated")
      end
    else
      # Render form with errors within Turbo Frame for inline validation
      if request.headers["Turbo-Frame"] == "project-expense-form"
        render :edit, status: :unprocessable_entity
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    authorize @project_expense
    @project_expense.destroy

    # Broadcast Turbo Stream updates
    broadcast_project_updates(@project)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_project_expenses_path(@project), notice: I18n.t("flash.project_expenses.deleted") }
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_project_expense
    @project_expense = @project.project_expenses.find(params[:id])
  end

  def project_expense_params
    params.require(:project_expense).permit(
      :name,
      :description,
      :total_amount_cents,
      :total_amount_currency,
      :expense_date,
      :category_id,
      :paid_by_user_id,
      :transaction_id,
      expense_contributions_attributes: [ :id, :user_id, :amount_cents, :amount_currency, :note, :_destroy ]
    )
  end

  def broadcast_project_updates(project)
    # Reload project to get updated expenses
    project.reload

    # Get all project members (for broadcasting to all)
    all_members = (project.members + [ project.owner ]).uniq

    # Broadcast update to expense list
    project_expenses = project.project_expenses
                              .includes(:category, :paid_by_user, :expense_contributions)
                              .order(expense_date: :desc, created_at: :desc)

    Turbo::StreamsChannel.broadcast_replace_to(
      "project_#{project.id}",
      target: "project-#{project.id}-expenses",
      partial: "project_expenses/list",
      locals: { project: project, project_expenses: project_expenses, current_user: current_user }
    )

    # Broadcast update to summary stats
    Turbo::StreamsChannel.broadcast_replace_to(
      "project_#{project.id}",
      target: "project-#{project.id}-summary",
      partial: "projects/summary",
      locals: { project: project, current_user: current_user }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast project updates: #{e.message}"
  end
end
