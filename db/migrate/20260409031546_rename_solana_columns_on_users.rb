class RenameSolanaColumnsOnUsers < ActiveRecord::Migration[7.2]
  def up
    # Only runs on prod where old column names exist
    if column_exists?(:users, :solana_address)
      rename_column :users, :solana_address, :web3_solana_address
    end

    if column_exists?(:users, :encrypted_solana_private_key)
      rename_column :users, :encrypted_solana_private_key, :encrypted_web2_solana_private_key
    end

    unless column_exists?(:users, :web2_solana_address)
      add_column :users, :web2_solana_address, :string
      add_index :users, :web2_solana_address, unique: true, where: "web2_solana_address IS NOT NULL"
    end
  end

  def down
    if column_exists?(:users, :web3_solana_address)
      rename_column :users, :web3_solana_address, :solana_address
    end

    if column_exists?(:users, :encrypted_web2_solana_private_key)
      rename_column :users, :encrypted_web2_solana_private_key, :encrypted_solana_private_key
    end

    if column_exists?(:users, :web2_solana_address)
      remove_column :users, :web2_solana_address
    end
  end
end
