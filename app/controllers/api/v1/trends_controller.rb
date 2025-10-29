# API controller for trends data
class Api::V1::TrendsController < Api::V1::BaseController
  before_action :load_account_or_return

  # GET /api/v1/trends/data
  def data
    return render_error(code: 'account_not_found', message: 'Account not found', status: :not_found) unless @account

    # Calculate all trends statistics using service
    stats = TrendsStatsCalculator.call(@account)

    render_success({
      current_date: stats[:current_date],
      current_month_income: stats[:current_month_income],
      current_month_expenses: stats[:current_month_expenses],
      net_savings: stats[:net_savings],
      last_month_income: stats[:last_month_income],
      last_month_expenses: stats[:last_month_expenses],
      income_change_pct: stats[:income_change_pct],
      expense_change_pct: stats[:expense_change_pct],
      net_change_pct: stats[:net_change_pct],
      active_recurring_count: stats[:active_recurring_count],
      top_merchant: stats[:top_merchant]
    })
  end
end

