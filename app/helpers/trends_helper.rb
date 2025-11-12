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

  # Savings rate helpers
  def trends_savings_rate
    @trends_stats&.dig(:current_savings_rate) || 0
  end

  def trends_last_month_savings_rate
    @trends_stats&.dig(:last_month_savings_rate) || 0
  end

  def trends_savings_rate_change
    @trends_stats&.dig(:savings_rate_change) || 0
  end

  def trends_three_month_avg_savings_rate
    @trends_stats&.dig(:three_month_avg_savings_rate) || 0
  end

  def trends_savings_rate_trend_direction
    @trends_stats&.dig(:savings_rate_trend_direction) || "stable"
  end

  # Spending rate helpers
  def trends_spending_rate_data
    @trends_stats&.dig(:spending_rate_data) || {}
  end

  def trends_spending_rate
    trends_spending_rate_data[:spending_rate] || 0
  end

  def trends_income_utilization_pct
    trends_spending_rate_data[:income_utilization_pct] || 0
  end

  def trends_days_of_income_remaining
    trends_spending_rate_data[:days_of_income_remaining]
  end

  # Recurring vs discretionary helpers
  def trends_recurring_vs_discretionary
    @trends_stats&.dig(:recurring_vs_discretionary) || {}
  end

  def trends_recurring_total
    trends_recurring_vs_discretionary[:recurring_total] || 0
  end

  def trends_discretionary_total
    trends_recurring_vs_discretionary[:discretionary_total] || 0
  end

  def trends_recurring_pct
    trends_recurring_vs_discretionary[:recurring_pct] || 0
  end

  def trends_discretionary_pct
    trends_recurring_vs_discretionary[:discretionary_pct] || 0
  end

  # Category changes helpers
  def trends_category_changes
    @trends_stats&.dig(:category_changes) || []
  end

  def trends_top_category_increase
    @trends_stats&.dig(:top_category_increase)
  end

  def trends_top_category_decrease
    @trends_stats&.dig(:top_category_decrease)
  end

  # Income stability helpers
  def trends_income_stability
    @trends_stats&.dig(:income_stability_data) || {}
  end

  def trends_income_stability_score
    trends_income_stability[:score] || 100
  end

  def trends_income_stability_message
    trends_income_stability[:message] || "consistent"
  end

  # Quick actions helpers
  def trends_quick_actions
    @trends_stats&.dig(:quick_actions) || []
  end
end
