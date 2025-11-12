module AccountsHelper
  # Calculate and return account statistics for display
  # Returns a hash with month_stats, all_time_count, and active_recurring_count
  def account_statistics(account)
    # Calculate statistics for this month
    start_date = Date.today.beginning_of_month
    end_date = Date.today.end_of_month
    month_stats = TransactionStatsCalculator.call(account, start_date, end_date)

    # Get all-time transaction count
    all_time_count = account.transactions.count

    # Get active recurring transactions count
    active_recurring_count = account.recurring_transactions.where(is_active: true).count

    {
      month_stats: month_stats,
      all_time_count: all_time_count,
      active_recurring_count: active_recurring_count
    }
  end

  def account_goal_mode(account)
    amount = account.target_savings_amount
    rate = account.target_savings_rate

    return :amount if amount.present? && amount.positive?
    return :rate if rate.present? && rate.positive?

    :break_even
  end

  def account_goal_rate_percentage(account)
    rate = account.target_savings_rate || 0
    (rate * 100).round(1)
  end

  def account_goal_summary(account)
    case account_goal_mode(account)
    when :amount
      amount = number_to_currency(account.target_savings_amount || 0, precision: 0)
      "Save #{amount} per month"
    when :rate
      percentage = number_with_precision(
        account_goal_rate_percentage(account),
        precision: 1,
        strip_insignificant_zeros: true
      )
      "Save #{percentage}% of monthly income"
    else
      "Aim to break even each month"
    end
  end

  def account_goal_last_updated(account)
    return "Goal not set yet" if account.goal_last_set_at.blank?

    "Updated #{time_ago_in_words(account.goal_last_set_at)} ago"
  end
end
