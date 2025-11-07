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

  # Enums
  enum :status, {
    held: "HELD",
    settled: "SETTLED",
    hypothetical: "HYPOTHETICAL"
  }, prefix: true

  # Scopes
  scope :real, -> { where(is_hypothetical: false) }
  scope :hypothetical, -> { where(is_hypothetical: true) }
  scope :expenses, -> { where("amount < 0") }
  scope :income, -> { where("amount > 0") }
  scope :for_date, ->(date) { where(transaction_date: date) }
  scope :for_month, ->(date) { where(transaction_date: date.beginning_of_month..date.end_of_month) }
  scope :from_recurring, -> { where.not(recurring_transaction_id: nil) }

  # Filtering scopes
  scope :in_date_range, ->(start_date, end_date) {
    if start_date.present? && end_date.present?
      where(transaction_date: start_date..end_date)
    else
      all
    end
  }

  scope :by_categories, ->(categories) {
    normalized = Array.wrap(categories).compact_blank

    if normalized.any?
      where(category: normalized)
    else
      all
    end
  }

  scope :by_merchants, ->(merchants) {
    normalized = Array.wrap(merchants).compact_blank

    if normalized.any?
      where(merchant: normalized)
    else
      all
    end
  }

  scope :by_statuses, ->(statuses) {
    normalized = Array.wrap(statuses).compact_blank

    if normalized.any?
      where(status: normalized)
    else
      all
    end
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

  # Callbacks
  after_create_commit :broadcast_dashboard_update
  after_update_commit :broadcast_dashboard_update
  after_destroy_commit :broadcast_dashboard_update
  after_create_commit :check_velocity, if: -> { !is_hypothetical && amount < 0 }

  # Public methods
  def recurring?
    recurring_transaction_id.present?
  end

  def transaction_type
    return "expense" if amount.nil? # Default for new transactions
    amount < 0 ? "expense" : "income"
  end

  private

  def broadcast_dashboard_update
    TransactionBroadcastService.call(self)
  end

  def check_velocity
    # Check velocity asynchronously when real expense transactions are created
    # Only check once per day per account to avoid excessive job runs
    return if is_hypothetical || amount >= 0 # Only for real expenses

    cache_key = "velocity_check_#{account_id}_#{Date.today}"
    unless Rails.cache.exist?(cache_key)
      VelocityCheckJob.perform_later(account_id)
      Rails.cache.write(cache_key, true, expires_in: 1.day)
    end
  end
end
