module Solana
  module AuthVerifier
    class VerificationError < StandardError; end

    NONCE_MAX_AGE = 5.minutes

    # Verifies a Phantom wallet signature against a session nonce.
    # Returns the Base58 public key on success, raises VerificationError on failure.
    def verify_solana_signature!(message:, signature_b58:, pubkey_b58:, session:)
      # Delete nonce BEFORE verification to prevent replay
      stored_nonce = session.delete(:solana_nonce)
      nonce_at = session.delete(:solana_nonce_at)

      raise VerificationError, "No nonce in session" unless stored_nonce

      # Reject stale nonces
      if nonce_at && Time.current.to_i - nonce_at > NONCE_MAX_AGE.to_i
        raise VerificationError, "Nonce expired"
      end

      sig_bytes = Solana::Keypair.decode_base58(signature_b58)
      pub_bytes = Solana::Keypair.decode_base58(pubkey_b58)

      verify_key = Ed25519::VerifyKey.new(pub_bytes)
      verify_key.verify(sig_bytes, message)

      claimed_nonce = message.match(/Nonce: (\w+)/)&.captures&.first
      unless claimed_nonce == stored_nonce
        raise VerificationError, "Invalid nonce"
      end

      pubkey_b58
    end
  end
end
