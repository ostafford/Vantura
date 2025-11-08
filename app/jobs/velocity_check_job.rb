class VelocityCheckJob < ApplicationJob
  queue_as :default

  # Real-time velocity monitoring
  # Triggered when spending velocity significantly changes
  # This job monitors spending patterns and generates insights when velocity changes
  def perform(account_id)
    account = Account.find_by(id: account_id)
    return unless account

    Rails.logger.info "[VELOCITY] Checking velocity for account: #{account.id}"

    begin
      insights_service = FinancialInsightsService.new(account)
      velocity_insight = insights_service.spending_velocity_insight

      # Only create insight if velocity change is significant
      return unless velocity_insight.present?

      # Check if similar insight already exists recently (avoid duplicates)
      existing = account.financial_insights
                       .not_actioned
                       .by_type("spending_velocity")
                       .where("created_at > ?", 1.day.ago)
                       .first

      return if existing.present?

      # Create new insight
      FinancialInsight.create!(
        account: account,
        insight_type: velocity_insight[:type],
        title: velocity_insight[:title],
        message: velocity_insight[:message],
        evidence_data: velocity_insight[:evidence] || {},
        suggested_action: velocity_insight[:suggested_action],
        suggested_amount: velocity_insight[:suggested_amount],
        suggested_date: velocity_insight[:suggested_date],
        is_actioned: false
      )

      Rails.logger.info "[VELOCITY] Created velocity insight for account: #{account.id}"

      # Broadcast via Turbo Stream if user is online (optional enhancement)
      # This would require ActionCable setup
    rescue StandardError => e
      Rails.logger.error "[VELOCITY] Failed to check velocity for account #{account.id}: #{e.message}"
      Rails.error.report(e, context: { account_id: account.id })
    end
  end
end
