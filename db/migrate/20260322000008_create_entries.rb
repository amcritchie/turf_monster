class CreateEntries < ActiveRecord::Migration[7.2]
  def change
    create_table :entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :contest, null: false, foreign_key: true
      t.float :score, default: 0.0, null: false
      t.string :status, default: "cart", null: false
      t.integer :rank
      t.integer :payout_cents, default: 0
      t.integer :entry_number
      t.string :onchain_entry_id
      t.string :onchain_tx_signature
      t.string :payout_tx_signature
      t.string :slug
      t.timestamps
    end

    add_index :entries, :slug, unique: true
    add_index :entries, :status
    add_index :entries, [:user_id, :contest_id]
  end
end
