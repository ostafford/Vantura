class CalendarStatsCalculator < ApplicationService
  # Calculate all calendar statistics for a given account, date range, and view type
  # @param account [Account] The account to calculate stats for
  # @param date [Date] The current date being viewed
  # @param start_date [Date] Start of the date range
  # @param end_date [Date] End of the date range
  # @param view [String] 'week' or 'month' view type
  # @return [Hash] Hash containing all calendar statistics
  def initialize(account, date, start_date, end_date, view)
    @account = account
    @date = date
    @start_date = start_date
    @end_date = end_date
    @view = view
  end

  def call
    {
      # Hypothetical transaction stats
      hypothetical_income: hypothetical_income,
      hypothetical_expenses: hypothetical_expenses,

      # Actual transaction stats
      actual_income: actual_income,
      actual_expenses: actual_expenses,
      transaction_count: transaction_count,

      # Month progress stats
      month_day: month_day,
      total_days: total_days,
      progress_pct: progress_pct,

      # View-specific stats
      week_income: week_income,
      week_expenses: week_expenses,
      week_transaction_count: week_transaction_count,
      week_total: week_total,

      # Counts for views
      week_expense_count: week_expense_count,
      week_income_count: week_income_count,
      month_expense_count: month_expense_count,
      month_income_count: month_income_count,

      # Top merchants (week or month depending on view)
      top_expense_merchants: top_expense_merchants,
      top_income_merchants: top_income_merchants
    }
  end

  private

  # Get hypothetical transactions for the period
  def hypothetical_transactions
    @hypothetical_transactions ||= @account.transactions
                                            .where(transaction_date: @start_date..@end_date)
                                            .where(is_hypothetical: true)
  end

  def hypothetical_income
    hypothetical_transactions.where("amount > 0").sum(:amount)
  end

  def hypothetical_expenses
    hypothetical_transactions.where("amount < 0").sum(:amount).abs
  end

  # Get actual (non-hypothetical) transactions for the period
  def actual_transactions
    @actual_transactions ||= @account.transactions
                                     .where(transaction_date: @start_date..@end_date)
                                     .where(is_hypothetical: false)
  end

  def actual_income
    actual_transactions.where("amount > 0").sum(:amount)
  end

  def actual_expenses
    actual_transactions.where("amount < 0").sum(:amount).abs
  end

  def transaction_count
    actual_transactions.count
  end

  # Month progress calculations
  def month_day
    @date.day
  end

  def total_days
    @date.end_of_month.day
  end

  def progress_pct
    ((month_day.to_f / total_days.to_f) * 100).round
  end

  # Week-specific calculations
  def week_transactions
    @week_transactions ||= begin
      week_start = @date.beginning_of_week(:monday)
      week_end = @date.end_of_week(:monday)
      @account.transactions.where(transaction_date: week_start..week_end)
    end
  end

  def week_income
    return 0 unless @view == "week"
    week_transactions.where("amount > 0").sum(:amount)
  end

  def week_expenses
    return 0 unless @view == "week"
    week_transactions.where("amount < 0").sum(:amount).abs
  end

  def week_transaction_count
    return 0 unless @view == "week"
    week_transactions.count
  end

  def week_total
    return 0 unless @view == "week"
    week_transactions.sum(:amount)
  end

  # Counts for week view
  def week_expense_count
    return 0 unless @view == "week"
    week_transactions.where("amount < 0").count
  end

  def week_income_count
    return 0 unless @view == "week"
    week_transactions.where("amount > 0").count
  end

  # Counts for month view
  def month_expense_count
    actual_transactions.where("amount < 0").count
  end

  def month_income_count
    actual_transactions.where("amount > 0").count
  end

  # Top merchants calculation
  def top_merchants_date_range
    if @view == "week"
      [ @date.beginning_of_week(:monday), @date.end_of_week(:monday) ]
    else
      [ @start_date, @end_date ]
    end
  end

  def top_expense_merchants
    start_date, end_date = top_merchants_date_range
    Transaction.top_merchants_by_type(
      "expense",
      account: @account,
      start_date: start_date,
      end_date: end_date,
      limit: 3
    )
  end

  def top_income_merchants
    start_date, end_date = top_merchants_date_range
    Transaction.top_merchants_by_type(
      "income",
      account: @account,
      start_date: start_date,
      end_date: end_date,
      limit: 3
    )
  end
end
