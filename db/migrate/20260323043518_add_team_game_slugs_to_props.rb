class AddTeamGameSlugsToProps < ActiveRecord::Migration[7.2]
  def change
    add_column :props, :team_slug, :string
    add_column :props, :opponent_team_slug, :string
    add_column :props, :game_slug, :string

    add_index :props, :team_slug
    add_index :props, :opponent_team_slug
    add_index :props, :game_slug
  end
end
