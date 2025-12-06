class Session < ApplicationRecord
  belongs_to :user

  # Validations
  validates :user_id, presence: true

  # Scopes
  scope :active, -> { where("last_active_at >= ? OR last_active_at IS NULL", 2.hours.ago) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }

  # Instance methods
  def active?
    # Session is active if last_active_at is within 2 hours, or if it's never been set (new session)
    return true if last_active_at.nil?
    last_active_at >= 2.hours.ago
  end

  def update_activity!
    update!(last_active_at: Time.current)
  end

  def expired?
    !active?
  end
end

