class AddWebhookEventUpId < ActiveRecord::Migration[8.0]
  def change
    add_column :webhook_events, :up_event_id, :string, if_not_exists: true
  end
end
