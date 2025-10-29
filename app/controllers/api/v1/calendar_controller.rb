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

    # Get appropriate date range based on view
    start_date, end_date = date_range_for_view(view)

    # Generate recurring transactions for this period if needed
    generate_recurring_for_month(start_date, end_date)

    transactions = @account.transactions
                           .where(transaction_date: start_date..end_date)
                           .order(:transaction_date)

    # Group transactions by date for easy lookup
    transactions_by_date = transactions.group_by(&:transaction_date)

    # Calculate stats using service
    calendar_stats = CalendarStatsCalculator.call(@account, @date, start_date, end_date, view)

    # Build calendar structure based on view
    calendar_structure = if view == "week"
      build_week_days_for_api(@date)
    else
      build_calendar_weeks_for_api(@date)
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

  def date_range_for_view(view)
    case view
    when "week"
      week_start = @date.beginning_of_week(:monday)
      week_end = @date.end_of_week(:monday)
      [week_start, week_end]
    else
      month_date_range
    end
  end

  def build_week_days_for_api(date)
    week_days = []
    current_date = date.beginning_of_week(:monday)

    7.times do
      week_days << {
        date: current_date,
        day_name: current_date.strftime("%A"),
        day_number: current_date.day,
        is_today: current_date == Date.today,
        is_current_month: current_date.month == @month
      }
      current_date += 1.day
    end

    week_days
  end

  def build_calendar_weeks_for_api(date)
    weeks = []
    current_date = date.beginning_of_month.beginning_of_week(:monday)
    end_date = date.end_of_month.end_of_week(:monday)

    while current_date <= end_date
      week = []
      7.times do
        week << {
          date: current_date,
          in_current_month: current_date.month == @month
        }
        current_date += 1.day
      end
      weeks << week
    end

    weeks
  end

  def generate_recurring_for_month(start_date, end_date)
    @account.recurring_transactions.active.where(projection_months: "indefinite").each do |recurring|
      current_date = recurring.next_occurrence_date

      while current_date <= end_date
        break if current_date < start_date && recurring.calculate_next_occurrence(current_date) > end_date

        existing = @account.transactions
                           .where(recurring_transaction_id: recurring.id)
                           .where(transaction_date: current_date)
                           .exists?

        unless existing
          if current_date >= start_date && current_date <= end_date && current_date > Date.today
            @account.transactions.create!(
              description: recurring.description,
              amount: recurring.amount,
              category: recurring.category,
              transaction_date: current_date,
              status: "HYPOTHETICAL",
              is_hypothetical: true,
              recurring_transaction_id: recurring.id
            )
          end
        end

        current_date = recurring.calculate_next_occurrence(current_date)
      end
    end
  end
end

