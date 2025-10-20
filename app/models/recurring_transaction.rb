class RecurringTransaction < ApplicationRecord
  # Associations
  belongs_to :account

  # Validations
  validates :description, presence: true
  validates :amount, presence: true, numericality: true
  validates :frequency, presence: true
  validates :next_occurrence_date, presence: true
  validates :transaction_type, presence: true
  validates :is_active, inclusion: { in: [true, false] }

  # Enums
  enum :frequency, {
    weekly: 'weekly',
    fortnightly: 'fortnightly',
    monthly: 'monthly',
    quarterly: 'quarterly',
    yearly: 'yearly'
  }, prefix: true

  enum :transaction_type, {
    income: 'income',
    expense: 'expense'
  }, prefix: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :income_transactions, -> { where(transaction_type: 'income') }
  scope :expense_transactions, -> { where(transaction_type: 'expense') }
  scope :due_soon, ->(days = 7) { where('next_occurrence_date <= ?', Date.today + days.days) }
end
