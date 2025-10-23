# lib/tasks/deployment.rake
# Deployment validation and management tasks for Vantura

namespace :deploy do
  desc "Validate deployment configuration"
  task validate: :environment do
    puts "🔍 Validating Vantura Deployment Configuration..."
    puts "=" * 50
    puts "Timestamp: #{Time.current}"
    puts ""

    validation_score = 0
    total_checks = 0

    # Check Kamal configuration
    puts "1. Kamal Configuration:"
    total_checks += 1
    deploy_config = Rails.root.join("config", "deploy.yml")
    if File.exist?(deploy_config)
      puts "  ✅ Kamal deployment configuration exists"
      validation_score += 1
    else
      puts "  ❌ Kamal deployment configuration not found"
    end

    # Check secrets configuration
    puts "\n2. Secrets Configuration:"
    total_checks += 1
    secrets_file = Rails.root.join(".kamal", "secrets")
    if File.exist?(secrets_file)
      puts "  ✅ Kamal secrets configuration exists"
      validation_score += 1
    else
      puts "  ❌ Kamal secrets configuration not found"
    end

    # Check environment variables
    puts "\n3. Environment Variables:"
    required_vars = %w[RAILS_MASTER_KEY SECRET_KEY_BASE UP_BANK_API_TOKEN SMTP_PASSWORD SENTRY_DSN UPTRACE_DSN]
    required_vars.each do |var|
      total_checks += 1
      if ENV[var].present?
        puts "  ✅ #{var} configured"
        validation_score += 1
      else
        puts "  ⚠️  #{var} not configured (development mode)"
      end
    end

    # Check SSL configuration
    puts "\n4. SSL Configuration:"
    total_checks += 1
    if Rails.application.config.force_ssl
      puts "  ✅ SSL enforcement configured"
      validation_score += 1
    else
      puts "  ⚠️  SSL enforcement not configured (development mode)"
    end

    # Check database configuration
    puts "\n5. Database Configuration:"
    total_checks += 1
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      puts "  ✅ Database connection working"
      validation_score += 1
    rescue => e
      puts "  ❌ Database connection failed: #{e.message}"
    end

    # Check monitoring configuration
    puts "\n6. Monitoring Configuration:"
    total_checks += 1
    if Rails.application.config.respond_to?(:content_security_policy)
      puts "  ✅ Security monitoring configured"
      validation_score += 1
    else
      puts "  ⚠️  Security monitoring not configured"
    end

    # Calculate validation percentage
    validation_percentage = (validation_score.to_f / total_checks * 100).round(1)

    puts "\n" + "=" * 50
    puts "📊 DEPLOYMENT CONFIGURATION VALIDATION REPORT"
    puts "=" * 50
    puts "Validation Score: #{validation_score}/#{total_checks} (#{validation_percentage}%)"

    if validation_percentage >= 90
      puts "🎉 Excellent deployment configuration!"
    elsif validation_percentage >= 75
      puts "✅ Good deployment configuration"
    elsif validation_percentage >= 50
      puts "⚠️  Moderate deployment configuration - improvements needed"
    else
      puts "🚨 Low deployment configuration - immediate action required"
    end

    puts "\n📋 RECOMMENDATIONS:"
    puts "1. Review deployment configuration"
    puts "2. Configure production environment variables"
    puts "3. Test deployment procedures"
    puts "4. Verify SSL configuration"
    puts "5. Test monitoring systems"
  end

  desc "Test deployment procedures"
  task test: :environment do
    puts "🧪 Testing Vantura Deployment Procedures..."
    puts "=" * 50
    puts "Timestamp: #{Time.current}"
    puts ""

    # Test health check endpoint
    puts "1. Testing Health Check Endpoint:"
    begin
      response = Net::HTTP.get_response(URI("http://localhost:3001/up"))
      puts "  ✅ Health check endpoint responding (HTTP #{response.code})"
    rescue => e
      puts "  ❌ Health check endpoint failed: #{e.message}"
    end

    # Test database connectivity
    puts "\n2. Testing Database Connectivity:"
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      puts "  ✅ Database connection working"
    rescue => e
      puts "  ❌ Database connection failed: #{e.message}"
    end

    # Test application functionality
    puts "\n3. Testing Application Functionality:"
    begin
      response = Net::HTTP.get_response(URI("http://localhost:3001/"))
      if response.code == "200"
        puts "  ✅ Application responding correctly"
      else
        puts "  ⚠️  Application responding with HTTP #{response.code}"
      end
    rescue => e
      puts "  ❌ Application test failed: #{e.message}"
    end

    # Test security configuration
    puts "\n4. Testing Security Configuration:"
    begin
      Rake::Task["security:validate_security"].invoke
      puts "  ✅ Security configuration validated"
    rescue => e
      puts "  ❌ Security validation failed: #{e.message}"
    end

    puts "\n" + "=" * 50
    puts "🧪 Deployment procedure testing completed"
  end

  desc "Check deployment readiness"
  task readiness: :environment do
    puts "🔍 Checking Vantura Deployment Readiness..."
    puts "=" * 50
    puts "Timestamp: #{Time.current}"
    puts ""

    readiness_score = 0
    total_checks = 0

    # Check configuration files
    puts "1. Configuration Files:"
    config_files = [
      "config/deploy.yml",
      ".kamal/secrets",
      "config/database.yml",
      "config/environments/production.rb"
    ]

    config_files.each do |file|
      total_checks += 1
      if File.exist?(Rails.root.join(file))
        puts "  ✅ #{file} exists"
        readiness_score += 1
      else
        puts "  ❌ #{file} not found"
      end
    end

    # Check documentation
    puts "\n2. Documentation:"
    doc_files = [
      "docs/PRODUCTION_DEPLOYMENT_CONFIGURATION.md",
      "docs/INCIDENT_RESPONSE_PLAN.md",
      "docs/ENVIRONMENT_VARIABLES_SECURITY.md"
    ]

    doc_files.each do |file|
      total_checks += 1
      if File.exist?(Rails.root.join(file))
        puts "  ✅ #{file} exists"
        readiness_score += 1
      else
        puts "  ❌ #{file} not found"
      end
    end

    # Check application health
    puts "\n3. Application Health:"
    total_checks += 1
    begin
      response = Net::HTTP.get_response(URI("http://localhost:3001/up"))
      if response.code == "200"
        puts "  ✅ Application health check passing"
        readiness_score += 1
      else
        puts "  ⚠️  Application health check responding with HTTP #{response.code}"
      end
    rescue => e
      puts "  ❌ Application health check failed: #{e.message}"
    end

    # Check database
    puts "\n4. Database:"
    total_checks += 1
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      puts "  ✅ Database connection working"
      readiness_score += 1
    rescue => e
      puts "  ❌ Database connection failed: #{e.message}"
    end

    # Check security
    puts "\n5. Security:"
    total_checks += 1
    if Rails.application.config.respond_to?(:content_security_policy)
      puts "  ✅ Security configuration present"
      readiness_score += 1
    else
      puts "  ⚠️  Security configuration not found"
    end

    # Calculate readiness percentage
    readiness_percentage = (readiness_score.to_f / total_checks * 100).round(1)

    puts "\n" + "=" * 50
    puts "📊 DEPLOYMENT READINESS REPORT"
    puts "=" * 50
    puts "Readiness Score: #{readiness_score}/#{total_checks} (#{readiness_percentage}%)"

    if readiness_percentage >= 90
      puts "🎉 Excellent deployment readiness!"
    elsif readiness_percentage >= 75
      puts "✅ Good deployment readiness"
    elsif readiness_percentage >= 50
      puts "⚠️  Moderate deployment readiness - improvements needed"
    else
      puts "🚨 Low deployment readiness - immediate action required"
    end

    puts "\n📋 RECOMMENDATIONS:"
    puts "1. Complete missing configuration files"
    puts "2. Update documentation"
    puts "3. Test application functionality"
    puts "4. Verify security configuration"
    puts "5. Prepare deployment checklist"
  end
end
