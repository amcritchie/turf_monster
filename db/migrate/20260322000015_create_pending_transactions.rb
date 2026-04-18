class CreatePendingTransactions < ActiveRecord::Migration[7.2]
  def change
    create_table :pending_transactions do |t|
      t.string :tx_type, null: false
      t.text :serialized_tx, null: false
      t.string :status, default: "pending", null: false
      t.references :target, polymorphic: true
      t.string :initiator_address
      t.string :cosigner_address
      t.string :tx_signature
      t.jsonb :metadata, default: {}
      t.string :slug
      t.timestamps
    end

    add_index :pending_transactions, :slug, unique: true
    add_index :pending_transactions, :status
  end
end
