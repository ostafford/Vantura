class ProjectExpensesController < ApplicationController
  before_action :set_project
  before_action :authorize_member!
  before_action :authorize_owner!, only: [:new, :create, :edit, :update, :destroy]
  before_action :set_expense, only: [:edit, :update, :destroy]

  def new
    @expense = @project.project_expenses.new
  end

  def create
    @expense = @project.project_expenses.new(expense_params)
    if @expense.save
      @expense.rebuild_contributions!
      redirect_to project_path(@project), notice: "Expense added"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @expense.update(expense_params)
      @expense.rebuild_contributions!
      redirect_to project_path(@project), notice: "Expense updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @expense.destroy
    redirect_to project_path(@project), notice: "Expense deleted"
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
end


