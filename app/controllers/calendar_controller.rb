class CalendarController < ApplicationController
  def index
    # Get year and month from params, default to current
    @year = params[:year]&.to_i || Date.today.year
    @month = params[:month]&.to_i || Date.today.month
    @date = Date.new(@year, @month, 1)

    # Get account (we'll handle multiple accounts later)
    @account = Account.order(:created_at).last

    return unless @account

    # Get all transactions for this month
    start_date = @date.beginning_of_month
    end_date = @date.end_of_month

    # Reload account to ensure we have fresh transaction data
    @account.reload

    # Generate recurring transactions for this month if needed (for indefinite patterns)
    generate_recurring_for_month(start_date, end_date)

    @transactions = @account.transactions
                            .where(transaction_date: start_date..end_date)
                            .order(:transaction_date)

    # Group transactions by date for easy lookup
    @transactions_by_date = @transactions.group_by(&:transaction_date)

    # Build calendar weeks
    @weeks = build_calendar_weeks

    # Calculate EOW amounts
    @eow_amounts = calculate_eow_amounts
  end

  private

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
