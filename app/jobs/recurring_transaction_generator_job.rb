class RecurringTransactionGeneratorJob < ApplicationJob
  queue_as :low_priority

  # Generate future hypothetical transactions for all active recurring patterns
  # This ensures projections are always up-to-date
  # Run this job daily (e.g., at midnight) via cron or scheduled task
  def perform(months_ahead: 12)
    active_patterns = RecurringTransaction.active
    total_generated = 0

    active_patterns.find_each do |recurring|
      # Only generate for active patterns
      next unless recurring.is_active?

      # Skip if projection has a limit and we've reached it
      if recurring.projection_months != "indefinite"
        max_months = recurring.projection_months.to_i
        # Check if we already have projections far enough
        furthest_projection = recurring.generated_transactions.hypothetical.maximum(:transaction_date)
        if furthest_projection && furthest_projection > Date.today + max_months.months
          next
        end
      end

      # Generate transactions for this pattern
      begin
        result = RecurringTransactions::GenerateService.call(
          recurring,
          months_ahead: months_ahead
        )

        generated_count = result[:generated_count] || 0
        total_generated += generated_count

        Rails.logger.info "[RECURRING] Generated #{generated_count} transactions for pattern: #{recurring.description}"
      rescue StandardError => e
        # Log error but continue with other patterns
        Rails.logger.error "[RECURRING] Failed to generate for pattern #{recurring.id}: #{e.message}"
        Rails.error.report(e, context: { recurring_transaction_id: recurring.id })
      end
    end

    Rails.logger.info "[RECURRING] Generated #{total_generated} total transactions from #{active_patterns.count} active patterns"

    # Return summary for monitoring
    {
      patterns_processed: active_patterns.count,
      transactions_generated: total_generated
    }
  end
end
