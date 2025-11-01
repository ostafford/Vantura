# Service Object: Calculate project statistics including MoM, YoY, and projections
#
# Usage:
#   stats = ProjectStatsCalculator.call(project)
#   stats = ProjectStatsCalculator.call(project, Date.today)
#
# Returns hash with:
#   - current_month_total_cents: Total expenses for current month
#   - last_month_total_cents: Total expenses for previous month
#   - mom_change_cents: Dollar change (current - last)
#   - mom_change_pct: Percentage change (MoM)
#   - ytd_this_year_cents: Year-to-date this year (Jan through current month)
#   - ytd_last_year_cents: Year-to-date last year (Jan through same month)
#   - yoy_change_cents: Dollar change (YTD this year - YTD last year)
#   - yoy_change_pct: Percentage change (YoY)
#   - projected_next_month_cents: Weighted projection (50% last, 30% 2 ago, 20% 3 ago)
#
class ProjectStatsCalculator < ApplicationService
  def initialize(project, reference_date = Date.today)
    @project = project
    @reference_date = reference_date
    @current_month_start = @reference_date.beginning_of_month
    @current_month_end = @reference_date.end_of_month
    @last_month_start = @reference_date.prev_month.beginning_of_month
    @last_month_end = @reference_date.prev_month.end_of_month
  end

  def call
    {
      # Current month stats
      current_month_total_cents: current_month_total_cents,

      # Month-over-month stats
      last_month_total_cents: last_month_total_cents,
      mom_change_cents: mom_change_cents,
      mom_change_pct: mom_change_pct,

      # Year-over-year stats (YTD)
      ytd_this_year_cents: ytd_this_year_cents,
      ytd_last_year_cents: ytd_last_year_cents,
      yoy_change_cents: yoy_change_cents,
      yoy_change_pct: yoy_change_pct,

      # Projection
      projected_next_month_cents: projected_next_month_cents,

      # Top categories
      top_categories_current_month: top_categories_current_month,
      top_categories_ytd_this_year: top_categories_ytd_this_year,
      top_categories_last_month: top_categories_last_month
    }
  end

  private

  def expenses_relation
    @expenses_relation ||= @project.project_expenses.where.not(due_on: nil)
  end

  # Current month total
  def current_month_total_cents
    @current_month_total_cents ||= expenses_relation
      .where(due_on: @current_month_start..@current_month_end)
      .sum(:total_cents)
  end

  # Last month total
  def last_month_total_cents
    @last_month_total_cents ||= expenses_relation
      .where(due_on: @last_month_start..@last_month_end)
      .sum(:total_cents)
  end

  # Month-over-month change in cents
  def mom_change_cents
    @mom_change_cents ||= current_month_total_cents - last_month_total_cents
  end

  # Month-over-month percentage change
  def mom_change_pct
    return 0.0 if last_month_total_cents.zero?
    ((mom_change_cents.to_f / last_month_total_cents) * 100).round(1)
  end

  # Year-to-date this year (Jan through current month)
  def ytd_this_year_cents
    @ytd_this_year_cents ||= begin
      year_start = Date.new(@reference_date.year, 1, 1)
      expenses_relation
        .where(due_on: year_start..@current_month_end)
        .sum(:total_cents)
    end
  end

  # Year-to-date last year (Jan through same month last year)
  def ytd_last_year_cents
    @ytd_last_year_cents ||= begin
      last_year = @reference_date.year - 1
      last_year_start = Date.new(last_year, 1, 1)
      last_year_same_month_end = Date.new(last_year, @reference_date.month, -1)
      expenses_relation
        .where(due_on: last_year_start..last_year_same_month_end)
        .sum(:total_cents)
    end
  end

  # Year-over-year change in cents
  def yoy_change_cents
    @yoy_change_cents ||= ytd_this_year_cents - ytd_last_year_cents
  end

  # Year-over-year percentage change
  def yoy_change_pct
    return 0.0 if ytd_last_year_cents.zero?
    ((yoy_change_cents.to_f / ytd_last_year_cents) * 100).round(1)
  end

  # Projected next month using weighted average:
  # 50% last month, 30% 2 months ago, 20% 3 months ago
  def projected_next_month_cents
    @projected_next_month_cents ||= begin
      months_data = last_three_months_totals

      # If we have 3 months of data, use weighted average
      if months_data.size == 3
        (months_data[0] * 0.5) + (months_data[1] * 0.3) + (months_data[2] * 0.2)
      # If we have 2 months, use 70%/30% split
      elsif months_data.size == 2
        (months_data[0] * 0.7) + (months_data[1] * 0.3)
      # If we have 1 month, just use that
      elsif months_data.size == 1
        months_data[0]
      # No data available
      else
        0
      end
    end.round
  end

  # Get totals for last 3 complete months (excluding current month)
  def last_three_months_totals
    totals = []
    # Start from last month and go back 3 months
    3.times do |i|
      month_date = @reference_date.prev_month(i + 1)
      month_start = month_date.beginning_of_month
      month_end = month_date.end_of_month
      total = expenses_relation
        .where(due_on: month_start..month_end)
        .sum(:total_cents)
      totals << total if total > 0 || i == 0 # Include even if zero for first month
    end
    totals
  end

  # Top 3 categories from current month
  def top_categories_current_month
    top_categories_for_range(@current_month_start..@current_month_end)
  end

  # Top 3 categories from YTD this year
  def top_categories_ytd_this_year
    year_start = Date.new(@reference_date.year, 1, 1)
    top_categories_for_range(year_start..@current_month_end)
  end

  # Top 3 categories from last month
  def top_categories_last_month
    top_categories_for_range(@last_month_start..@last_month_end)
  end

  # Helper method to calculate top categories for a date range
  def top_categories_for_range(date_range)
    categories = expenses_relation
      .where(due_on: date_range)
      .group(:category)
      .sum(:total_cents)

    # Handle nil categories as "Uncategorized"
    categorized_data = categories.map do |category, total_cents|
      {
        category: category.presence || "Uncategorized",
        total_cents: total_cents
      }
    end

    # Sort by total_cents descending and take top 3
    categorized_data
      .sort_by { |item| -item[:total_cents] }
      .first(3)
  end
end
