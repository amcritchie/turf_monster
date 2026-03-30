module Solana
  module AuthVerifier
    class VerificationError < StandardError; end

    # Verifies a Phantom wallet signature against a session nonce.
    # Returns the Base58 public key on success, raises VerificationError on failure.
    def verify_solana_signature!(message:, signature_b58:, pubkey_b58:, session:)
      sig_bytes = Solana::Keypair.decode_base58(signature_b58)
      pub_bytes = Solana::Keypair.decode_base58(pubkey_b58)

      verify_key = Ed25519::VerifyKey.new(pub_bytes)
      verify_key.verify(sig_bytes, message)

      claimed_nonce = message.match(/Nonce: (\w+)/)&.captures&.first
      unless claimed_nonce == session[:solana_nonce]
        raise VerificationError, "Invalid nonce"
      end

      session.delete(:solana_nonce)

      pubkey_b58
    end
  end
end
