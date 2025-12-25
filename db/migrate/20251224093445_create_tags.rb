class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.bigint :user_id, null: false
      t.string :name, null: false
      t.timestamps
    end

    add_index :tags, :user_id
    add_index :tags, [:user_id, :name], unique: true, name: "index_tags_on_user_and_name"
    add_foreign_key :tags, :users
  end
end
