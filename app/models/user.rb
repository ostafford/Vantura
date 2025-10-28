class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :accounts, dependent: :destroy
  has_many :filters, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Validations
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: :password_digest_changed?

  # Encrypt the Up Bank token using Rails encrypted attributes
  encrypts :up_bank_token, deterministic: false

  # Validate token presence for syncing
  validates :up_bank_token, presence: true, if: :token_required?

  private

  def token_required?
    # Token is required if user has accounts or is attempting to sync
    accounts.any?
  end
end
