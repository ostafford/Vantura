# Service Object: Calculate percentage change with trend indicators
#
# Usage:
#   TrendCalculator.calculate_change(current, previous, context: "neutral")
#
# Parameters:
#   - current [Numeric] Current value
#   - previous [Numeric] Previous value
#   - context [String] Context for determining if increase is good ('expense', 'income', 'neutral')
#
# Returns hash with:
#   - change [Numeric] Absolute change value
#   - change_pct [Float] Percentage change
#   - trend_icon [String] Icon symbol ("↑", "↓", "→")
#   - trend_color [String] CSS class for trend color
#   - formatted [String] Formatted change string
#   - is_positive [Boolean] Whether change is positive based on context
#
class TrendCalculator
  def self.calculate_change(current, previous, context: "neutral")
    return { change: 0, change_pct: 0, trend_icon: "→", trend_color: "text-gray-500", formatted: "No change", is_positive: false } if previous.zero? && current.zero?

    change = current - previous
    change_pct = previous.positive? ? ((change / previous) * 100).round(1) : (current.positive? ? 100.0 : 0.0)

    # Determine if change is positive based on context
    # For expenses: decrease is good (negative change is positive)
    # For income: increase is good (positive change is positive)
    is_positive = case context
    when "expense"
      change.negative? # Spending less is good
    when "income"
      change.positive? # Earning more is good
    else
      change.positive? # Neutral: increase is positive
    end

    trend_icon = if change.positive?
      "↑"
    elsif change.negative?
      "↓"
    else
      "→"
    end

    trend_color = if is_positive
      "text-green-600 dark:text-green-400"
    elsif change.zero?
      "text-gray-500 dark:text-gray-400"
    else
      "text-red-600 dark:text-red-400"
    end

    sign = change.positive? ? "+" : ""
    formatted = "#{sign}#{format_currency(change.abs)} (#{sign}#{change_pct}%)"

    {
      change: change,
      change_pct: change_pct,
      trend_icon: trend_icon,
      trend_color: trend_color,
      formatted: formatted,
      is_positive: is_positive
    }
  end

  def self.format_currency(amount)
    ActionController::Base.helpers.number_to_currency(amount)
  end
end
