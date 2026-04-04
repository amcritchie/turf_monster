class WalletsController < ApplicationController
  before_action :require_login
  before_action :require_geo_allowed, only: [:deposit, :withdraw]

  def show
    @user = current_user
    @pending_withdrawals = TransactionLog.where(user: current_user, transaction_type: "withdrawal", status: "pending").order(created_at: :desc)
    @recent_transactions = TransactionLog.where(user: current_user).order(created_at: :desc).limit(10)

    # Fetch SOL balance if wallet connected and devnet
    if current_user.solana_connected? && Solana::Config.devnet?
      begin
        client = Solana::Client.new
        result = client.get_balance(current_user.solana_address)
        sol_lamports = result.is_a?(Hash) ? result["value"] : result
        @sol_balance = sol_lamports.to_f / 1_000_000_000
      rescue => e
        Rails.logger.warn "Failed to fetch SOL balance: #{e.message}"
      end
    end
  end

  def deposit
    amount_dollars = params[:amount].to_f
    return redirect_to wallet_path, alert: "Invalid amount" if amount_dollars <= 0

    amount_cents = (amount_dollars * 100).to_i

    rescue_and_log(target: current_user) do
      if current_user.managed_wallet?
        current_user.add_funds!(amount_cents)
        TransactionLog.record!(user: current_user, type: "deposit", amount_cents: amount_cents, direction: "credit", description: "Deposit $#{'%.2f' % amount_dollars}")
        redirect_to wallet_path, notice: "Deposited $#{'%.2f' % amount_dollars}."
      elsif current_user.phantom_wallet?
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
      current_user.with_lock do
        current_user.reload
        raise "Insufficient withdrawable balance" if current_user.withdrawable_cents < amount_cents
        current_user.decrement!(:balance_cents, amount_cents)
      end
      TransactionLog.record!(
        user: current_user,
        type: "withdrawal",
        amount_cents: amount_cents,
        direction: "debit",
        description: "Withdrawal request $#{'%.2f' % amount_dollars}",
        status: "pending"
      )
      redirect_to wallet_path, notice: "Withdrawal of $#{'%.2f' % amount_dollars} submitted for review."
    end
  rescue StandardError => e
    redirect_to wallet_path, alert: "Withdrawal failed: #{e.message}"
  end

  def faucet
    rescue_and_log(target: current_user) do
      raise "Faucet only available on Devnet" unless Solana::Config.devnet?
      current_user.add_funds!(10_00)
      TransactionLog.record!(user: current_user, type: "faucet", amount_cents: 10_00, direction: "credit", description: "Devnet faucet $10.00")
      redirect_to wallet_path, notice: "Added $10.00 test USDC to your balance."
    end
  rescue StandardError => e
    redirect_to wallet_path, alert: "Faucet failed: #{e.message}"
  end

  def airdrop
    rescue_and_log(target: current_user) do
      raise "Airdrop only available on Devnet" unless Solana::Config.devnet?
      raise "No Solana wallet connected" unless current_user.solana_connected?

      client = Solana::Client.new
      signature = client.request_airdrop(current_user.solana_address, 1_000_000_000) # 1 SOL
      redirect_to wallet_path, notice: "Airdropped 1 SOL! TX: #{signature}"
    end
  rescue StandardError => e
    redirect_to wallet_path, alert: "Airdrop failed: #{e.message}"
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
      @pending_withdrawals = TransactionLog.where(user: current_user, transaction_type: "withdrawal", status: "pending").order(created_at: :desc)
      @recent_transactions = TransactionLog.where(user: current_user).order(created_at: :desc).limit(10)
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
