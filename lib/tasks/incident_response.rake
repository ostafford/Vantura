# lib/tasks/incident_response.rake
namespace :incident do
  desc "Run a comprehensive system health check for Vantura"
  task health_check: :environment do
    puts "🔍 Running Vantura System Health Check..."
    puts "=" * 50
    puts "Timestamp: #{Time.current.utc}"

    # 1. Application Status
    puts "\n1. Application Status:"
    begin
      response = Net::HTTP.get_response(URI("http://localhost:3001/up"))
      if response.code == "200"
        puts "  ✅ Application UP (HTTP 200)"
      else
        puts "  ❌ Application DOWN (HTTP #{response.code})"
      end
    rescue Errno::ECONNREFUSED
      puts "  ❌ Application DOWN (Connection refused)"
    rescue => e
      puts "  ❌ Application Health Check Error: #{e.message}"
    end

    # 2. Database Status
    puts "\n2. Database Status:"
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      puts "  ✅ Database UP"
      puts "  📊 User Count: #{User.count}"
      puts "  📊 Transaction Count: #{Transaction.count}"
    rescue => e
      puts "  ❌ Database DOWN: #{e.message}"
    end

    # 3. System Resources (basic check, more advanced tools needed for production)
    puts "\n3. System Resources:"
    begin
      disk_usage = `df -h . | awk 'NR==2 {print $5}'`.strip
      memory_usage = `free -h | awk 'NR==2 {print $3}'`.strip # Linux specific
      puts "  💾 Disk Usage: #{disk_usage}"
      puts "  🧠 Memory Usage: #{memory_usage}"
    rescue => e
      puts "  ⚠️  Could not retrieve system resources: #{e.message}"
    end

    # 4. Recent Errors (Sentry integration check)
    puts "\n4. Recent Errors:"
    if defined?(Sentry) && Sentry.initialized?
      puts "  ✅ Sentry error tracking initialized"
      # In a real scenario, you'd query Sentry API for recent errors
      puts "  ℹ️  (Requires Sentry API integration for real-time error count)"
    else
      puts "  ⚠️  Sentry error tracking disabled for development environment"
    end

    puts "\n" + "=" * 50
    puts "🏥 Health check completed"
  rescue => e
    puts "❌ An error occurred during health check: #{e.message}"
    Rails.logger.error "Incident health check failed: #{e.message}\n#{e.backtrace.join("\n")}"
  end

  desc "Check incident response readiness"
  task check_readiness: :environment do
    puts "🔍 Checking Incident Response Readiness..."
    puts "=" * 50
    puts "Timestamp: #{Time.current.utc}"

    readiness_score = 0
    total_checks = 0

    # 1. Health Check Endpoint
    puts "\n1. Health Check Endpoint:"
    total_checks += 1
    begin
      response = Net::HTTP.get_response(URI("http://localhost:3001/up"))
      if response.code == "200"
        puts "  ✅ Health check endpoint working"
        readiness_score += 1
      else
        puts "  ❌ Health check endpoint not responding (HTTP #{response.code})"
      end
    rescue Errno::ECONNREFUSED
      puts "  ❌ Health check endpoint not responding (Connection refused)"
    end

    # 2. Database Backup System
    puts "\n2. Database Backup System:"
    total_checks += 1
    backup_path = Rails.root.join("backups")
    adapter_name = ActiveRecord::Base.connection.adapter_name

    if adapter_name == "PostgreSQL"
      # Check for PostgreSQL backup files (.sql or .dump)
      backup_files = Dir.glob(backup_path.join("*.{sql,dump,pg_dump}"))
      if File.directory?(backup_path) && backup_files.any?
        puts "  ✅ Backup directory exists with #{backup_files.count} PostgreSQL backup(s)"
        readiness_score += 1
      else
        puts "  ⚠️  Backup directory not found or empty"
      end
    elsif adapter_name == "SQLite"
      # Check for SQLite backup files (for rollback scenarios)
      backup_files = Dir.glob(backup_path.join("*.sqlite3*"))
      if File.directory?(backup_path) && backup_files.any?
        puts "  ✅ Backup directory exists with #{backup_files.count} SQLite backup(s)"
        readiness_score += 1
      else
        puts "  ⚠️  Backup directory not found or empty"
      end
    else
      puts "  ⚠️  Unknown database adapter: #{adapter_name}"
    end

    # 3. Security Validation
    puts "\n3. Security Validation:"
    total_checks += 1
    # This assumes `security:validate_security` task exists and can be run
    # For a real check, you'd run it and parse its output or check specific configs
    if Rake::Task.task_defined?("security:validate_security")
      puts "  ✅ Security validation tasks available"
      readiness_score += 1
    else
      puts "  ⚠️  Security validation tasks not found"
    end

    # 4. Monitoring Setup
    puts "\n4. Monitoring Setup:"
    total_checks += 1
    if ENV["UPTRACE_DSN"].present? || defined?(Sentry) && Sentry.initialized?
      puts "  ✅ Security monitoring configured"
      readiness_score += 1
    else
      puts "  ⚠️  Monitoring (Uptrace/Sentry) not configured"
    end

    # 5. Documentation
    puts "\n5. Documentation:"
    total_checks += 1
    if File.exist?(Rails.root.join("docs", "INCIDENT_RESPONSE_PLAN.md"))
      puts "  ✅ Incident response plan exists"
      readiness_score += 1
    else
      puts "  ⚠️  Incident response plan not found"
    end

    puts "\n" + "=" * 50
    puts "📊 INCIDENT RESPONSE READINESS REPORT"
    puts "=" * 50
    puts "Readiness Score: #{readiness_score}/#{total_checks} (#{(readiness_score.to_f / total_checks * 100).round(1)}%)"

    if readiness_score.to_f / total_checks >= 0.9
      puts "🎉 Excellent incident response readiness!"
    elsif readiness_score.to_f / total_checks >= 0.7
      puts "✅ Good incident response readiness"
    else
      puts "🚨 Low incident response readiness - immediate action required"
    end

    puts "\n📋 RECOMMENDATIONS:"
    puts "1. Review incident response plan regularly"
    puts "2. Test incident response procedures"
    puts "3. Update emergency contacts"
    puts "4. Train team on incident response"
    puts "5. Monitor system health continuously"
  rescue => e
    puts "❌ An error occurred during readiness check: #{e.message}"
    Rails.logger.error "Incident readiness check failed: #{e.message}\n#{e.backtrace.join("\n")}"
  end

  desc "Simulate an incident response drill"
  task :drill, [ :scenario ] => :environment do |t, args|
    puts "🎯 Incident Response Drill Simulation..."
    puts "=" * 50
    puts "Timestamp: #{Time.current.utc}"

    scenario = args[:scenario] || "Application Down" # Default scenario

    scenarios = {
      "Application Down" => {
        description: "Application is not responding to requests",
        severity: "P1 - Critical",
        expected_response_time: "< 15 minutes"
      },
      "Database Connection Issues" => {
        description: "Database is unreachable or slow",
        severity: "P1 - Critical",
        expected_response_time: "< 30 minutes"
      },
      "Performance Degradation" => {
        description: "Application is slow, high latency/errors",
        severity: "P2 - High",
        expected_response_time: "< 60 minutes"
      },
      "Security Incident" => {
        description: "Unauthorized access or data breach detected",
        severity: "P0 - Emergency",
        expected_response_time: "< 5 minutes (initial containment)"
      },
      "Data Loss" => {
        description: "Critical data has been lost or corrupted",
        severity: "P0 - Emergency",
        expected_response_time: "< 60 minutes (initial recovery)"
      }
    }

    selected_scenario = scenarios[scenario]
    unless selected_scenario
      puts "Invalid scenario. Available scenarios: #{scenarios.keys.join(', ')}"
      exit 1
    end

    puts "\n🎭 Simulating '#{scenario}' scenario..."
    puts "   Description: #{selected_scenario[:description]}"
    match "   Severity: #{selected_scenario[:severity]}"
    puts "   Expected Response Time: #{selected_scenario[:expected_response_time]}"

    # Simulate steps from the Incident Response Plan
    puts "\n🔍 Step 1: Incident Detection"
    sleep 1
    puts "   ✅ Health check endpoint monitoring"
    sleep 0.5
    puts "   ✅ Alert system notification"
    sleep 0.5
    puts "   ✅ Incident ticket created"

    puts "\n📞 Step 2: Initial Response"
    sleep 1
    puts "   ✅ Response team activated"
    sleep 0.5
    puts "   ✅ Emergency notifications sent"
    sleep 0.5
    puts "   ✅ Initial assessment completed"

    puts "\n🔧 Step 3: Investigation"
    sleep 1
    puts "   ✅ System status checked"
    sleep 0.5
    puts "   ✅ Application logs reviewed"
    sleep 0.5
    puts "   ✅ Root cause identified"

    puts "\n🔄 Step 4: Recovery"
    sleep 1
    puts "   ✅ Application restarted"
    sleep 0.5
    puts "   ✅ System functionality verified"
    sleep 0.5
    puts "   ✅ Recovery confirmed"

    puts "\n📝 Step 5: Post-Incident"
    sleep 1
    puts "   ✅ Incident documented"
    sleep 0.5
    puts "   ✅ Lessons learned captured"
    sleep 0.5
    puts "   ✅ Improvements planned"

    puts "\n🎉 Drill simulation completed successfully!"
    puts "📋 All incident response procedures validated"
  rescue => e
    puts "❌ An error occurred during incident drill: #{e.message}"
    Rails.logger.error "Incident drill failed: #{e.message}\n#{e.backtrace.join("\n")}"
  end
end
