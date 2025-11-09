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

  # Calculate week switch date for view switching
  # When switching to week view, use today's date to show current week
  # When in week view already, stay on the current date
  # @param view [String] Current view ('week' or 'month')
  # @param date [Date] Current date
  # @return [Date] Date to use for week switch
  def calendar_week_switch_date(view, date)
    view == "week" ? date : Date.today
  end

  # Generate today path based on current view
  # @param view [String] Current view ('week' or 'month')
  # @param today [Date] Today's date
  # @return [String] Path to today's calendar view
  def calendar_today_path(view, today)
    if view == "week"
      calendar_month_path(today.year, today.month, today.day, view: "week")
    else
      calendar_month_path(today.year, today.month, view: "month")
    end
  end

  # Format period end data for display
  # Takes pre-calculated values and formats them for the view
  # @param view [String] Current view ('week' or 'month')
  # @param end_value [Numeric] End of period balance value
  # @param end_date [Date] End of period date
  # @return [Hash] Hash with formatted value, date, and label
  def calendar_period_end_data(view, end_value, end_date)
    {
      value: end_value,
      date: end_date,
      label: view == "week" ? "End of Week" : "End of Month"
    }
  end

  # Count hypothetical transactions for a specific day
  # @param date [Date] The date to count hypothetical transactions for
  # @return [Integer] Number of hypothetical transactions for the day
  def day_hypothetical_count(date)
    return 0 unless day_transactions(date).any?
    day_transactions(date).count(&:is_hypothetical)
  end

  # Check if a day has any hypothetical transactions
  # @param date [Date] The date to check
  # @return [Boolean] True if day has hypothetical transactions
  def day_has_hypothetical?(date)
    day_hypothetical_count(date) > 0
  end

  # Generate view switcher button (Month/Week toggle)
  # @param view [String] Target view ('month' or 'week')
  # @param icon [String] Icon identifier (not used, kept for consistency)
  # @param label [String] Button label text
  # @param active [Boolean] Whether this view is currently active
  # @param path [String] URL path for the button
  # @return [String] HTML for view switcher button
  def view_switcher_button(view:, icon:, label:, active:, path:)
    base_classes = "inline-flex items-center justify-center w-10 h-10 md:px-4 md:py-2 md:w-auto md:h-auto rounded-md text-xs md:text-sm font-medium transition-all"
    active_classes = "bg-primary-700 text-white shadow-sm"
    inactive_classes = "text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700"

    classes = "#{base_classes} #{active ? active_classes : inactive_classes}"

    link_to path, class: classes, data: { view: view, turbo_frame: "calendar_content", calendar_target: "viewLink" } do
      concat month_icon_svg if view == "month"
      concat week_icon_svg if view == "week"
      concat content_tag(:span, label, class: "hidden sm:inline")
    end
  end

  # Generate add transaction button
  # @return [String] HTML for add transaction button
  def add_transaction_button
    button_tag type: "button",
               id: "calendar-add-transaction-button",
               data: { action: "click->modal#open" },
               class: "inline-flex items-center justify-center w-10 h-10 bg-primary-700 text-white rounded-lg hover:bg-primary-900 hover:shadow-lg hover:scale-105 transition-all font-medium shadow-md",
               title: "Add Transaction",
               aria: { label: "Add new transaction" } do
      add_icon_svg
    end
  end

  # Get spending pace indicator status and color classes
  # @param spending_rate [Numeric] Spending rate percentage (0-100+)
  # @return [Hash] Hash with status, color classes, and bar color
  def spending_pace_indicator(spending_rate)
    if spending_rate > 100
      {
        status: "Ahead of pace",
        pace_color: "text-red-600 dark:text-red-400",
        bar_color: "bg-red-400",
        indicator_bg: "bg-red-100 dark:bg-red-900/30",
        indicator_text: "text-red-700 dark:text-red-400"
      }
    elsif spending_rate > 75
      {
        status: "On track",
        pace_color: "text-yellow-600 dark:text-yellow-400",
        bar_color: "bg-yellow-400",
        indicator_bg: "bg-yellow-100 dark:bg-yellow-900/30",
        indicator_text: "text-yellow-700 dark:text-yellow-400"
      }
    else
      {
        status: "Behind pace",
        pace_color: "text-green-600 dark:text-green-400",
        bar_color: "bg-green-400",
        indicator_bg: "bg-green-100 dark:bg-green-900/30",
        indicator_text: "text-green-700 dark:text-green-400"
      }
    end
  end

  # Format spending pace comparison text
  # @param velocity_change_pct [Numeric] Percentage change from historical average
  # @return [String] Formatted comparison text
  def format_spending_pace_comparison(velocity_change_pct)
    if velocity_change_pct.abs < 0.1
      "Similar to 6-month average"
    elsif velocity_change_pct > 0
      "#{velocity_change_pct.abs.round(1)}% above 6-month average"
    else
      "#{velocity_change_pct.abs.round(1)}% below 6-month average"
    end
  end

  # Combine and format upcoming transactions list
  # @param upcoming_recurring_expenses [Array] Array of recurring expense records
  # @param upcoming_recurring_income [Array] Array of recurring income records
  # @param upcoming_hypothetical_expenses [Array] Array of hypothetical expense transactions
  # @param upcoming_hypothetical_income [Array] Array of hypothetical income transactions
  # @return [Hash] Hash with combined and sorted transactions
  def upcoming_transactions_list(upcoming_recurring_expenses, upcoming_recurring_income, upcoming_hypothetical_expenses, upcoming_hypothetical_income)
    all_expenses = []
    all_income = []

    # Add recurring expenses with their next occurrence date
    upcoming_recurring_expenses.each do |recurring|
      all_expenses << {
        description: recurring.description,
        amount: recurring.amount.abs,
        date: recurring.next_occurrence_date,
        type: 'recurring'
      }
    end

    # Add hypothetical expenses
    upcoming_hypothetical_expenses.each do |transaction|
      all_expenses << {
        description: transaction.description,
        amount: transaction.amount.abs,
        date: transaction.transaction_date,
        type: 'hypothetical'
      }
    end

    # Add recurring income
    upcoming_recurring_income.each do |recurring|
      all_income << {
        description: recurring.description,
        amount: recurring.amount,
        date: recurring.next_occurrence_date,
        type: 'recurring'
      }
    end

    # Add hypothetical income
    upcoming_hypothetical_income.each do |transaction|
      all_income << {
        description: transaction.description,
        amount: transaction.amount,
        date: transaction.transaction_date,
        type: 'hypothetical'
      }
    end

    # Sort by date
    {
      expenses: all_expenses.sort_by { |t| t[:date] },
      income: all_income.sort_by { |t| t[:date] }
    }
  end

  private

  # SVG icon for month view button
  # @return [String] SVG HTML for calendar month icon
  def month_icon_svg
    content_tag :svg, class: "w-5 h-5 md:w-4 md:h-4 md:mr-2", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24" do
      content_tag :path, "", stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
    end
  end

  # SVG icon for week view button
  # @return [String] SVG HTML for calendar week icon
  def week_icon_svg
    content_tag :svg, class: "w-5 h-5 md:w-4 md:h-4 md:mr-2", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24" do
      content_tag :path, "", stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
    end
  end

  # SVG icon for add transaction button
  # @return [String] SVG HTML for plus/add icon
  def add_icon_svg
    content_tag :svg, class: "w-5 h-5", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24" do
      content_tag :path, "", stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M12 4v16m8-8H4"
    end
  end
end
