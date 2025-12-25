class Account < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :destroy
  has_many :investment_goals

  validates :up_id, presence: true, uniqueness: true
  validates :account_type, inclusion: { in: %w[TRANSACTIONAL SAVER HOME_LOAN] }
  validates :ownership_type, inclusion: { in: %w[INDIVIDUAL JOINT] }

  scope :transactional, -> { where(account_type: 'TRANSACTIONAL') }
  scope :saver, -> { where(account_type: 'SAVER') }
  scope :home_loan, -> { where(account_type: 'HOME_LOAN') }

  def display_name_or_type
    display_name.presence || account_type.humanize
  end
end

