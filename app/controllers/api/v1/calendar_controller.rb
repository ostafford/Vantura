# API controller for calendar events
class Api::V1::CalendarController < Api::V1::BaseController
  include DateParseable

  before_action :load_account_or_return

  # GET /api/v1/calendar/events
  # Query params: year, month, day, view (month/week)
  def events
    return render_error(code: 'account_not_found', message: 'Account not found', status: :not_found) unless @account

    # Parse date parameters
    parse_month_params

    # Set view (month or week)
    view = params[:view] || "month"

    # Get appropriate date range and structure via shared services
    builder = Calendar::StructureBuilder.new(date: @date, month: @month, week_start: :monday)
    start_date, end_date = builder.date_range_for_view(view)

    # Ensure recurring projection is centralized
    RecurringTransactions::Projector.call(account: @account, start_date: start_date, end_date: end_date)

    transactions = @account.transactions
                           .where(transaction_date: start_date..end_date)
                           .order(:transaction_date)

    # Group transactions by date for easy lookup
    transactions_by_date = transactions.group_by(&:transaction_date)

    # Calculate stats using service
    calendar_stats = CalendarStatsCalculator.call(@account, @date, start_date, end_date, view)

    # Build calendar structure based on view (shared builder)
    calendar_structure = if view == "week"
      builder.week_days
    else
      builder.month_weeks
    end

    render_success({
      view: view,
      date: @date,
      year: @year,
      month: @month,
      start_date: start_date,
      end_date: end_date,
      transactions: transactions.map(&:attributes),
      transactions_by_date: transactions_by_date.transform_values { |txs| txs.map(&:attributes) },
      calendar_structure: calendar_structure,
      end_of_month_balance: @account.end_of_month_balance(@date),
      stats: calendar_stats
    })
  end

  private

end

