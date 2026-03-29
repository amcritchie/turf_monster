class AddOnchainFields < ActiveRecord::Migration[7.2]
  def change
    add_column :contests, :onchain_contest_id, :string
    add_column :contests, :onchain_settled, :boolean, default: false, null: false
    add_column :contests, :onchain_tx_signature, :string

    add_column :entries, :onchain_entry_id, :string
    add_column :entries, :onchain_tx_signature, :string
    add_column :entries, :entry_number, :integer
  end
end
