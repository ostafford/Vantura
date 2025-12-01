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
    key: ENV.fetch("ENCRYPTION_KEY"),
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

  # Validations
  validates :email_address, presence: true, uniqueness: true

  # Methods
  def has_up_bank_token?
    up_bank_token.present?
  end
end
