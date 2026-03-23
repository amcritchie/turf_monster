class ConvertEntryStatusToCartFlow < ActiveRecord::Migration[7.2]
  def up
    # Migrate existing statuses
    execute "UPDATE entries SET status = 'active' WHERE status = 'pending'"
    execute "UPDATE entries SET status = 'complete' WHERE status = 'scored'"

    # Change default to 'cart'
    change_column_default :entries, :status, "cart"

    # Drop draft_picks table
    drop_table :draft_picks
  end

  def down
    change_column_default :entries, :status, "pending"

    execute "UPDATE entries SET status = 'pending' WHERE status = 'active'"
    execute "UPDATE entries SET status = 'scored' WHERE status = 'complete'"
    execute "DELETE FROM entries WHERE status = 'cart'"

    create_table :draft_picks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :contest, null: false, foreign_key: true
      t.jsonb :picks
      t.timestamps
      t.index [:user_id, :contest_id], unique: true
    end
  end
end
