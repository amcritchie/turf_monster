class StripeDepositJob < ApplicationJob
  queue_as :default

  def perform(user_id:, amount_cents:, wallet_address:, stripe_session_id:)
    # Idempotency check
    return if TransactionLog.exists?(metadata: { "stripe_session_id" => stripe_session_id })

    user = User.find_by(id: user_id)
    return unless user

    vault = Solana::Vault.new
    amount_lamports = Solana::Config.dollars_to_lamports(amount_cents / 100.0)
    onchain_tx = nil

    if user.managed_wallet?
      # Ensure onchain accounts exist
      vault.ensure_ata(wallet_address, mint: Solana::Config::USDC_MINT)
      vault.ensure_user_account(wallet_address)

      # Devnet: mint USDC to user's ATA, then deposit into vault
      # Mainnet: transfer USDC from treasury to user's ATA, then deposit
      fund_result = vault.fund_user(wallet_address, amount_lamports)

      # Deposit from user's ATA into vault
      deposit_sig = vault.deposit(user.solana_keypair, amount_lamports)
      onchain_tx = deposit_sig
    elsif user.phantom_wallet?
      # Phantom: mint/transfer USDC to wallet ATA (user deposits via enter_contest_direct)
      vault.ensure_ata(wallet_address, mint: Solana::Config::USDC_MINT)
      fund_result = vault.fund_user(wallet_address, amount_lamports)
      onchain_tx = fund_result[:signature]
    end

    # Credit DB balance
    user.add_funds!(amount_cents)

    # Record transaction
    TransactionLog.record!(
      user: user,
      type: "deposit",
      amount_cents: amount_cents,
      direction: "credit",
      description: "Stripe deposit $#{'%.2f' % (amount_cents / 100.0)}",
      onchain_tx: onchain_tx,
      metadata: { stripe_session_id: stripe_session_id, method: "stripe" }
    )
  end
end
