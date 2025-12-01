class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories, if_not_exists: true do |t|
      t.string :name
      t.references :parent, null: true, foreign_key: { to_table: :categories }
      t.string :icon

      t.timestamps
    end
  end
end
