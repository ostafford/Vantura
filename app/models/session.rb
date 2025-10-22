class Session < ApplicationRecord
  belongs_to :user

  # Session security settings
  SESSION_EXPIRY_TIME = 30.days

  # Scopes for session management
  scope :active, -> { where("last_active_at > ?", SESSION_EXPIRY_TIME.ago) }
  scope :expired, -> { where("last_active_at <= ? OR last_active_at IS NULL", SESSION_EXPIRY_TIME.ago) }

  # Check if session has expired
  def expired?
    return true if last_active_at.nil?
    last_active_at < SESSION_EXPIRY_TIME.ago
  end

  # Update last activity timestamp
  def touch_activity!
    update_column(:last_active_at, Time.current)
  end
end
