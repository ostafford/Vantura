# Service Object: Calculate spending pace metrics for a given month
#
# Usage:
#   SpendingPaceCalculator.calculate(transactions_data)
#
# Parameters:
#   - transactions_data [Hash] Hash containing :date, :expense_total keys
#
# Returns hash with:
#   - is_current_month [Boolean] Whether viewing current month
#   - days_elapsed [Integer] Days elapsed in the month
#   - days_in_month [Integer] Total days in the month
#   - month_progress [Float] Percentage of month elapsed (0-100)
#   - expected_expenses [Float] Expected expenses for full month
#   - spending_rate [Float] Spending rate percentage (0-100+)
#
class SpendingPaceCalculator
  def self.calculate(transactions_data)
    date = transactions_data[:date]
    expense_total = transactions_data[:expense_total] || 0

    # Check if viewing current month by comparing year and month
    # This is more reliable than date equality comparison
    is_current_month = date.year == Date.today.year && date.month == Date.today.month

    days_elapsed = is_current_month ? Date.today.day : date.end_of_month.day
    days_in_month = date.end_of_month.day
    month_progress = (days_elapsed.to_f / days_in_month * 100).round(1)

    # Calculate if spending pace is on track
    # For current month: project full month based on current pace
    # For past months: compare actual vs actual (always 100%)
    expected_expenses = if is_current_month && days_elapsed > 0
      (expense_total / days_elapsed * days_in_month)
    else
      expense_total
    end

    spending_rate = expected_expenses > 0 ? (expense_total / expected_expenses * 100) : 0

    {
      is_current_month: is_current_month,
      days_elapsed: days_elapsed,
      days_in_month: days_in_month,
      month_progress: month_progress,
      expected_expenses: expected_expenses,
      spending_rate: spending_rate
    }
  end
end
