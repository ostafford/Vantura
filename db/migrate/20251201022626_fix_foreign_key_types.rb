class FixForeignKeyTypes < ActiveRecord::Migration[8.0]
  def up
    # Fix project_expenses foreign keys
    change_column :project_expenses, :transaction_id, :bigint if column_exists?(:project_expenses, :transaction_id)
    change_column :project_expenses, :category_id, :bigint if column_exists?(:project_expenses, :category_id)
    
    # Fix planned_transactions foreign keys
    change_column :planned_transactions, :transaction_id, :bigint if column_exists?(:planned_transactions, :transaction_id)
    change_column :planned_transactions, :category_id, :bigint if column_exists?(:planned_transactions, :category_id)
    
    # Fix categories parent_id
    change_column :categories, :parent_id, :bigint if column_exists?(:categories, :parent_id)
    
    # Fix any other integer foreign keys found in schema
    if table_exists?(:recurring_transactions)
      change_column :recurring_transactions, :account_id, :bigint if column_exists?(:recurring_transactions, :account_id)
      change_column :recurring_transactions, :template_transaction_id, :bigint if column_exists?(:recurring_transactions, :template_transaction_id)
    end
    
    if table_exists?(:sessions)
      change_column :sessions, :user_id, :bigint if column_exists?(:sessions, :user_id)
    end
    
    if table_exists?(:filters)
      change_column :filters, :user_id, :bigint if column_exists?(:filters, :user_id)
    end
    
    if table_exists?(:notifications)
      change_column :notifications, :user_id, :bigint if column_exists?(:notifications, :user_id)
    end
  end

  def down
    # Revert to integer (though this is unlikely to be needed)
    change_column :project_expenses, :transaction_id, :integer if column_exists?(:project_expenses, :transaction_id)
    change_column :project_expenses, :category_id, :integer if column_exists?(:project_expenses, :category_id)
    change_column :planned_transactions, :transaction_id, :integer if column_exists?(:planned_transactions, :transaction_id)
    change_column :planned_transactions, :category_id, :integer if column_exists?(:planned_transactions, :category_id)
    change_column :categories, :parent_id, :integer if column_exists?(:categories, :parent_id)
  end
end
