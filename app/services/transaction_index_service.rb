# Service Object: Prepare all data needed for transactions index page
#
# Usage:
#   data = TransactionIndexService.call(@account, filter_type, date_params)
#   data = TransactionIndexService.call(@account, "all", { year: 2024, month: 10 })
#
# Returns hash with:
#   - transactions: Filtered and date-range transactions
#   - date: Parsed date from params or today
#   - year: Year for the date
#   - month: Month for the date
#   - filter_type: The filter type used
#   - expense_total: Total expenses
#   - income_total: Total income
#   - expense_count: Count of expenses
#   - income_count: Count of income transactions
#   - net_cash_flow: Income - Expenses
#   - transaction_count: Total transaction count
#   - top_category: Category with highest total
#   - top_category_amount: Amount for top category
#   - top_expense_merchants: Top 3 expense merchants
#   - top_income_merchants: Top 3 income merchants
#   - last_month_stats: Comparison data from previous month
#   - three_month_average: 3-month average expenses/income
#   - category_breakdown: Top 3-5 categories with percentages
#   - largest_transaction: Largest single transaction
#   - savings_rate: (income - expenses) / income
#   - projected_month_end: Projected totals if current month
#   - transaction_velocity: Daily average transactions
#   - week_over_week: Week-over-week comparison
#
class TransactionIndexService < ApplicationService
  def initialize(account, filter_type, date_params = {})
    @account = account
    @filter_type = filter_type || "all"
    @date_params = date_params
  end

  def call
    {
      transactions: transactions,
      date: date,
      year: year,
      month: month,
      filter_type: @filter_type,
      expense_total: stats[:expense_total],
      income_total: stats[:income_total],
      expense_count: stats[:expense_count],
      income_count: stats[:income_count],
      net_cash_flow: stats[:net_cash_flow],
      transaction_count: stats[:transaction_count],
      top_category: stats[:top_category],
      top_category_amount: stats[:top_category_amount],
      top_expense_merchants: top_expense_merchants,
      top_income_merchants: top_income_merchants,
      last_month_stats: last_month_stats,
      three_month_average: three_month_average,
      category_breakdown: stats[:category_breakdown],
      largest_transaction: largest_transaction,
      savings_rate: savings_rate,
      projected_month_end: projected_month_end,
      transaction_velocity: transaction_velocity,
      week_over_week: week_over_week
    }
  end

  private

  def date
    @date ||= begin
      if @date_params[:year].present? && @date_params[:month].present?
        y = @date_params[:year].to_i
        m = @date_params[:month].to_i
        # Validate date values are reasonable
        if y > 0 && m.between?(1, 12)
          Date.new(y, m, 1)
        else
          Date.today
        end
      else
        Date.today
      end
    rescue ArgumentError
      # Handle invalid dates gracefully
      Date.today
    end
  end

  def year
    @year ||= date.year
  end

  def month
    @month ||= date.month
  end

  def start_date
    @start_date ||= begin
      if @date_params[:start_date].present?
        Date.parse(@date_params[:start_date])
      else
        date.beginning_of_month
      end
    rescue ArgumentError
      date.beginning_of_month
    end
  end

  def end_date
    @end_date ||= begin
      if @date_params[:end_date].present?
        Date.parse(@date_params[:end_date])
      else
        date.end_of_month
      end
    rescue ArgumentError
      date.end_of_month
    end
  end

  def filtered_transactions
    @filtered_transactions ||= case @filter_type
    when "expenses"
                                 @account.transactions.expenses
    when "income"
                                 @account.transactions.income
    when "hypothetical"
                                 @account.transactions.hypothetical
    else
                                 @account.transactions
    end
  end

  def transactions
    @transactions ||= begin
      base = filtered_transactions.includes(:recurring_transaction)

      # Use in_date_range scope if date range is provided, otherwise use month range
      if @date_params[:start_date].present? && @date_params[:end_date].present?
        base.in_date_range(start_date, end_date).order(transaction_date: :desc)
      else
        base.where(transaction_date: start_date..end_date).order(transaction_date: :desc)
      end
    end
  end

  def stats
    @stats ||= TransactionStatsCalculator.call(@account, start_date, end_date)
  end

  def top_expense_merchants
    @top_expense_merchants ||= TransactionMerchantService.call(
      @account,
      "expense",
      start_date,
      end_date,
      limit: 3
    )
  end

  def top_income_merchants
    @top_income_merchants ||= TransactionMerchantService.call(
      @account,
      "income",
      start_date,
      end_date,
      limit: 3
    )
  end

  def last_month_stats
    @last_month_stats ||= begin
      last_month_date = date.prev_month
      last_start = last_month_date.beginning_of_month
      last_end = last_month_date.end_of_month
      TransactionStatsCalculator.call(@account, last_start, last_end)
    end
  end

  def three_month_average
    @three_month_average ||= begin
      three_months_ago = date - 2.months
      three_months_start = three_months_ago.beginning_of_month
      three_months_end = date.end_of_month

      transactions = @account.transactions.where(transaction_date: three_months_start..three_months_end)
      expense_total = transactions.expenses.sum(:amount).abs
      income_total = transactions.income.sum(:amount)
      expense_count = transactions.expenses.count
      income_count = transactions.income.count
      transaction_count = transactions.count

      # Calculate number of months (handle partial months)
      months_count = ((three_months_end - three_months_start).to_f / 30.0).ceil
      months_count = [ months_count, 1 ].max # At least 1 month

      {
        expense_total: (expense_total / months_count).round(2),
        income_total: (income_total / months_count).round(2),
        expense_count: (expense_count.to_f / months_count).round(1),
        income_count: (income_count.to_f / months_count).round(1),
        transaction_count: (transaction_count.to_f / months_count).round(1)
      }
    end
  end

  def largest_transaction
    @largest_transaction ||= transactions.max_by { |t| t.amount.abs }
  end

  def savings_rate
    return 0 if stats[:income_total].zero?
    ((stats[:net_cash_flow] / stats[:income_total]) * 100).round(1)
  end

  def projected_month_end
    return nil unless is_current_month?

    days_elapsed = Date.today.day
    days_in_month = date.end_of_month.day
    return nil if days_elapsed.zero?

    {
      expense_total: (stats[:expense_total] / days_elapsed * days_in_month).round(2),
      income_total: (stats[:income_total] / days_elapsed * days_in_month).round(2),
      transaction_count: (stats[:transaction_count].to_f / days_elapsed * days_in_month).round(0)
    }
  end

  def transaction_velocity
    days_elapsed = if is_current_month?
      Date.today.day
    else
      (end_date - start_date).to_i + 1
    end
    days_elapsed = [ days_elapsed, 1 ].max # At least 1 day

    {
      daily_average: (stats[:transaction_count].to_f / days_elapsed).round(2),
      days_elapsed: days_elapsed
    }
  end

  def week_over_week
    return nil unless is_current_month?

    # Current week (last 7 days)
    current_week_start = [ Date.today - 6.days, start_date ].max
    current_week_end = Date.today

    # Previous week (7 days before current week)
    prev_week_end = current_week_start - 1.day
    prev_week_start = prev_week_end - 6.days

    current_week_transactions = @account.transactions.where(transaction_date: current_week_start..current_week_end)
    prev_week_transactions = @account.transactions.where(transaction_date: prev_week_start..prev_week_end)

    current_expenses = current_week_transactions.expenses.sum(:amount).abs
    prev_expenses = prev_week_transactions.expenses.sum(:amount).abs

    {
      current_week_expenses: current_expenses,
      previous_week_expenses: prev_expenses,
      change: current_expenses - prev_expenses,
      change_pct: prev_expenses.positive? ? ((current_expenses - prev_expenses) / prev_expenses * 100).round(1) : 0
    }
  end

  def is_current_month?
    date.year == Date.today.year && date.month == Date.today.month
  end
end
