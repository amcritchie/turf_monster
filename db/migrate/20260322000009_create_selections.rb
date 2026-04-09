class CreateSelections < ActiveRecord::Migration[7.2]
  def change
    create_table :selections do |t|
      t.references :entry, null: false, foreign_key: true
      t.references :slate_matchup, null: false, foreign_key: true
      t.decimal :points, precision: 5, scale: 1
      t.string :slug
      t.timestamps
    end

    add_index :selections, :slug, unique: true
    add_index :selections, [:entry_id, :slate_matchup_id], unique: true
  end
end
