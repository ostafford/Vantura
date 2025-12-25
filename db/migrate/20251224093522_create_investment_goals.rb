class CreateInvestmentGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :investment_goals do |t|
      t.bigint :user_id, null: false
      t.string :name, null: false
      t.text :description
      t.decimal :target_amount, precision: 10, scale: 2, null: false
      t.decimal :current_amount, precision: 10, scale: 2, default: 0.0
      t.bigint :account_id
      t.date :target_date
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :investment_goals, :user_id
    add_index :investment_goals, :account_id
    add_foreign_key :investment_goals, :users
    add_foreign_key :investment_goals, :accounts
  end
end
