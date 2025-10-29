# lib/tasks/postgresql_verify.rake
namespace :db do
  desc "Verify PostgreSQL setup and connection"
  task verify_postgresql: :environment do
    puts "🔍 Verifying PostgreSQL Setup"
    puts "=" * 60

    # Check adapter
    adapter_name = ActiveRecord::Base.connection.adapter_name
    puts "Database Adapter: #{adapter_name}"

    unless adapter_name == "PostgreSQL"
      puts "❌ Expected PostgreSQL adapter, but got #{adapter_name}"
      puts "   Please update config/database.yml to use PostgreSQL"
      exit 1
    end
    puts "✅ Using PostgreSQL adapter"

    # Check connection
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      puts "✅ Database connection successful"
    rescue => e
      puts "❌ Database connection failed: #{e.message}"
      exit 1
    end

    # Check PostgreSQL version
    begin
      version_result = ActiveRecord::Base.connection.execute("SELECT version()").first
      version = version_result["version"]
      puts "✅ PostgreSQL Version: #{version}"

      # Extract version number
      version_match = version.match(/PostgreSQL (\d+\.\d+)/)
      if version_match
        major_version = version_match[1].to_f
        if major_version < 12.0
          puts "⚠️  Warning: PostgreSQL #{major_version} detected. PostgreSQL 12+ recommended."
        else
          puts "✅ PostgreSQL version #{major_version} is supported"
        end
      end
    rescue => e
      puts "⚠️  Could not determine PostgreSQL version: #{e.message}"
    end

    # Check current database
    begin
      db_result = ActiveRecord::Base.connection.execute("SELECT current_database(), current_user").first
      puts "✅ Current Database: #{db_result['current_database']}"
      puts "✅ Current User: #{db_result['current_user']}"
    rescue => e
      puts "⚠️  Could not get database info: #{e.message}"
    end

    # Check jsonb support
    puts "\n📋 Checking jsonb column support..."
    begin
      jsonb_test = ActiveRecord::Base.connection.execute(
        "SELECT '{\"test\": \"value\"}'::jsonb AS test_jsonb"
      ).first
      if jsonb_test
        puts "✅ jsonb type supported and working"
      end
    rescue => e
      puts "❌ jsonb test failed: #{e.message}"
      puts "   This may cause issues with Filter model jsonb columns"
    end

    # Check ILIKE support (for case-insensitive search)
    puts "\n📋 Checking ILIKE support..."
    begin
      ilike_test = ActiveRecord::Base.connection.execute(
        "SELECT 'test' ILIKE 'TEST' AS case_insensitive_match"
      ).first
      if ilike_test && ilike_test["case_insensitive_match"] == true
        puts "✅ ILIKE case-insensitive matching supported"
      end
    rescue => e
      puts "❌ ILIKE test failed: #{e.message}"
    end

    # Check pending migrations
    puts "\n📋 Checking database migrations..."
    begin
      ActiveRecord::Base.connection.schema_migration.table_exists?
      current_version = ActiveRecord::Base.connection.schema_migration.current_version
      all_migrations = ActiveRecord::Base.connection.migration_context.migrations.map(&:version).sort
      pending = all_migrations.select { |v| v > current_version.to_i }

      if pending.empty?
        puts "✅ All migrations are up to date (version: #{current_version || 'none'})"
      else
        puts "⚠️  #{pending.count} pending migration(s) detected"
        puts "   Run: bin/rails db:migrate"
      end
    rescue => e
      # If schema_migrations table doesn't exist, migrations haven't been run
      if e.message.include?("does not exist") || e.message.include?("table")
        puts "⚠️  Database schema not initialized"
        puts "   Run: bin/rails db:migrate"
      else
        puts "⚠️  Could not check migration status: #{e.message}"
        puts "   Run: bin/rails db:migrate"
      end
    end

    # Check jsonb columns in filters table (if it exists)
    puts "\n📋 Checking Filter model jsonb columns..."
    if ActiveRecord::Base.connection.table_exists?(:filters)
      begin
        columns = ActiveRecord::Base.connection.columns(:filters)
        jsonb_columns = columns.select { |c| c.sql_type == "jsonb" }

        expected_jsonb = [ "filter_params", "filter_types", "date_range" ]
        found_jsonb = jsonb_columns.map(&:name)

        expected_jsonb.each do |col|
          if found_jsonb.include?(col)
            puts "✅ #{col} is jsonb"
          else
            text_col = columns.find { |c| c.name == col && c.sql_type.include?("text") }
            if text_col
              puts "⚠️  #{col} is still text (needs migration)"
            else
              puts "❌ #{col} column not found"
            end
          end
        end
      rescue => e
        puts "⚠️  Could not check filter columns: #{e.message}"
      end
    else
      puts "⚠️  filters table does not exist yet (run migrations)"
    end

    # Summary
    puts "\n" + "=" * 60
    puts "✅ PostgreSQL verification complete!"
    puts "\nNext steps:"
    puts "  1. Run migrations: bin/rails db:migrate"
    puts "  2. Run tests: bin/rails test"
    puts "  3. Start server: bin/dev"
  end
end
