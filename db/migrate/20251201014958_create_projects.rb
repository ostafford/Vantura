class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects, if_not_exists: true do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :name
      t.text :description

      t.timestamps
    end
  end
end
