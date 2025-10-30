class Transactions::SearchService < ApplicationService
  Result = Struct.new(:transactions, :stats)

  def initialize(account:, query:, year: nil, month: nil)
    @account = account
    @query = (query || "").to_s.strip
    @year = year
    @month = month
  end

  def call
    start_date, end_date = resolve_date_range

    if @query.length >= 3
      search_pattern = "%#{@query}%"
      transactions = @account.transactions
                              .where(transaction_date: start_date..end_date)
                              .where("description ILIKE ? OR category ILIKE ? OR merchant ILIKE ?",
                                     search_pattern, search_pattern, search_pattern)
                              .order(transaction_date: :desc)
                              .limit(10)

      expense_transactions = transactions.select { |t| t.amount < 0 }
      income_transactions = transactions.select { |t| t.amount > 0 }

      stats = {
        expense_total: expense_transactions.sum { |t| t.amount.abs },
        income_total: income_transactions.sum { |t| t.amount },
        expense_count: expense_transactions.count,
        income_count: income_transactions.count,
        net_cash_flow: income_transactions.sum(&:amount) - expense_transactions.sum { |t| t.amount.abs },
        transaction_count: transactions.count,
        top_category: top_category_from(transactions),
        top_category_amount: top_category_amount_from(transactions),
        top_expense_merchants: calculate_top_merchants(expense_transactions),
        top_income_merchants: calculate_top_merchants(income_transactions)
      }

      Result.new(transactions, stats)
    else
      transactions = @account.transactions
                              .where(transaction_date: start_date..end_date)
                              .order(transaction_date: :desc)

      stats = TransactionStatsCalculator.call(@account, start_date, end_date)
      Result.new(transactions, stats)
    end
  end

  private

  def resolve_date_range
    if @year.present? && @month.present?
      date = Date.new(@year.to_i, @month.to_i, 1)
      [date.beginning_of_month, date.end_of_month]
    else
      today = Date.today
      [today.beginning_of_month, today.end_of_month]
    end
  end

  def top_category_from(transactions)
    category_totals = transactions.group_by(&:category).transform_values { |txs| txs.sum(&:amount).abs }
    category_totals.max_by { |_, total| total }&.first || "N/A"
  end

  def top_category_amount_from(transactions)
    category_totals = transactions.group_by(&:category).transform_values { |txs| txs.sum(&:amount).abs }
    category_totals.max_by { |_, total| total }&.last || 0
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


