class CreateWebhookEvents < ActiveRecord::Migration[8.0]
  def change
    unless table_exists?(:webhook_events)
      create_table :webhook_events do |t|
        t.references :user, null: false, foreign_key: true
        t.string :event_type
        t.jsonb :payload
        t.datetime :processed_at
        t.text :error_message

        t.timestamps
      end
      add_index :webhook_events, [:user_id, :processed_at] unless index_exists?(:webhook_events, [:user_id, :processed_at])
      add_index :webhook_events, :event_type unless index_exists?(:webhook_events, :event_type)
    else
      add_index :webhook_events, [:user_id, :processed_at] unless index_exists?(:webhook_events, [:user_id, :processed_at])
      add_index :webhook_events, :event_type unless index_exists?(:webhook_events, :event_type)
    end
  end
end
