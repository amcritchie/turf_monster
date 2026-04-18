class CreateSlateMatchups < ActiveRecord::Migration[7.2]
  def change
    create_table :slate_matchups do |t|
      t.references :slate, null: false, foreign_key: true
      t.string :team_slug, null: false
      t.string :opponent_team_slug
      t.string :game_slug
      t.integer :rank
      t.decimal :turf_score, precision: 3, scale: 1
      t.integer :goals
      t.string :status, default: "pending", null: false
      t.decimal :dk_goals_expectation, precision: 3, scale: 1
      t.integer :team_total_over_odds
      t.integer :team_total_under_odds
      t.decimal :over_decimal_odds, precision: 4, scale: 2
      t.decimal :under_decimal_odds, precision: 4, scale: 2
      t.decimal :house_score, precision: 4, scale: 2
      t.string :slug
      t.timestamps
    end

    add_index :slate_matchups, :slug, unique: true
    add_index :slate_matchups, [:slate_id, :team_slug], unique: true
    add_index :slate_matchups, :game_slug
  end
end
