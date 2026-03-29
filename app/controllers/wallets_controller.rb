class WalletsController < ApplicationController
  before_action :require_login

  def show
    @user = current_user
  end

  def deposit
    amount_dollars = params[:amount].to_f
    return redirect_to wallet_path, alert: "Invalid amount" if amount_dollars <= 0

    amount_cents = (amount_dollars * 100).to_i

    rescue_and_log(target: current_user) do
      if current_user.custodial_wallet?
        # Custodial: server signs deposit tx onchain
        # For Devnet: just credit the DB balance (no real tokens yet)
        current_user.add_funds!(amount_cents)
        redirect_to wallet_path, notice: "Deposited $#{'%.2f' % amount_dollars}."
      elsif current_user.phantom_wallet?
        # Phantom: return unsigned tx for frontend signing
        # For now, redirect — Phase 5 will wire up Phantom tx signing
        redirect_to wallet_path, alert: "Phantom deposits coming soon. Use the faucet for testing."
      else
        redirect_to wallet_path, alert: "Connect a wallet first."
      end
    end
  rescue StandardError => e
    redirect_to wallet_path, alert: "Deposit failed: #{e.message}"
  end

  def withdraw
    amount_dollars = params[:amount].to_f
    return redirect_to wallet_path, alert: "Invalid amount" if amount_dollars <= 0

    amount_cents = (amount_dollars * 100).to_i

    rescue_and_log(target: current_user) do
      raise "Insufficient withdrawable balance" if current_user.withdrawable_cents < amount_cents

      if current_user.custodial_wallet?
        # Custodial: server signs withdraw tx onchain
        # For Devnet: just debit the DB balance
        current_user.decrement!(:balance_cents, amount_cents)
        redirect_to wallet_path, notice: "Withdrew $#{'%.2f' % amount_dollars}."
      elsif current_user.phantom_wallet?
        redirect_to wallet_path, alert: "Phantom withdrawals coming soon."
      else
        redirect_to wallet_path, alert: "Connect a wallet first."
      end
    end
  rescue StandardError => e
    redirect_to wallet_path, alert: "Withdrawal failed: #{e.message}"
  end

  def faucet
    rescue_and_log(target: current_user) do
      raise "Faucet only available on Devnet" unless Solana::Config.devnet?
      current_user.add_funds!(10_00) # $10 test funds
      redirect_to wallet_path, notice: "Added $10.00 test USDC to your balance."
    end
  rescue StandardError => e
    redirect_to wallet_path, alert: "Faucet failed: #{e.message}"
  end

  def sync
    rescue_and_log(target: current_user) do
      unless current_user.solana_connected?
        return redirect_to wallet_path, alert: "No Solana wallet connected."
      end

      vault = Solana::Vault.new
      onchain = vault.sync_balance(current_user.solana_address)

      if onchain
        @onchain_balance = onchain
        flash.now[:notice] = "Onchain balance: $#{'%.2f' % onchain[:balance_dollars]}"
      else
        flash.now[:alert] = "No onchain account found. Deposit to create one."
      end

      @user = current_user
      render :show
    end
  rescue StandardError => e
    redirect_to wallet_path, alert: "Sync failed: #{e.message}"
  end

  private

  def require_login
    return if logged_in?
    redirect_to login_path, alert: "Please log in to access your wallet."
  end
end
