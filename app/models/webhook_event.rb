class WebhookEvent < ApplicationRecord
  belongs_to :user

  # Scopes
  scope :processed, -> { where.not(processed_at: nil) }
  scope :unprocessed, -> { where(processed_at: nil) }
  scope :by_event_type, ->(type) { where(event_type: type) }

  # Methods
  def processed?
    processed_at.present?
  end

  def mark_as_processed!
    update!(processed_at: Time.current)
  end

  def mark_as_failed!(error_message)
    update!(
      processed_at: Time.current,
      error_message: error_message
    )
  end
end
