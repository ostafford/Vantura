class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :account
  # Note: Transactions do not have a direct category_id column in the database.
  # Categories are associated through tags or can be inferred from transaction data.
  # PlannedTransactions and ProjectExpenses have category_id for categorization.
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
  scope :expenses, -> { where("amount_cents < 0") }
  scope :income, -> { where("amount_cents > 0") }

  # Class methods
  def self.find_or_create_from_up_data(up_data, user, account)
    transaction = find_or_initialize_by(up_id: up_data["id"])
    transaction.assign_attributes(
      user: user,
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
