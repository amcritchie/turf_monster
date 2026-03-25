class CreatePicks < ActiveRecord::Migration[7.2]
  def change
    create_table :picks do |t|
      t.references :entry, null: false, foreign_key: true
      t.references :prop, null: false, foreign_key: true
      t.string :selection, null: false
      t.string :result, default: "pending", null: false
      t.string :slug
      t.timestamps
    end

    add_index :picks, [:entry_id, :prop_id], unique: true
  end
end
