class AddPayoutTxSignatureToEntries < ActiveRecord::Migration[7.2]
  def change
    add_column :entries, :payout_tx_signature, :string
  end
end
