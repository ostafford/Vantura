class DropExistingSchemaTables < ActiveRecord::Migration[8.1]
  def up
    # Drop foreign keys from other tables that reference transactions and categories
    remove_foreign_key "expense_contributions", "transactions", column: "paid_via_transaction_id" if foreign_key_exists?("expense_contributions", "transactions", column: "paid_via_transaction_id")
    remove_foreign_key "planned_transactions", "transactions" if foreign_key_exists?("planned_transactions", "transactions")
    remove_foreign_key "planned_transactions", "categories" if foreign_key_exists?("planned_transactions", "categories")
    remove_foreign_key "project_expenses", "transactions" if foreign_key_exists?("project_expenses", "transactions")
    remove_foreign_key "project_expenses", "categories" if foreign_key_exists?("project_expenses", "categories")
    remove_foreign_key "recurring_transactions", "transactions", column: "template_transaction_id" if foreign_key_exists?("recurring_transactions", "transactions", column: "template_transaction_id")
    
    # Drop tables in dependency order
    drop_table "transaction_tags" if table_exists?("transaction_tags")
    drop_table "transactions" if table_exists?("transactions")
    drop_table "accounts" if table_exists?("accounts")
    drop_table "tags" if table_exists?("tags")
    drop_table "categories" if table_exists?("categories")
  end

  def down
    # This migration is irreversible - we're dropping and recreating tables
    raise ActiveRecord::IrreversibleMigration
  end
end
