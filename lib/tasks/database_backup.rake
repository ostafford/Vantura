# lib/tasks/database_backup.rake
namespace :db do
  desc "Create a backup of the database"
  task :backup => :environment do
    require_relative 'database_backup'
    DatabaseBackup.new.run
  end

  desc "List available database backups"
  task :list_backups => :environment do
    require_relative 'database_backup'
    DatabaseBackup.new.list_backups
  end

  desc "Display instructions for setting up automated backup schedule"
  task :setup_backup_schedule => :environment do
    require_relative 'database_backup'
    DatabaseBackup.new.setup_schedule
  end

  desc "Restore database from a specified backup file (e.g., db:restore[backup_filename])"
  task :restore, [:backup_filename] => :environment do |t, args|
    require_relative 'database_backup'
    backup_filename = args[:backup_filename]
    if backup_filename.nil? || backup_filename.empty?
      puts "Usage: rails db:restore[backup_filename]"
      puts "Example: rails db:restore[development_development_20251023_130149.sqlite3]"
      exit 1
    end
    DatabaseBackup.new.restore_backup(backup_filename)
  end
end
