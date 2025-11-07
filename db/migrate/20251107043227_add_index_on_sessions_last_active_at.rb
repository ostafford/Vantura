class AddIndexOnSessionsLastActiveAt < ActiveRecord::Migration[8.0]
  def change
    add_index :sessions, :last_active_at
  end
end
