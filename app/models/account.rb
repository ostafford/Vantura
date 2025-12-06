class Account < ApplicationRecord
  belongs_to :user, touch: true
  has_many :transactions, dependent: :destroy
  has_many :recurring_transactions, dependent: :destroy

  # Money Rails
  monetize :balance_cents, with_currency: :aud

  # Validations
  validates :up_id, presence: true, uniqueness: { scope: :user_id }
  validates :account_type, presence: true
  validates :display_name, presence: true

  # Scopes
  scope :transactional, -> { where(account_type: "TRANSACTIONAL") }
  scope :saver, -> { where(account_type: "SAVER") }
end
