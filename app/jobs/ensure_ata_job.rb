class EnsureAtaJob < ApplicationJob
  queue_as :default

  def perform(wallet_address)
    vault = Solana::Vault.new
    vault.ensure_ata(wallet_address, mint: Solana::Config::USDC_MINT)
  end
end
