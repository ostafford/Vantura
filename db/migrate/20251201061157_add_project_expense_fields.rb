class AddProjectExpenseFields < ActiveRecord::Migration[8.0]
  def change
    add_column :project_expenses, :name, :string, if_not_exists: true
    add_reference :project_expenses, :paid_by_user, foreign_key: { to_table: :users }, null: true, if_not_exists: true
  end
end
