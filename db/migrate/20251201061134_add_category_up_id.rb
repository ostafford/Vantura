class AddCategoryUpId < ActiveRecord::Migration[8.0]
  def change
    add_column :categories, :up_id, :string, if_not_exists: true
    add_index :categories, :up_id, unique: true, if_not_exists: true, where: "up_id IS NOT NULL"
  end
end
