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
      end_of_month_balance: end_of_month_balance,
      top_expense_merchants: top_expense_merchants,
      top_income_merchants: top_income_merchants
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
  def stats
    @stats ||= @account.transactions
                       .where(transaction_date: month_range)
                       .group("CASE WHEN amount < 0 THEN 'expense' ELSE 'income' END")
                       .select("
                         CASE WHEN amount < 0 THEN 'expense' ELSE 'income' END as type,
                         COUNT(*) as count,
                         SUM(amount) as total
                       ")
                       .index_by(&:type)
  end

  def expense_stats
    @expense_stats ||= {
      count: stats["expense"]&.count || 0,
      total: stats["expense"]&.total&.abs || 0
    }
  end

  def income_stats
    @income_stats ||= {
      count: stats["income"]&.count || 0,
      total: stats["income"]&.total || 0
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
end
