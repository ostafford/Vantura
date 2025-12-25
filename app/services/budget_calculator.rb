class BudgetCalculator
  def initialize(user)
    @user = user
  end

  def calculate_for_period(budget, date = Date.current)
    period_start = calculate_period_start(budget.period, date)
    period_end = calculate_period_end(budget.period, date)
    
    transactions = fetch_budget_transactions(budget, period_start, period_end)
    spent = calculate_spent(transactions)
    
    {
      budget: budget,
      period_start: period_start,
      period_end: period_end,
      limit: budget.amount,
      spent: spent,
      remaining: budget.amount - spent,
      percentage: calculate_percentage(spent, budget.amount),
      alert_threshold: budget.alert_threshold,
      alert_triggered: spent >= (budget.amount * budget.alert_threshold / 100),
      transactions_count: transactions.count
    }
  end

  def calculate_all_for_period(date = Date.current)
    @user.budgets.active.map do |budget|
      calculate_for_period(budget, date)
    end
  end

  def calculate_spending_by_category(date = Date.current)
    period_start = date.beginning_of_month
    period_end = date.end_of_month
    
    @user.transactions
      .settled
      .where(settled_at: period_start..period_end)
      .joins(:categories)
      .group('categories.id', 'categories.name')
      .sum('ABS(transactions.amount)')
      .map do |(category_id, category_name), amount|
        {
          category_id: category_id,
          category_name: category_name,
          amount: amount
        }
      end
  end

  private

  def fetch_budget_transactions(budget, start_date, end_date)
    transactions = @user.transactions
      .settled
      .where(settled_at: start_date..end_date)
    
    if budget.category_id
      transactions = transactions.by_category(budget.category_id)
    end
    
    transactions
  end

  def calculate_spent(transactions)
    # Use SQL aggregation for efficiency (matching Budget model approach)
    transactions.sum('ABS(amount)')
  end

  def calculate_percentage(spent, limit)
    return 0 if limit.zero?
    (spent / limit * 100).round(2)
  end

  def calculate_period_start(period, date)
    case period
    when 'monthly' then date.beginning_of_month
    when 'weekly' then date.beginning_of_week
    when 'yearly' then date.beginning_of_year
    else date.beginning_of_month
    end
  end

  def calculate_period_end(period, date)
    case period
    when 'monthly' then date.end_of_month
    when 'weekly' then date.end_of_week
    when 'yearly' then date.end_of_year
    else date.end_of_month
    end
  end
end

