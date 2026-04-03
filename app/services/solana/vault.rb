require "digest"

module Solana
  class Vault
    attr_reader :client

    def initialize(client: Solana::Client.new)
      @client = client
      @program_id = Keypair.decode_base58(Config::PROGRAM_ID)
    end

    # --- PDA helpers ---

    def vault_state_pda
      Transaction.find_pda([b("vault")], @program_id)
    end

    def vault_usdc_pda
      Transaction.find_pda([b("vault_usdc")], @program_id)
    end

    def vault_usdt_pda
      Transaction.find_pda([b("vault_usdt")], @program_id)
    end

    def user_account_pda(wallet_address)
      wallet_bytes = Keypair.decode_base58(wallet_address)
      Transaction.find_pda([b("user"), wallet_bytes], @program_id)
    end

    def contest_pda(contest_slug)
      contest_id = Digest::SHA256.digest(contest_slug)
      Transaction.find_pda([b("contest"), contest_id], @program_id)
    end

    def entry_pda(contest_slug, wallet_address, entry_num)
      contest_id = Digest::SHA256.digest(contest_slug)
      wallet_bytes = Keypair.decode_base58(wallet_address)
      entry_num_bytes = [entry_num].pack("V") # u32 LE
      Transaction.find_pda([b("entry"), contest_id, wallet_bytes, entry_num_bytes], @program_id)
    end

    # --- ATA helpers ---

    def admin_usdc_ata
      admin = Keypair.admin
      Solana::SplToken.find_associated_token_address(admin.public_key_bytes, Config::USDC_MINT)
    end

    # Ensure an ATA exists for wallet + mint. Creates it if missing.
    # Returns { ata: base58, created: bool, signature: string|nil }
    def ensure_ata(wallet_address, mint:)
      ata_bytes, _ = Solana::SplToken.find_associated_token_address(wallet_address, mint)
      ata_base58 = Keypair.encode_base58(ata_bytes)

      info = client.get_account_info(ata_base58)
      if info&.dig("value")
        return { ata: ata_base58, created: false, signature: nil }
      end

      admin = Keypair.admin
      create_ix = Solana::SplToken.create_associated_token_account_instruction(
        payer: admin.public_key_bytes,
        wallet: wallet_address,
        mint: mint
      )

      tx = build_tx(admin)
      tx.add_instruction(**create_ix)
      signature = client.send_and_confirm(tx.serialize_base64)

      { ata: ata_base58, created: true, signature: signature }
    end

    # Mint SPL tokens (admin must be mint authority). Defaults to admin's ATA.
    def mint_spl(amount_lamports, mint:, to: nil)
      admin = Keypair.admin

      if to
        dest_bytes, _ = Solana::SplToken.find_associated_token_address(to, mint)
      else
        dest_bytes, _ = admin_usdc_ata
      end

      mint_ix = Solana::SplToken.mint_to_instruction(
        mint: mint,
        destination: dest_bytes,
        authority: admin.public_key_bytes,
        amount: amount_lamports
      )

      tx = build_tx(admin)
      tx.add_instruction(**mint_ix)
      signature = client.send_and_confirm(tx.serialize_base64)

      { signature: signature, amount: amount_lamports, destination: Keypair.encode_base58(dest_bytes) }
    end

    # --- High-level operations ---

    # Initialize the vault (run once after program deploy)
    def initialize_vault
      admin = Keypair.admin
      vault_pda, _ = vault_state_pda
      usdc_mint = Keypair.decode_base58(Config::USDC_MINT)
      usdt_mint = Keypair.decode_base58(Config::USDT_MINT)
      vault_usdc, _ = vault_usdc_pda
      vault_usdt, _ = vault_usdt_pda

      data = Transaction.anchor_discriminator("initialize")

      tx = build_tx(admin)
      tx.add_instruction(
        program_id: @program_id,
        accounts: [
          { pubkey: admin.public_key_bytes, is_signer: true, is_writable: true },
          { pubkey: vault_pda, is_signer: false, is_writable: true },
          { pubkey: usdc_mint, is_signer: false, is_writable: false },
          { pubkey: usdt_mint, is_signer: false, is_writable: false },
          { pubkey: vault_usdc, is_signer: false, is_writable: true },
          { pubkey: vault_usdt, is_signer: false, is_writable: true },
          { pubkey: Transaction::TOKEN_PROGRAM_ID, is_signer: false, is_writable: false },
          { pubkey: Transaction::SYSTEM_PROGRAM_ID, is_signer: false, is_writable: false },
          { pubkey: Transaction::SYSVAR_RENT_PUBKEY, is_signer: false, is_writable: false }
        ],
        data: data
      )

      signature = client.send_and_confirm(tx.serialize_base64)
      { signature: signature, vault_pda: Keypair.encode_base58(vault_pda) }
    end

    # Create a UserAccount PDA for a wallet (admin pays rent)
    def create_user_account(wallet_address)
      admin = Keypair.admin
      user_pda, _bump = user_account_pda(wallet_address)
      wallet_bytes = Keypair.decode_base58(wallet_address)

      data = Transaction.anchor_discriminator("create_user_account") +
             Borsh.encode_pubkey(wallet_bytes)

      tx = build_tx(admin)
      tx.add_instruction(
        program_id: @program_id,
        accounts: [
          { pubkey: admin.public_key_bytes, is_signer: true, is_writable: true },
          { pubkey: user_pda, is_signer: false, is_writable: true },
          { pubkey: Transaction::SYSTEM_PROGRAM_ID, is_signer: false, is_writable: false }
        ],
        data: data
      )

      signature = client.send_and_confirm(tx.serialize_base64)
      { signature: signature, pda: Keypair.encode_base58(user_pda) }
    end

    # Deposit for custodial users (server signs with their keypair)
    def deposit(user_keypair, amount_lamports, mint: :usdc)
      admin = Keypair.admin
      wallet_address = user_keypair.to_base58
      user_pda, _ = user_account_pda(wallet_address)
      vault_pda, _ = vault_state_pda
      vault_token_pda, _ = mint == :usdc ? vault_usdc_pda : vault_usdt_pda
      mint_pubkey = mint == :usdc ? Config::USDC_MINT : Config::USDT_MINT

      data = Transaction.anchor_discriminator("deposit") +
             Borsh.encode_u64(amount_lamports)

      # For custodial: user_keypair signs, admin pays fees
      tx = build_tx(user_keypair)
      tx.add_instruction(
        program_id: @program_id,
        accounts: [
          { pubkey: user_keypair.public_key_bytes, is_signer: true, is_writable: true },
          { pubkey: user_pda, is_signer: false, is_writable: true },
          { pubkey: vault_pda, is_signer: false, is_writable: false },
          { pubkey: Keypair.decode_base58(mint_pubkey), is_signer: false, is_writable: false },
          { pubkey: nil, is_signer: false, is_writable: true },  # user_token_account — caller must set
          { pubkey: vault_token_pda, is_signer: false, is_writable: true },
          { pubkey: Transaction::TOKEN_PROGRAM_ID, is_signer: false, is_writable: false }
        ],
        data: data
      )

      client.send_and_confirm(tx.serialize_base64)
    end

    # Returns unsigned transaction bytes for Phantom user to sign
    def deposit_unsigned(wallet_address, amount_lamports, user_token_account:, mint: :usdc)
      user_pda, _ = user_account_pda(wallet_address)
      vault_pda, _ = vault_state_pda
      vault_token_pda, _ = mint == :usdc ? vault_usdc_pda : vault_usdt_pda
      mint_pubkey = mint == :usdc ? Config::USDC_MINT : Config::USDT_MINT
      wallet_bytes = Keypair.decode_base58(wallet_address)

      data = Transaction.anchor_discriminator("deposit") +
             Borsh.encode_u64(amount_lamports)

      blockhash = client.get_latest_blockhash
      tx = Transaction.new
      tx.set_recent_blockhash(blockhash)
      # Phantom user is fee payer — we add a placeholder signer
      tx.add_instruction(
        program_id: @program_id,
        accounts: [
          { pubkey: wallet_bytes, is_signer: true, is_writable: true },
          { pubkey: user_pda, is_signer: false, is_writable: true },
          { pubkey: vault_pda, is_signer: false, is_writable: false },
          { pubkey: Keypair.decode_base58(mint_pubkey), is_signer: false, is_writable: false },
          { pubkey: Keypair.decode_base58(user_token_account), is_signer: false, is_writable: true },
          { pubkey: vault_token_pda, is_signer: false, is_writable: true },
          { pubkey: Transaction::TOKEN_PROGRAM_ID, is_signer: false, is_writable: false }
        ],
        data: data
      )

      # Return serialized message (not signed) for frontend
      { blockhash: blockhash, message: tx }
    end

    # Create contest onchain (admin signs)
    def create_contest(contest_slug, entry_fee:, max_entries:, payout_bps:, bonus:)
      admin = Keypair.admin
      contest_id = Digest::SHA256.digest(contest_slug)
      contest_pda_addr, _ = contest_pda(contest_slug)
      vault_pda, _ = vault_state_pda

      data = Transaction.anchor_discriminator("create_contest") +
             Borsh.encode_bytes32(contest_id) +
             Borsh.encode_u64(entry_fee) +
             Borsh.encode_u32(max_entries) +
             Borsh.encode_vec(payout_bps) { |bps| Borsh.encode_u16(bps) } +
             Borsh.encode_u64(bonus)

      tx = build_tx(admin)
      tx.add_instruction(
        program_id: @program_id,
        accounts: [
          { pubkey: admin.public_key_bytes, is_signer: true, is_writable: true },
          { pubkey: vault_pda, is_signer: false, is_writable: false },
          { pubkey: contest_pda_addr, is_signer: false, is_writable: true },
          { pubkey: Transaction::SYSTEM_PROGRAM_ID, is_signer: false, is_writable: false }
        ],
        data: data
      )

      # Atomic SPL transfer: move USDC from admin ATA to vault token account
      if bonus > 0
        admin_ata, _ = admin_usdc_ata
        vault_usdc, _ = vault_usdc_pda
        transfer_ix = Solana::SplToken.transfer_instruction(
          from: admin_ata, to: vault_usdc,
          authority: admin.public_key_bytes, amount: bonus
        )
        tx.add_instruction(**transfer_ix)
      end

      signature = client.send_and_confirm(tx.serialize_base64)
      { signature: signature, pda: Keypair.encode_base58(contest_pda_addr) }
    end

    # Enter contest (admin signs, deducts from user balance onchain)
    def enter_contest(wallet_address, contest_slug, entry_num)
      admin = Keypair.admin
      contest_id = Digest::SHA256.digest(contest_slug)
      wallet_bytes = Keypair.decode_base58(wallet_address)
      user_pda, _ = user_account_pda(wallet_address)
      c_pda, _ = contest_pda(contest_slug)
      e_pda, _ = entry_pda(contest_slug, wallet_address, entry_num)

      data = Transaction.anchor_discriminator("enter_contest") +
             Borsh.encode_u32(entry_num)

      tx = build_tx(admin)
      tx.add_instruction(
        program_id: @program_id,
        accounts: [
          { pubkey: admin.public_key_bytes, is_signer: true, is_writable: true },
          { pubkey: wallet_bytes, is_signer: false, is_writable: false },
          { pubkey: user_pda, is_signer: false, is_writable: true },
          { pubkey: c_pda, is_signer: false, is_writable: true },
          { pubkey: e_pda, is_signer: false, is_writable: true },
          { pubkey: Transaction::SYSTEM_PROGRAM_ID, is_signer: false, is_writable: false }
        ],
        data: data
      )

      signature = client.send_and_confirm(tx.serialize_base64)
      { signature: signature, entry_pda: Keypair.encode_base58(e_pda) }
    end

    # Settle contest — admin distributes payouts
    def settle_contest(contest_slug, settlements)
      admin = Keypair.admin
      c_pda, _ = contest_pda(contest_slug)
      vault_pda, _ = vault_state_pda

      # Build settlement data
      settlement_data = settlements.map do |s|
        Borsh.encode_pubkey(Keypair.decode_base58(s[:wallet])) +
        Borsh.encode_u32(s[:entry_num]) +
        Borsh.encode_u32(s[:rank]) +
        Borsh.encode_u64(s[:payout])
      end

      data = Transaction.anchor_discriminator("settle_contest") +
             Borsh.encode_u32(settlements.length) +
             settlement_data.join

      # Build remaining accounts (pairs of user_account + contest_entry)
      remaining = settlements.flat_map do |s|
        user_pda, _ = user_account_pda(s[:wallet])
        e_pda, _ = entry_pda(contest_slug, s[:wallet], s[:entry_num])
        [
          { pubkey: user_pda, is_signer: false, is_writable: true },
          { pubkey: e_pda, is_signer: false, is_writable: true }
        ]
      end

      tx = build_tx(admin)
      tx.add_instruction(
        program_id: @program_id,
        accounts: [
          { pubkey: admin.public_key_bytes, is_signer: true, is_writable: true },
          { pubkey: vault_pda, is_signer: false, is_writable: false },
          { pubkey: c_pda, is_signer: false, is_writable: true }
        ] + remaining,
        data: data
      )

      signature = client.send_and_confirm(tx.serialize_base64)
      { signature: signature }
    end

    # Read onchain Contest account
    def read_contest(contest_slug)
      pda, _ = contest_pda(contest_slug)
      pda_base58 = Keypair.encode_base58(pda)

      info = client.get_account_info(pda_base58)
      return nil unless info&.dig("value")

      data = Base64.decode64(info["value"]["data"][0])
      offset = 8 # skip Anchor discriminator

      _contest_id, offset = Borsh.decode_pubkey(data, offset) # [u8; 32] same size as pubkey
      entry_fee, offset = Borsh.decode_u64(data, offset)
      max_entries, offset = Borsh.decode_u32(data, offset)
      current_entries, offset = Borsh.decode_u32(data, offset)
      prize_pool, offset = Borsh.decode_u64(data, offset)
      bonus, offset = Borsh.decode_u64(data, offset)
      status_byte, offset = Borsh.decode_u8(data, offset)
      # Vec<u16> payout_bps
      vec_len, offset = Borsh.decode_u32(data, offset)
      payout_bps = vec_len.times.map { |_| v, offset = Borsh.decode_u16(data, offset); v }
      admin_bytes, offset = Borsh.decode_pubkey(data, offset)

      status_name = %w[Open Locked Settled][status_byte] || "Unknown"

      {
        pda: pda_base58,
        entry_fee: entry_fee,
        entry_fee_dollars: Config.lamports_to_dollars(entry_fee),
        max_entries: max_entries,
        current_entries: current_entries,
        prize_pool: prize_pool,
        prize_pool_dollars: Config.lamports_to_dollars(prize_pool),
        bonus: bonus,
        bonus_dollars: Config.lamports_to_dollars(bonus),
        status: status_name,
        payout_bps: payout_bps,
        admin: Keypair.encode_base58(admin_bytes)
      }
    end

    # Read onchain UserAccount balance
    def sync_balance(wallet_address)
      user_pda, _ = user_account_pda(wallet_address)
      pda_base58 = Keypair.encode_base58(user_pda)

      info = client.get_account_info(pda_base58)
      return nil unless info&.dig("value")

      account_data = Base64.decode64(info["value"]["data"][0])
      # Skip 8-byte discriminator
      offset = 8
      _wallet, offset = Borsh.decode_pubkey(account_data, offset)
      balance, offset = Borsh.decode_u64(account_data, offset)
      total_deposited, offset = Borsh.decode_u64(account_data, offset)
      total_withdrawn, offset = Borsh.decode_u64(account_data, offset)
      total_won, _ = Borsh.decode_u64(account_data, offset)

      {
        balance: balance,
        total_deposited: total_deposited,
        total_withdrawn: total_withdrawn,
        total_won: total_won,
        balance_dollars: Config.lamports_to_dollars(balance)
      }
    end

    # Fetch native SOL and SPL token balances for a wallet address
    def fetch_wallet_balances(wallet_address)
      sol_result = client.get_balance(wallet_address)
      sol_lamports = sol_result.is_a?(Hash) ? sol_result["value"] : sol_result
      sol_balance = sol_lamports.to_f / 1_000_000_000

      tokens = {}
      begin
        result = client.get_token_accounts_by_owner(wallet_address)
        if result && result["value"]
          result["value"].each do |account|
            parsed = account.dig("account", "data", "parsed", "info")
            next unless parsed
            mint = parsed["mint"]
            amount = parsed.dig("tokenAmount", "uiAmount") || 0
            tokens[mint] = amount
          end
        end
      rescue Solana::Client::RpcError
        # Token accounts may not exist yet — that's fine
      end

      {
        sol: sol_balance,
        usdc: Config::USDC_MINT.present? ? (tokens[Config::USDC_MINT] || 0) : nil,
        usdt: Config::USDT_MINT.present? ? (tokens[Config::USDT_MINT] || 0) : nil,
        tokens: tokens
      }
    end

    private

    def build_tx(signer)
      blockhash = client.get_latest_blockhash
      tx = Transaction.new
      tx.set_recent_blockhash(blockhash)
      tx.add_signer(signer)
      tx
    end

    def b(str)
      str.b
    end
  end
end
