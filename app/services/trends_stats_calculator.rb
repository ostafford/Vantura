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
      year_over_year_comparison: year_over_year_comparison
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
      if @view_type == "merchant"
        # Top merchants
        merchants = TransactionMerchantService.call(
          @account,
          "expense",
          calculate_start_date_for_range,
          @current_month_end,
          limit: 10
        )

        merchants.map do |merchant|
          {
            name: merchant[:merchant] || "Unknown",
            amount: merchant[:total],
            count: merchant[:count],
            type: "merchant"
          }
        end
      else
        # Top categories
        categories = @account.transactions
                            .real
                            .expenses
                            .where(transaction_date: calculate_start_date_for_range..@current_month_end)
                            .where.not(category: [nil, ""])
                            .group(:category)
                            .select("category, SUM(amount) as total, COUNT(*) as count")
                            .order("total ASC")
                            .limit(10)

        categories.map do |category|
          {
            name: category.category || "Uncategorized",
            amount: category.total.abs,
            count: category.count,
            type: "category"
          }
        end
      end
    end
  end

  # Savings rate trend over historical period
  def savings_rate_trend
    @savings_rate_trend ||= begin
      historical_data.map do |month_data|
        {
          month: month_data[:month],
          month_name: month_data[:month_name],
          savings_rate: month_data[:savings_rate]
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
end
