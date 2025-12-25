class InvestmentTracker
  def initialize(user)
    @user = user
  end

  def track_savings_growth(account, months: 12)
    end_date = Date.current
    start_date = months.months.ago
    
    # Get all transactions in period
    transactions = account.transactions
      .settled
      .where('settled_at >= ?', start_date)
      .order(:settled_at)
    
    # Calculate balance history
    balance_history = calculate_balance_history(account, transactions, start_date)
    
    # Calculate statistics
    start_balance = balance_history.first&.dig(:balance) || account.balance
    end_balance = account.balance
    growth = end_balance - start_balance
    growth_percentage = start_balance > 0 ? (growth / start_balance * 100) : 0
    
    {
      account: account,
      start_date: start_date,
      end_date: end_date,
      start_balance: start_balance,
      end_balance: end_balance,
      growth: growth,
      growth_percentage: growth_percentage.round(2),
      history: balance_history,
      monthly_average: calculate_monthly_average(balance_history)
    }
  end

  def update_investment_goals
    @user.investment_goals.active.each do |goal|
      if goal.account_id
        account = @user.accounts.find_by(id: goal.account_id)
        if account
          goal.update(current_amount: account.balance)
        end
      end
    end
  end

  def calculate_goal_progress(goal)
    return nil unless goal.account_id

    account = @user.accounts.find_by(id: goal.account_id)
    return nil unless account

    current = account.balance
    target = goal.target_amount
    progress = target > 0 ? (current / target * 100) : 0

    {
      goal: goal,
      current: current,
      target: target,
      remaining: [target - current, 0].max,
      progress: progress.round(2),
      on_track: calculate_on_track(goal, current)
    }
  end

  private

  def calculate_balance_history(account, transactions, start_date)
    # Start with current balance and work backwards
    running_balance = account.balance
    history = []
    
    # Process transactions in reverse chronological order
    transactions.reverse.each do |transaction|
      # Subtract transaction amount to get previous balance
      running_balance -= transaction.amount
      
      history.unshift({
        date: transaction.settled_at.to_date,
        balance: running_balance,
        change: transaction.amount,
        transaction_id: transaction.id
      })
    end
    
    # Add starting point if no transactions
    if history.empty?
      history << {
        date: start_date,
        balance: account.balance,
        change: 0,
        transaction_id: nil
      }
    end
    
    history
  end

  def calculate_monthly_average(history)
    return 0 if history.empty?
    
    monthly_balances = history.group_by { |h| h[:date].beginning_of_month }
      .map { |month, entries| entries.last[:balance] }
    
    monthly_balances.sum / monthly_balances.size
  end

  def calculate_on_track(goal, current)
    return false unless goal.target_date
    
    days_elapsed = (Date.current - goal.created_at.to_date).to_i
    days_total = (goal.target_date - goal.created_at.to_date).to_i
    
    return false if days_total <= 0
    
    expected_progress = (days_elapsed.to_f / days_total * 100)
    actual_progress = (current / goal.target_amount * 100)
    
    actual_progress >= expected_progress * 0.9  # 90% of expected
  end
end

