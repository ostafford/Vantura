# frozen_string_literal: true

namespace :sentry do
  desc "Test Sentry error reporting"
  task test: :environment do
    puts "🔍 Testing Sentry error reporting..."
    puts ""
    
    # Check if Sentry is configured
    if Sentry.configuration.dsn.blank?
      puts "❌ Sentry DSN not configured!"
      puts "   Run: bin/rails credentials:edit"
      puts "   Add: sentry:"
      puts "        dsn: YOUR_SENTRY_DSN"
      exit 1
    end
    
    puts "✅ Sentry DSN configured"
    puts "📍 Environment: #{Rails.env}"
    puts "📍 Enabled: #{Sentry.configuration.enabled_environments.include?(Rails.env)}"
    puts ""
    
    # Test 1: Simple message
    puts "Test 1: Sending test message..."
    Sentry.capture_message("Test message from Vantura rake task")
    puts "✅ Message sent"
    puts ""
    
    # Test 2: Capture exception with context
    puts "Test 2: Sending test error with context..."
    begin
      Rails.error.report(
        StandardError.new("Test error from Vantura"),
        handled: true,
        severity: :info,
        context: {
          test_type: "manual_test",
          timestamp: Time.current,
          user_id: "test_user"
        }
      )
      puts "✅ Error sent with context"
    rescue => e
      puts "❌ Failed to send error: #{e.message}"
    end
    puts ""
    
    # Test 3: Rails.error.handle
    puts "Test 3: Testing Rails.error.handle..."
    result = Rails.error.handle(StandardError, context: { test: "handle_test" }) do
      raise StandardError, "Test error via Rails.error.handle"
    end
    puts "✅ Rails.error.handle test complete (error was swallowed)"
    puts ""
    
    puts "🎉 All tests complete!"
    puts ""
    puts "Check your Sentry dashboard at: https://sentry.io"
    puts "You should see 3 new events (2 errors + 1 message)"
  end
  
  desc "Show Sentry configuration"
  task config: :environment do
    puts "Sentry Configuration:"
    puts "=" * 60
    puts "DSN: #{Sentry.configuration.dsn ? '✅ Configured' : '❌ Not configured'}"
    puts "Environment: #{Rails.env}"
    puts "Enabled Environments: #{Sentry.configuration.enabled_environments.join(', ')}"
    puts "Enabled: #{Sentry.configuration.enabled_environments.include?(Rails.env) ? 'Yes' : 'No'}"
    puts "Release: #{Sentry.configuration.release || 'Not set'}"
    puts "Sample Rate: #{Sentry.configuration.traces_sample_rate}"
    puts "=" * 60
  end
end

