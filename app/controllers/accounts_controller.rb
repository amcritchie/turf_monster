class AccountsController < ApplicationController
  include UserMergeable

  def show
    @user = current_user
  end

  def update
    @user = current_user
    rescue_and_log(target: @user) do
      @user.update!(account_params)
      redirect_to account_path, notice: "Account updated."
    end
  rescue StandardError => e
    flash.now[:alert] = "Failed to update account."
    render :show, status: :unprocessable_entity
  end

  def link_wallet
    message = params[:message]
    signature = params[:signature]

    rescue_and_log(target: current_user) do
      recovered = Eth::Signature.personal_recover(message, signature)
      recovered_address = Eth::Util.public_key_to_address(recovered).to_s.downcase

      claimed_address = message.match(/0x[a-fA-F0-9]{40}/)&.to_s&.downcase
      claimed_nonce = message.match(/Nonce: (\w+)/)&.captures&.first

      unless recovered_address == claimed_address
        return render json: { error: "Signature verification failed" }, status: :unauthorized
      end

      unless claimed_nonce == session[:wallet_nonce]
        return render json: { error: "Invalid nonce" }, status: :unauthorized
      end

      session.delete(:wallet_nonce)

      # Check if wallet belongs to another user
      existing = User.from_wallet(claimed_address)
      if existing && existing.id != current_user.id
        merge_users!(survivor: current_user, absorbed: existing)
        return render json: { success: true, redirect: account_path, notice: "Accounts merged." }
      end

      current_user.update!(wallet_address: claimed_address)
      render json: { success: true, redirect: account_path }
    end
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def unlink_google
    rescue_and_log(target: current_user) do
      current_user.update!(provider: nil, uid: nil)
      redirect_to account_path, notice: "Google account unlinked."
    end
  rescue StandardError => e
    redirect_to account_path, alert: "Failed to unlink Google."
  end

  def change_password
    rescue_and_log(target: current_user) do
      # If user already has a password, verify current one
      if current_user.has_password? && !current_user.authenticate(params[:current_password])
        flash.now[:alert] = "Current password is incorrect."
        @user = current_user
        return render :show, status: :unprocessable_entity
      end

      current_user.update!(password: params[:new_password], password_confirmation: params[:new_password_confirmation])
      redirect_to account_path, notice: "Password updated."
    end
  rescue StandardError => e
    flash.now[:alert] = e.message
    @user = current_user
    render :show, status: :unprocessable_entity
  end

  private

  def account_params
    params.require(:user).permit(:name, :email)
  end
end
