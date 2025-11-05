module CalendarHelper
  # Calculate the progress through the current month
  # @param date [Date] The date to calculate progress for
  # @return [Integer] Percentage through the month (0-100)
  def month_progress(date)
    days_in_month = date.end_of_month.day
    current_day = date.day
    (current_day.to_f / days_in_month * 100).round
  end

  # Format month and year for display
  # @param date [Date] The date to format
  # @return [String] Formatted month and year (e.g., "October 2025")
  def format_month_year(date)
    date.strftime("%B %Y")
  end

  # Get day name for a given date
  # @param date [Date] The date to get day name for
  # @return [String] Day name (e.g., "Monday")
  def day_name(date)
    date.strftime("%A")
  end

  # Check if a date is today
  # @param date [Date] The date to check
  # @return [Boolean] True if date is today
  def today?(date)
    date == Date.today
  end

  # Check if a date is in the past
  # @param date [Date] The date to check
  # @return [Boolean] True if date is in the past
  def past_date?(date)
    date < Date.today
  end

  # Check if a date is in the future
  # @param date [Date] The date to check
  # @return [Boolean] True if date is in the future
  def future_date?(date)
    date > Date.today
  end

  # Format a date range for display
  # @param start_date [Date] Start of the range
  # @param end_date [Date] End of the range
  # @return [String] Formatted date range
  def format_date_range(start_date, end_date)
    if start_date.year == end_date.year
      if start_date.month == end_date.month
        "#{start_date.strftime('%B %d')}-#{end_date.strftime('%d, %Y')}"
      else
        "#{start_date.strftime('%B %d')} - #{end_date.strftime('%B %d, %Y')}"
      end
    else
      "#{start_date.strftime('%B %d, %Y')} - #{end_date.strftime('%B %d, %Y')}"
    end
  end

  def calendar_day_bg_class(total:, in_current_month: true, is_today: false)
    return "bg-gray-50 dark:bg-gray-900" unless in_current_month

    base = if total > 0
      "bg-green-50 dark:bg-green-900/15"
    elsif total < 0
      "bg-red-50 dark:bg-red-900/15"
    else
      "bg-white dark:bg-gray-800"
    end

    today_class = is_today ? " border-2 border-primary-700/40 dark:border-primary-500/40" : ""
    base + today_class
  end

  # Calculate end of week balance for a given account and date
  # @param account [Account] Account to calculate balance for
  # @param date [Date] Date to calculate from
  # @return [Numeric] Projected end of week balance
  def calculate_week_end_balance(account, date)
    week_end = date.end_of_week(:monday)
    week_transactions = account.transactions.where(transaction_date: Date.today..week_end)
    account.current_balance + week_transactions.sum(:amount)
  end

  # Calculate hypothetical total from income and expenses
  # @param income [Numeric] Total income amount
  # @param expenses [Numeric] Total expenses amount
  # @return [Numeric] Net hypothetical amount (income - expenses)
  def calculate_hypothetical_total(income, expenses)
    income - expenses
  end

  # Format date range with transaction count
  # @param start_date [Date] Start of the range
  # @param end_date [Date] End of the range
  # @param count [Integer] Number of transactions
  # @param year [Integer] Year to display
  # @return [Hash] Hash with formatted value, subtitle, and detail
  def format_date_range_with_count(start_date, end_date, count, year)
    {
      value: "#{start_date.strftime('%b %d')} - #{end_date.strftime('%b %d')}".html_safe,
      subtitle: "<span class='font-semibold text-gray-900 dark:text-white'>#{count} transactions</span>".html_safe,
      detail: year.to_s
    }
  end
end
