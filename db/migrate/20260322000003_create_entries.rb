class CreateEntries < ActiveRecord::Migration[7.2]
  def change
    create_table :entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :contest, null: false, foreign_key: true
      t.float :score, default: 0.0, null: false
      t.string :status, default: "cart", null: false
      t.string :slug
      t.timestamps
    end

    add_index :entries, [:user_id, :contest_id]
  end
end
