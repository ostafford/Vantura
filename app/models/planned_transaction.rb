class PlannedTransaction < ApplicationRecord
  belongs_to :user
  belongs_to :transaction, optional: true
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
    transaction.present?
  end
end
