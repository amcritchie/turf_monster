class FaucetController < ApplicationController
  skip_before_action :require_authentication

  def show
    @recent_claims = TransactionLog.where(transaction_type: "faucet")
                                   .order(created_at: :desc)
                                   .limit(10)
                                   .includes(:user)
    @contest = Contest.where(status: "open").order(created_at: :asc).first
  end

  def claim
    unless logged_in?
      return redirect_to login_path, alert: "Please log in to claim test USDC."
    end

    amount_dollars = params[:amount].to_f
    amount_cents = (amount_dollars * 100).to_i

    unless amount_cents > 0 && amount_cents <= 500_00
      return redirect_to faucet_path, alert: "Amount must be between $1 and $500."
    end

    rescue_and_log(target: current_user) do
      raise "Faucet only available on Devnet" unless Solana::Config.devnet?
      raise "No Solana wallet connected" unless current_user.solana_connected?

      vault = Solana::Vault.new
      wallet = current_user.solana_address

      vault.ensure_ata(wallet, mint: Solana::Config::USDC_MINT)
      amount_lamports = Solana::Config.dollars_to_lamports(amount_dollars)
      result = vault.mint_spl(amount_lamports, mint: Solana::Config::USDC_MINT, to: wallet)

      invalidate_usdc_cache
      TransactionLog.record!(
        user: current_user,
        type: "faucet",
        amount_cents: amount_cents,
        direction: "credit",
        description: "Devnet faucet $#{'%.2f' % amount_dollars}",
        onchain_tx: result[:signature]
      )
      redirect_to faucet_path, notice: "Minted $#{'%.2f' % amount_dollars} USDC! TX: #{result[:signature]}"
    end
  rescue StandardError => e
    redirect_to faucet_path, alert: "Faucet failed: #{e.message}"
  end
end
