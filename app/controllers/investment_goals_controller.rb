class InvestmentGoalsController < ApplicationController
  before_action :set_investment_goal, only: [:show, :edit, :update, :destroy, :toggle_active]

  def index
    @investment_goals = current_user.investment_goals.order(:name)
    @tracker = InvestmentTracker.new(current_user)
    @tracker.update_investment_goals
  end

  def show
    @tracker = InvestmentTracker.new(current_user)
    @progress = @tracker.calculate_goal_progress(@investment_goal)
    
    if @investment_goal.account
      @growth_data = @tracker.track_savings_growth(@investment_goal.account)
      @chart_data = prepare_chart_data(@growth_data) if @growth_data
      @chart_options = prepare_chart_options
    end
  end

  def new
    @investment_goal = current_user.investment_goals.build
    @accounts = current_user.accounts.saver
  end

  def create
    @investment_goal = current_user.investment_goals.build(investment_goal_params)

    if @investment_goal.save
      redirect_to investment_goals_path, notice: "Investment goal created successfully"
    else
      @accounts = current_user.accounts.saver
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @accounts = current_user.accounts.saver
  end

  def update
    if @investment_goal.update(investment_goal_params)
      redirect_to investment_goals_path, notice: "Investment goal updated successfully"
    else
      @accounts = current_user.accounts.saver
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @investment_goal.destroy
    redirect_to investment_goals_path, notice: "Investment goal deleted successfully"
  end

  def toggle_active
    @investment_goal.update(active: !@investment_goal.active)
    redirect_to investment_goals_path, notice: "Investment goal #{@investment_goal.active? ? 'activated' : 'deactivated'}"
  end

  private

  def set_investment_goal
    @investment_goal = current_user.investment_goals.find(params[:id])
  end

  def investment_goal_params
    params.require(:investment_goal).permit(
      :name,
      :description,
      :target_amount,
      :account_id,
      :target_date,
      :active
    )
  end

  def prepare_chart_data(growth_data)
    history = growth_data[:history] || []
    
    labels = history.map { |h| h[:date].strftime("%b %d, %Y") }
    balances = history.map { |h| h[:balance].to_f }
    
    {
      labels: labels,
      datasets: [
        {
          label: "Balance (AUD)",
          data: balances,
          borderColor: "rgb(59, 130, 246)",
          backgroundColor: "rgba(59, 130, 246, 0.1)",
          tension: 0.4,
          fill: true
        }
      ]
    }
  end

  def prepare_chart_options
    {
      responsive: true,
      maintainAspectRatio: true,
      scales: {
        y: {
          beginAtZero: false
        }
      },
      plugins: {
        legend: {
          display: true
        }
      }
    }
  end
end

