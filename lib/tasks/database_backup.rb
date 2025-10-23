# lib/tasks/database_backup.rb
require "fileutils"
require "active_record"
require "active_support/core_ext/numeric/time"
require "zlib"
require "json"

class DatabaseBackup
  attr_reader :env, :storage_path, :backup_path, :timestamp

  def initialize(env = Rails.env)
    @env = env.to_s
    @storage_path = Rails.root.join("storage")
    @backup_path = Rails.root.join("backups")
    @timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
    FileUtils.mkdir_p(@backup_path) unless File.directory?(@backup_path)
  end

  def run
    puts "🔄 Starting database backup for #{env} environment..."
    puts "📁 Storage directory: #{storage_path}"
    puts "💾 Backup directory: #{backup_path}"
    puts "⏰ Timestamp: #{timestamp}"
    puts "=" * 50

    FileUtils.mkdir_p(backup_path) unless File.directory?(backup_path)
    puts "✅ Created backup directory: #{backup_path}"

    backup_files = []
    database_configs.each do |db_name, config|
      next unless config["database"] # Skip if database path is not defined

      db_file = Pathname.new(config["database"])
      # Ensure the database file path is absolute or relative to Rails.root
      db_file_path = db_file.absolute? ? db_file : Rails.root.join(db_file)

      if File.exist?(db_file_path)
        puts "📊 Backing up #{db_name}..."
        backup_filename = "#{env}_#{db_name}_#{timestamp}.sqlite3"
        backup_filepath = backup_path.join(backup_filename)
        FileUtils.cp(db_file_path, backup_filepath)
        puts "  ✅ Success: #{backup_filename} (#{format_file_size(File.size(backup_filepath))})"
        backup_files << backup_filepath

        # Compress the backup
        compressed_filepath = compress_file(backup_filepath)
        if compressed_filepath
          puts "  📦 Compressed: #{File.basename(compressed_filepath)} (#{format_file_size(File.size(compressed_filepath))})"
          backup_files << compressed_filepath
        end
      else
        puts "  ❌ Warning: Database file not found for #{db_name} at #{db_file_path}"
      end
    end

    cleanup_old_backups
    display_summary(backup_files)
  rescue => e
    puts "❌ An error occurred during backup: #{e.message}"
    Rails.logger.error "Database backup failed: #{e.message}\n#{e.backtrace.join("\n")}"
  end

  def list_backups
    puts "📁 Available Database Backups"
    puts "=" * 50
    puts "Backup Directory: #{backup_path}\n"

    backup_files = Dir.glob(backup_path.join("*.sqlite3*")).sort_by { |f| File.mtime(f) }.reverse

    if backup_files.empty?
      puts "No backups found."
      return
    end

    backup_files.each_with_index do |file, index|
      puts "#{index + 1}. #{File.basename(file)}"
      puts "   Size: #{format_file_size(File.size(file))}"
      puts "   Created: #{File.mtime(file).strftime('%Y-%m-%d %H:%M:%S')}\n"
    end
  rescue => e
    puts "❌ An error occurred while listing backups: #{e.message}"
    Rails.logger.error "Database backup listing failed: #{e.message}\n#{e.backtrace.join("\n")}"
  end

  def setup_schedule
    puts "🔄 Setting up automated backup schedule..."
    puts "📋 Add this line to your crontab for daily backups at 2 AM:"
    puts "=" * 60
    puts "0 2 * * * cd #{Rails.root} && RAILS_ENV=#{env} ruby #{Rails.root.join('lib', 'tasks', 'database_backup.rb')}"
    puts "=" * 60
    puts "\nTo edit your crontab, run: crontab -e"
    puts "To view current crontab, run: crontab -l"
  end

  def restore_backup(backup_filename, target_env = nil)
    target_env ||= env
    puts "🔄 Restoring database from backup: #{backup_filename}"
    puts "⚠️  WARNING: This will overwrite your current database!"
    print "Are you sure you want to continue? (yes/no) "
    confirm = STDIN.gets.chomp
    unless confirm.downcase == "yes"
      puts "Restoration cancelled."
      return
    end

    backup_filepath = backup_path.join(backup_filename)
    unless File.exist?(backup_filepath)
      # Check for gzipped version if original not found
      if File.exist?("#{backup_filepath}.gz")
        puts "📦 Decompressing #{backup_filename}.gz..."
        decompressed_filepath = decompress_file("#{backup_filepath}.gz")
        backup_filepath = decompressed_filepath
      else
        puts "❌ Backup file not found: #{backup_filepath}"
        return
      end
    end

    # Determine which database to restore based on the backup filename
    # Example: development_development_20251023_130149.sqlite3
    match = backup_filename.match(/#{target_env}_(?<db_name>[a-z_]+)_(\d{8}_\d{6})\.sqlite3/)
    unless match
      puts "❌ Could not determine target database from backup filename: #{backup_filename}"
      return
    end
    db_identifier = match[:db_name] # e.g., 'development', 'test', 'primary', 'cache', 'queue', 'cable'

    target_config = database_configs[db_identifier]
    unless target_config && target_config["database"]
      puts "❌ Could not find database configuration for identifier: #{db_identifier} in #{target_env} environment."
      return
    end

    target_db_file = Pathname.new(target_config["database"])
    target_db_filepath = target_db_file.absolute? ? target_db_file : Rails.root.join(target_db_file)

    puts "📊 Restoring #{db_identifier} database..."

    # Backup current database before overwriting
    if File.exist?(target_db_filepath)
      current_db_backup_path = "#{target_db_filepath}.backup_#{timestamp}"
      FileUtils.cp(target_db_filepath, current_db_backup_path)
      puts "💾 Current database backed up to: #{File.basename(current_db_backup_path)}"
    end

    FileUtils.cp(backup_filepath, target_db_filepath)
    puts "✅ Database restored successfully!"
    puts "📁 Restored to: #{target_db_filepath}"

    # Clean up decompressed file if it was gzipped
    FileUtils.rm(backup_filepath) if backup_filepath.to_s.end_with?(".decompressed")

  rescue => e
    puts "❌ An error occurred during restoration: #{e.message}"
    Rails.logger.error "Database restoration failed: #{e.message}\n#{e.backtrace.join("\n")}"
  end

  private

  def database_configs
    # Load database.yml and get configurations for the current environment
    db_config_path = Rails.root.join("config", "database.yml")
    full_config = YAML.load_file(db_config_path, aliases: true)[env]

    # Handle multi-database configurations (e.g., production with primary, cache, queue, cable)
    if full_config.is_a?(Hash) && full_config.keys.any? { |k| [ "primary", "cache", "queue", "cable" ].include?(k.to_s) }
      full_config # Return the hash of configurations
    else
      { env => full_config } # Wrap single database config in a hash for consistent iteration
    end
  end

  def compress_file(filepath)
    return nil unless File.exist?(filepath)
    compressed_filepath = "#{filepath}.gz"
    Zlib::GzipWriter.open(compressed_filepath) do |gz|
      gz.write File.binread(filepath)
    end
    FileUtils.rm(filepath) # Remove original uncompressed file
    compressed_filepath
  rescue => e
    puts "❌ Error compressing file #{filepath}: #{e.message}"
    Rails.logger.error "Compression failed for #{filepath}: #{e.message}\n#{e.backtrace.join("\n")}"
    nil
  end

  def decompress_file(filepath)
    return nil unless File.exist?(filepath)
    decompressed_filepath = filepath.sub(/\.gz$/, ".decompressed")
    Zlib::GzipReader.open(filepath) do |gz|
      File.open(decompressed_filepath, "wb") do |f|
        f.write gz.read
      end
    end
    decompressed_filepath
  rescue => e
    puts "❌ Error decompressing file #{filepath}: #{e.message}"
    Rails.logger.error "Decompression failed for #{filepath}: #{e.message}\n#{e.backtrace.join("\n")}"
    nil
  end

  def cleanup_old_backups
    puts "\n🧹 Cleaning up old backups..."
    retention_days = 30 # Keep backups for 30 days
    old_backups = Dir.glob(backup_path.join("*.sqlite3*")).select do |f|
      File.mtime(f) < retention_days.days.ago
    end

    old_backups.each do |file|
      FileUtils.rm(file)
      puts "  🗑️  Deleted old backup: #{File.basename(file)}"
    end
    puts "  ✅ Cleaned up #{old_backups.count} old backup files"
  rescue => e
    puts "❌ An error occurred during cleanup: #{e.message}"
    Rails.logger.error "Database backup cleanup failed: #{e.message}\n#{e.backtrace.join("\n")}"
  end

  def display_summary(backup_files)
    puts "\n📋 Backup Summary"
    puts "=" * 50
    puts "Environment: #{env}"
    puts "Timestamp: #{timestamp}"
    puts "Backup Directory: #{backup_path}"
    puts "Files Created: #{backup_files.count}"

    puts "\n📁 Backup Files:"
    backup_files.each do |file|
      puts "  • #{File.basename(file)} (#{format_file_size(File.size(file))})"
    end

    total_size = backup_files.sum { |f| File.size(f) }
    puts "\n💾 Total Backup Size: #{format_file_size(total_size)}"

    puts "\n✅ Database backup completed successfully!"
  end

  def format_file_size(size)
    size = size.to_i if size.is_a?(String)
    units = [ "B", "KB", "MB", "GB" ]
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end

    "#{size.round(2)} #{units[unit_index]}"
  end
end

# Run the backup if this script is executed directly
if __FILE__ == $0
  require_relative "../../config/environment"
  DatabaseBackup.new.run
end
