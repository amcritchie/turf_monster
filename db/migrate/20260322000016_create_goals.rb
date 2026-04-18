class CreateGoals < ActiveRecord::Migration[7.2]
  def change
    create_table :goals do |t|
      t.string :game_slug, null: false, index: true
      t.string :team_slug, null: false, index: true
      t.string :player_slug, index: true
      t.integer :minute
      t.string :slug, null: false

      t.timestamps
    end

    add_index :goals, :slug, unique: true
  end
end
