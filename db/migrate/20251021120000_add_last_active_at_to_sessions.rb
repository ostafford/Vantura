class AddLastActiveAtToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :last_active_at, :datetime

    # Set default for existing sessions to created_at or current time
    reversible do |dir|
      dir.up do
        # For existing sessions, set last_active_at to created_at if it exists, otherwise now
        execute <<-SQL
          UPDATE sessions
          SET last_active_at = COALESCE(created_at, datetime('now'))
          WHERE last_active_at IS NULL
        SQL
      end
    end
  end
end
