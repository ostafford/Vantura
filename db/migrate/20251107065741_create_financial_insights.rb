class CreateFinancialInsights < ActiveRecord::Migration[8.0]
  def change
    create_table :financial_insights do |t|
      t.references :account, null: false, foreign_key: true
      t.string :insight_type, null: false
      t.string :title, null: false
      t.text :message, null: false
      t.json :evidence_data, default: {}
      t.text :suggested_action
      t.decimal :suggested_amount, precision: 10, scale: 2
      t.date :suggested_date
      t.boolean :is_actioned, default: false, null: false

      t.timestamps
    end

    # account_id index is automatically created by t.references
    add_index :financial_insights, :insight_type
    add_index :financial_insights, :is_actioned
    add_index :financial_insights, [ :account_id, :is_actioned ]
    add_index :financial_insights, :created_at
  end
end
