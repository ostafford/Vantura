class User < ApplicationRecord
  # Database field: email_address (not 'email')
  # Devise is configured to use email_address as the authentication key (see config/initializers/devise.rb)
  # This alias allows Devise methods that expect 'email' to work correctly
  # Reference: https://guides.rubyonrails.org/active_record_basics.html
  alias_attribute :email, :email_address

  # Devise modules
  # Note: Using email_address as the authentication key (configured in devise.rb)
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Encrypted Up Bank token
  attr_encrypted :up_bank_token,
    key: ENV.fetch("ENCRYPTION_KEY") { Rails.env.development? ? "development_key_32_bytes_long!!" : nil },
    algorithm: "aes-256-gcm",
    mode: :per_attribute_iv_and_salt

  # Associations
  has_many :accounts, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :webhook_events, dependent: :destroy
  has_many :planned_transactions, dependent: :destroy
  has_many :owned_projects, class_name: "Project", foreign_key: "owner_id"
  has_many :project_members
  has_many :projects, through: :project_members
  has_many :expense_contributions
  has_many :goals, dependent: :destroy
  has_many :feedback_items, dependent: :destroy

  # Touch updated_at when related records change for cache invalidation
  after_touch :touch_accounts

  # Validations
  validates :email_address, presence: true, uniqueness: true

  # Methods
  def has_up_bank_token?
    up_bank_token.present?
  end

  def needs_up_bank_setup?
    up_bank_token.blank?
  end

  def calculate_stats
    {
      total_balance: accounts.sum(:balance_cents),
      income_this_month: transactions.income.this_month.sum(:amount_cents),
      expenses_this_month: transactions.expenses.this_month.sum(:amount_cents).abs,
      net_this_month: transactions.this_month.sum(:amount_cents)
    }
  end

  private

  def touch_accounts
    accounts.touch_all
  end
end
