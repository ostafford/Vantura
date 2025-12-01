class GoalsController < ApplicationController
  before_action :authenticate_user!

  def index
    @goals = current_user.goals.order(created_at: :desc)
  end

  def create
    @goal = current_user.goals.build(goal_params)
    if @goal.save
      redirect_to goals_path, notice: "Goal created successfully"
    else
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @goal = current_user.goals.find(params[:id])
    if @goal.update(goal_params)
      redirect_to goals_path, notice: "Goal updated successfully"
    else
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @goal = current_user.goals.find(params[:id])
    @goal.destroy
    redirect_to goals_path, notice: "Goal deleted successfully"
  end

  private

  def goal_params
    params.require(:goal).permit(:name, :goal_type, :target_amount_cents, :period, :start_date, :end_date, :active)
  end
end

