class CreateGoals < ActiveRecord::Migration[8.0]
  def change
    create_table :goals, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :goal_type
      t.integer :target_amount_cents
      t.string :period
      t.date :start_date
      t.date :end_date
      t.boolean :active, default: true

      t.timestamps
    end
    add_index :goals, [:user_id, :active], if_not_exists: true
  end
end
