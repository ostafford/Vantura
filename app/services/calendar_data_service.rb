# Service Object: Prepare all data needed for calendar index page
#
# Usage:
#   data = CalendarDataService.call(@account, date_params, view, session_view)
#   data = CalendarDataService.call(@account, { year: 2024, month: 10 }, "month", "month")
#
# Returns hash with:
#   - date: Parsed/calculated date
#   - year: Year for the date
#   - month: Month for the date
#   - view: The view type ("week" or "month")
#   - start_date: Start date for the range
#   - end_date: End date for the range
#   - transactions: Transactions in the date range
#   - transactions_by_date: Transactions grouped by date
#   - weeks: Calendar weeks for month view (nil for week view)
#   - week_days: Week days for week view (nil for month view)
#   - eow_amounts: End of week amounts for month view (nil for week view)
#   - week_end_balance: Week end balance for week view (nil for month view)
#   - end_of_month_balance: End of month balance
#   - calendar_stats: Stats from CalendarStatsCalculator
#
class CalendarDataService < ApplicationService
  def initialize(account, date_params, view, session_view = nil)
    @account = account
    @date_params = date_params
    @view = view || "month"
  end

  def call
    # Generate recurring transactions for this period if needed
    generate_recurring_for_month(start_date, end_date)

    result = {
      date: date,
      year: year,
      month: month,
      view: @view,
      start_date: start_date,
      end_date: end_date,
      transactions: transactions,
      transactions_by_date: transactions_by_date,
      end_of_month_balance: end_of_month_balance
    }

    if @view == "week"
      result.merge!(
        week_days: build_week_days,
        week_end_balance: calculate_week_end_balance,
        weeks: nil,
        eow_amounts: nil
      )
    else
      weeks = build_calendar_weeks
      result.merge!(
        weeks: weeks,
        eow_amounts: calculate_eow_amounts(weeks),
        week_days: nil,
        week_end_balance: nil
      )
    end

    # Add calendar stats
    result[:calendar_stats] = CalendarStatsCalculator.call(@account, date, start_date, end_date, @view)

    # Add upcoming transactions data (month view only)
    if @view == "month"
      result[:upcoming_transactions] = get_upcoming_transactions
    end

    result
  end

  private

  def date
    @date ||= begin
      if @view == "week" && !@date_params[:day]
        Date.today
      elsif @date_params[:year].present? && @date_params[:month].present?
        y = @date_params[:year].to_i
        m = @date_params[:month].to_i
        day = @date_params[:day]&.to_i || 1
        begin
          Date.new(y, m, day)
        rescue ArgumentError
          Date.today
        end
      else
        Date.today
      end
    end
  end

  def year
    @year ||= date.year
  end

  def month
    @month ||= date.month
  end

  def start_date
    @start_date ||= begin
      if @view == "week"
        date.beginning_of_week(:monday)
      else
        date.beginning_of_month
      end
    end
  end

  def end_date
    @end_date ||= begin
      if @view == "week"
        date.end_of_week(:monday)
      else
        date.end_of_month
      end
    end
  end

  def transactions
    @transactions ||= @account.transactions
                             .where(transaction_date: start_date..end_date)
                             .includes(:recurring_transaction)
                             .order(:transaction_date)
                             .to_a
  end

  def transactions_by_date
    @transactions_by_date ||= transactions.group_by(&:transaction_date)
  end

  def build_week_days
    week_days = []
    current_date = date.beginning_of_week(:monday)

    7.times do
      week_days << {
        date: current_date,
        day_name: current_date.strftime("%A"),
        day_number: current_date.day,
        is_today: current_date == Date.today,
        is_current_month: current_date.month == month
      }
      current_date += 1.day
    end

    week_days
  end

  def build_calendar_weeks
    weeks = []
    current_date = date.beginning_of_month.beginning_of_week(:monday)
    end_date_cal = date.end_of_month.end_of_week(:monday)

    while current_date <= end_date_cal
      week = []
      7.times do
        week << {
          date: current_date,
          in_current_month: current_date.month == month
        }
        current_date += 1.day
      end
      weeks << week
    end

    weeks
  end

  def calculate_eow_amounts(weeks)
    return [] unless @account

    today = Date.today
    current_balance = @account.current_balance

    # Determine span we need cumulative sums for
    week_end_dates = weeks.map { |w| w.last[:date] }
    min_date = [ week_end_dates.min, today ].min
    max_date = [ week_end_dates.max, today ].max

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

    weeks.map do |week|
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

  def calculate_week_end_balance
    return 0 unless @account

    today = Date.today
    current_balance = @account.current_balance
    week_end_date = date.end_of_week(:monday)

    # Match the pattern from end_of_month_balance and calculate_eow_amounts
    if week_end_date < today
      # Past week: current balance minus sums from (week_end_date, today]
      transactions_after_week = @account.transactions
                                        .where("transaction_date > ? AND transaction_date <= ?",
                                               week_end_date, today)
      current_balance - transactions_after_week.sum(:amount)
    else
      # Current/future week: current balance plus sums from (today, week_end_date]
      transactions_until_week_end = @account.transactions
                                             .where("transaction_date > ? AND transaction_date <= ?",
                                                    today, week_end_date)
      current_balance + transactions_until_week_end.sum(:amount)
    end
  end

  def end_of_month_balance
    @end_of_month_balance ||= @account.end_of_month_balance(date)
  end

  def generate_recurring_for_month(start_date_range, end_date_range)
    # Only generate for active, indefinite recurring patterns
    existing_hypotheticals = @account.transactions
                                     .hypothetical
                                     .where(transaction_date: start_date_range..end_date_range)
                                     .where.not(recurring_transaction_id: nil)
                                     .pluck(:recurring_transaction_id, :transaction_date)
                                     .to_set

    @account.recurring_transactions.active.where(projection_months: "indefinite").each do |recurring|
      # Check if we need to generate transactions for this month
      current_date = recurring.next_occurrence_date

      while current_date <= end_date_range
        # Skip if already past
        break if current_date < start_date_range && recurring.calculate_next_occurrence(current_date) > end_date_range

        # Check if transaction already exists for this date (in-memory set)
        unless existing_hypotheticals.include?([ recurring.id, current_date ])
          # Generate transaction for this occurrence
          if current_date >= start_date_range && current_date <= end_date_range && current_date > Date.today
            @account.transactions.create!(
              description: recurring.description,
              amount: recurring.amount,
              category: recurring.category,
              transaction_date: current_date,
              status: "HYPOTHETICAL",
              is_hypothetical: true,
              recurring_transaction_id: recurring.id
            )
            existing_hypotheticals.add([ recurring.id, current_date ])
          end
        end

        # Move to next occurrence
        current_date = recurring.calculate_next_occurrence(current_date)
      end
    end
  end

  # Get upcoming transactions (recurring + standalone hypothetical)
  def get_upcoming_transactions
    today = Date.today
    
    # Get upcoming recurring transactions
    upcoming_recurring = RecurringTransactionsService.upcoming(@account, end_date)
    
    # Get standalone hypothetical transactions (not from recurring patterns)
    # Only get future transactions
    standalone_hypothetical = @account.transactions
                                      .hypothetical
                                      .where(transaction_date: today..end_date)
                                      .where(recurring_transaction_id: nil)
                                      .order(:transaction_date)
                                      .to_a
    
    # Separate hypothetical by expense/income
    hypothetical_expenses = standalone_hypothetical.select { |t| t.amount < 0 }
    hypothetical_income = standalone_hypothetical.select { |t| t.amount > 0 }
    
    {
      upcoming_recurring_expenses: upcoming_recurring[:expenses],
      upcoming_recurring_income: upcoming_recurring[:income],
      upcoming_hypothetical_expenses: hypothetical_expenses,
      upcoming_hypothetical_income: hypothetical_income
    }
  end
end
