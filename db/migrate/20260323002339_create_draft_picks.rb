class CreateDraftPicks < ActiveRecord::Migration[7.2]
  def change
    create_table :draft_picks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :contest, null: false, foreign_key: true
      t.jsonb :picks

      t.timestamps
    end

    add_index :draft_picks, [:user_id, :contest_id], unique: true
  end
end
