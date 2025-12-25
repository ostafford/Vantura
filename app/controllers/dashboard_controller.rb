class DashboardController < ApplicationController
  def index
    @accounts = current_user.accounts.order(:account_type)
    @recent_transactions = current_user.transactions
      .settled
      .recent
      .includes(:account, :categories)
      .order(settled_at: :desc)
      .limit(10)
    
    @total_balance = @accounts.sum(:balance)
    @transaction_count = current_user.transactions.settled.count
    
    @budget_calculator = BudgetCalculator.new(current_user)
    @budgets_summary = @budget_calculator.calculate_all_for_period
    
    # Chart data
    @spending_over_time_data = prepare_spending_over_time_data
    @category_breakdown_data = prepare_category_breakdown_data
    @budget_progress_data = prepare_budget_progress_data
  end

  private

  def prepare_spending_over_time_data
    # Last 12 months of spending
    months = []
    spending = []
    
    12.times do |i|
      date = (11 - i).months.ago
      month_start = date.beginning_of_month
      month_end = date.end_of_month
      
      monthly_spending = current_user.transactions
        .settled
        .where(settled_at: month_start..month_end)
        .where('amount < 0') # Only debits
        .sum('ABS(amount)')
      
      months << date.strftime("%b %Y")
      spending << (monthly_spending / 100.0) # Convert from cents to dollars
    end
    
    {
      labels: months,
      datasets: [{
        label: 'Monthly Spending',
        data: spending,
        borderColor: 'rgb(59, 130, 246)',
        backgroundColor: 'rgba(59, 130, 246, 0.1)',
        tension: 0.4
      }]
    }
  end

  def prepare_category_breakdown_data
    # Current month category spending
    current_month_start = Date.current.beginning_of_month
    current_month_end = Date.current.end_of_month
    
    category_data = current_user.transactions
      .settled
      .where(settled_at: current_month_start..current_month_end)
      .where('amount < 0') # Only debits
      .joins(:categories)
      .group('categories.id', 'categories.name')
      .sum('ABS(transactions.amount)')
      .sort_by { |_, amount| -amount }
      .first(10) # Top 10 categories
    
    return { labels: [], datasets: [{ data: [] }] } if category_data.empty?
    
    labels = category_data.map { |(_, name), _| name }
    data = category_data.map { |_, amount| (amount / 100.0) } # Convert from cents to dollars
    
    # Generate colors for doughnut chart
    colors = generate_chart_colors(category_data.length)
    
    {
      labels: labels,
      datasets: [{
        data: data,
        backgroundColor: colors,
        borderWidth: 2,
        borderColor: '#ffffff'
      }]
    }
  end

  def prepare_budget_progress_data
    active_budgets = current_user.budgets.active.limit(10)
    return { labels: [], datasets: [] } if active_budgets.empty?
    
    budget_names = []
    budget_limits = []
    budget_spent = []
    
    active_budgets.each do |budget|
      calculation = @budget_calculator.calculate_for_period(budget)
      budget_names << budget.name
      budget_limits << (calculation[:limit] / 100.0) # Convert from cents to dollars
      budget_spent << (calculation[:spent] / 100.0) # Convert from cents to dollars
    end
    
    {
      labels: budget_names,
      datasets: [
        {
          label: 'Budget Limit',
          data: budget_limits,
          backgroundColor: 'rgba(59, 130, 246, 0.5)',
          borderColor: 'rgb(59, 130, 246)',
          borderWidth: 1
        },
        {
          label: 'Spent',
          data: budget_spent,
          backgroundColor: 'rgba(239, 68, 68, 0.5)',
          borderColor: 'rgb(239, 68, 68)',
          borderWidth: 1
        }
      ]
    }
  end

  def generate_chart_colors(count)
    base_colors = [
      'rgba(59, 130, 246, 0.8)',   # blue
      'rgba(239, 68, 68, 0.8)',    # red
      'rgba(34, 197, 94, 0.8)',    # green
      'rgba(251, 191, 36, 0.8)',   # yellow
      'rgba(168, 85, 247, 0.8)',   # purple
      'rgba(236, 72, 153, 0.8)',   # pink
      'rgba(20, 184, 166, 0.8)',   # teal
      'rgba(249, 115, 22, 0.8)',   # orange
      'rgba(14, 165, 233, 0.8)',   # sky
      'rgba(139, 92, 246, 0.8)'    # violet
    ]
    
    colors = []
    count.times do |i|
      colors << base_colors[i % base_colors.length]
    end
    colors
  end
end

