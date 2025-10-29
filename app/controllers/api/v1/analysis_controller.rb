# API controller for analysis data
class Api::V1::AnalysisController < Api::V1::BaseController
  before_action :load_account_or_return

  # GET /api/v1/analysis/data
  # Query params: filter_id (optional)
  def data
    return render_error(code: 'account_not_found', message: 'Account not found', status: :not_found) unless @account

    current_date = Date.current

    # Calculate analysis statistics using the same service as trends
    stats = TrendsStatsCalculator.call(@account)

    # Get all transactions for the current month
    transactions = @account.transactions
                          .includes(:account)
                          .where(transaction_date: current_date.beginning_of_month..current_date.end_of_month)
                          .where(is_hypothetical: false)
                          .order(transaction_date: :desc)

    # Apply filter if one is selected
    selected_filter = nil
    if params[:filter_id].present?
      selected_filter = Current.user.filters.find_by(id: params[:filter_id])
      if selected_filter
        transactions = Transaction.apply_filter(selected_filter)
        transactions = @account.transactions
                              .includes(:account)
                              .where(id: transactions.select(:id))
      end
    end

    # Calculate breakdowns for ALL selected filter types
    breakdowns = {}

    if selected_filter&.filter_types&.present?
      filter_types = selected_filter.filter_types

      filter_types.each do |filter_type|
        case filter_type
        when "merchant"
          breakdowns["merchant"] = transactions.group(:merchant).sum(:amount)
                                               .sort_by { |_, amount| -amount.abs }
                                               .to_h
        when "status"
          breakdowns["status"] = transactions.group(:status).sum(:amount)
                                            .sort_by { |_, amount| -amount.abs }
                                            .to_h
        when "category"
          breakdowns["category"] = transactions.group(:category).sum(:amount)
                                               .sort_by { |_, amount| -amount.abs }
                                               .to_h
        end
      end
    end

    # Always include category breakdown as default if no filter selected
    if breakdowns.empty?
      breakdowns["category"] = transactions.group(:category).sum(:amount)
                                          .sort_by { |_, amount| -amount.abs }
                                          .to_h
    end

    render_success({
      current_date: current_date,
      selected_filter: selected_filter&.attributes,
      transactions: transactions.map(&:attributes),
      stats: {
        current_month_income: stats[:current_month_income],
        current_month_expenses: stats[:current_month_expenses],
        net_savings: stats[:net_savings],
        last_month_income: stats[:last_month_income],
        last_month_expenses: stats[:last_month_expenses],
        income_change_pct: stats[:income_change_pct],
        expense_change_pct: stats[:expense_change_pct],
        net_change_pct: stats[:net_change_pct],
        top_merchant: stats[:top_merchant]
      },
      breakdowns: breakdowns
    })
  end
end

