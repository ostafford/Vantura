class GoalsController < ApplicationController
  before_action :authenticate_user!

  def index
    @goals = policy_scope(Goal).order(created_at: :desc)
  end

  def create
    @goal = current_user.goals.build(goal_params)
    authorize @goal
    if @goal.save
      redirect_to goals_path, notice: I18n.t("flash.goals.created")
    else
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @goal = current_user.goals.find(params[:id])
    authorize @goal
    if @goal.update(goal_params)
      redirect_to goals_path, notice: I18n.t("flash.goals.updated")
    else
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @goal = current_user.goals.find(params[:id])
    authorize @goal
    @goal.destroy
    redirect_to goals_path, notice: I18n.t("flash.goals.deleted")
  end

  private

  def goal_params
    params.require(:goal).permit(:name, :goal_type, :target_amount_cents, :period, :start_date, :end_date, :active)
  end
end
