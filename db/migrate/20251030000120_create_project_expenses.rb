class CreateProjectExpenses < ActiveRecord::Migration[7.0]
  def change
    create_table :project_expenses do |t|
      t.references :project, null: false, foreign_key: true
      t.string :merchant, null: false
      t.string :category
      t.integer :total_cents, null: false, default: 0
      t.date :due_on
      t.text :notes

      t.timestamps
    end
  end
end
