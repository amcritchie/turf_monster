class DropPicksAndProps < ActiveRecord::Migration[7.2]
  def up
    drop_table :picks, if_exists: true
    drop_table :props, if_exists: true
  end

  def down
    create_table :props do |t|
      t.references :contest, null: false, foreign_key: true
      t.string :description
      t.decimal :line, precision: 4, scale: 1
      t.string :stat_type
      t.decimal :result_value, precision: 4, scale: 1
      t.string :status, default: "pending"
      t.string :team_slug
      t.string :opponent_team_slug
      t.string :game_slug
      t.string :slug
      t.timestamps
    end

    create_table :picks do |t|
      t.references :entry, null: false, foreign_key: true
      t.references :prop, null: false, foreign_key: true
      t.string :selection
      t.string :result
      t.string :slug
      t.timestamps
    end
  end
end
