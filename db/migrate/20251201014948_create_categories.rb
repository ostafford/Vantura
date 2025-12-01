class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories, if_not_exists: true do |t|
      t.string :name
      t.integer :parent_id
      t.string :icon

      t.timestamps
    end
  end
end
