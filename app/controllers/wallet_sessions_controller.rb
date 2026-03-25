class WalletSessionsController < ApplicationController
  skip_before_action :require_authentication

  def nonce
    session[:wallet_nonce] = SecureRandom.hex(16)
    render json: { nonce: session[:wallet_nonce] }
  end

  def verify
    message = params[:message]
    signature = params[:signature]

    rescue_and_log(target: nil) do
      # Recover signer address from signature
      recovered = Eth::Signature.personal_recover(message, signature)
      recovered_address = Eth::Util.public_key_to_address(recovered).to_s.downcase

      # Parse claimed address and nonce from SIWE message
      claimed_address = message.match(/0x[a-fA-F0-9]{40}/)&.to_s&.downcase
      claimed_nonce = message.match(/Nonce: (\w+)/)&.captures&.first

      # Verify recovered matches claimed
      unless recovered_address == claimed_address
        return render json: { error: "Signature verification failed" }, status: :unauthorized
      end

      # Verify nonce matches session
      unless claimed_nonce == session[:wallet_nonce]
        return render json: { error: "Invalid nonce" }, status: :unauthorized
      end

      # Clear nonce (single-use)
      session.delete(:wallet_nonce)

      # Find or create user
      user = User.from_wallet(claimed_address) || User.create!(
        name: "anon",
        wallet_address: claimed_address,
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
