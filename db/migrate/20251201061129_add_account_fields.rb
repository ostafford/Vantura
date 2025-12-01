class AddAccountFields < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :ownership_type, :string, if_not_exists: true
    add_column :accounts, :created_at_up, :datetime, if_not_exists: true
  end
end
