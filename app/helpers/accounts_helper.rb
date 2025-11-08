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
end
