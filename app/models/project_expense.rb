class ProjectExpense < ApplicationRecord
  belongs_to :project
  belongs_to :paid_by_user, class_name: "User", optional: true
  # Uses 'transaction_record' instead of 'transaction' to avoid conflict with
  # ActiveRecord's transaction method (used for database transactions)
  # Reference: https://guides.rubyonrails.org/active_record_basics.html
  belongs_to :transaction_record, class_name: "Transaction", foreign_key: "transaction_id", optional: true
  belongs_to :category, optional: true
  has_many :expense_contributions, dependent: :destroy

  # Money Rails
  monetize :total_amount_cents, with_currency: :aud

  validates :description, presence: true
  validates :total_amount_cents, presence: true
  validates :expense_date, presence: true
end
