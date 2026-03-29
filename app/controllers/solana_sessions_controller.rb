class SolanaSessionsController < ApplicationController
  skip_before_action :require_authentication

  def nonce
    session[:solana_nonce] = SecureRandom.hex(16)
    render json: { nonce: session[:solana_nonce] }
  end

  def verify
    message = params[:message]
    signature_b58 = params[:signature]
    pubkey_b58 = params[:pubkey]

    rescue_and_log(target: nil) do
      # Decode base58 signature and public key
      sig_bytes = Solana::Keypair.decode_base58(signature_b58)
      pub_bytes = Solana::Keypair.decode_base58(pubkey_b58)

      # Verify Ed25519 signature
      verify_key = Ed25519::VerifyKey.new(pub_bytes)
      verify_key.verify(sig_bytes, message)

      # Parse nonce from message
      claimed_nonce = message.match(/Nonce: (\w+)/)&.captures&.first

      unless claimed_nonce == session[:solana_nonce]
        return render json: { error: "Invalid nonce" }, status: :unauthorized
      end

      session.delete(:solana_nonce)

      # Find or create user with this Solana address
      user = User.from_solana_wallet(pubkey_b58) || User.create!(
        name: "anon",
        solana_address: pubkey_b58,
        wallet_type: "phantom",
        password: SecureRandom.hex(16),
        balance_cents: 0
      )

      set_app_session(user)
      render json: { success: true, redirect: "/" }
    end
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
