class CreateContestMatchups < ActiveRecord::Migration[7.2]
  def change
    create_table :contest_matchups do |t|
      t.references :contest, null: false, foreign_key: true
      t.string :team_slug, null: false
      t.string :opponent_team_slug
      t.string :game_slug
      t.integer :rank
      t.decimal :multiplier, precision: 3, scale: 1
      t.integer :goals
      t.string :status, default: "pending", null: false
      t.string :slug

      t.timestamps
    end

    add_index :contest_matchups, [:contest_id, :team_slug], unique: true
    add_index :contest_matchups, :game_slug
    add_index :contest_matchups, :slug, unique: true
  end
end
