class BudgetsController < ApplicationController
  before_action :set_budget, only: [:show, :edit, :update, :destroy, :toggle_active]

  def index
    @budgets = current_user.budgets.order(:name)
    @budget_calculator = BudgetCalculator.new(current_user)
    @budgets_summary = @budget_calculator.calculate_all_for_period
    @categories = Category.order(:name)
    @budget = current_user.budgets.build
  end

  def show
    @budget_calculator = BudgetCalculator.new(current_user)
    @calculation = @budget_calculator.calculate_for_period(@budget)
  end

  def new
    @budget = current_user.budgets.build
    @categories = Category.order(:name)
  end

  def create
    @budget = current_user.budgets.build(budget_params)
    @categories = Category.order(:name)

    if @budget.save
      redirect_to budgets_path, notice: "Budget created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @categories = Category.order(:name)
  end

  def update
    @categories = Category.order(:name)
    
    if @budget.update(budget_params)
      redirect_to budgets_path, notice: "Budget updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @budget.destroy
    redirect_to budgets_path, notice: "Budget deleted successfully"
  end

  def toggle_active
    @budget.update(active: !@budget.active)
    redirect_to budgets_path, notice: "Budget #{@budget.active? ? 'activated' : 'deactivated'}"
  end

  private

  def set_budget
    @budget = current_user.budgets.find(params[:id])
  end

  def budget_params
    params.require(:budget).permit(
      :name,
      :amount,
      :period,
      :category_id,
      :start_date,
      :end_date,
      :alert_threshold,
      :active
    )
  end
end

