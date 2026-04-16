module Solana
  class Reconciler
    attr_reader :vault, :discrepancies

    def initialize
      @vault = Vault.new
      @discrepancies = []
    end

    # Verify user has an on-chain USDC account
    def reconcile_user(user)
      return unless user.solana_connected?

      onchain = vault.sync_balance(user.solana_address)
      unless onchain
        @discrepancies << {
          type: :missing_onchain_account,
          user_id: user.id,
          user_name: user.display_name,
          solana_address: user.solana_address
        }
        return
      end

      onchain
    end

    # Reconcile all users with Solana addresses
    def reconcile_all
      @discrepancies = []
      users = User.where.not(solana_address: nil)
      results = {}

      users.find_each do |user|
        results[user.id] = reconcile_user(user)
      rescue => e
        @discrepancies << {
          type: :error,
          user_id: user.id,
          user_name: user.display_name,
          error: e.message
        }
      end

      log_discrepancies if @discrepancies.any?
      { users_checked: users.count, discrepancies: @discrepancies }
    end

    # Verify onchain contest state matches DB
    def reconcile_contest(contest)
      return unless contest.onchain?

      # Read onchain contest account
      client = vault.client
      info = client.get_account_info(contest.onchain_contest_id)
      unless info&.dig("value")
        @discrepancies << {
          type: :missing_onchain_contest,
          contest_id: contest.id,
          contest_name: contest.name,
          onchain_id: contest.onchain_contest_id
        }
        return
      end

      account_data = Base64.decode64(info["value"]["data"][0])
      # Skip 8-byte discriminator + 32-byte contest_id + 8-byte prizes
      offset = 8 + 32 + 8
      entry_fee, offset = Borsh.decode_u64(account_data, offset)
      entry_fees, offset = Borsh.decode_u64(account_data, offset)
      max_entries, offset = Borsh.decode_u32(account_data, offset)
      current_entries, offset = Borsh.decode_u32(account_data, offset)

      db_entries = contest.entries.where(status: [:active, :complete]).count
      db_pool = Solana::Config.dollars_to_lamports(contest.pool_dollars)

      if current_entries.to_i != db_entries
        @discrepancies << {
          type: :entry_count_mismatch,
          contest_id: contest.id,
          contest_name: contest.name,
          db_entries: db_entries,
          onchain_entries: current_entries
        }
      end

      if entry_fees.to_i != db_pool
        @discrepancies << {
          type: :entry_fees_mismatch,
          contest_id: contest.id,
          contest_name: contest.name,
          db_pool_lamports: db_pool,
          onchain_pool_lamports: entry_fees
        }
      end

      { entry_fee: entry_fee, max_entries: max_entries, current_entries: current_entries, entry_fees: entry_fees }
    end

    private

    def log_discrepancies
      @discrepancies.each do |d|
        Rails.logger.warn "[Solana Reconciler] #{d[:type]}: #{d.except(:type).to_json}"
        ErrorLog.create!(
          message: "Solana reconciliation: #{d[:type]}",
          inspect: d.to_json,
          backtrace: caller.first(5).to_json
        )
      end
    end
  end
end
