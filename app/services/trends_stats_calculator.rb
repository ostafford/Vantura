# Service Object: Calculate all statistics for the Trends page
#
# Usage:
#   stats = TrendsStatsCalculator.call(account)
#   stats = TrendsStatsCalculator.call(account, Date.today)
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
#
class TrendsStatsCalculator < ApplicationService
  def initialize(account, reference_date = Date.today)
    @account = account
    @current_date = reference_date
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
      top_merchant: top_merchant
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
      # Use shared query helper to get top merchants
      merchants = Transaction.top_merchants_by_type(
        "expense",
        account: @account,
        start_date: @current_month_start,
        end_date: @current_month_end,
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
end
