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

  # Encrypted Up Bank token using Rails built-in encryption
  encrypts :up_bank_token

  # Override attribute reader to ensure decryption works
  # This is a workaround for a Rails 8 issue where encrypted attributes
  # don't automatically decrypt after reload
  def up_bank_token
    # Try Rails encryption first
    value = super
    return value if value.present?

    # If empty, manually decrypt from ciphertext column
    ciphertext = read_attribute(:up_bank_token_ciphertext)
    return nil if ciphertext.blank?

    begin
      type = self.class.type_for_attribute(:up_bank_token)
      type.deserialize(ciphertext)
    rescue => e
      Rails.logger.error "Failed to decrypt up_bank_token: #{e.message}"
      nil
    end
  end

  # Ensure ciphertext column is marked as changed when encrypted attribute changes
  # This fixes an issue where Rails encryption doesn't mark the ciphertext column as dirty
  before_save :ensure_ciphertext_is_saved, if: :will_save_change_to_up_bank_token?

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
  has_many :filters, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :sessions, dependent: :destroy

  # Touch updated_at when related records change for cache invalidation
  after_touch :touch_accounts

  # Validations
  validates :email_address, presence: true, uniqueness: true

  # Methods
  def has_up_bank_token?
    # Rails encryption automatically handles encryption/decryption
    # Check if the decrypted value is present
    up_bank_token.present?
  end

  def needs_up_bank_setup?
    # Rails encryption automatically handles encryption/decryption
    # Check if the decrypted value is blank
    up_bank_token.blank?
  end

  def needs_onboarding?
    # User needs onboarding if they haven't completed sync
    # (either no accounts or no sync timestamp)
    accounts.empty? || last_synced_at.blank?
  end

  def calculate_stats(start_date: nil, end_date: nil)
    start_date ||= Time.current.beginning_of_month
    end_date ||= Time.current.end_of_month

    income_vs_expenses = Transaction.income_vs_expenses(self, start_date, end_date)

    {
      total_balance: accounts.transactional.sum(:balance_cents),
      income_this_month: income_vs_expenses[:income_cents],
      expenses_this_month: income_vs_expenses[:expenses_cents],
      net_this_month: income_vs_expenses[:net_cents],
      income: income_vs_expenses[:income],
      expenses: income_vs_expenses[:expenses],
      net: income_vs_expenses[:net]
    }
  end

  private

  def touch_accounts
    accounts.touch_all
  end

  def ensure_ciphertext_is_saved
    # Force Rails to include the ciphertext column in the UPDATE statement
    # Rails encryption encrypts the value but doesn't update the ciphertext attribute
    # until save, and doesn't mark it as changed. We need to explicitly set it.
    if attribute_changed?(:up_bank_token)
      # Get the encrypted value that Rails encryption has prepared
      # The encrypted value is stored internally by Rails encryption
      type = self.class.type_for_attribute(:up_bank_token)
      new_value = read_attribute_before_type_cast(:up_bank_token)
      if new_value.present?
        # Serialize the new value to get the encrypted ciphertext
        encrypted_ciphertext = type.serialize(new_value)
        # Explicitly set the ciphertext column
        write_attribute(:up_bank_token_ciphertext, encrypted_ciphertext)
      else
        # If setting to nil/blank, also clear the ciphertext
        write_attribute(:up_bank_token_ciphertext, nil)
      end
    end
  end
end
