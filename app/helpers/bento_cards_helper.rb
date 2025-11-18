module BentoCardsHelper
  # Calculate projection card styling and display values
  # @param title [String] Card title
  # @param value [String] Formatted value to display
  # @param change [Numeric] Net cash flow change (income - expenses)
  # @param balance [Numeric] Actual balance value
  # @param days_remaining [Integer] Days remaining in period
  # @param upcoming_recurring_expenses [Array] Array of recurring expense records
  # @param upcoming_recurring_income [Array] Array of recurring income records
  # @return [Hash] Hash containing all calculated values for the projection card
  def projection_card_data(title:, value:, change:, balance:, days_remaining: 0, upcoming_recurring_expenses: [], upcoming_recurring_income: [], current_balance: nil, **options)
    change_is_positive = change >= 0
    balance_is_positive = balance >= 0

    # Format change value
    if change.is_a?(Numeric)
      change_absolute_display = "$#{format('%.2f', change.abs)}"
      change_display_signed =
        if change.positive?
          "+#{change_absolute_display}"
        elsif change.negative?
          "-#{change_absolute_display}"
        else
          change_absolute_display
        end
      change_display = change_absolute_display
    else
      change_display_signed = change.to_s
      change_display = change_display_signed
    end

    # Badge color based on NET CASH FLOW (Income - Expenses)
    badge_bg = change_is_positive ? "amount-positive-bg" : "amount-negative-bg"
    badge_text = change_is_positive ? "amount-positive" : "amount-negative"
    icon_path = change_is_positive ?
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 10l7-7m0 0l7 7m-7-7v18" />' :
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 14l-7 7m0 0l-7-7m7 7V3" />'

    # Value color based on ACTUAL BALANCE (positive or negative)
    value_color = balance_is_positive ? "amount-positive" : "amount-negative"

    # Calculate breakdown between current balance and upcoming net impact
    current_balance_value = current_balance.nil? ? balance : current_balance
    upcoming_net = balance - current_balance_value
    upcoming_net_is_positive = upcoming_net >= 0
    upcoming_net_display = "$#{format('%.2f', upcoming_net.abs)}"
    upcoming_net_display_signed =
      if upcoming_net.positive?
        "+#{upcoming_net_display}"
      elsif upcoming_net.negative?
        "-#{upcoming_net_display}"
      else
        upcoming_net_display
      end

    # Calculate recurring totals
    recurring_totals = calculate_recurring_totals(upcoming_recurring_expenses, upcoming_recurring_income)

    {
      title: title,
      value: value,
      change: change,
      balance: balance,
      change_is_positive: change_is_positive,
      balance_is_positive: balance_is_positive,
      change_display: change_display,
      change_display_signed: change_display_signed,
      badge_bg: badge_bg,
      badge_text: badge_text,
      icon_path: icon_path,
      value_color: value_color,
      days_remaining: days_remaining,
      current_balance_value: current_balance_value,
      upcoming_net: upcoming_net,
      upcoming_net_is_positive: upcoming_net_is_positive,
      upcoming_net_display: upcoming_net_display,
      upcoming_net_display_signed: upcoming_net_display_signed,
      show_details: days_remaining.to_i >= 0,
      **recurring_totals,
      **options
    }
  end

  # Calculate totals for recurring expenses and income
  # @param expenses [Array] Array of recurring expense records
  # @param income [Array] Array of recurring income records
  # @return [Hash] Hash containing expense_total, income_total, total_items, and net
  def calculate_recurring_totals(expenses, income)
    recurring_expense_total = expenses.sum { |r| r.amount.abs }
    recurring_income_total = income.sum { |r| r.amount }
    total_recurring_items = expenses.count + income.count
    recurring_net = recurring_income_total - recurring_expense_total

    {
      recurring_expense_total: recurring_expense_total,
      recurring_income_total: recurring_income_total,
      total_recurring_items: total_recurring_items,
      recurring_net: recurring_net,
      has_recurring_expenses: expenses.any?,
      has_recurring_income: income.any?,
      has_recurring_items: expenses.any? || income.any?
    }
  end

  # Get CSS class for balance color based on sign
  # @param balance [Numeric] Balance value
  # @return [String] CSS class for balance color
  def balance_color_class(balance)
    balance >= 0 ? "text-green-400 dark:text-green-300" : "text-red-400 dark:text-red-300"
  end

  # Format balance with color class
  # @param balance [Numeric] Balance value
  # @param size_class [String] Size class for text (default: 'text-3xl font-bold')
  # @return [String] HTML span with formatted balance and color class
  def formatted_balance_with_color(balance, size_class: "text-3xl font-bold")
    color_class = balance_color_class(balance)
    content_tag :span, number_to_currency(balance), class: "#{size_class} #{color_class}"
  end

  # Calculate hypothetical total (income - expenses)
  # @param hypothetical_income [Numeric] Hypothetical income amount
  # @param hypothetical_expenses [Numeric] Hypothetical expenses amount
  # @return [Numeric] Net hypothetical total
  def calculate_hypothetical_total(hypothetical_income, hypothetical_expenses)
    hypothetical_income - hypothetical_expenses
  end

  # Generate period text for transaction type cards
  # @param period [String] Period identifier ('week', 'search', or 'month')
  # @return [String] Human-readable period text
  def period_text(period)
    case period
    when "week"
      "This week"
    when "search"
      "Search Results"
    else
      "This month"
    end
  end
end
