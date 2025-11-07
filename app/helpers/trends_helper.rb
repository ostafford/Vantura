module TrendsHelper
  # Delegate accessor methods for @trends_stats
  # This keeps views clean and follows Rails conventions

  def trends_current_date
    @trends_stats&.dig(:current_date) || Date.today
  end

  def trends_current_month_income
    @trends_stats&.dig(:current_month_income) || 0
  end

  def trends_current_month_expenses
    @trends_stats&.dig(:current_month_expenses) || 0
  end

  def trends_net_savings
    @trends_stats&.dig(:net_savings) || 0
  end

  def trends_last_month_income
    @trends_stats&.dig(:last_month_income) || 0
  end

  def trends_last_month_expenses
    @trends_stats&.dig(:last_month_expenses) || 0
  end

  def trends_income_change_pct
    @trends_stats&.dig(:income_change_pct) || 0
  end

  def trends_expense_change_pct
    @trends_stats&.dig(:expense_change_pct) || 0
  end

  def trends_net_change_pct
    @trends_stats&.dig(:net_change_pct) || 0
  end

  def trends_active_recurring_count
    @trends_stats&.dig(:active_recurring_count) || 0
  end

  def trends_top_merchant
    @trends_stats&.dig(:top_merchant) || { name: "No transactions", amount: 0.0 }
  end

  def trends_historical_data
    @trends_stats&.dig(:historical_data) || []
  end

  def trends_category_breakdown
    @trends_stats&.dig(:category_breakdown) || []
  end

  def trends_savings_rate_trend
    @trends_stats&.dig(:savings_rate_trend) || []
  end

  def trends_year_over_year
    @trends_stats&.dig(:year_over_year_comparison) || {}
  end
end

