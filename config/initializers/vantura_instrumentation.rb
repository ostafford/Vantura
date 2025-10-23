# config/initializers/vantura_instrumentation.rb
require "opentelemetry/semantic_conventions"

# Custom instrumentation for Vantura-specific operations
module VanturaInstrumentation
  extend self

  def instrument_up_bank_sync(account_id, &block)
    tracer = OpenTelemetry.tracer_provider.tracer("vantura-up-bank")

    tracer.in_span("up_bank.sync", kind: :client) do |span|
      span.add_attributes({
        "up_bank.account_id" => account_id,
        "up_bank.sync_type" => "full_sync"
      })

      result = block.call

      span.add_attributes({
        "up_bank.transactions_synced" => result[:transactions_count] || 0,
        "up_bank.sync_duration_ms" => result[:duration_ms] || 0
      })

      span.status = OpenTelemetry::Trace::Status.ok
      result
    rescue StandardError => e
      span.record_exception(e)
      span.status = OpenTelemetry::Trace::Status.error("Up Bank sync failed: #{e.message}")
      raise
    end
  end

  def instrument_transaction_creation(transaction_data, &block)
    tracer = OpenTelemetry.tracer_provider.tracer("vantura-transactions")

    tracer.in_span("transaction.create", kind: :internal) do |span|
      span.add_attributes({
        "transaction.amount" => transaction_data[:amount],
        "transaction.type" => transaction_data[:is_hypothetical] ? "hypothetical" : "real",
        "transaction.category" => transaction_data[:category]
      })

      result = block.call

      span.add_attributes({
        "transaction.id" => result.id,
        "transaction.created_at" => result.created_at.iso8601
      })

      span.status = OpenTelemetry::Trace::Status.ok
      result
    rescue StandardError => e
      span.record_exception(e)
      span.status = OpenTelemetry::Trace::Status.error("Transaction creation failed: #{e.message}")
      raise
    end
  end

  def instrument_recurring_transaction_generation(&block)
    tracer = OpenTelemetry.tracer_provider.tracer("vantura-recurring")

    tracer.in_span("recurring_transaction.generate", kind: :internal) do |span|
      result = block.call

      span.add_attributes({
        "recurring_transaction.patterns_processed" => result[:patterns_count] || 0,
        "recurring_transaction.transactions_generated" => result[:transactions_count] || 0
      })

      span.status = OpenTelemetry::Trace::Status.ok
      result
    rescue StandardError => e
      span.record_exception(e)
      span.status = OpenTelemetry::Trace::Status.error("Recurring transaction generation failed: #{e.message}")
      raise
    end
  end

  def instrument_calendar_projection(account_id, start_date, end_date, &block)
    tracer = OpenTelemetry.tracer_provider.tracer("vantura-calendar")

    tracer.in_span("calendar.projection", kind: :internal) do |span|
      span.add_attributes({
        "calendar.account_id" => account_id,
        "calendar.start_date" => start_date.iso8601,
        "calendar.end_date" => end_date.iso8601,
        "calendar.days_count" => (end_date - start_date).to_i
      })

      result = block.call

      span.add_attributes({
        "calendar.projected_transactions" => result[:transactions_count] || 0,
        "calendar.projection_duration_ms" => result[:duration_ms] || 0
      })

      span.status = OpenTelemetry::Trace::Status.ok
      result
    rescue StandardError => e
      span.record_exception(e)
      span.status = OpenTelemetry::Trace::Status.error("Calendar projection failed: #{e.message}")
      raise
    end
  end
end

# Make instrumentation available globally
Rails.application.config.after_initialize do
  Rails.logger.info "Vantura custom instrumentation loaded"
end
