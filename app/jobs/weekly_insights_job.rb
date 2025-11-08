class WeeklyInsightsJob < ApplicationJob
  queue_as :default

  # Generate and deliver insights every Sunday
  # This job runs weekly to provide users with regular financial insights
  def perform
    Rails.logger.info "[INSIGHTS] Starting weekly insights generation"

    # Get all accounts with users (active accounts)
    accounts = Account.joins(:user).distinct
    total_insights = 0

    accounts.find_each do |account|
      begin
        insights_service = FinancialInsightsService.new(account)
        insights = insights_service.generate_key_insights(5)

        # Store insights in database
        insights.each do |insight_data|
          # Check if similar insight already exists (avoid duplicates)
          existing = account.financial_insights
                           .not_actioned
                           .by_type(insight_data[:type])
                           .where("created_at > ?", 7.days.ago)
                           .first

          next if existing.present?

          FinancialInsight.create!(
            account: account,
            insight_type: insight_data[:type],
            title: insight_data[:title],
            message: insight_data[:message],
            evidence_data: insight_data[:evidence] || {},
            suggested_action: insight_data[:suggested_action],
            suggested_amount: insight_data[:suggested_amount],
            suggested_date: insight_data[:suggested_date],
            is_actioned: false
          )

          total_insights += 1
        end

        Rails.logger.info "[INSIGHTS] Generated insights for account: #{account.id}"
      rescue StandardError => e
        Rails.logger.error "[INSIGHTS] Failed to generate insights for account #{account.id}: #{e.message}"
        Rails.error.report(e, context: { account_id: account.id })
      end
    end

    Rails.logger.info "[INSIGHTS] Weekly insights generation complete. Created #{total_insights} insights for #{accounts.count} accounts"

    {
      accounts_processed: accounts.count,
      insights_created: total_insights
    }
  end
end
