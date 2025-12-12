class CalendarController < ApplicationController
  before_action :authenticate_user!

  def index
    @year = params[:year]&.to_i || Time.current.year
    @month = params[:month]&.to_i || Time.current.month
    @selected_date = params[:selected_date] ? Date.parse(params[:selected_date]) : nil
    @view = params[:view] || "month" # month, week, day

    # Store selected date and view in session for optimized broadcasts
    if @selected_date
      session[:calendar_selected_date] = @selected_date.to_s
    elsif params[:selected_date].nil? && session[:calendar_selected_date]
      # Clear session if explicitly unset
      session.delete(:calendar_selected_date)
    end

    # Store view in session
    session[:calendar_view] = @view

    start_of_month = Date.new(@year, @month, 1)
    end_of_month = start_of_month.end_of_month

    # Calculate date ranges based on view
    case @view
    when "week"
      # Week view: show week containing selected_date or current week
      reference_date = @selected_date || Date.current
      @week_start = reference_date.beginning_of_week
      @week_end = reference_date.end_of_week
      @start_date = @week_start
      @end_date = @week_end
    when "day"
      # Day view: show single day
      reference_date = @selected_date || Date.current
      @start_date = reference_date
      @end_date = reference_date
    else
      # Month view (default)
      @start_date = start_of_month
      @end_date = end_of_month
    end

    # Calculate projection using service
    result = CalendarProjectionService.calculate(
      user: current_user,
      start_date: @start_date,
      end_date: @end_date
    )

    @projection_data = result[:projection_data]
    @weekly_projection = result[:weekly_projection]
    @monthly_projection = result[:monthly_projection]
    @current_balance = result[:current_balance]

    # Get planned transactions for display (already included in projection_data but needed for other uses)
    base_planned = current_user.planned_transactions
                                .by_date_range(@start_date, @end_date)
                                .includes(:category, :transaction_record)

    # Generate occurrences for the date range
    if @view == "month"
      @planned_transactions = base_planned.flat_map { |pt| pt.occurrences_for_month(@year, @month) }
    else
      # For week/day views, generate occurrences for the specific range
      @planned_transactions = base_planned.flat_map { |pt| pt.occurrences_for_date_range(@start_date, @end_date) }
    end

    # Get actual transactions for display
    @actual_transactions = current_user.transactions
                                       .by_settled_date_range(@start_date.beginning_of_day, @end_date.end_of_day)
                                       .includes(:account, :category)

    # If request is for day details only (Turbo Frame), render just the selected day partial
    if (request.headers["Turbo-Frame"] == "day-details" || request.headers["Turbo-Frame"] == "day-details-mobile") && @selected_date
      # Ensure projection data exists for selected date
      # This handles cases where the selected date is outside the current month's projection range
      unless @projection_data[@selected_date]
        # Recalculate for the month containing the selected date
        selected_year = @selected_date.year
        selected_month = @selected_date.month
        start_of_selected_month = Date.new(selected_year, selected_month, 1)
        end_of_selected_month = start_of_selected_month.end_of_month

        result = CalendarProjectionService.calculate(
          user: current_user,
          start_date: start_of_selected_month,
          end_date: end_of_selected_month
        )
        @projection_data = result[:projection_data]
      end

      # Provide fallback projection to prevent nil errors in the partial
      projection = @projection_data[@selected_date] || {
        balance_cents: 0,
        planned_transactions: [],
        actual_transactions: [],
        actual_count: 0
      }

      # Get the frame ID from the request header for the wrapper
      frame_id = request.headers["Turbo-Frame"]

      # Render with turbo_frame_tag wrapper - Turbo requires the response to contain the matching frame tag
      render partial: "calendar/selected_day_frame",
             locals: { date: @selected_date, projection: projection, frame_id: frame_id },
             layout: false
      nil
    end
  end

  def export
    start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.current.beginning_of_month
    end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.current.end_of_month

    # Get planned transactions - include all that could have occurrences in the range
    # For non-recurring: planned_date must be in range
    # For recurring: planned_date could be before range, but occurrences might be in range
    planned = current_user.planned_transactions
                          .where("planned_date <= ? OR is_recurring = ?", end_date, true)
                          .includes(:category)

    # Generate all occurrences for recurring transactions using the model method
    all_planned = planned.flat_map { |pt| pt.occurrences_for_date_range(start_date, end_date) }

    # Get actual transactions
    actual = current_user.transactions
                        .by_settled_date_range(start_date.beginning_of_day, end_date.end_of_day)
                        .includes(:account, :category)

    respond_to do |format|
      format.csv do
        send_data generate_calendar_csv(all_planned, actual, start_date, end_date),
                  filename: "calendar_export_#{start_date}_to_#{end_date}.csv",
                  type: "text/csv"
      end
    end
  end

  private

  def generate_calendar_csv(planned_transactions, actual_transactions, start_date, end_date)
    require "csv"

    CSV.generate(headers: true) do |csv|
      csv << [ "Date", "Type", "Description", "Amount", "Category", "Status", "Account" ]

      # Add planned transactions
      planned_transactions.each do |pt|
        csv << [
          pt[:date].strftime("%Y-%m-%d"),
          "Planned #{pt[:transaction_type]}",
          pt[:description],
          format_amount(pt[:amount_cents], pt[:transaction_type]),
          pt[:category]&.name || "Uncategorized",
          "Planned",
          "N/A"
        ]
      end

      # Add actual transactions
      actual_transactions.each do |t|
        transaction_date = t.settled_at&.to_date || t.created_at_up&.to_date || t.created_at.to_date
        csv << [
          transaction_date.strftime("%Y-%m-%d"),
          t.amount_cents > 0 ? "Income" : "Expense",
          t.description || t.raw_text || "Transaction",
          format_amount(t.amount_cents, t.amount_cents > 0 ? "income" : "expense"),
          t.category&.name || "Uncategorized",
          t.status,
          t.account&.display_name || "Unknown"
        ]
      end
    end
  end

  def format_amount(cents, type)
    amount = (cents.abs / 100.0)
    formatted = "$#{sprintf('%.2f', amount)}"
    type == "expense" || cents < 0 ? "-#{formatted}" : formatted
  end
end
