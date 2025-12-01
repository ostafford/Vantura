class User < ApplicationRecord
  # Devise modules
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
  validates :email, presence: true, uniqueness: true

  # Methods
  def has_up_bank_token?
    up_bank_token.present?
  end
end
