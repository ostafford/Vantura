class Transaction < ApplicationRecord
  belongs_to :user, touch: true
  belongs_to :account, touch: true
  belongs_to :category, optional: true
  has_many :transaction_tags, dependent: :destroy, foreign_key: "transaction_id"
  has_many :tags, through: :transaction_tags
  has_one :planned_transaction, dependent: :nullify
  has_many :project_expenses

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
