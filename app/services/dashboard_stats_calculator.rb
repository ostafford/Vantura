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
      average_daily_income: average_daily_income,
      on_track_status: on_track_status,
      income_frequency_data: income_frequency_data,
      days_until_break_even: days_until_break_even
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
                          .where.not(category: [ nil, "" ])
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
                          .where.not(category: [ nil, "" ])
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
        future_start = [ today + 1.day, month_range.first ].max
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
      days_elapsed = [ (@date - @date.beginning_of_month).to_i + 1, 1 ].max
      expense_total / days_elapsed.to_f
    end
  end

  # Calculate average daily income for the current month
  # Returns hash with: value, current_month_actual, recurring_daily_rate, historical_daily_rate, days_elapsed, has_recurring, has_historical
  def average_daily_income
    @average_daily_income ||= begin
      days_elapsed = [ (@date - @date.beginning_of_month).to_i + 1, 1 ].max

      # Current month's actual daily average (fallback only)
      current_month_actual = income_total / days_elapsed.to_f

      # Calculate recurring income daily rate (if exists)
      recurring_daily_rate = calculate_recurring_income_daily_rate

      # Calculate historical average (6 months)
      historical_daily_rate = calculate_historical_income_daily_rate(6)

      {
        value: current_month_actual.round(2), # Keep for backward compatibility, but won't be primary
        current_month_actual: current_month_actual.round(2),
        recurring_daily_rate: recurring_daily_rate&.round(2),
        historical_daily_rate: historical_daily_rate&.round(2),
        days_elapsed: days_elapsed,
        has_recurring: recurring_daily_rate.present? && recurring_daily_rate > 0,
        has_historical: historical_daily_rate.present? && historical_daily_rate > 0
      }
    end
  end

  # Calculate daily rate from recurring income patterns
  def calculate_recurring_income_daily_rate
    active_recurring_income = @account.recurring_transactions
                                       .active
                                       .income_transactions

    return nil if active_recurring_income.empty?

    total_daily_rate = 0.0

    active_recurring_income.each do |recurring|
      daily_rate = case recurring.frequency
      when "weekly"
        recurring.amount / 7.0
      when "fortnightly"
        recurring.amount / 14.0
      when "monthly"
        recurring.amount / 30.44 # Average days per month
      when "quarterly"
        recurring.amount / 91.25 # Average days per quarter
      when "yearly"
        recurring.amount / 365.25 # Average days per year
      else
        0.0
      end

      total_daily_rate += daily_rate
    end

    total_daily_rate
  end

  # Calculate historical average daily income over specified months
  def calculate_historical_income_daily_rate(months = 6)
    months_to_include = months.to_i.clamp(1, 12)
    total_income = 0.0
    total_days = 0

    months_to_include.times do |i|
      month_date = @date - i.months
      month_start = month_date.beginning_of_month
      month_end = month_date.end_of_month

      month_income = @account.transactions
                             .real
                             .income
                             .where(transaction_date: month_start..month_end)
                             .sum(:amount)
                             .abs

      days_in_month = (month_end - month_start).to_i + 1
      total_income += month_income
      total_days += days_in_month
    end

    return nil if total_days.zero?

    (total_income / total_days.to_f)
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
      days_elapsed = [ (@date - @date.beginning_of_month).to_i + 1, 1 ].max
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

  # Calculate days until break-even (returning to month-start balance)
  # Factors in recurring income when available, falls back to historical data
  # Returns hash with: days, target_date, daily_income_rate, daily_spending_target, net_daily_change, source
  def days_until_break_even
    @days_until_break_even ||= begin
      current_deficit = -balance_change_since_month_start # Positive number if negative change

      # If already positive or at break-even, return early
      if current_deficit <= 0
        return {
          days: 0,
          target_date: @date,
          daily_income_rate: 0,
          daily_spending_target: 0,
          net_daily_change: 0,
          source: :already_positive,
          message: "You're already at or ahead of your month-start balance"
        }
      end

      # Get daily income rate (prefer recurring, fallback to historical)
      income_data = average_daily_income
      daily_income_rate = if income_data[:has_recurring]
        income_data[:recurring_daily_rate]
      elsif income_data[:has_historical]
        income_data[:historical_daily_rate]
      else
        income_data[:current_month_actual]
      end

      income_source = if income_data[:has_recurring]
        :recurring
      elsif income_data[:has_historical]
        :historical
      else
        :current_month
      end

      # Get daily spending target (from daily_spending_target calculation logic)
      # We need to calculate this similar to how daily_spending_target does it
      month_start_balance = balance_at_month_start
      current_balance = @account.current_balance
      projected_income = projected_income_total || 0
      projected_expenses = projected_expense_total || 0
      days_remaining = [ (@date.end_of_month - @date).to_i + 1, 1 ].max
      target_end_balance = month_start_balance
      projected_end_balance = current_balance + projected_income - projected_expenses
      remaining_budget = target_end_balance - projected_end_balance
      daily_spending_target = days_remaining > 0 ? (remaining_budget / days_remaining.to_f) : 0

      # Calculate net daily change (income - spending target)
      # If spending target is negative (overspending), we need to account for reduction
      if daily_spending_target < 0
        # User needs to reduce spending - calculate based on reduction needed
        reduction_needed = daily_spending_target.abs
        # Net change = income - (current average spending - reduction needed)
        # Simplified: net change = income - average_spending + reduction_needed
        current_avg_spending = average_daily_spending
        net_daily_change = daily_income_rate - current_avg_spending + reduction_needed
      else
        # Normal case: net change = income - spending target
        net_daily_change = daily_income_rate - daily_spending_target
      end

      # Factor in upcoming recurring income payments
      upcoming_recurring = RecurringTransactionsService.upcoming(@account, @date.end_of_month)
      next_income_payment = upcoming_recurring[:income].first

      if next_income_payment && next_income_payment.next_occurrence_date > @date
        days_until_income = (next_income_payment.next_occurrence_date - @date).to_i
        income_amount = next_income_payment.amount

        # Calculate deficit after income payment
        deficit_after_income = current_deficit - income_amount

        if deficit_after_income <= 0
          # Income payment alone will bring us to break-even
          return {
            days: days_until_income,
            target_date: next_income_payment.next_occurrence_date,
            daily_income_rate: daily_income_rate,
            daily_spending_target: daily_spending_target,
            net_daily_change: net_daily_change,
            source: income_source,
            next_income_payment: income_amount,
            next_income_date: next_income_payment.next_occurrence_date,
            message: "Your next income payment will bring you to break-even on #{next_income_payment.next_occurrence_date.strftime('%b %d')}"
          }
        else
          # Income payment helps but we still need more days
          # Calculate days needed after income payment
          if net_daily_change > 0
            days_after_income = (deficit_after_income / net_daily_change.to_f).ceil
            total_days = days_until_income + days_after_income
            target_date = @date + total_days.days

            return {
              days: total_days,
              target_date: target_date,
              daily_income_rate: daily_income_rate,
              daily_spending_target: daily_spending_target,
              net_daily_change: net_daily_change,
              source: income_source,
              next_income_payment: income_amount,
              next_income_date: next_income_payment.next_occurrence_date,
              days_until_income: days_until_income,
              message: "Break-even in ~#{total_days} days (after your payment on #{next_income_payment.next_occurrence_date.strftime('%b %d')})"
            }
          end
        end
      end

      # No upcoming income or income doesn't solve it - calculate based on daily net change
      if net_daily_change > 0
        days = (current_deficit / net_daily_change.to_f).ceil
        target_date = @date + days.days

        {
          days: days,
          target_date: target_date,
          daily_income_rate: daily_income_rate,
          daily_spending_target: daily_spending_target,
          net_daily_change: net_daily_change,
          source: income_source,
          message: "Break-even in ~#{days} days if you follow your daily spending target"
        }
      else
        # Net change is negative or zero - can't break even with current trajectory
        {
          days: nil,
          target_date: nil,
          daily_income_rate: daily_income_rate,
          daily_spending_target: daily_spending_target,
          net_daily_change: net_daily_change,
          source: income_source,
          message: "Reduce spending to reach break-even"
        }
      end
    end
  end

  # Helper method for number formatting (used in days_until_break_even)
  # Note: This will be formatted in the view, so we'll just return the amount here
  # and format in the helper/view layer
end
