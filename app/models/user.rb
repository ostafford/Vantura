class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :lockable,
         :timeoutable

  # Associations
  has_many :accounts, dependent: :destroy
  has_many :transactions, dependent: :destroy
  has_many :budgets, dependent: :destroy
  has_many :budget_alerts, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :investment_goals, dependent: :destroy

  # Encrypted PAT (Rails 8.1.1+ built-in encryption)
  encrypts :up_pat

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :up_pat, presence: true, on: :update, if: :up_pat_changed?,
    format: {
      with: /\Aup:yeah:[a-zA-Z0-9]+\z/,
      message: "must be a valid Up Bank Personal Access Token"
    }

  # Scopes
  scope :with_pat, -> { where.not(up_pat_ciphertext: nil) }

  # Methods
  def up_pat_configured?
    # Check ciphertext directly - more reliable than decrypted value
    # Rails encrypted attributes may not always decrypt correctly, but ciphertext presence
    # indicates the PAT was successfully saved
    up_pat_ciphertext.present?
  end

  def sync_required?
    last_synced_at.nil? || last_synced_at < 1.hour.ago
  end

  def can_access?(resource)
    resource.user_id == id
  end
end
