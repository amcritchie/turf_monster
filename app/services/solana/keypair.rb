# Rails-specific extensions to Solana::Keypair (from solana_studio gem).
# Adds admin keypair loading, encrypt/decrypt for DB storage.

module Solana
  class Keypair
    # Load admin keypair — tries SOLANA_ADMIN_KEY env var (base58) first, falls back to JSON file
    def self.admin
      @admin ||= if ENV["SOLANA_ADMIN_KEY"].present?
        from_base58(ENV["SOLANA_ADMIN_KEY"])
      else
        from_json_file(Config::ADMIN_KEYPAIR_PATH)
      end
    end

    # Load from encrypted string (stored in DB)
    def self.from_encrypted(encrypted_string)
      decrypted = encryptor.decrypt_and_verify(encrypted_string)
      from_bytes(Base64.strict_decode64(decrypted))
    end

    # Encrypt for DB storage
    def encrypt
      self.class.encryptor.encrypt_and_sign(Base64.strict_encode64(to_bytes))
    end

    private

    def self.encryptor
      @encryptor ||= begin
        key = Rails.application.credentials.secret_key_base[0, 32]
        ActiveSupport::MessageEncryptor.new(key)
      end
    end
  end
end
