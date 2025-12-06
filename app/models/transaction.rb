class Transaction < ApplicationRecord
  belongs_to :user, touch: true
  belongs_to :account, touch: true
  belongs_to :category, optional: true
  has_many :transaction_tags, dependent: :destroy, foreign_key: "transaction_id"
  has_many :tags, through: :transaction_tags
  has_one :planned_transaction, dependent: :nullify
  has_many :project_expenses
  has_many :recurring_transactions, foreign_key: "template_transaction_id", dependent: :nullify

  # Money Rails
  monetize :amount_cents, with_currency: :aud
  monetize :foreign_amount_cents, with_currency: :aud, allow_nil: true

  # Enums
  enum :status, {
    held: "HELD",
    settled: "SETTLED",
    pending: "PENDING"
  }

  # Validations
  validates :up_id, presence: true, uniqueness: { scope: :user_id }
  validates :status, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_date_range, ->(start_date, end_date) {
    where(created_at: start_date..end_date)
  }
  scope :by_settled_date_range, ->(start_date, end_date) {
    where(settled_at: start_date..end_date)
  }
  scope :expenses, -> { where("amount_cents < 0") }
  scope :income, -> { where("amount_cents > 0") }
  scope :this_month, -> { where("created_at >= ?", Time.current.beginning_of_month) }

  # Analytics Class Methods
  def self.total_by_category(user, start_date = nil, end_date = nil)
    scope = where(user: user)
    scope = scope.by_settled_date_range(start_date, end_date) if start_date && end_date

    category_totals = scope.where.not(category_id: nil)
        .joins(:category)
        .group("categories.id", "categories.name")
        .sum(Arel.sql("ABS(amount_cents)"))

    category_counts = scope.where.not(category_id: nil)
        .joins(:category)
        .group("categories.id", "categories.name")
        .count

    results = category_totals.map do |key, total_cents|
      category_id, category_name = key.is_a?(Array) ? key : [ key, nil ]
      Struct.new(:id, :name, :total_cents, :transaction_count).new(
        category_id,
        category_name || Category.find_by(id: category_id)&.name,
        total_cents.to_i,
        category_counts[key] || 0
      )
    end

    results.sort_by(&:total_cents).reverse
  end

  def self.total_by_merchant(user, start_date = nil, end_date = nil)
    scope = where(user: user).expenses
    scope = scope.by_settled_date_range(start_date, end_date) if start_date && end_date

    merchant_totals = scope.where.not(description: nil)
        .group("description")
        .sum(Arel.sql("ABS(amount_cents)"))

    merchant_counts = scope.where.not(description: nil)
        .group("description")
        .count

    results = merchant_totals.map do |description, total_cents|
      Struct.new(:description, :total_cents, :transaction_count).new(
        description,
        total_cents.to_i,
        merchant_counts[description] || 0
      )
    end

    results.sort_by(&:total_cents).reverse.first(50)
  end

  def self.income_vs_expenses(user, start_date = nil, end_date = nil)
    scope = where(user: user)
    scope = scope.by_settled_date_range(start_date, end_date) if start_date && end_date

    income = scope.income.sum(:amount_cents)
    expenses = scope.expenses.sum(:amount_cents).abs
    net = income - expenses

    {
      income_cents: income,
      expenses_cents: expenses,
      net_cents: net,
      income: income / 100.0,
      expenses: expenses / 100.0,
      net: net / 100.0
    }
  end

  def self.time_series_by_day(user, start_date, end_date, type: :all)
    # Ensure end_date includes the full day
    end_date = end_date.end_of_day if end_date.respond_to?(:end_of_day)
    scope = where(user: user).by_settled_date_range(start_date, end_date)

    case type
    when :expenses
      scope = scope.expenses
    when :income
      scope = scope.income
    end

    result = scope.where.not(settled_at: nil)
        .group(Arel.sql("DATE(settled_at)"))
        .order(Arel.sql("DATE(settled_at) ASC"))
        .sum(Arel.sql("ABS(amount_cents)"))

    # Transform keys to strings consistently
    result.transform_keys do |date|
      case date
      when Date
        date.strftime("%Y-%m-%d")
      when Time, DateTime
        date.to_date.strftime("%Y-%m-%d")
      else
        Date.parse(date.to_s).strftime("%Y-%m-%d") rescue date.to_s
      end
    end
  end

  def self.time_series_by_month(user, start_date, end_date, type: :all)
    scope = where(user: user).by_settled_date_range(start_date, end_date)

    case type
    when :expenses
      scope = scope.expenses
    when :income
      scope = scope.income
    end

    scope.where.not(settled_at: nil)
        .group(Arel.sql("DATE_TRUNC('month', settled_at)"))
        .order(Arel.sql("DATE_TRUNC('month', settled_at) ASC"))
        .sum(Arel.sql("ABS(amount_cents)"))
        .transform_keys do |date|
          if date.is_a?(Date) || date.is_a?(Time) || date.is_a?(DateTime)
            date.strftime("%Y-%m")
          else
            date.to_s[0..6]
          end
        end
  end

  # Advanced Analytics Methods

  # Spending trends analysis - compare two periods
  def self.spending_trend(user, current_start, current_end, previous_start, previous_end, type: :expenses)
    current_scope = where(user: user).by_settled_date_range(current_start, current_end)
    previous_scope = where(user: user).by_settled_date_range(previous_start, previous_end)

    case type
    when :expenses
      current_scope = current_scope.expenses
      previous_scope = previous_scope.expenses
    when :income
      current_scope = current_scope.income
      previous_scope = previous_scope.income
    end

    current_total = current_scope.sum(:amount_cents).abs
    previous_total = previous_scope.sum(:amount_cents).abs

    difference = current_total - previous_total
    percent_change = previous_total > 0 ? ((difference.to_f / previous_total) * 100).round(2) : 0

    {
      current_period_cents: current_total,
      previous_period_cents: previous_total,
      difference_cents: difference,
      percent_change: percent_change,
      trend: difference > 0 ? :increasing : (difference < 0 ? :decreasing : :stable),
      current_period: current_total / 100.0,
      previous_period: previous_total / 100.0,
      difference: difference / 100.0
    }
  end

  # Category comparison over time - compare categories across periods
  def self.category_comparison_over_time(user, period1_start, period1_end, period2_start, period2_end)
    period1_data = total_by_category(user, period1_start, period1_end).map { |cat| [cat.name, cat.total_cents] }.to_h
    period2_data = total_by_category(user, period2_start, period2_end).map { |cat| [cat.name, cat.total_cents] }.to_h

    all_categories = (period1_data.keys + period2_data.keys).uniq

    all_categories.map do |category_name|
      period1_amount = period1_data[category_name] || 0
      period2_amount = period2_data[category_name] || 0
      difference = period2_amount - period1_amount
      percent_change = period1_amount > 0 ? ((difference.to_f / period1_amount) * 100).round(2) : (period2_amount > 0 ? 100.0 : 0)

      {
        category_name: category_name,
        period1_cents: period1_amount,
        period2_cents: period2_amount,
        difference_cents: difference,
        percent_change: percent_change,
        trend: difference > 0 ? :increasing : (difference < 0 ? :decreasing : :stable),
        period1: period1_amount / 100.0,
        period2: period2_amount / 100.0,
        difference: difference / 100.0
      }
    end.sort_by { |cat| cat[:period2_cents] }.reverse
  end

  # Enhanced merchant analysis with trends
  def self.merchant_trends(user, merchant_name, start_date, end_date)
    scope = where(user: user).expenses
                             .by_settled_date_range(start_date, end_date)
                             .where("description ILIKE ? OR message ILIKE ?", "%#{merchant_name}%", "%#{merchant_name}%")

    transactions = scope.order(:settled_at)

    return nil if transactions.empty?

    total_amount = transactions.sum(:amount_cents).abs
    transaction_count = transactions.count
    average_amount = transaction_count > 0 ? (total_amount / transaction_count) : 0

    # Calculate frequency (average days between transactions)
    dates = transactions.pluck(:settled_at).compact.sort
    intervals = []
    (1...dates.length).each do |i|
      interval_days = ((dates[i] - dates[i - 1]) / 1.day).round
      intervals << interval_days if interval_days > 0
    end
    avg_frequency_days = intervals.any? ? (intervals.sum.to_f / intervals.length).round : nil

    {
      merchant_name: merchant_name,
      total_cents: total_amount,
      transaction_count: transaction_count,
      average_amount_cents: average_amount,
      average_frequency_days: avg_frequency_days,
      first_transaction_date: dates.first,
      last_transaction_date: dates.last,
      total: total_amount / 100.0,
      average_amount: average_amount / 100.0
    }
  end

  # Monthly spending trends - compare month over month
  def self.monthly_spending_trends(user, months_back: 6)
    end_date = Date.current.end_of_month
    start_date = (months_back - 1).months.ago.beginning_of_month

    monthly_data = time_series_by_month(user, start_date, end_date, type: :expenses)

    trends = []
    previous_amount = nil

    monthly_data.sort_by { |date_str, _| date_str }.each do |date_str, amount_cents|
      date = Date.strptime("#{date_str}-01", "%Y-%m-%d")
      month_name = date.strftime("%B %Y")

      trend_data = {
        month: date_str,
        month_name: month_name,
        amount_cents: amount_cents,
        amount: amount_cents / 100.0
      }

      if previous_amount
        difference = amount_cents - previous_amount
        percent_change = previous_amount > 0 ? ((difference.to_f / previous_amount) * 100).round(2) : 0
        trend_data.merge!(
          difference_cents: difference,
          percent_change: percent_change,
          trend: difference > 0 ? :increasing : (difference < 0 ? :decreasing : :stable),
          difference: difference / 100.0
        )
      end

      trends << trend_data
      previous_amount = amount_cents
    end

    trends
  end

  # Class methods
  def self.find_or_create_from_up_data(up_data, user, account)
    transaction = find_or_initialize_by(up_id: up_data["id"], user_id: user.id)
    transaction.assign_attributes(
      account: account,
      status: up_data.dig("attributes", "status")&.downcase,
      raw_text: up_data.dig("attributes", "rawText"),
      description: up_data.dig("attributes", "description"),
      message: up_data.dig("attributes", "message"),
      amount_cents: up_data.dig("attributes", "amount", "valueInBaseUnits"),
      settled_at: parse_up_datetime(up_data.dig("attributes", "settledAt")),
      hold_info: up_data.dig("attributes", "holdInfo"),
      card_purchase_method: up_data.dig("attributes", "cardPurchaseMethod", "method")
    )
    transaction.save!
    transaction
  end

  private

  def self.parse_up_datetime(datetime_string)
    return nil if datetime_string.blank?
    Time.parse(datetime_string)
  rescue ArgumentError
    nil
  end
end
