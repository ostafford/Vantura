class DashboardStatsCalculator < ApplicationService
  # Calculate all dashboard statistics for a given account and date
  # @param account [Account] The account to calculate stats for
  # @param date [Date] The date to calculate stats for (defaults to today)
  # @return [Hash] Hash containing all dashboard statistics
  def initialize(account, date = Date.today)
    @account = account
    @date = date
  end

  def call
    {
      current_date: @date,
      recent_transactions: recent_transactions,
      expense_count: expense_count,
      expense_total: expense_total,
      income_count: income_count,
      income_total: income_total,
      projected_expense_count: projected_expense_count,
      projected_expense_total: projected_expense_total,
      projected_income_count: projected_income_count,
      projected_income_total: projected_income_total,
      end_of_month_balance: end_of_month_balance,
      top_expense_merchants: top_expense_merchants,
      top_income_merchants: top_income_merchants,
      top_expense_categories: top_expense_categories,
      top_income_categories: top_income_categories,
      balance_at_month_start: balance_at_month_start,
      balance_change_since_month_start: balance_change_since_month_start,
      average_daily_spending: average_daily_spending,
      on_track_status: on_track_status,
      income_frequency_data: income_frequency_data
    }
  end

  private

  def month_range
    @month_range ||= @date.beginning_of_month..@date.end_of_month
  end

  def recent_transactions
    @recent_transactions ||= begin
      transactions = @account.transactions
                            .where(transaction_date: month_range)
                            .includes(:recurring_transaction) # Prevent N+1 queries
                            .to_a
      # Sort by date descending, then by id descending to ensure consistent ordering
      transactions.sort do |a, b|
        date_compare = b.transaction_date <=> a.transaction_date
        date_compare != 0 ? date_compare : (b.id <=> a.id)
      end
    end
    # Removed .limit(10) to allow week-based pagination to show all transactions
  end

  def expense_count
    expense_stats[:count]
  end

  def expense_total
    expense_stats[:total]
  end

  def income_count
    income_stats[:count]
  end

  def income_total
    income_stats[:total]
  end

  def end_of_month_balance
    @end_of_month_balance ||= @account.end_of_month_balance(@date)
  end

  # Optimized query that calculates both expenses and income in a single database query
  # Uses .real scope to exclude hypothetical transactions for consistency with other services
  # Uses amount > 0 for income (not >= 0) to match TransactionMerchantService logic
  def stats
    @stats ||= begin
      base = @account.transactions.real.where(transaction_date: month_range)
      
      expense_data = base.expenses
                         .select("COUNT(*) as count, SUM(amount) as total")
                         .first
      
      income_data = base.income
                        .select("COUNT(*) as count, SUM(amount) as total")
                        .first
      
      {
        "expense" => expense_data ? { count: expense_data.count || 0, total: expense_data.total || 0 } : { count: 0, total: 0 },
        "income" => income_data ? { count: income_data.count || 0, total: income_data.total || 0 } : { count: 0, total: 0 }
      }
    end
  end

  def expense_stats
    @expense_stats ||= {
      count: stats["expense"][:count],
      total: (stats["expense"][:total] || 0).abs
    }
  end

  def income_stats
    @income_stats ||= {
      count: stats["income"][:count],
      total: (stats["income"][:total] || 0).abs
    }
  end

  def top_expense_merchants
    @top_expense_merchants ||= TransactionMerchantService.call(
      @account,
      "expense",
      month_range.first,
      month_range.last,
      limit: 3
    )
  end

  def top_income_merchants
    @top_income_merchants ||= TransactionMerchantService.call(
      @account,
      "income",
      month_range.first,
      month_range.last,
      limit: 3
    )
  end

  # Get top expense categories for current month
  def top_expense_categories
    @top_expense_categories ||= begin
      categories = @account.transactions
                          .real
                          .expenses
                          .where(transaction_date: month_range)
                          .where.not(category: [nil, ""])
                          .group(:category)
                          .select("category, SUM(amount) as total, COUNT(*) as count")
                          .order("total ASC")
                          .limit(3)

      categories.map do |cat|
        {
          category: cat.category || "Uncategorized",
          total: cat.total.abs,
          count: cat.count
        }
      end
    end
  end

  # Get top income categories for current month
  def top_income_categories
    @top_income_categories ||= begin
      categories = @account.transactions
                          .real
                          .income
                          .where(transaction_date: month_range)
                          .where.not(category: [nil, ""])
                          .group(:category)
                          .select("category, SUM(amount) as total, COUNT(*) as count")
                          .order("total DESC")
                          .limit(3)

      categories.map do |cat|
        {
          category: cat.category || "Uncategorized",
          total: cat.total.abs,
          count: cat.count
        }
      end
    end
  end

  # Projected (hypothetical) transactions for the month
  def projected_stats
    @projected_stats ||= begin
      today = Date.today
      month_end = @date.end_of_month
      
      # Only calculate projections for current/future months
      if month_end >= today
        # Get hypothetical transactions in the month range that are in the future
        future_start = [today + 1.day, month_range.first].max
        future_end = month_range.last
        
        base = @account.transactions.hypothetical.where(transaction_date: future_start..future_end)
        
        expense_data = base.expenses
                           .select("COUNT(*) as count, SUM(amount) as total")
                           .first
        
        income_data = base.income
                          .select("COUNT(*) as count, SUM(amount) as total")
                          .first
        
        {
          "expense" => expense_data ? { count: expense_data.count || 0, total: expense_data.total || 0 } : { count: 0, total: 0 },
          "income" => income_data ? { count: income_data.count || 0, total: income_data.total || 0 } : { count: 0, total: 0 }
        }
      else
        # Past months have no projections
        { "expense" => { count: 0, total: 0 }, "income" => { count: 0, total: 0 } }
      end
    end
  end

  def projected_expense_count
    projected_stats["expense"][:count]
  end

  def projected_expense_total
    (projected_stats["expense"][:total] || 0).abs
  end

  def projected_income_count
    projected_stats["income"][:count]
  end

  def projected_income_total
    (projected_stats["income"][:total] || 0).abs
  end

  # Calculate balance at the start of the month
  # Current balance minus all transactions that occurred this month
  def balance_at_month_start
    @balance_at_month_start ||= begin
      month_transactions_sum = @account.transactions
                                        .where(transaction_date: month_range)
                                        .sum(:amount) || BigDecimal("0")
      @account.current_balance - month_transactions_sum
    end
  end

  # Calculate balance change since month start
  def balance_change_since_month_start
    @balance_change_since_month_start ||= @account.current_balance - balance_at_month_start
  end

  # Calculate average daily spending for the current month
  def average_daily_spending
    @average_daily_spending ||= begin
      days_elapsed = [(@date - @date.beginning_of_month).to_i + 1, 1].max
      expense_total / days_elapsed.to_f
    end
  end

  # Determine "On Track" status by comparing current trajectory to projection
  # Returns: :on_track (green), :caution (yellow), :off_track (red)
  def on_track_status
    @on_track_status ||= begin
      return :on_track if end_of_month_balance.nil? # No projection available

      current_balance = @account.current_balance
      projected_balance = end_of_month_balance
      month_start_balance = balance_at_month_start
      
      # Calculate expected balance based on linear progression
      days_elapsed = [(@date - @date.beginning_of_month).to_i + 1, 1].max
      days_in_month = @date.end_of_month.day
      progress = days_elapsed.to_f / days_in_month
      
      # Expected balance if progressing linearly from start to projection
      expected_balance = month_start_balance + ((projected_balance - month_start_balance) * progress)
      
      # Calculate absolute deviation
      absolute_deviation = (current_balance - expected_balance).abs
      
      # Use a fixed threshold based on balance magnitude for more stable calculation
      # For balances > $1000, use percentage; for smaller balances, use fixed dollar amount
      if expected_balance.abs > 1000
        deviation_pct = (absolute_deviation / expected_balance.abs * 100).abs
        if deviation_pct <= 5
          :on_track
        elsif deviation_pct <= 15
          :caution
        else
          :off_track
        end
      else
        # For smaller balances, use fixed dollar thresholds
        if absolute_deviation <= 50
          :on_track
        elsif absolute_deviation <= 150
          :caution
        else
          :off_track
        end
      end
    end
  end

  # Calculate income frequency data (count, last date, next recurring)
  def income_frequency_data
    @income_frequency_data ||= begin
      # Get all income transactions this month
      month_income_transactions = @account.transactions
                                          .real
                                          .income
                                          .where(transaction_date: month_range)
                                          .order(transaction_date: :desc)
      
      income_count_this_month = month_income_transactions.count
      last_income_date = month_income_transactions.first&.transaction_date
      
      # Check for upcoming recurring income
      upcoming_recurring = RecurringTransactionsService.upcoming(@account, @date.end_of_month)
      next_recurring_income = upcoming_recurring[:income].first
      
      {
        count_this_month: income_count_this_month,
        last_income_date: last_income_date,
        next_recurring_income: next_recurring_income,
        next_recurring_date: next_recurring_income&.next_occurrence_date
      }
    end
  end
end
