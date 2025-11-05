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
      top_income_merchants: top_income_merchants
    }
  end

  private

  def date
    @date ||= begin
      if @date_params[:year].present? && @date_params[:month].present?
        y = @date_params[:year].to_i
        m = @date_params[:month].to_i
        Date.new(y, m, 1)
      else
        Date.today
      end
    end
  end

  def year
    @year ||= date.year
  end

  def month
    @month ||= date.month
  end

  def start_date
    @start_date ||= date.beginning_of_month
  end

  def end_date
    @end_date ||= date.end_of_month
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
    @transactions ||= filtered_transactions
                       .where(transaction_date: start_date..end_date)
                       .includes(:recurring_transaction)
                       .order(transaction_date: :desc)
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
end
