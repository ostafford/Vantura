class CreateFilters < ActiveRecord::Migration[8.0]
  def change
    create_table :filters do |t|
      t.string :name
      t.string :filter_type
      t.text :filter_params
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
