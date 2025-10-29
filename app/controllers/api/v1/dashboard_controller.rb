# API controller for dashboard stats
class Api::V1::DashboardController < Api::V1::BaseController
  before_action :load_account_or_return

  # GET /api/v1/dashboard/stats
  def stats
    return render_error(code: 'account_not_found', message: 'Account not found', status: :not_found) unless @account

    # Calculate all dashboard stats using service with caching
    cache_key = "dashboard_stats_#{@account.id}_#{Date.today.strftime('%Y-%m-%d')}"
    stats = Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      DashboardStatsCalculator.call(@account)
    end

    # Get current week transactions
    week_start = Date.today.beginning_of_week(:monday)
    week_end = Date.today.end_of_week(:monday)
    recent_transactions = @account.transactions
                                  .where(transaction_date: week_start..week_end)
                                  .includes(:recurring_transaction)
                                  .order(transaction_date: :desc, id: :desc)
                                  .limit(10)

    # Get upcoming recurring transactions
    end_of_month = Date.today.end_of_month
    upcoming = @account.recurring_transactions
                       .active
                       .where("next_occurrence_date <= ?", end_of_month)
                       .order(:next_occurrence_date)

    expenses = upcoming.select { |r| r.transaction_type_expense? }
    income = upcoming.select { |r| r.transaction_type_income? }

    render_success({
      current_date: stats[:current_date],
      recent_transactions: recent_transactions.map(&:attributes),
      expense_count: stats[:expense_count],
      expense_total: stats[:expense_total],
      income_count: stats[:income_count],
      income_total: stats[:income_total],
      end_of_month_balance: stats[:end_of_month_balance],
      top_expense_merchants: stats[:top_expense_merchants],
      top_income_merchants: stats[:top_income_merchants],
      upcoming_recurring: {
        expenses: expenses.map(&:attributes),
        income: income.map(&:attributes),
        expense_total: expenses.sum { |r| r.amount.abs },
        income_total: income.sum { |r| r.amount }
      }
    })
  end
end

