class SyncCategoriesJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)

    unless user.up_pat_configured?
      Rails.logger.warn "SyncCategoriesJob: User #{user_id} does not have PAT configured, skipping"
      return
    end

    Rails.logger.info "SyncCategoriesJob: Starting categories sync (triggered by user #{user_id})"

    start_time = Time.current
    UpApi::CategoriesSync.new.sync(user.up_pat)
    duration = Time.current - start_time

    Rails.logger.info "SyncCategoriesJob: Completed categories sync in #{duration.round(2)}s"
  rescue UpApi::AuthenticationError => e
    Rails.logger.error "SyncCategoriesJob: Authentication failed for user #{user_id}: #{e.message}"
    raise # Will be discarded by ApplicationJob
  rescue UpApi::ApiError => e
    Rails.logger.error "SyncCategoriesJob: API error for user #{user_id}: #{e.message}"
    raise # Will be retried by ApplicationJob
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "SyncCategoriesJob: User #{user_id} not found: #{e.message}"
    # Don't retry if user doesn't exist
  end
end

