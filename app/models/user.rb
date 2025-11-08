class User < ApplicationRecord
  has_secure_password

  # Password reset token generation (Rails 8 authentication)
  generates_token_for :password_reset, expires_in: 15.minutes

  # Associations
  has_many :sessions, dependent: :destroy
  has_many :accounts, dependent: :destroy
  has_many :owned_projects, class_name: "Project", foreign_key: "owner_id", dependent: :destroy

  # Validations
  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :up_bank_token, presence: true, if: :token_required?
  validates :name, length: { maximum: 100 }, format: { with: /\A[\p{L}\s\-']+\z/u }, allow_blank: true

  # Encrypt the Up Bank token using Rails encrypted attributes
  encrypts :up_bank_token, deterministic: false

  private

  def token_required?
    # Token is required if user has accounts or is attempting to sync
    accounts.any?
  end
end
