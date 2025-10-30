# Service Object: Calculate transaction statistics for a given account and date range
#
# Usage:
#   stats = TransactionStatsCalculator.call(@account, start_date, end_date)
#   stats = TransactionStatsCalculator.call(@account, Date.today.beginning_of_month, Date.today.end_of_month)
#
# Returns hash with:
#   - expense_total: Total expenses (absolute value)
#   - income_total: Total income
#   - expense_count: Count of expense transactions
#   - income_count: Count of income transactions
#   - net_cash_flow: Income - Expenses
#   - transaction_count: Total transaction count
#   - top_category: Category with highest total amount
#   - top_category_amount: Amount for top category
#
class TransactionStatsCalculator < ApplicationService
  def initialize(account, start_date, end_date)
    @account = account
    @start_date = start_date
    @end_date = end_date
  end

  def call
    {
      expense_total: expense_total,
      income_total: income_total,
      expense_count: expense_count,
      income_count: income_count,
      net_cash_flow: net_cash_flow,
      transaction_count: transaction_count,
      top_category: top_category,
      top_category_amount: top_category_amount,
      top_expense_merchants: top_expense_merchants,
      top_income_merchants: top_income_merchants
    }
  end

  private

  def transactions_in_range
    @transactions_in_range ||= @account.transactions
                                        .where(transaction_date: @start_date..@end_date)
  end

  def expense_total
    @expense_total ||= transactions_in_range.expenses.sum(:amount).abs
  end

  def income_total
    @income_total ||= transactions_in_range.income.sum(:amount)
  end

  def expense_count
    @expense_count ||= transactions_in_range.expenses.count
  end

  def income_count
    @income_count ||= transactions_in_range.income.count
  end

  def net_cash_flow
    @net_cash_flow ||= income_total - expense_total
  end

  def transaction_count
    @transaction_count ||= transactions_in_range.count
  end

  def top_category
    top_category_data&.first || "N/A"
  end

  def top_category_amount
    top_category_data&.last || 0
  end

  def top_category_data
    @top_category_data ||= transactions_in_range
                           .group(:category)
                           .sum(:amount)
                           .max_by { |_, v| v.abs }
  end

  def top_expense_merchants
    @top_expense_merchants ||= Transaction.top_merchants_by_type(
      "expense",
      account: @account,
      start_date: @start_date,
      end_date: @end_date,
      limit: 3
    )
  end

  def top_income_merchants
    @top_income_merchants ||= Transaction.top_merchants_by_type(
      "income",
      account: @account,
      start_date: @start_date,
      end_date: @end_date,
      limit: 3
    )
  end
end
