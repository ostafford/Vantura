# lib/tasks/arch_linux_deployment.rake
# Arch Linux deployment validation and testing tasks

namespace :arch_linux do
  desc "Test Arch Linux server connectivity"
  task :test_connectivity => :environment do
    puts "🔍 Testing Arch Linux Server Connectivity..."
    puts "=" * 50
    puts "Target Server: okky@192.168.1.18"
    puts "Timestamp: #{Time.current}"
    puts ""

    # Test SSH connectivity
    puts "1. Testing SSH Connectivity:"
    begin
      result = `ssh -o ConnectTimeout=10 -o BatchMode=yes okky@192.168.1.18 "echo 'SSH connection successful'" 2>&1`
      if $?.success?
        puts "  ✅ SSH connection successful"
        puts "  📝 Response: #{result.strip}"
      else
        puts "  ❌ SSH connection failed"
        puts "  📝 Error: #{result.strip}"
      end
    rescue => e
      puts "  ❌ SSH connection error: #{e.message}"
    end

    # Test Docker installation
    puts "\n2. Testing Docker Installation:"
    begin
      result = `ssh -o ConnectTimeout=10 -o BatchMode=yes okky@192.168.1.18 "docker --version" 2>&1`
      if $?.success?
        puts "  ✅ Docker installed"
        puts "  📝 Version: #{result.strip}"
      else
        puts "  ❌ Docker not installed or not accessible"
        puts "  📝 Error: #{result.strip}"
      end
    rescue => e
      puts "  ❌ Docker check error: #{e.message}"
    end

    # Test Docker service status
    puts "\n3. Testing Docker Service Status:"
    begin
      result = `ssh -o ConnectTimeout=10 -o BatchMode=yes okky@192.168.1.18 "sudo systemctl is-active docker" 2>&1`
      if $?.success? && result.strip == "active"
        puts "  ✅ Docker service is running"
      else
        puts "  ❌ Docker service is not running"
        puts "  📝 Status: #{result.strip}"
      end
    rescue => e
      puts "  ❌ Docker service check error: #{e.message}"
    end

    # Test firewall status
    puts "\n4. Testing Firewall Configuration:"
    begin
      result = `ssh -o ConnectTimeout=10 -o BatchMode=yes okky@192.168.1.18 "sudo ufw status" 2>&1`
      if $?.success?
        puts "  ✅ Firewall status retrieved"
        puts "  📝 Status: #{result.strip}"
      else
        puts "  ❌ Firewall status check failed"
        puts "  📝 Error: #{result.strip}"
      end
    rescue => e
      puts "  ❌ Firewall check error: #{e.message}"
    end

    puts "\n" + "=" * 50
    puts "🏥 Arch Linux connectivity test completed"
  end

  desc "Test domain resolution"
  task :test_domain => :environment do
    puts "🔍 Testing Domain Resolution..."
    puts "=" * 50
    puts "Domain: vantura.app"
    puts "Target IP: 192.168.1.18"
    puts "Timestamp: #{Time.current}"
    puts ""

    # Test domain resolution
    puts "1. Testing Domain Resolution:"
    begin
      result = `nslookup vantura.app 2>&1`
      if result.include?("192.168.1.18")
        puts "  ✅ Domain resolving to correct IP"
        puts "  📝 Resolution: #{result.strip}"
      else
        puts "  ❌ Domain not resolving to correct IP"
        puts "  📝 Resolution: #{result.strip}"
      end
    rescue => e
      puts "  ❌ Domain resolution error: #{e.message}"
    end

    # Test HTTP connectivity
    puts "\n2. Testing HTTP Connectivity:"
    begin
      response = Net::HTTP.get_response(URI('http://vantura.app'))
      puts "  ✅ HTTP connection successful"
      puts "  📝 Status: HTTP #{response.code}"
    rescue => e
      puts "  ❌ HTTP connection failed: #{e.message}"
    end

    # Test HTTPS connectivity
    puts "\n3. Testing HTTPS Connectivity:"
    begin
      response = Net::HTTP.get_response(URI('https://vantura.app'))
      puts "  ✅ HTTPS connection successful"
      puts "  📝 Status: HTTP #{response.code}"
    rescue => e
      puts "  ❌ HTTPS connection failed: #{e.message}"
    end

    puts "\n" + "=" * 50
    puts "🏥 Domain resolution test completed"
  end

  desc "Test deployment configuration"
  task :test_deployment => :environment do
    puts "🔍 Testing Deployment Configuration..."
    puts "=" * 50
    puts "Timestamp: #{Time.current}"
    puts ""

    # Test Kamal configuration
    puts "1. Testing Kamal Configuration:"
    begin
      result = `kamal config validate 2>&1`
      if $?.success?
        puts "  ✅ Kamal configuration valid"
      else
        puts "  ❌ Kamal configuration invalid"
        puts "  📝 Error: #{result.strip}"
      end
    rescue => e
      puts "  ❌ Kamal configuration check error: #{e.message}"
    end

    # Test secrets configuration
    puts "\n2. Testing Secrets Configuration:"
    begin
      secrets_file = Rails.root.join('.kamal', 'secrets')
      if File.exist?(secrets_file)
        puts "  ✅ Secrets file exists"
        secrets_content = File.read(secrets_file)
        required_secrets = %w[RAILS_MASTER_KEY SECRET_KEY_BASE UP_BANK_API_TOKEN SMTP_PASSWORD SENTRY_DSN UPTRACE_DSN]
        missing_secrets = required_secrets.select { |secret| !secrets_content.include?(secret) }
        if missing_secrets.empty?
          puts "  ✅ All required secrets configured"
        else
          puts "  ⚠️  Missing secrets: #{missing_secrets.join(', ')}"
        end
      else
        puts "  ❌ Secrets file not found"
      end
    rescue => e
      puts "  ❌ Secrets configuration check error: #{e.message}"
    end

    # Test deployment configuration
    puts "\n3. Testing Deployment Configuration:"
    begin
      deploy_config = Rails.root.join('config', 'deploy.yml')
      if File.exist?(deploy_config)
        puts "  ✅ Deployment configuration exists"
        deploy_content = File.read(deploy_config)
        if deploy_content.include?('okky@192.168.1.18')
          puts "  ✅ Server configuration correct"
        else
          puts "  ❌ Server configuration incorrect"
        end
      else
        puts "  ❌ Deployment configuration not found"
      end
    rescue => e
      puts "  ❌ Deployment configuration check error: #{e.message}"
    end

    puts "\n" + "=" * 50
    puts "🏥 Deployment configuration test completed"
  end

  desc "Test complete deployment setup"
  task :test_setup => :environment do
    puts "🔍 Testing Complete Arch Linux Deployment Setup..."
    puts "=" * 50
    puts "Timestamp: #{Time.current}"
    puts ""

    # Run all tests
    Rake::Task['arch_linux:test_connectivity'].invoke
    puts ""
    Rake::Task['arch_linux:test_domain'].invoke
    puts ""
    Rake::Task['arch_linux:test_deployment'].invoke

    puts "\n" + "=" * 50
    puts "🎉 Complete Arch Linux deployment setup test completed"
    puts "📋 Review the results above and address any issues before deployment"
  end
end
