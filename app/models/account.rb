class Account < ApplicationRecord
  # Associations
  has_many :transactions, dependent: :destroy
  has_many :recurring_transactions, dependent: :destroy

  # Validations
  validates :up_account_id, presence: true, uniqueness: true
  validates :display_name, presence: true
  validates :account_type, presence: true
  validates :current_balance, presence: true, numericality: true

  # Enums for account types (matching Up Bank API)
  enum :account_type, {
    transactional: "TRANSACTIONAL",
    saver: "SAVER",
    home_loan: "HOME_LOAN"
  }, prefix: true
end
