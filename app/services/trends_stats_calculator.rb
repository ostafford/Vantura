# Service Object: Calculate all statistics for the Trends page
#
# Usage:
#   stats = TrendsStatsCalculator.call(account)
#   stats = TrendsStatsCalculator.call(account, Date.today, months: 6, view_type: "category")
#
# Parameters:
#   - account: Account to calculate stats for
#   - reference_date: Date to use as reference (default: Date.today)
#   - months: Number of months to include in historical data (3, 6, 12, or "all")
#   - view_type: "category" or "merchant" for breakdown view
#
# Returns hash with:
#   - current_date: Date for calculations
#   - current_month_income: Income for current month
#   - current_month_expenses: Expenses for current month (absolute value)
#   - net_savings: Income - Expenses (can be negative)
#   - last_month_income: Income for previous month
#   - last_month_expenses: Expenses for previous month (absolute value)
#   - income_change_pct: Percentage change in income (month over month)
#   - expense_change_pct: Percentage change in expenses (month over month)
#   - net_change_pct: Percentage change in net savings
#   - active_recurring_count: Count of active recurring transactions
#   - top_merchant: { name, amount } - Merchant with highest total spend this month
#   - historical_data: Array of monthly stats for selected range
#   - category_breakdown: Top categories/merchants based on view_type
#   - savings_rate_trend: Percentage of income saved over time
#   - year_over_year_comparison: Same month last year comparison
#
class TrendsStatsCalculator < ApplicationService
  def initialize(account, reference_date = Date.today, months: 6, view_type: "category")
    @account = account
    @current_date = reference_date
    @months = months
    @view_type = view_type
    @current_month_start = @current_date.beginning_of_month
    @current_month_end = @current_date.end_of_month
    @last_month_start = @current_date.prev_month.beginning_of_month
    @last_month_end = @current_date.prev_month.end_of_month
  end

  def call
    {
      current_date: @current_date,

      # Current month stats
      current_month_income: current_month_income,
      current_month_expenses: current_month_expenses,
      net_savings: net_savings,

      # Last month stats
      last_month_income: last_month_income,
      last_month_expenses: last_month_expenses,

      # Month-over-month changes
      income_change_pct: income_change_percentage,
      expense_change_pct: expense_change_percentage,
      net_change_pct: net_change_percentage,

      # Recurring count
      active_recurring_count: active_recurring_count,

      # Top merchant
      top_merchant: top_merchant,

      # Historical data
      historical_data: historical_data,

      # Category/Merchant breakdown
      category_breakdown: category_breakdown,

      # Savings rate trend
      savings_rate_trend: savings_rate_trend,

      # Year-over-year comparison
      year_over_year_comparison: year_over_year_comparison,

      # Savings rate calculations
      current_savings_rate: current_savings_rate,
      last_month_savings_rate: last_month_savings_rate,
      savings_rate_change: savings_rate_change,
      three_month_avg_savings_rate: three_month_avg_savings_rate,
      savings_rate_trend_direction: savings_rate_trend_direction,

      # Spending rate vs income rate
      spending_rate_data: spending_rate_data,

      # Recurring vs discretionary breakdown
      recurring_vs_discretionary: recurring_vs_discretionary,

      # Category-level insights
      category_changes: category_changes,
      top_category_increase: top_category_increase,
      top_category_decrease: top_category_decrease,

      # Income stability indicator
      income_stability_data: income_stability_data,

      # Quick actions
      quick_actions: quick_actions
    }
  end

  private

  # Current month calculations (real transactions only)
  def current_month_income
    @current_month_income ||= @account.transactions
      .real
      .income
      .where(transaction_date: @current_month_start..@current_month_end)
      .sum(:amount)
      .abs
  end

  def current_month_expenses
    @current_month_expenses ||= @account.transactions
      .real
      .expenses
      .where(transaction_date: @current_month_start..@current_month_end)
      .sum(:amount)
      .abs
  end

  def net_savings
    @net_savings ||= current_month_income - current_month_expenses
  end

  # Last month calculations
  def last_month_income
    @last_month_income ||= @account.transactions
      .real
      .income
      .where(transaction_date: @last_month_start..@last_month_end)
      .sum(:amount)
      .abs
  end

  def last_month_expenses
    @last_month_expenses ||= @account.transactions
      .real
      .expenses
      .where(transaction_date: @last_month_start..@last_month_end)
      .sum(:amount)
      .abs
  end

  # Month-over-month percentage changes
  def income_change_percentage
    return 0 if last_month_income.zero?
    ((current_month_income - last_month_income) / last_month_income * 100).round(1)
  end

  def expense_change_percentage
    return 0 if last_month_expenses.zero?
    ((current_month_expenses - last_month_expenses) / last_month_expenses * 100).round(1)
  end

  def net_change_percentage
    last_month_net = last_month_income - last_month_expenses
    return 0 if last_month_net.zero?
    ((net_savings - last_month_net) / last_month_net.abs * 100).round(1)
  end

  # Active recurring transactions count
  def active_recurring_count
    @active_recurring_count ||= @account.recurring_transactions.active.count
  end

  # Top merchant by total spend (current month, expenses only)
  def top_merchant
    @top_merchant ||= begin
      # Use service to get top merchants
      merchants = TransactionMerchantService.call(
        @account,
        "expense",
        @current_month_start,
        @current_month_end,
        limit: 1
      )

      if merchants.any?
        merchant = merchants.first
        { name: merchant[:merchant] || "No transactions", amount: merchant[:total] || 0.0 }
      else
        { name: "No transactions", amount: 0.0 }
      end
    end
  end

  # Historical data for selected months range
  def historical_data
    @historical_data ||= begin
      months_to_include = calculate_months_to_include
      data = []

      months_to_include.times do |i|
        month_date = @current_date - i.months
        month_start = month_date.beginning_of_month
        month_end = month_date.end_of_month

        income = @account.transactions
                        .real
                        .income
                        .where(transaction_date: month_start..month_end)
                        .sum(:amount)
                        .abs

        expenses = @account.transactions
                          .real
                          .expenses
                          .where(transaction_date: month_start..month_end)
                          .sum(:amount)
                          .abs

        net = income - expenses
        savings_rate = income.positive? ? ((net / income) * 100).round(1) : 0

        data << {
          month: month_date.strftime("%Y-%m"),
          month_name: month_date.strftime("%B %Y"),
          income: income,
          expenses: expenses,
          net_savings: net,
          savings_rate: savings_rate
        }
      end

      data.reverse # Return oldest to newest
    end
  end

  # Category or merchant breakdown based on view_type
  def category_breakdown
    @category_breakdown ||= begin
      total_expenses = current_month_expenses

      if @view_type == "merchant"
        # Top merchants
        merchants = TransactionMerchantService.call(
          @account,
          "expense",
          @current_month_start,
          @current_month_end,
          limit: 10
        )

        # Get last month merchants for comparison
        last_month_merchants = TransactionMerchantService.call(
          @account,
          "expense",
          @last_month_start,
          @last_month_end,
          limit: 10
        )
        last_month_hash = last_month_merchants.index_by { |m| m[:merchant] }

        merchants.map do |merchant|
          merchant_name = merchant[:merchant] || "Unknown"
          current_amount = merchant[:total]
          last_amount = last_month_hash[merchant_name]&.dig(:total) || 0
          change_amount = current_amount - last_amount
          change_pct = last_amount.positive? ? ((change_amount.to_f / last_amount) * 100).round(1) : (current_amount.positive? ? 100.0 : 0)
          pct_of_total = total_expenses.positive? ? ((current_amount.to_f / total_expenses) * 100).round(1) : 0
          avg_transaction = merchant[:count].positive? ? (current_amount / merchant[:count]).round(2) : 0

          {
            name: merchant_name,
            amount: current_amount,
            count: merchant[:count],
            type: "merchant",
            pct_of_total: pct_of_total,
            change_pct: change_pct,
            change_amount: change_amount.round(2),
            avg_transaction: avg_transaction
          }
        end
      else
        # Top categories
        categories = @account.transactions
                            .real
                            .expenses
                            .where(transaction_date: @current_month_start..@current_month_end)
                            .where.not(category: [ nil, "" ])
                            .group(:category)
                            .select("category, SUM(amount) as total, COUNT(*) as count")
                            .order("total ASC")
                            .limit(10)

        # Get last month categories for comparison
        last_month_categories = category_totals_for_month(@last_month_start, @last_month_end)
        last_month_counts = @account.transactions
                                    .real
                                    .expenses
                                    .where(transaction_date: @last_month_start..@last_month_end)
                                    .where.not(category: [ nil, "" ])
                                    .group(:category)
                                    .count

        categories.map do |category|
          category_name = category.category || "Uncategorized"
          current_amount = category.total.abs
          last_amount = last_month_categories[category_name] || 0
          change_amount = current_amount - last_amount
          change_pct = last_amount.positive? ? ((change_amount.to_f / last_amount) * 100).round(1) : (current_amount.positive? ? 100.0 : 0)
          pct_of_total = total_expenses.positive? ? ((current_amount.to_f / total_expenses) * 100).round(1) : 0
          avg_transaction = category.count.positive? ? (current_amount.to_f / category.count).round(2) : 0

          {
            name: category_name,
            amount: current_amount,
            count: category.count,
            type: "category",
            pct_of_total: pct_of_total,
            change_pct: change_pct,
            change_amount: change_amount.round(2),
            avg_transaction: avg_transaction
          }
        end
      end
    end
  end

  # Savings rate trend over historical period
  def savings_rate_trend
    @savings_rate_trend ||= begin
      # Calculate goal rate based on user's goal type (amount vs rate)
      target_amount = @account.target_savings_amount
      target_rate = @account.target_savings_rate
      
      historical_data.map do |month_data|
        month_income = month_data[:income]
        
        # Calculate actual expected goal rate for this month
        goal_rate_pct = if target_amount.present? && target_amount.positive? && month_income.positive?
          # If user set an amount goal, calculate rate based on that month's income
          calculated_rate = (target_amount / month_income) * 100
          [calculated_rate, 100.0].min.round(1) # Cap at 100%
        elsif target_rate.present? && target_rate.positive?
          # If user set a rate goal, use that rate
          (target_rate * 100).round(1)
        else
          # No goal set
          nil
        end
        
        {
          month: month_data[:month],
          month_name: month_data[:month_name],
          savings_rate: month_data[:savings_rate],
          goal_rate: goal_rate_pct
        }
      end
    end
  end

  # Year-over-year comparison (same month last year)
  def year_over_year_comparison
    @year_over_year_comparison ||= begin
      last_year_date = @current_date - 1.year
      last_year_start = last_year_date.beginning_of_month
      last_year_end = last_year_date.end_of_month

      last_year_income = @account.transactions
                                 .real
                                 .income
                                 .where(transaction_date: last_year_start..last_year_end)
                                 .sum(:amount)
                                 .abs

      last_year_expenses = @account.transactions
                                   .real
                                   .expenses
                                   .where(transaction_date: last_year_start..last_year_end)
                                   .sum(:amount)
                                   .abs

      last_year_net = last_year_income - last_year_expenses

      income_change = last_year_income.positive? ? ((current_month_income - last_year_income) / last_year_income * 100).round(1) : 0
      expense_change = last_year_expenses.positive? ? ((current_month_expenses - last_year_expenses) / last_year_expenses * 100).round(1) : 0
      net_change = last_year_net.zero? ? 0 : ((net_savings - last_year_net) / last_year_net.abs * 100).round(1)

      {
        last_year_month: last_year_date.strftime("%B %Y"),
        last_year_income: last_year_income,
        last_year_expenses: last_year_expenses,
        last_year_net: last_year_net,
        income_change_pct: income_change,
        expense_change_pct: expense_change,
        net_change_pct: net_change
      }
    end
  end

  # Calculate number of months to include based on @months parameter
  def calculate_months_to_include
    return @account.transactions.real.minimum(:transaction_date)&.then { |d| ((@current_date.year - d.year) * 12) + (@current_date.month - d.month) + 1 } || 12 if @months == "all"

    @months.to_i.clamp(1, 24) # Cap at 24 months for performance
  end

  # Calculate start date for historical range
  def calculate_start_date_for_range
    months_to_include = calculate_months_to_include
    (@current_date - (months_to_include - 1).months).beginning_of_month
  end

  # Savings rate calculations
  def current_savings_rate
    return 0 if current_month_income.zero?
    ((net_savings.to_f / current_month_income) * 100).round(1)
  end

  def last_month_savings_rate
    last_month_net = last_month_income - last_month_expenses
    return 0 if last_month_income.zero?
    ((last_month_net.to_f / last_month_income) * 100).round(1)
  end

  def savings_rate_change
    current_savings_rate - last_month_savings_rate
  end

  def three_month_avg_savings_rate
    recent_months = historical_data.last(3)
    return 0 if recent_months.empty?

    rates = recent_months.map { |m| m[:savings_rate] }.compact
    return 0 if rates.empty?

    (rates.sum.to_f / rates.size).round(1)
  end

  def savings_rate_trend_direction
    recent_months = historical_data.last(3)
    return "stable" if recent_months.size < 3

    rates = recent_months.map { |m| m[:savings_rate] }.compact
    return "stable" if rates.size < 3

    # Check if trend is improving (increasing), declining (decreasing), or stable
    if rates[2] > rates[0] && (rates[2] - rates[0]).abs > 1.0
      "improving"
    elsif rates[2] < rates[0] && (rates[0] - rates[2]).abs > 1.0
      "declining"
    else
      "stable"
    end
  end

  # Spending rate vs income rate
  def spending_rate_data
    days_elapsed = [(@current_date - @current_month_start).to_i + 1, 1].max
    days_in_month = @current_month_end.day

    avg_daily_income = current_month_income.positive? ? (current_month_income.to_f / days_elapsed) : 0
    avg_daily_expenses = current_month_expenses.positive? ? (current_month_expenses.to_f / days_elapsed) : 0

    spending_rate = avg_daily_income.positive? ? (avg_daily_expenses / avg_daily_income) : 0
    income_utilization_pct = current_month_income.positive? ? ((current_month_expenses.to_f / current_month_income) * 100).round(1) : 0

    # Calculate days of income remaining (if positive net)
    days_of_income_remaining = nil
    if net_savings.positive? && avg_daily_expenses.positive?
      days_of_income_remaining = (net_savings.to_f / avg_daily_expenses).round(1)
    end

    {
      spending_rate: spending_rate.round(3),
      income_utilization_pct: income_utilization_pct,
      days_of_income_remaining: days_of_income_remaining,
      avg_daily_income: avg_daily_income.round(2),
      avg_daily_expenses: avg_daily_expenses.round(2),
      days_elapsed: days_elapsed,
      days_in_month: days_in_month
    }
  end

  # Recurring vs discretionary breakdown
  def recurring_vs_discretionary
    recurring_total = recurring_expenses_total
    discretionary_total = current_month_expenses - recurring_total

    total_expenses = current_month_expenses
    recurring_pct = total_expenses.positive? ? ((recurring_total.to_f / total_expenses) * 100).round(1) : 0
    discretionary_pct = total_expenses.positive? ? ((discretionary_total.to_f / total_expenses) * 100).round(1) : 0

    {
      recurring_total: recurring_total.round(2),
      discretionary_total: discretionary_total.round(2),
      recurring_pct: recurring_pct,
      discretionary_pct: discretionary_pct,
      total_expenses: total_expenses
    }
  end

  def recurring_expenses_total
    @recurring_expenses_total ||= begin
      # Get active recurring expense transactions
      active_recurring = @account.recurring_transactions
                                 .active
                                 .where(transaction_type: "expense")

      # Calculate how many times each recurring transaction occurs in the current month
      total = 0.0
      active_recurring.each do |recurring|
        occurrences = occurrences_in_month(recurring, @current_month_start, @current_month_end)
        total += (recurring.amount.abs * occurrences)
      end

      total
    end
  end

  def occurrences_in_month(recurring, month_start, month_end)
    case recurring.frequency
    when "weekly"
      # Approximately 4.33 weeks per month
      4.33
    when "fortnightly"
      # Approximately 2.17 fortnights per month
      2.17
    when "monthly"
      1.0
    when "quarterly"
      # 1/3 of a month
      0.33
    when "yearly"
      # 1/12 of a month
      0.08
    else
      0
    end
  end

  # Category-level insights
  def category_changes
    @category_changes ||= begin
      current_categories = category_totals_for_month(@current_month_start, @current_month_end)
      last_categories = category_totals_for_month(@last_month_start, @last_month_end)

      changes = []
      all_categories = (current_categories.keys + last_categories.keys).uniq

      all_categories.each do |category|
        current_amount = current_categories[category] || 0
        last_amount = last_categories[category] || 0

        next if current_amount.zero? && last_amount.zero?

        change_amount = current_amount - last_amount
        change_pct = last_amount.positive? ? ((change_amount.to_f / last_amount) * 100).round(1) : (current_amount.positive? ? 100.0 : 0)

        changes << {
          name: category,
          current_amount: current_amount.round(2),
          last_month_amount: last_amount.round(2),
          change_pct: change_pct,
          change_amount: change_amount.round(2)
        }
      end

      changes.sort_by { |c| c[:change_amount].abs }.reverse
    end
  end

  def category_totals_for_month(start_date, end_date)
    @account.transactions
            .real
            .expenses
            .where(transaction_date: start_date..end_date)
            .where.not(category: [nil, ""])
            .group(:category)
            .sum(:amount)
            .transform_values(&:abs)
  end

  def top_category_increase
    increases = category_changes.select { |c| c[:change_amount].positive? }
    increases.max_by { |c| c[:change_amount] }
  end

  def top_category_decrease
    decreases = category_changes.select { |c| c[:change_amount].negative? }
    decreases.min_by { |c| c[:change_amount] }
  end

  # Income stability indicator
  def income_stability_data
    @income_stability_data ||= begin
      # Get income for last 6 months (or available months)
      months_data = []
      6.times do |i|
        month_date = @current_date - i.months
        month_start = month_date.beginning_of_month
        month_end = month_date.end_of_month

        income = @account.transactions
                         .real
                         .income
                         .where(transaction_date: month_start..month_end)
                         .sum(:amount)
                         .abs

        months_data << income if income.positive?
      end

      return { score: 100, message: "consistent", variance: 0 } if months_data.size < 2

      # Calculate variance
      mean = months_data.sum.to_f / months_data.size
      variance = months_data.sum { |x| (x - mean)**2 } / months_data.size
      std_dev = Math.sqrt(variance)

      # Calculate stability score (0-100, where 100 = perfectly stable)
      # Lower coefficient of variation = higher stability
      coefficient_of_variation = mean.positive? ? (std_dev / mean) : 1.0
      score = [(100 - (coefficient_of_variation * 100)).round(0), 0].max

      message = score >= 80 ? "consistent" : "varies month-to-month"

      {
        score: score,
        message: message,
        variance: variance.round(2),
        std_dev: std_dev.round(2),
        coefficient_of_variation: coefficient_of_variation.round(3),
        months_analyzed: months_data.size
      }
    end
  end

  # Quick actions
  def quick_actions
    @quick_actions ||= begin
      actions = []

      # Category-specific reduction targets
      top_category = category_breakdown.first
      if top_category && top_category[:amount].positive?
        reduction_10_pct = (top_category[:amount] * 0.1).round(2)
        actions << {
          type: "category_reduction",
          category: top_category[:name],
          reduction_pct: 10,
          savings_amount: reduction_10_pct,
          message: "Reduce #{top_category[:name]} by 10% to save $#{reduction_10_pct}/month"
        }
      end

      # Spending pace recommendations
      spending_rate = spending_rate_data
      if net_savings.negative? && spending_rate[:avg_daily_expenses].positive?
        days_remaining = @current_month_end.day - (@current_date - @current_month_start).to_i - 1
        target_daily = (current_month_income.to_f / @current_month_end.day).round(2)
        current_daily = spending_rate[:avg_daily_expenses]
        if current_daily > target_daily && days_remaining.positive?
          actions << {
            type: "spending_pace",
            target_daily: target_daily,
            current_daily: current_daily.round(2),
            days_remaining: days_remaining,
            message: "Spend below $#{target_daily}/day for the next #{days_remaining} days to reach net $0"
          }
        end
      end

      # Savings opportunities from category changes
      top_decrease = top_category_decrease
      if top_decrease && top_decrease[:change_amount].negative?
        potential_savings = top_decrease[:change_amount].abs
        actions << {
          type: "savings_opportunity",
          category: top_decrease[:name],
          savings_amount: potential_savings.round(2),
          message: "If you reduce #{top_decrease[:name]} by 10%, you could save $#{(top_decrease[:current_amount] * 0.1).round(2)}/month"
        }
      end

      actions
    end
  end
end
