class PlannedTransaction < ApplicationRecord
  belongs_to :user
  # Uses 'transaction_record' instead of 'transaction' to avoid conflict with
  # ActiveRecord's transaction method (used for database transactions)
  # Reference: https://guides.rubyonrails.org/active_record_basics.html
  belongs_to :transaction_record, class_name: "Transaction", foreign_key: "transaction_id", optional: true
  belongs_to :category, optional: true

  # Money Rails
  monetize :amount_cents, with_currency: :aud

  # Enums
  enum transaction_type: {
    expense: "expense",
    income: "income"
  }

  # Validations
  validates :planned_date, presence: true
  validates :description, presence: true
  validates :amount_cents, presence: true

  # Scopes
  scope :upcoming, -> { where("planned_date >= ?", Date.current) }
  scope :past, -> { where("planned_date < ?", Date.current) }
  scope :by_date_range, ->(start_date, end_date) {
    where(planned_date: start_date..end_date)
  }

  # Methods
  def linked?
    transaction_record.present?
  end
end
