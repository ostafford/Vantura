class SessionCleanupJob < ApplicationJob
  queue_as :low_priority

  # Delete expired sessions to maintain database hygiene
  # Run this job daily via cron or scheduled task
  def perform
    expired_count = Session.expired.count

    # Delete all expired sessions
    Session.expired.destroy_all

    Rails.logger.info "[CLEANUP] Deleted #{expired_count} expired sessions"

    # Return count for monitoring/alerting
    { deleted_count: expired_count }
  end
end
