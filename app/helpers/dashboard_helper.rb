module DashboardHelper
  # Delegate accessor methods for @dashboard_data
  # This keeps views clean and follows Rails conventions

  # Expense statistics
  def expense_total
    @dashboard_data&.dig(:expense_total)
  end

  def expense_count
    @dashboard_data&.dig(:expense_count)
  end

  # Income statistics
  def income_total
    @dashboard_data&.dig(:income_total)
  end

  def income_count
    @dashboard_data&.dig(:income_count)
  end

  # Date and timing
  def current_date
    @dashboard_data&.dig(:current_date)
  end

  # Balance projections
  def end_of_month_balance
    @dashboard_data&.dig(:end_of_month_balance)
  end

  # Top merchants
  def top_expense_merchants
    @dashboard_data&.dig(:top_expense_merchants) || []
  end

  def top_income_merchants
    @dashboard_data&.dig(:top_income_merchants) || []
  end

  # Recent transactions
  def recent_transactions
    @dashboard_data&.dig(:recent_transactions) || []
  end

  # Upcoming recurring transactions
  def upcoming_recurring_expenses
    @dashboard_data&.dig(:upcoming_recurring_expenses) || []
  end

  def upcoming_recurring_income
    @dashboard_data&.dig(:upcoming_recurring_income) || []
  end

  def upcoming_recurring_total
    @dashboard_data&.dig(:upcoming_recurring_total)
  end
end
