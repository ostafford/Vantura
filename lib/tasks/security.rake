# lib/tasks/security.rake
namespace :security do
  desc "Generate secure secrets for Rails application"
  task generate_secrets: :environment do
    puts "🔐 Generating secure secrets for Vantura..."
    puts "=" * 50
    # Generate a strong secret key base
    puts "SECRET_KEY_BASE=#{SecureRandom.hex(64)}"
    # Generate a session secret
    puts "SESSION_SECRET=#{SecureRandom.hex(32)}"
    # Generate a CSRF secret
    puts "CSRF_SECRET=#{SecureRandom.hex(32)}"
    # Generate a generic API key
    puts "API_KEY=#{SecureRandom.hex(32)}"
    puts "=" * 50
    puts "⚠️  SECURITY WARNING:"
    puts "1. Store these secrets securely"
    puts "2. Never commit them to version control"
    puts "3. Use environment-specific secret management in production"
    puts "4. Rotate secrets regularly (every 90 days recommended)"
    puts "5. Monitor access to these secrets"
  end

  desc "Audit environment variables for security"
  task audit_env_vars: :environment do
    puts "🔍 Auditing environment variables for security..."
    puts "=" * 50

    critical_secrets = %w[RAILS_MASTER_KEY SECRET_KEY_BASE UPTRACE_DSN SENTRY_DSN UP_BANK_API_TOKEN]
    sensitive_config = %w[DATABASE_URL SMTP_USERNAME SMTP_PASSWORD MAILER_HOST]
    public_config = ENV.keys - critical_secrets - sensitive_config

    puts "🔴 CRITICAL SECRETS (#{critical_secrets.count}):"
    critical_secrets.each do |key|
      value = ENV[key]
      status = value.present? ? "✅ Configured" : "❌ MISSING"
      puts "  • #{key}: #{status}"
    end

    puts "\n🟡 SENSITIVE CONFIGURATION (#{sensitive_config.count}):"
    sensitive_config.each do |key|
      value = ENV[key]
      status = value.present? ? "✅ Configured" : "❌ MISSING"
      puts "  • #{key}: #{status}"
    end

    puts "\n🟢 PUBLIC CONFIGURATION (#{public_config.count}):"
    public_config.sort.each do |key|
      puts "  • #{key}"
    end

    puts "\n" + "=" * 50
    puts "📋 SECURITY RECOMMENDATIONS:"
    puts "1. Ensure critical secrets are properly secured"
    puts "2. Use environment-specific secret management"
    puts "3. Implement secret rotation policies"
    puts "4. Monitor access to sensitive configuration"
    puts "5. Regular security audits"
  end

  desc "Validate environment variable security"
  task validate_security: :environment do
    puts "🔒 Validating environment variable security..."
    puts "=" * 50

    issues_found = []

    # Check for critical secrets
    %w[SECRET_KEY_BASE RAILS_MASTER_KEY].each do |key|
      issues_found << "Missing required secret: #{key}" unless ENV[key].present?
    end

    # Check for length of secrets (example)
    if ENV["SECRET_KEY_BASE"].present? && ENV["SECRET_KEY_BASE"].length < 64
      issues_found << "SECRET_KEY_BASE is too short (min 64 chars recommended)"
    end

    if issues_found.empty?
      puts "✅ No critical security issues found."
    else
      puts "⚠️  SECURITY ISSUES FOUND:"
      issues_found.each { |issue| puts "  • #{issue}" }
    end

    puts "\n" + "=" * 50
    puts "📋 NEXT STEPS:"
    puts "1. Address any security issues found"
    puts "2. Implement proper secret management"
    puts "3. Regular security validation"
    puts "4. Monitor for security issues"
  end

  desc "Validate Rails security guide compliance"
  task validate_rails_security: :environment do
    puts "🔒 Validating Rails Security Guide compliance..."
    puts "=" * 50
    puts "Reference: https://guides.rubyonrails.org/security.html"
    puts "=" * 50

    compliance_score = 0
    total_checks = 0

    # Check SSL/TLS Configuration
    puts "\n🔐 SSL/TLS Configuration:"
    total_checks += 1
    if Rails.application.config.force_ssl
      puts "  ✅ Force SSL enabled"
      compliance_score += 1
    else
      puts "  ⚠️  Force SSL not enabled"
    end

    if Rails.application.config.assume_ssl
      puts "  ✅ Assume SSL enabled"
      compliance_score += 1
    else
      puts "  ⚠️  Assume SSL not enabled"
    end
    total_checks += 1

    # Check Content Security Policy
    puts "\n🛡️ Content Security Policy:"
    total_checks += 1
    if Rails.application.config.content_security_policy
      puts "  ✅ Content Security Policy configured"
      compliance_score += 1
    else
      puts "  ⚠️  Content Security Policy not configured"
    end

    # Check Security Headers
    puts "\n📋 Security Headers:"
    headers = Rails.application.config.action_dispatch.default_headers

    security_headers = {
      "X-Frame-Options" => "Prevents clickjacking",
      "X-Content-Type-Options" => "Prevents MIME-sniffing",
      "X-XSS-Protection" => "XSS protection",
      "Referrer-Policy" => "Referrer information control"
    }

    security_headers.each do |header, description|
      total_checks += 1
      if headers[header]
        puts "  ✅ #{header}: #{description}"
        compliance_score += 1
      else
        puts "  ⚠️  #{header} not configured: #{description}"
      end
    end

    # Check Parameter Filtering
    puts "\n🔍 Parameter Filtering:"
    total_checks += 1
    if Rails.application.config.filter_parameters.any?
      puts "  ✅ Sensitive parameters filtered from logs"
      compliance_score += 1
    else
      puts "  ⚠️  No parameter filtering configured"
    end

    # Check CSRF Protection
    puts "\n🛡️ CSRF Protection:"
    total_checks += 1
    if Rails.application.config.action_controller.default_protect_from_forgery
      puts "  ✅ CSRF protection enabled"
      compliance_score += 1
    else
      puts "  ⚠️  CSRF protection not enabled"
    end

    # Check Session Security
    puts "\n🍪 Session Security:"
    total_checks += 1
    session_config = Rails.application.config.session_options
    if session_config[:httponly]
      puts "  ✅ HTTPOnly cookies enabled"
      compliance_score += 1
    else
      puts "  ⚠️  HTTPOnly cookies not enabled"
    end

    # Calculate compliance percentage
    compliance_percentage = (compliance_score.to_f / total_checks * 100).round(1)

    puts "\n" + "=" * 50
    puts "📊 RAILS SECURITY COMPLIANCE REPORT"
    puts "=" * 50
    puts "Compliance Score: #{compliance_score}/#{total_checks} (#{compliance_percentage}%)"

    if compliance_percentage >= 90
      puts "🎉 Excellent security compliance!"
    elsif compliance_percentage >= 75
      puts "✅ Good security compliance"
    elsif compliance_percentage >= 50
      puts "⚠️  Moderate security compliance - improvements needed"
    else
      puts "🚨 Low security compliance - immediate action required"
    end

    puts "\n📋 RECOMMENDATIONS:"
    puts "1. Review Rails Security Guide: https://guides.rubyonrails.org/security.html"
    puts "2. Implement missing security measures"
    puts "3. Regular security audits"
    puts "4. Keep dependencies updated"
    puts "5. Monitor security advisories"
  end
end
