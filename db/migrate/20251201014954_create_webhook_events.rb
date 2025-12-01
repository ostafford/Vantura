class CreateWebhookEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :webhook_events, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true
      t.string :event_type
      t.jsonb :payload
      t.datetime :processed_at
      t.text :error_message

      t.timestamps
    end
    add_index :webhook_events, [ :user_id, :processed_at ], if_not_exists: true
    add_index :webhook_events, :event_type, if_not_exists: true
  end
end
