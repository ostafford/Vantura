# frozen_string_literal: true

namespace :webhook do
  desc "Test webhook processing with encrypted token"
  task test: :environment do
    puts "=== Webhook Processing Test ==="
    puts ""

    # Find user with token
    user = User.all.find { |u| u.has_up_bank_token? }

    unless user
      puts "ERROR: No user with Up Bank token found"
      puts "Create a user and set up_bank_token first"
      exit 1
    end

    puts "✓ Found user with token"
    puts "  User ID: #{user.id}"
    puts "  Email: #{user.email_address}"
    puts "  Has token: #{user.has_up_bank_token?}"
    puts ""

    # Verify token encryption
    ciphertext = user.read_attribute(:up_bank_token_ciphertext)
    if ciphertext.present?
      puts "✓ Token is encrypted"
      puts "  Ciphertext present: Yes"
      puts "  Ciphertext length: #{ciphertext.length} characters"
    else
      puts "✗ Token encryption issue"
      puts "  Ciphertext is missing"
      exit 1
    end
    puts ""

    # Test token decryption
    decrypted_token = user.up_bank_token
    if decrypted_token.present?
      puts "✓ Token decrypts correctly"
      puts "  Decrypted token length: #{decrypted_token.length} characters"
      puts "  Token starts with: #{decrypted_token[0..10]}..."
    else
      puts "✗ Token decryption failed"
      puts "  Token is nil after decryption"
      exit 1
    end
    puts ""

    # Create test webhook event
    puts "Creating test webhook event..."
    webhook_event = WebhookEvent.create!(
      user: user,
      payload: {
        "data" => {
          "attributes" => {
            "eventType" => "PING"
          }
        }
      }
    )
    puts "✓ Webhook event created (ID: #{webhook_event.id})"
    puts ""

    # Process webhook
    puts "Processing webhook..."
    begin
      ProcessUpWebhookJob.perform_now(webhook_event)
      webhook_event.reload

      if webhook_event.processed?
        puts "✓ Webhook processed successfully"
        puts "  Processed at: #{webhook_event.processed_at}"
      else
        puts "✗ Webhook processing failed"
        if webhook_event.error_message
          puts "  Error: #{webhook_event.error_message}"
        end
        exit 1
      end
    rescue => e
      puts "✗ Error processing webhook: #{e.message}"
      puts "  Backtrace:"
      puts e.backtrace.first(5).map { |line| "    #{line}" }.join("\n")
      exit 1
    end
    puts ""

    # Test API service initialization
    puts "Testing API service initialization..."
    begin
      service = UpBankApiService.new(user)
      puts "✓ API service initialized successfully"
    rescue => e
      puts "✗ API service initialization failed: #{e.message}"
      exit 1
    end
    puts ""

    puts "=== All Tests Passed ==="
    puts ""
    puts "Summary:"
    puts "  ✓ Token encryption working"
    puts "  ✓ Token decryption working"
    puts "  ✓ Webhook processing working"
    puts "  ✓ API service initialization working"
  end

  desc "Test token encryption/decryption cycle"
  task test_token: :environment do
    puts "=== Token Encryption/Decryption Test ==="
    puts ""

    # Find or create test user
    user = User.first || User.create!(
      email_address: "test_webhook@example.com",
      password: "password123"
    )

    test_token = "test_token_#{SecureRandom.hex(16)}"
    puts "Test token: #{test_token[0..20]}..."
    puts ""

    # Test encryption
    puts "1. Testing encryption..."
    user.update!(up_bank_token: test_token)
    ciphertext = user.read_attribute(:up_bank_token_ciphertext)

    if ciphertext.present?
      puts "   ✓ Token encrypted"
      puts "   Ciphertext: #{ciphertext[0..50]}..."
    else
      puts "   ✗ Encryption failed"
      exit 1
    end
    puts ""

    # Test decryption
    puts "2. Testing decryption..."
    user.reload
    decrypted = user.up_bank_token

    if decrypted == test_token
      puts "   ✓ Token decrypted correctly"
      puts "   Decrypted: #{decrypted[0..20]}..."
    else
      puts "   ✗ Decryption failed"
      puts "   Expected: #{test_token[0..20]}..."
      puts "   Got: #{decrypted}"
      exit 1
    end
    puts ""

    # Test helper methods
    puts "3. Testing helper methods..."
    if user.has_up_bank_token?
      puts "   ✓ has_up_bank_token? returns true"
    else
      puts "   ✗ has_up_bank_token? returns false"
      exit 1
    end

    if !user.needs_up_bank_setup?
      puts "   ✓ needs_up_bank_setup? returns false"
    else
      puts "   ✗ needs_up_bank_setup? returns true"
      exit 1
    end
    puts ""

    puts "=== All Token Tests Passed ==="
  end
end
