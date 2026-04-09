class MoonpayDepositJob < ApplicationJob
  queue_as :default

  def perform(user_id:, amount_cents:, wallet_address:, moonpay_tx_id:)
    # Idempotency check
    return if TransactionLog.exists?(metadata: { "moonpay_tx_id" => moonpay_tx_id })

    user = User.find_by(id: user_id)
    return unless user

    onchain_tx = nil

    if user.managed_wallet?
      # MoonPay delivered USDC to the wallet's ATA — deposit into vault
      vault = Solana::Vault.new
      vault.ensure_user_account(wallet_address)
      amount_lamports = Solana::Config.dollars_to_lamports(amount_cents / 100.0)
      onchain_tx = vault.deposit(user.solana_keypair, amount_lamports)
    end
    # Phantom wallets: USDC already in ATA, no vault deposit needed

    # Credit DB balance
    user.add_funds!(amount_cents)

    # Record transaction
    TransactionLog.record!(
      user: user,
      type: "deposit",
      amount_cents: amount_cents,
      direction: "credit",
      description: "MoonPay deposit $#{'%.2f' % (amount_cents / 100.0)}",
      onchain_tx: onchain_tx,
      metadata: { moonpay_tx_id: moonpay_tx_id, method: "moonpay" }
    )
  end
end
