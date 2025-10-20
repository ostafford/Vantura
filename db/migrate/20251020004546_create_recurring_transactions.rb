class CreateRecurringTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :recurring_transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.string :description
      t.decimal :amount, precision: 10, scale: 2
      t.string :frequency
      t.date :next_occurrence_date
      t.boolean :is_active
      t.string :transaction_type
      t.string :category

      t.timestamps
    end
  end
end
