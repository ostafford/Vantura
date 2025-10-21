class CalendarController < ApplicationController
  include AccountLoadable
  include DateParseable

  def index
    # Parse date parameters
    parse_month_params

    # Set view (month or week)
    @view = params[:view] || session[:calendar_view] || "month"
    session[:calendar_view] = @view  # Remember user's preference

    # If switching to week view without a day parameter, use today
    if @view == "week" && !params[:day]
      @date = Date.today
      @year = @date.year
      @month = @date.month
    end

    # Load account or return early if not found
    load_account_or_return
    return unless @account

    # Get appropriate date range based on view
    start_date, end_date = date_range_for_view

    # Generate recurring transactions for this period if needed (for indefinite patterns)
    generate_recurring_for_month(start_date, end_date)

    @transactions = @account.transactions
                            .where(transaction_date: start_date..end_date)
                            .order(:transaction_date)

    # Group transactions by date for easy lookup
    @transactions_by_date = @transactions.group_by(&:transaction_date)

    if @view == "week"
      # Build week days for week view
      @week_days = build_week_days
    else
      # Build calendar weeks for month view
      @weeks = build_calendar_weeks

      # Calculate EOW amounts (only for month view)
      @eow_amounts = calculate_eow_amounts
    end

    # Calculate End of Month balance using Account model method
    @end_of_month_balance = @account.end_of_month_balance(@date)
  end

  private

  def date_range_for_view
    case @view
    when "week"
      # Get the week containing the current date
      week_start = @date.beginning_of_week(:monday)
      week_end = @date.end_of_week(:monday)
      [ week_start, week_end ]
    else
      # Default to month view
      month_date_range
    end
  end

  def build_week_days
    week_days = []
    current_date = @date.beginning_of_week(:monday)

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

  def build_calendar_weeks
    weeks = []
    current_date = @date.beginning_of_month.beginning_of_week(:monday)
    end_date = @date.end_of_month.end_of_week(:monday)

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

  def calculate_eow_amounts
    return [] unless @account

    eow_amounts = []
    today = Date.today
    current_balance = @account.current_balance

    @weeks.each do |week|
      # Get the last day of the week (Sunday)
      week_end_date = week.last[:date]

      # Calculate balance at end of this week
      if week_end_date < today
        # For past weeks: current balance minus all transactions from week_end_date to today
        transactions_after_week = @account.transactions
                                          .where("transaction_date > ? AND transaction_date <= ?",
                                                 week_end_date, today)
        balance_at_eow = current_balance - transactions_after_week.sum(:amount)
      else
        # For current/future weeks: current balance plus all transactions from today onwards to week_end_date
        # This includes hypothetical transactions created for today or future dates
        transactions_until_week = @account.transactions
                                          .where("transaction_date >= ? AND transaction_date <= ?",
                                                 today, week_end_date)
        balance_at_eow = current_balance + transactions_until_week.sum(:amount)
      end

      eow_amounts << balance_at_eow
    end

    eow_amounts
  end

  def day_total(date)
    return 0 unless @transactions_by_date[date]
    @transactions_by_date[date].sum(&:amount)
  end
  helper_method :day_total

  def day_transactions(date)
    @transactions_by_date[date] || []
  end
  helper_method :day_transactions

  def generate_recurring_for_month(start_date, end_date)
    # Only generate for active, indefinite recurring patterns
    @account.recurring_transactions.active.where(projection_months: "indefinite").each do |recurring|
      # Check if we need to generate transactions for this month
      current_date = recurring.next_occurrence_date

      while current_date <= end_date
        # Skip if already past
        break if current_date < start_date && recurring.calculate_next_occurrence(current_date) > end_date

        # Check if transaction already exists for this date
        existing = @account.transactions
                           .where(recurring_transaction_id: recurring.id)
                           .where(transaction_date: current_date)
                           .exists?

        unless existing
          # Generate transaction for this occurrence
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

        # Move to next occurrence
        current_date = recurring.calculate_next_occurrence(current_date)
      end
    end
  end
end
