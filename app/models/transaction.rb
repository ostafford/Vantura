class Transaction < ApplicationRecord
  include Turbo::Broadcastable

  # Associations
  belongs_to :account
  belongs_to :recurring_transaction, optional: true

  # Validations
  validates :description, presence: true
  validates :amount, presence: true, numericality: true
  validates :transaction_date, presence: true
  validates :status, presence: true
  validates :is_hypothetical, inclusion: { in: [ true, false ] }

  # Broadcast dashboard updates after creating/updating transactions
  after_create_commit :broadcast_dashboard_update, :broadcast_calendar_refresh
  after_update_commit :broadcast_dashboard_update, :broadcast_calendar_refresh
  after_destroy_commit :broadcast_dashboard_update, :broadcast_calendar_refresh

  # Scopes for common queries
  scope :real, -> { where(is_hypothetical: false) }
  scope :hypothetical, -> { where(is_hypothetical: true) }
  scope :expenses, -> { where("amount < 0") }
  scope :income, -> { where("amount > 0") }
  scope :for_date, ->(date) { where(transaction_date: date) }
  scope :for_month, ->(date) { where(transaction_date: date.beginning_of_month..date.end_of_month) }
  scope :from_recurring, -> { where.not(recurring_transaction_id: nil) }

  # Filtering scopes
  scope :in_date_range, ->(start_date, end_date) {
    where(transaction_date: start_date..end_date) if start_date.present? && end_date.present?
  }

  scope :by_categories, ->(categories) {
    where(category: categories) if categories.present? && categories.any?
  }

  scope :by_merchants, ->(merchants) {
    where(merchant: merchants) if merchants.present? && merchants.any?
  }

  scope :by_statuses, ->(statuses) {
    where(status: statuses) if statuses.present? && statuses.any?
  }

  scope :by_recurring, ->(recurring_value) {
    case recurring_value
    when "true"
      where.not(recurring_transaction_id: nil)
    when "false"
      where(recurring_transaction_id: nil)
    else
      all
    end
  }

  # Shared query helpers for common transaction queries

  # Get top merchants by transaction type (expense or income) within a date range
  # @param transaction_type [String] 'expense' or 'income'
  # @param account [Account] the account to query
  # @param start_date [Date] start of date range
  # @param end_date [Date] end of date range
  # @param limit [Integer] number of merchants to return (default: 3)
  # @return [Array<Hash>] Array of merchant data with total, count, and hypothetical flag
  def self.top_merchants_by_type(transaction_type, account:, start_date:, end_date:, limit: 3)
    # Direct date range query
    relation = account.transactions.where(transaction_date: start_date..end_date)

    # Filter by transaction type
    if transaction_type == "expense"
      relation = relation.where("amount < 0")
    else # income
      relation = relation.where("amount > 0")
    end

    # Get top merchants
    merchants = relation.group(:merchant)
                       .select("merchant, SUM(amount) as total, COUNT(*) as count")
                       .order(transaction_type == "expense" ? "total ASC" : "total DESC")
                       .limit(limit)

    # Build hash with hypothetical flag
    merchants.map do |merchant|
      {
        merchant: merchant.merchant,
        total: merchant.total.abs,
        count: merchant.count,
        hypothetical: self.merchant_has_hypothetical?(merchant.merchant, transaction_type, account: account, start_date: start_date, end_date: end_date)
      }
    end
  end

  # Check if a merchant has hypothetical transactions
  # @param merchant_name [String] name of the merchant
  # @param transaction_type [String] 'expense' or 'income'
  # @param account [Account] the account to query
  # @param start_date [Date] start of date range
  # @param end_date [Date] end of date range
  # @return [Boolean] true if merchant has hypothetical transactions
  def self.merchant_has_hypothetical?(merchant_name, transaction_type, account:, start_date:, end_date:)
    relation = account.transactions
                      .where(transaction_date: start_date..end_date)
                      .where(merchant: merchant_name)
                      .where(is_hypothetical: true)

    if transaction_type == "expense"
      relation = relation.where("amount < 0")
    else # income
      relation = relation.where("amount > 0")
    end

    relation.exists?
  end

  # Apply a Filter object's criteria to this transaction relation
  def self.apply_filter(filter)
    relation = all

    # Apply date range filter
    if filter.date_range.present?
      date_range = filter.date_range
      if date_range["start_date"].present? && date_range["end_date"].present?
        relation = relation.in_date_range(date_range["start_date"], date_range["end_date"])
      end
    end

    # Apply filter type criteria
    filter.filter_types.each do |filter_type|
      case filter_type
      when "category"
        if filter.filter_params["categories"].present?
          relation = relation.by_categories(filter.filter_params["categories"])
        end
      when "merchant"
        if filter.filter_params["merchants"].present?
          relation = relation.by_merchants(filter.filter_params["merchants"])
        end
      when "status"
        if filter.filter_params["statuses"].present?
          relation = relation.by_statuses(filter.filter_params["statuses"])
        end
      when "recurring_transactions"
        if filter.filter_params["recurring_transactions"].present?
          relation = relation.by_recurring(filter.filter_params["recurring_transactions"])
        end
      end
    end

    relation
  end

  # Enums for status
  enum :status, {
    held: "HELD",
    settled: "SETTLED",
    hypothetical: "HYPOTHETICAL"
  }, prefix: true

  # Check if this is a recurring transaction (generated or real matched)
  def recurring?
    recurring_transaction_id.present?
  end

  # Determine the transaction type based on amount
  # @return [String] "expense" or "income"
  def transaction_type
    return "expense" if amount.nil? # Default for new transactions
    amount < 0 ? "expense" : "income"
  end

  private

  # Broadcast calendar refresh to update the calendar in real-time
  # Note: The actual refresh is handled in the create.turbo_stream.erb template
  # This method is a placeholder for future broadcasting capabilities
  def broadcast_calendar_refresh
    # Calendar refresh is handled via Turbo Stream responses in the controller
    # No action needed here
  end

  # Broadcast dashboard updates to the user's channel using Turbo Streams
  def broadcast_dashboard_update
    return unless account&.user # Ensure we have a user to broadcast to

    # Calculate updated stats using service
    stats = DashboardStatsCalculator.call(account)

    current_date = stats[:current_date]
    expense_count = stats[:expense_count]
    expense_total = stats[:expense_total]
    income_count = stats[:income_count]
    income_total = stats[:income_total]
    end_of_month_balance = stats[:end_of_month_balance]

    # Broadcast Turbo Stream updates to user's channel
    broadcast_replace_to(
      account.user,
      target: "expenses_card",
      partial: "dashboard/transaction_type_card",
      locals: {
        type: "expense",
        expense_total: expense_total,
        expense_count: expense_count,
        current_date: current_date,
        top_expense_merchants: []
      }
    )

    broadcast_replace_to(
      account.user,
      target: "income_card",
      partial: "dashboard/transaction_type_card",
      locals: {
        type: "income",
        income_total: income_total,
        income_count: income_count,
        current_date: current_date,
        top_income_merchants: []
      }
    )

    # Calculate upcoming recurring transactions for projection
    upcoming_recurring = get_upcoming_recurring_transactions
    upcoming_recurring_expenses = upcoming_recurring[:expenses]
    upcoming_recurring_income = upcoming_recurring[:income]
    upcoming_recurring_total = upcoming_recurring[:expense_total] + upcoming_recurring[:income_total]

    broadcast_replace_to(
      account.user,
      target: "projection_card",
      partial: "dashboard/projection_card",
      locals: {
        income_total: income_total,
        expense_total: expense_total,
        end_of_month_balance: end_of_month_balance,
        current_date: current_date,
        upcoming_recurring_expenses: upcoming_recurring_expenses,
        upcoming_recurring_income: upcoming_recurring_income,
        upcoming_recurring_total: upcoming_recurring_total
      }
    )
  end

  # Get upcoming recurring transactions for the rest of the month
  def get_upcoming_recurring_transactions
    end_of_month = Date.today.end_of_month

    upcoming = account.recurring_transactions
                     .active
                     .where("next_occurrence_date <= ?", end_of_month)
                     .order(:next_occurrence_date)

    # Separate by type
    expenses = upcoming.select { |r| r.transaction_type_expense? }
    income = upcoming.select { |r| r.transaction_type_income? }

    {
      expenses: expenses,
      income: income,
      expense_total: expenses.sum { |r| r.amount.abs },
      income_total: income.sum { |r| r.amount }
    }
  end
  private :get_upcoming_recurring_transactions
end
