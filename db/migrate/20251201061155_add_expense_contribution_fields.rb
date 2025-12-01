class AddExpenseContributionFields < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_contributions, :status, :string, default: "pending", if_not_exists: true
    add_column :expense_contributions, :note, :text, if_not_exists: true
  end
end
