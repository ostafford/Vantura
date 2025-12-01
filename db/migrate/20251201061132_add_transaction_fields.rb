class AddTransactionFields < ActiveRecord::Migration[8.0]
  def change
    add_reference :transactions, :category, foreign_key: true, null: true, if_not_exists: true
    add_column :transactions, :created_at_up, :datetime, if_not_exists: true
    add_column :transactions, :is_categorizable, :boolean, default: true, if_not_exists: true
    add_column :transactions, :round_up_cents, :integer, if_not_exists: true
    add_column :transactions, :cashback_cents, :integer, if_not_exists: true
  end
end
