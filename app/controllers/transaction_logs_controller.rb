class TransactionLogsController < ApplicationController
  before_action :require_admin

  def index
    @transaction_logs = TransactionLog.includes(:user, :source).order(created_at: :desc)
    @transaction_logs = @transaction_logs.by_type(params[:type]) if params[:type].present?
    @transaction_logs = @transaction_logs.where(status: params[:status]) if params[:status].present?
    @transaction_logs = @transaction_logs.where(user_id: params[:user_id]) if params[:user_id].present?
    @transaction_logs = @transaction_logs.limit(100)

    @summary = {
      total_deposits: TransactionLog.by_type("deposit").completed.sum(:amount_cents),
      total_withdrawals: TransactionLog.by_type("withdrawal").completed.sum(:amount_cents),
      total_payouts: TransactionLog.by_type("payout").completed.sum(:amount_cents),
      total_entry_fees: TransactionLog.by_type("entry_fee").completed.sum(:amount_cents),
      pending_count: TransactionLog.pending.count
    }
  end

  def show
    @transaction_log = TransactionLog.find_by(slug: params[:slug])
    return redirect_to admin_transactions_path, alert: "Transaction not found" unless @transaction_log
  end

  def approve
    txn = TransactionLog.find_by(slug: params[:slug])
    return redirect_to admin_transactions_path, alert: "Transaction not found" unless txn

    rescue_and_log(target: txn) do
      raise "Only pending transactions can be approved" unless txn.status == "pending"

      # Execute onchain withdrawal for managed wallet users
      onchain_tx = nil
      if txn.user.managed_wallet? && txn.user.solana_keypair
        vault = Solana::Vault.new
        amount_lamports = Solana::Config.dollars_to_lamports(txn.amount_cents / 100.0)
        onchain_tx = vault.withdraw(txn.user.solana_keypair, amount_lamports)
      end

      txn.update!(status: "approved", onchain_tx: onchain_tx)
      redirect_to admin_transactions_path(status: "pending"), notice: "Withdrawal approved for #{txn.user.display_name}. Onchain withdrawal executed."
    end
  rescue StandardError => e
    redirect_to admin_transactions_path, alert: "Approve failed: #{e.message}"
  end

  def complete
    txn = TransactionLog.find_by(slug: params[:slug])
    return redirect_to admin_transactions_path, alert: "Transaction not found" unless txn

    rescue_and_log(target: txn) do
      raise "Only approved transactions can be completed" unless txn.status == "approved"
      txn.update!(status: "completed", description: "#{txn.description} (fiat sent)")
      redirect_to admin_transactions_path, notice: "Withdrawal marked complete for #{txn.user.display_name}."
    end
  rescue StandardError => e
    redirect_to admin_transactions_path, alert: "Complete failed: #{e.message}"
  end

  def deny
    txn = TransactionLog.find_by(slug: params[:slug])
    return redirect_to admin_transactions_path, alert: "Transaction not found" unless txn

    rescue_and_log(target: txn) do
      raise "Only pending transactions can be denied" unless txn.status == "pending"
      # Refund the held balance
      txn.user.increment!(:balance_cents, txn.amount_cents)
      txn.update!(status: "failed", description: "#{txn.description} (denied — funds returned)")
      redirect_to admin_transactions_path(status: "pending"), notice: "Withdrawal denied, funds returned to #{txn.user.display_name}."
    end
  rescue StandardError => e
    redirect_to admin_transactions_path, alert: "Deny failed: #{e.message}"
  end
end
