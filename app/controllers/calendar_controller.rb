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

    # Build calendar structure and date range via shared service
    builder = Calendar::StructureBuilder.new(date: @date, month: @month, week_start: :monday)
    @start_date, @end_date = builder.date_range_for_view(@view)

    # Ensure recurring projection sourced from a single place
    RecurringTransactions::Projector.call(account: @account, start_date: @start_date, end_date: @end_date)

    @transactions = @account.transactions
                            .where(transaction_date: @start_date..@end_date)
                            .order(:transaction_date)

    # Group transactions by date for easy lookup
    @transactions_by_date = @transactions.group_by(&:transaction_date)

    if @view == "week"
      # Build week days for week view (shared builder)
      @week_days = builder.week_days
    else
      # Build calendar weeks for month view (shared builder)
      @weeks = builder.month_weeks

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
    @top_expense_merchants = calendar_stats[:top_expense_merchants]
    @top_income_merchants = calendar_stats[:top_income_merchants]
    @month_top_expense_merchants = calendar_stats[:top_expense_merchants]
    @month_top_income_merchants = calendar_stats[:top_income_merchants]
    @week_top_expense_merchants = calendar_stats[:top_expense_merchants]
    @week_top_income_merchants = calendar_stats[:top_income_merchants]
  end


  private


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
        # For current/future weeks: current balance plus all FUTURE transactions (after today)
        # This includes hypothetical transactions created for future dates
        transactions_until_week = @account.transactions
                                          .where("transaction_date > ? AND transaction_date <= ?",
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
