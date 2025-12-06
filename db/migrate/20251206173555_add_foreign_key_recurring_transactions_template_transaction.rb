class AddForeignKeyRecurringTransactionsTemplateTransaction < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :recurring_transactions, :transactions, column: :template_transaction_id, on_delete: :nullify
  end
end
