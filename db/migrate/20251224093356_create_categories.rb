class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :up_id, null: false
      t.string :name, null: false
      t.string :parent_id
      t.timestamps
    end

    add_index :categories, :up_id, unique: true
    add_index :categories, :parent_id
  end
end
