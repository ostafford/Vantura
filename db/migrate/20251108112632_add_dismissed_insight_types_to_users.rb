class AddDismissedInsightTypesToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :dismissed_insight_types, :json, default: [], null: false
  end
end
