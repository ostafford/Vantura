# Service Object: Calculate spending velocity and patterns
#
# Usage:
#   calculator = SpendingVelocityCalculator.new(account)
#   velocity = calculator.current_velocity
#   average = calculator.historical_average(6)
#
# Purpose: Calculate spending rate and patterns to identify savings opportunities
#
class SpendingVelocityCalculator
  def initialize(account, reference_date = Date.today)
    @account = account
    @reference_date = reference_date
    @current_month_start = @reference_date.beginning_of_month
    @current_month_end = @reference_date.end_of_month
  end

  # Current spending velocity (daily rate for current month)
  def current_velocity
    @current_velocity ||= begin
      days_elapsed = [(@reference_date - @current_month_start).to_i + 1, 1].max
      current_spending = current_month_spending
      {
        daily_rate: (current_spending / days_elapsed.to_f).round(2),
        total_spent: current_spending,
        days_elapsed: days_elapsed,
        days_remaining: (@current_month_end - @reference_date).to_i
      }
    end
  end

  # Historical average spending velocity over specified months
  def historical_average(months = 6)
    @historical_averages ||= {}
    @historical_averages[months] ||= begin
      months_to_include = months.to_i.clamp(1, 12)
      total_spending = 0.0
      total_days = 0

      months_to_include.times do |i|
        month_date = @reference_date - i.months
        month_start = month_date.beginning_of_month
        month_end = month_date.end_of_month

        month_spending = @account.transactions
                                 .real
                                 .expenses
                                 .where(transaction_date: month_start..month_end)
                                 .sum(:amount)
                                 .abs

        days_in_month = (month_end - month_start).to_i + 1
        total_spending += month_spending
        total_days += days_in_month
      end

      average_daily = total_days.positive? ? (total_spending / total_days.to_f).round(2) : 0.0

      {
        average_daily_rate: average_daily,
        total_spending: total_spending,
        months_included: months_to_include,
        total_days: total_days
      }
    end
  end

  # Percentage change in velocity
  def velocity_change_pct(months = 6)
    current = current_velocity[:daily_rate]
    historical = historical_average(months)[:average_daily_rate]

    return 0 if historical.zero?

    ((current - historical) / historical * 100).round(1)
  end

  # Projected month-end spending based on current velocity
  def projected_month_end_spending
    @projected_month_end_spending ||= begin
      velocity = current_velocity
      days_remaining = velocity[:days_remaining]
      projected_remaining = velocity[:daily_rate] * days_remaining
      total_projected = velocity[:total_spent] + projected_remaining

      {
        projected_total: total_projected.round(2),
        current_spent: velocity[:total_spent],
        projected_remaining: projected_remaining.round(2),
        days_remaining: days_remaining
      }
    end
  end

  # Calculate savings opportunity if current velocity is maintained
  def savings_opportunity(months = 6)
    @savings_opportunity ||= {}
    @savings_opportunity[months] ||= begin
      historical_avg = historical_average(months)
      projected = projected_month_end_spending
      historical_monthly_avg = historical_avg[:average_daily_rate] * 30.44 # Average days per month

      if projected[:projected_total] < historical_monthly_avg
        potential_savings = historical_monthly_avg - projected[:projected_total]
        {
          potential_savings: potential_savings.round(2),
          current_projection: projected[:projected_total],
          historical_average: historical_monthly_avg.round(2),
          opportunity_exists: true
        }
      else
        {
          potential_savings: 0,
          current_projection: projected[:projected_total],
          historical_average: historical_monthly_avg.round(2),
          opportunity_exists: false
        }
      end
    end
  end

  private

  def current_month_spending
    @current_month_spending ||= @account.transactions
                                       .real
                                       .expenses
                                       .where(transaction_date: @current_month_start..@reference_date)
                                       .sum(:amount)
                                       .abs
  end
end

