class ExtractSlateFromContests < ActiveRecord::Migration[7.2]
  def change
    create_table :slate_matchups do |t|
      t.references :slate, null: false, foreign_key: true
      t.string :team_slug, null: false
      t.string :opponent_team_slug
      t.string :game_slug
      t.integer :rank
      t.decimal :multiplier, precision: 3, scale: 1
      t.integer :goals
      t.string :status, default: "pending", null: false
      t.decimal :expected_team_total, precision: 3, scale: 1
      t.integer :team_total_over_odds
      t.integer :team_total_under_odds
      t.decimal :dk_score, precision: 4, scale: 2
      t.string :slug

      t.timestamps
    end

    add_index :slate_matchups, [:slate_id, :team_slug], unique: true
    add_index :slate_matchups, :game_slug
    add_index :slate_matchups, :slug, unique: true

    # Contest now belongs_to slate
    add_reference :contests, :slate, foreign_key: true

    # Selection now points to slate_matchup instead of contest_matchup
    add_reference :selections, :slate_matchup, null: false, foreign_key: true
    remove_reference :selections, :contest_matchup, foreign_key: true, index: true
    add_index :selections, [:entry_id, :slate_matchup_id], unique: true

    # Drop old table
    drop_table :contest_matchups
  end
end
