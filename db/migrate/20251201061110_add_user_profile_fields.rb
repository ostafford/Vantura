class AddUserProfileFields < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :name, :string, if_not_exists: true
    add_column :users, :avatar_url, :string, if_not_exists: true
    add_column :users, :dark_mode, :boolean, default: false, if_not_exists: true
    add_column :users, :currency, :string, default: "AUD", if_not_exists: true
    add_column :users, :last_synced_at, :datetime, if_not_exists: true
  end
end
