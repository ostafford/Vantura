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
        @project_expense.split_evenly_among_members
      end
      redirect_to [ @project, @project_expense ], notice: I18n.t("flash.project_expenses.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @project_expense
  end

  def update
    authorize @project_expense
    if @project_expense.update(project_expense_params)
      redirect_to [ @project, @project_expense ], notice: I18n.t("flash.project_expenses.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @project_expense
    @project_expense.destroy
    redirect_to project_project_expenses_path(@project), notice: I18n.t("flash.project_expenses.deleted")
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
end
