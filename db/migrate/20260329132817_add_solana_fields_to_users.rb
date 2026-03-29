class AddSolanaFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :solana_address, :string
    add_column :users, :encrypted_solana_private_key, :text
    add_column :users, :wallet_type, :string
    add_index :users, :solana_address, unique: true, where: "solana_address IS NOT NULL"
  end
end
