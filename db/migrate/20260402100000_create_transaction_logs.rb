class CreateTransactionLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :transaction_logs do |t|
      t.string :transaction_type, null: false
      t.integer :amount_cents, null: false
      t.string :direction, null: false
      t.integer :balance_after_cents
      t.references :user, null: false, foreign_key: true
      t.string :source_type
      t.bigint :source_id
      t.string :source_name
      t.string :description
      t.string :status, default: "completed", null: false
      t.string :onchain_tx
      t.jsonb :metadata, default: {}
      t.string :slug

      t.timestamps
    end

    add_index :transaction_logs, :slug, unique: true
    add_index :transaction_logs, :transaction_type
    add_index :transaction_logs, :status
    add_index :transaction_logs, [:source_type, :source_id]
  end
end
