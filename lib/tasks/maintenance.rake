# frozen_string_literal: true

namespace :maintenance do
  desc "Run all maintenance tasks"
  task all: :environment do
    puts "🧹 Running all maintenance tasks..."
    puts ""

    Rake::Task["maintenance:cleanup_sessions"].invoke
    Rake::Task["maintenance:generate_recurring"].invoke

    puts ""
    puts "✅ All maintenance tasks complete!"
  end

  desc "Clean up expired sessions"
  task cleanup_sessions: :environment do
    puts "🗑️  Cleaning up expired sessions..."

    result = SessionCleanupJob.perform_now

    puts "   ✅ Deleted #{result[:deleted_count]} expired sessions"
  end

  desc "Generate recurring transactions"
  task generate_recurring: :environment do
    puts "🔄 Generating recurring transactions..."

    result = RecurringTransactionGeneratorJob.perform_now(months_ahead: 12)

    puts "   ✅ Processed #{result[:patterns_processed]} patterns"
    puts "   ✅ Generated #{result[:transactions_generated]} transactions"
  end

  desc "Show maintenance status"
  task status: :environment do
    puts "📊 Maintenance Status"
    puts "=" * 60

    # Sessions
    active_sessions = Session.active.count
    expired_sessions = Session.expired.count
    puts "Sessions:"
    puts "  Active: #{active_sessions}"
    puts "  Expired: #{expired_sessions}"
    puts ""

    # Recurring Transactions
    active_recurring = RecurringTransaction.active.count
    inactive_recurring = RecurringTransaction.inactive.count
    puts "Recurring Patterns:"
    puts "  Active: #{active_recurring}"
    puts "  Inactive: #{inactive_recurring}"
    puts ""

    # Hypothetical Transactions
    hypothetical_txns = Transaction.hypothetical.count
    real_txns = Transaction.real.count
    puts "Transactions:"
    puts "  Hypothetical: #{hypothetical_txns}"
    puts "  Real: #{real_txns}"
    puts ""

    # Users
    total_users = User.count
    users_with_accounts = User.joins(:accounts).distinct.count
    puts "Users:"
    puts "  Total: #{total_users}"
    puts "  With Accounts: #{users_with_accounts}"

    puts "=" * 60
  end

  desc "Database statistics"
  task db_stats: :environment do
    puts "💾 Database Statistics"
    puts "=" * 60

    # Get database size
    if ActiveRecord::Base.connection.adapter_name == "SQLite"
      db_path = Rails.root.join("storage", "#{Rails.env}.sqlite3")
      if File.exist?(db_path)
        size_mb = File.size(db_path).to_f / 1024 / 1024
        puts "Database Size: #{'%.2f' % size_mb} MB"
      end
    end

    # Record counts
    puts ""
    puts "Record Counts:"
    puts "  Users: #{User.count}"
    puts "  Accounts: #{Account.count}"
    puts "  Transactions: #{Transaction.count}"
    puts "  Recurring Patterns: #{RecurringTransaction.count}"
    puts "  Sessions: #{Session.count}"

    puts "=" * 60
  end
end
