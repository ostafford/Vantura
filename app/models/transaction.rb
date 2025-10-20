class Transaction < ApplicationRecord
  # Associations
  belongs_to :account
  belongs_to :recurring_transaction, optional: true

  # Validations
  validates :description, presence: true
  validates :amount, presence: true, numericality: true
  validates :transaction_date, presence: true
  validates :status, presence: true
  validates :is_hypothetical, inclusion: { in: [true, false] }

  # Scopes for common queries
  scope :real, -> { where(is_hypothetical: false) }
  scope :hypothetical, -> { where(is_hypothetical: true) }
  scope :expenses, -> { where('amount < 0') }
  scope :income, -> { where('amount > 0') }
  scope :for_date, ->(date) { where(transaction_date: date) }
  scope :for_month, ->(month, year) { where('extract(month from transaction_date) = ? AND extract(year from transaction_date) = ?', month, year) }
  scope :from_recurring, -> { where.not(recurring_transaction_id: nil) }

  # Enums for status
  enum :status, {
    held: 'HELD',
    settled: 'SETTLED',
    hypothetical: 'HYPOTHETICAL'
  }, prefix: true
  
  # Check if this is a recurring transaction (generated or real matched)
  def recurring?
    recurring_transaction_id.present?
  end
end
