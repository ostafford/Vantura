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

    # Set current_date alias for consistency with other controllers
    @current_date = @date

    # Get appropriate date range based on view
    @start_date, @end_date = date_range_for_view

    # Generate recurring transactions for this period if needed (for indefinite patterns)
    generate_recurring_for_month(@start_date, @end_date)

    @transactions = @account.transactions
                            .where(transaction_date: @start_date..@end_date)
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

    # Calculate additional stats for cards using service object
    calendar_stats = CalendarStatsCalculator.call(@account, @date, @start_date, @end_date, @view)
    @hypothetical_income = calendar_stats[:hypothetical_income]
    @hypothetical_expenses = calendar_stats[:hypothetical_expenses]
    @actual_income = calendar_stats[:actual_income]
    @actual_expenses = calendar_stats[:actual_expenses]
    @transaction_count = calendar_stats[:transaction_count]
    @month_day = calendar_stats[:month_day]
    @total_days = calendar_stats[:total_days]
    @progress_pct = calendar_stats[:progress_pct]
    @week_income = calendar_stats[:week_income]
    @week_expenses = calendar_stats[:week_expenses]
    @week_transaction_count = calendar_stats[:week_transaction_count]
    @week_total = calendar_stats[:week_total]
    @week_expense_count = calendar_stats[:week_expense_count]
    @week_income_count = calendar_stats[:week_income_count]
    @month_expense_count = calendar_stats[:month_expense_count]
    @month_income_count = calendar_stats[:month_income_count]
    @top_expense_merchants = calendar_stats[:top_expense_merchants]
    @top_income_merchants = calendar_stats[:top_income_merchants]
    @month_top_expense_merchants = calendar_stats[:top_expense_merchants]
    @month_top_income_merchants = calendar_stats[:top_income_merchants]
    @week_top_expense_merchants = calendar_stats[:top_expense_merchants]
    @week_top_income_merchants = calendar_stats[:top_income_merchants]
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

    today = Date.today
    current_balance = @account.current_balance

    # Determine span we need cumulative sums for
    week_end_dates = @weeks.map { |w| w.last[:date] }
    min_date = [week_end_dates.min, today].min
    max_date = [week_end_dates.max, today].max

    # Single grouped query for sums per date across the full span
    sums_by_date = @account.transactions
                           .where(transaction_date: min_date..max_date)
                           .group(:transaction_date)
                           .sum(:amount)

    # Build cumulative sums for each date in the span
    cumulative_by_date = {}
    running_total = 0
    (min_date..max_date).each do |date|
      running_total += (sums_by_date[date] || 0)
      cumulative_by_date[date] = running_total
    end

    # Helper to get total sum between (a, b]
    get_sum_between = lambda do |a_date, b_date|
      return 0 if b_date <= a_date
      (cumulative_by_date[b_date] || 0) - (cumulative_by_date[a_date] || 0)
    end

    @weeks.map do |week|
      week_end_date = week.last[:date]
      if week_end_date < today
        # Past week: current balance minus sums from (week_end_date, today]
        current_balance - get_sum_between.call(week_end_date, today)
      else
        # Current/future week: current balance plus sums from (today, week_end_date]
        current_balance + get_sum_between.call(today, week_end_date)
      end
    end
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
    existing_hypotheticals = @account.transactions
                                     .hypothetical
                                     .where(transaction_date: start_date..end_date)
                                     .where.not(recurring_transaction_id: nil)
                                     .pluck(:recurring_transaction_id, :transaction_date)
                                     .to_set

    @account.recurring_transactions.active.where(projection_months: "indefinite").each do |recurring|
      # Check if we need to generate transactions for this month
      current_date = recurring.next_occurrence_date

      while current_date <= end_date
        # Skip if already past
        break if current_date < start_date && recurring.calculate_next_occurrence(current_date) > end_date

        # Check if transaction already exists for this date (in-memory set)
        unless existing_hypotheticals.include?([recurring.id, current_date])
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
            existing_hypotheticals.add([recurring.id, current_date])
          end
        end

        # Move to next occurrence
        current_date = recurring.calculate_next_occurrence(current_date)
      end
    end
  end
end
