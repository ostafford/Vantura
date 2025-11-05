# Service Object: Search transactions and calculate stats
#
# Usage:
#   data = TransactionSearchService.call(@account, query, date_params)
#   data = TransactionSearchService.call(@account, "grocery", { year: 2024, month: 10 })
#
# Returns hash with:
#   - transactions: Search results or month transactions
#   - date: Parsed date from params or today
#   - year: Year for the date
#   - month: Month for the date
#   - filter_type: "search" if query >= 3 chars, otherwise filter param or "all"
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
class TransactionSearchService < ApplicationService
  def initialize(account, query, date_params = {}, filter_type = "all")
    @account = account
    @query = query.to_s.strip
    @date_params = date_params
    @filter_type = filter_type
  end

  def call
    if @query.length >= 3
      search_results
    else
      month_results
    end
  end

  private

  def search_results
    {
      transactions: search_transactions,
      date: date,
      year: year,
      month: month,
      filter_type: "search",
      expense_total: search_expense_total,
      income_total: search_income_total,
      expense_count: search_expense_count,
      income_count: search_income_count,
      net_cash_flow: search_net_cash_flow,
      transaction_count: search_transaction_count,
      top_category: search_top_category,
      top_category_amount: search_top_category_amount,
      top_expense_merchants: search_top_expense_merchants,
      top_income_merchants: search_top_income_merchants
    }
  end

  def month_results
    {
      transactions: month_transactions,
      date: date,
      year: year,
      month: month,
      filter_type: @filter_type,
      expense_total: month_stats[:expense_total],
      income_total: month_stats[:income_total],
      expense_count: month_stats[:expense_count],
      income_count: month_stats[:income_count],
      net_cash_flow: month_stats[:net_cash_flow],
      transaction_count: month_stats[:transaction_count],
      top_category: month_stats[:top_category],
      top_category_amount: month_stats[:top_category_amount],
      top_expense_merchants: month_top_expense_merchants,
      top_income_merchants: month_top_income_merchants
    }
  end

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

  def search_transactions
    @search_transactions ||= begin
      search_pattern = "%#{@query}%"
      @account.transactions
        .where(transaction_date: start_date..end_date)
        .where("description LIKE ? COLLATE NOCASE OR category LIKE ? COLLATE NOCASE OR merchant LIKE ? COLLATE NOCASE",
               search_pattern, search_pattern, search_pattern)
        .includes(:recurring_transaction)
        .order(transaction_date: :desc)
        .limit(10)
        .to_a
    end
  end

  def search_expense_transactions
    @search_expense_transactions ||= search_transactions.select { |t| t.amount < 0 }
  end

  def search_income_transactions
    @search_income_transactions ||= search_transactions.select { |t| t.amount > 0 }
  end

  def search_expense_total
    @search_expense_total ||= search_expense_transactions.sum { |t| t.amount.abs }
  end

  def search_income_total
    @search_income_total ||= search_income_transactions.sum { |t| t.amount }
  end

  def search_expense_count
    @search_expense_count ||= search_expense_transactions.count
  end

  def search_income_count
    @search_income_count ||= search_income_transactions.count
  end

  def search_net_cash_flow
    @search_net_cash_flow ||= search_income_total - search_expense_total
  end

  def search_transaction_count
    @search_transaction_count ||= search_transactions.count
  end

  def search_top_category
    search_top_category_data&.first || "N/A"
  end

  def search_top_category_amount
    search_top_category_data&.last || 0
  end

  def search_top_category_data
    @search_top_category_data ||= begin
      category_totals = search_transactions.group_by(&:category).transform_values do |transactions|
        transactions.sum(&:amount).abs
      end
      category_totals.max_by { |_, total| total }
    end
  end

  def search_top_expense_merchants
    @search_top_expense_merchants ||= calculate_top_merchants(search_expense_transactions)
  end

  def search_top_income_merchants
    @search_top_income_merchants ||= calculate_top_merchants(search_income_transactions)
  end

  def month_transactions
    @month_transactions ||= @account.transactions
                                     .where(transaction_date: start_date..end_date)
                                     .includes(:recurring_transaction)
                                     .order(transaction_date: :desc)
  end

  def month_stats
    @month_stats ||= TransactionStatsCalculator.call(@account, start_date, end_date)
  end

  def month_top_expense_merchants
    @month_top_expense_merchants ||= TransactionMerchantService.call(
      @account,
      "expense",
      start_date,
      end_date,
      limit: 3
    )
  end

  def month_top_income_merchants
    @month_top_income_merchants ||= TransactionMerchantService.call(
      @account,
      "income",
      start_date,
      end_date,
      limit: 3
    )
  end

  def calculate_top_merchants(transactions)
    return [] if transactions.empty?

    merchants = transactions.group_by(&:merchant).transform_values do |txs|
      { total: txs.sum(&:amount).abs, count: txs.count }
    end

    merchants.sort_by { |_, data| -data[:total] }
             .first(3)
             .map do |merchant_name, data|
               {
                 merchant: merchant_name || "Unknown",
                 total: data[:total],
                 count: data[:count],
                 hypothetical: transactions.any? { |t| t.is_hypothetical? && t.merchant == merchant_name }
               }
             end
  end
end
