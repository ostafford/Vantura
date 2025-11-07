class Session < ApplicationRecord
  # Constants
  SESSION_EXPIRY_TIME = 30.days

  # Associations
  belongs_to :user

  # Validations
  # (No validations needed - session validity handled by expiry logic)

  # Scopes
  scope :active, -> { where("last_active_at > ?", SESSION_EXPIRY_TIME.ago) }
  scope :expired, -> { where("last_active_at <= ? OR last_active_at IS NULL", SESSION_EXPIRY_TIME.ago) }

  # Public methods
  def expired?
    return true if last_active_at.nil?
    last_active_at < SESSION_EXPIRY_TIME.ago
  end

  def touch_activity!
    update_column(:last_active_at, Time.current)
  end

  # Private methods
  # (No private methods currently needed)
end
