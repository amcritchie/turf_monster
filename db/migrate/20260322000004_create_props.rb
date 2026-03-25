class CreateProps < ActiveRecord::Migration[7.2]
  def change
    create_table :props do |t|
      t.references :contest, null: false, foreign_key: true
      t.string :description, null: false
      t.float :line, null: false
      t.string :stat_type
      t.float :result_value
      t.string :status, default: "pending", null: false
      t.string :slug
      t.string :team_slug
      t.string :opponent_team_slug
      t.string :game_slug
      t.timestamps
    end

    add_index :props, :team_slug
    add_index :props, :opponent_team_slug
    add_index :props, :game_slug
  end
end
