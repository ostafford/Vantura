class ProjectBarsAggregator < ApplicationService
  def initialize(project:, period:, year:, month:, group_by:, ids: [])
    @project = project
    @period = period
    @year = year
    @month = month
    @group_by = group_by
    @ids = Array(ids)
  end

  def call
    range = compute_range
    labels = build_labels(range)

    case @group_by
    when "category"
      datasets = build_grouped_datasets(range, column: :category)
    when "merchant"
      datasets = build_grouped_datasets(range, column: :merchant)
    when "contributor"
      datasets = build_contributor_datasets(range)
    else
      datasets = [build_total_dataset(range)]
    end

    {
      labels: labels,
      datasets: datasets,
      totals: {
        period_total_cents: datasets.sum { |ds| ds[:data].sum } # already in cents
      }
    }
  end

  private

  def compute_range
    if @period == "year"
      (Date.new(@year, 1, 1)..Date.new(@year, 12, 31))
    else
      base_date = Date.new(@year, @month, 1)
      (base_date.prev_year.beginning_of_month..base_date.end_of_month)
    end
  end

  def months_in_range(range)
    start_month = Date.new(range.first.year, range.first.month, 1)
    end_month = Date.new(range.last.year, range.last.month, 1)
    months = []
    d = start_month
    while d <= end_month
      months << d
      d = d.next_month
    end
    months
  end

  def build_labels(range)
    months_in_range(range).map { |d| d.strftime("%b %y") }
  end

  def expenses_relation
    @project.project_expenses.where.not(due_on: nil)
  end

  def build_total_dataset(range)
    data_by_month = months_in_range(range).map do |month_date|
      month_start = month_date.beginning_of_month
      month_end = month_date.end_of_month
      expenses_relation.where(due_on: month_start..month_end).sum(:total_cents)
    end

    {
      name: "Expenses",
      data: data_by_month,
      color: "#EF4444"
    }
  end

  def build_grouped_datasets(range, column:)
    # Determine groups to include
    groups = if @ids.present?
      @ids
    else
      # Top 5 groups by total over the range
      totals = expenses_relation.where(due_on: range).group(column).sum(:total_cents)
      totals.sort_by { |_, v| -v }.map(&:first).compact.first(5)
    end

    groups.compact.first(6).map do |group_value|
      data_by_month = months_in_range(range).map do |month_date|
        month_start = month_date.beginning_of_month
        month_end = month_date.end_of_month
        expenses_relation.where(due_on: month_start..month_end).where(column => group_value).sum(:total_cents)
      end

      {
        name: group_value.to_s,
        data: data_by_month,
        color: color_for(group_value)
      }
    end
  end

  def build_contributor_datasets(range)
    # Map user id -> name for participants
    participant_ids = @project.participants.pluck(:id)
    selected_ids = if @ids.present?
      @ids.map(&:to_i) & participant_ids
    else
      participant_ids.first(5)
    end

    selected_ids.first(6).map do |user_id|
      user_name = User.find_by(id: user_id)&.name || "User #{user_id}"
      data_by_month = months_in_range(range).map do |month_date|
        month_start = month_date.beginning_of_month
        month_end = month_date.end_of_month
        ExpenseContribution
          .joins(:project_expense)
          .where(project_expenses: { project_id: @project.id, due_on: month_start..month_end })
          .where(user_id: user_id)
          .sum(:share_cents)
      end

      {
        name: user_name,
        data: data_by_month,
        color: color_for(user_id)
      }
    end
  end

  def color_for(key)
    palette = ["#3B82F6", "#EF4444", "#10B981", "#F59E0B", "#8B5CF6", "#06B6D4"]
    idx = key.to_s.hash % palette.length
    palette[idx]
  end
end


