namespace :solana do
  desc "Initialize vault on Devnet (run once)"
  task init_vault: :environment do
    vault = Solana::Vault.new
    admin = Solana::Keypair.admin

    puts "Admin address: #{admin.to_base58}"
    puts "Program ID: #{Solana::Config::PROGRAM_ID}"
    puts "Network: #{Solana::Config::NETWORK}"

    # Check balance
    balance = vault.client.get_balance(admin.to_base58)
    puts "Admin SOL balance: #{balance.dig('value').to_f / 1_000_000_000}"

    puts "\nVault PDAs:"
    vault_pda, vault_bump = vault.vault_state_pda
    puts "  vault_state: #{Solana::Keypair.encode_base58(vault_pda)} (bump: #{vault_bump})"

    usdc_pda, usdc_bump = vault.vault_usdc_pda
    puts "  vault_usdc:  #{Solana::Keypair.encode_base58(usdc_pda)} (bump: #{usdc_bump})"

    usdt_pda, usdt_bump = vault.vault_usdt_pda
    puts "  vault_usdt:  #{Solana::Keypair.encode_base58(usdt_pda)} (bump: #{usdt_bump})"

    puts "\nTo initialize the vault, deploy the program and run this task again with INIT=true"

    if ENV["INIT"] == "true"
      puts "\nInitializing vault..."
      # This would require the vault to not already be initialized
      # Actual initialization needs the mint addresses configured
      puts "Set SOLANA_USDC_MINT and SOLANA_USDT_MINT first!"
    end
  end

  desc "Airdrop SOL to admin wallet"
  task airdrop: :environment do
    vault = Solana::Vault.new
    admin = Solana::Keypair.admin
    amount = (ENV["SOL"] || "2").to_i

    puts "Airdropping #{amount} SOL to #{admin.to_base58}..."
    sig = vault.client.request_airdrop(admin.to_base58, amount * 1_000_000_000)
    puts "Signature: #{sig}"

    sleep 2
    balance = vault.client.get_balance(admin.to_base58)
    puts "New balance: #{balance.dig('value').to_f / 1_000_000_000} SOL"
  end

  desc "Check onchain balance for a user"
  task check_balance: :environment do
    address = ENV["ADDRESS"]
    unless address
      puts "Usage: bin/rails solana:check_balance ADDRESS=<solana_address>"
      exit 1
    end

    vault = Solana::Vault.new
    result = vault.sync_balance(address)

    if result
      puts "Onchain balance for #{address}:"
      puts "  Balance:         $#{result[:balance_dollars]}"
      puts "  Total deposited: #{result[:total_deposited]} lamports"
      puts "  Total withdrawn: #{result[:total_withdrawn]} lamports"
      puts "  Total won:       #{result[:total_won]} lamports"
    else
      puts "No UserAccount found for #{address}"
    end
  end

  desc "Generate a test keypair"
  task generate_keypair: :environment do
    keypair = Solana::Keypair.generate
    puts "Address: #{keypair.to_base58}"
    puts "Encrypted key: #{keypair.encrypt}"
    puts "\nStore the encrypted key in user.encrypted_solana_private_key"
  end

  desc "Test key encryption roundtrip"
  task test_encryption: :environment do
    keypair = Solana::Keypair.generate
    address = keypair.to_base58
    encrypted = keypair.encrypt

    restored = Solana::Keypair.from_encrypted(encrypted)

    if restored.to_base58 == address
      puts "Encryption roundtrip: PASS"
      puts "Address: #{address}"
    else
      puts "Encryption roundtrip: FAIL"
      puts "Original: #{address}"
      puts "Restored: #{restored.to_base58}"
    end
  end
end
