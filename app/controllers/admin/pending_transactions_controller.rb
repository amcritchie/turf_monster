module Admin
  class PendingTransactionsController < ApplicationController
    before_action :require_admin
    before_action :set_pending_transaction, only: [:show, :confirm, :rebuild]

    def index
      @pending = PendingTransaction.order(created_at: :desc)
      @pending_count = PendingTransaction.pending.count
    end

    def show
    end

    def confirm
      rescue_and_log(target: @tx) do
        raise "Transaction is #{@tx.status}, not pending" unless @tx.pending?

        @tx.update!(
          status: "confirmed",
          cosigner_address: params[:cosigner_address],
          tx_signature: params[:tx_signature]
        )

        # Mark contest as settled onchain if target is a Contest
        if @tx.target.is_a?(Contest)
          @tx.target.update!(onchain_settled: true)
        end

        respond_to do |format|
          format.json { render json: { status: "confirmed", tx_signature: @tx.tx_signature } }
          format.html { redirect_to admin_pending_transactions_path, notice: "Transaction confirmed." }
        end
      end
    rescue StandardError => e
      respond_to do |format|
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
        format.html { redirect_to admin_pending_transactions_path, alert: "Confirmation failed: #{e.message}" }
      end
    end

    def rebuild
      rescue_and_log(target: @tx) do
        raise "Transaction is #{@tx.status}, cannot rebuild" unless @tx.pending?

        settlements = JSON.parse(@tx.metadata)["settlements"].map(&:symbolize_keys)
        vault = Solana::Vault.new
        cosigner = Solana::Config::MULTISIG_COSIGNER
        result = vault.build_settle_contest(@tx.target.slug, settlements, cosigner_pubkey: cosigner)
        @tx.update!(serialized_tx: result[:serialized_tx], status: "pending")

        respond_to do |format|
          format.json { render json: { status: "rebuilt", serialized_tx: result[:serialized_tx] } }
          format.html { redirect_to admin_pending_transactions_path, notice: "Transaction rebuilt with fresh blockhash." }
        end
      end
    rescue StandardError => e
      respond_to do |format|
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
        format.html { redirect_to admin_pending_transactions_path, alert: "Rebuild failed: #{e.message}" }
      end
    end

    private

    def set_pending_transaction
      @tx = PendingTransaction.find_by(slug: params[:slug])
      return redirect_to admin_pending_transactions_path, alert: "Transaction not found" unless @tx
    end
  end
end
