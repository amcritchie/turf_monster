class CreateContests < ActiveRecord::Migration[7.2]
  def change
    create_table :contests do |t|
      t.string :name, null: false
      t.string :contest_type, default: "small", null: false
      t.integer :entry_fee_cents, default: 0, null: false
      t.string :status, default: "draft", null: false
      t.integer :max_entries
      t.string :tagline
      t.integer :rank
      t.datetime :starts_at
      t.references :slate, foreign_key: true
      t.string :onchain_contest_id
      t.boolean :onchain_settled, default: false, null: false
      t.string :onchain_tx_signature
      t.string :slug
      t.timestamps
    end

    add_index :contests, :slug, unique: true
    add_index :contests, :status
    add_index :contests, :rank
  end
end
