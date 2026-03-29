require "ed25519"
require "securerandom"
require "json"

module Solana
  class Keypair
    BASE58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

    attr_reader :signing_key, :verify_key

    def initialize(signing_key)
      @signing_key = signing_key
      @verify_key = signing_key.verify_key
    end

    # Generate a new random keypair
    def self.generate
      new(Ed25519::SigningKey.generate)
    end

    # Load from raw 64-byte secret key (Solana format: 32-byte private + 32-byte public)
    def self.from_bytes(bytes)
      bytes = bytes.pack("C*") if bytes.is_a?(Array)
      private_key = bytes[0, 32]
      new(Ed25519::SigningKey.new(private_key))
    end

    # Load from Solana CLI keypair JSON file (array of 64 bytes)
    def self.from_json_file(path)
      bytes = JSON.parse(File.read(path))
      from_bytes(bytes)
    end

    # Load admin keypair from configured path
    def self.admin
      @admin ||= from_json_file(Config::ADMIN_KEYPAIR_PATH)
    end

    # Load from encrypted string (stored in DB)
    def self.from_encrypted(encrypted_string)
      decrypted = encryptor.decrypt_and_verify(encrypted_string)
      from_bytes(Base64.strict_decode64(decrypted))
    end

    # Public key as 32 bytes
    def public_key_bytes
      @verify_key.to_bytes
    end

    # Public key as base58 string (Solana address)
    def to_base58
      self.class.encode_base58(public_key_bytes)
    end
    alias_method :address, :to_base58

    # Sign a message
    def sign(message)
      message = message.pack("C*") if message.is_a?(Array)
      @signing_key.sign(message)
    end

    # Full 64-byte secret key (Solana format)
    def to_bytes
      @signing_key.to_bytes + public_key_bytes
    end

    # Encrypt for DB storage
    def encrypt
      self.class.encryptor.encrypt_and_sign(Base64.strict_encode64(to_bytes))
    end

    # --- Base58 utilities ---

    def self.encode_base58(bytes)
      bytes = bytes.b if bytes.is_a?(String)
      num = bytes.unpack1("H*").to_i(16)

      result = ""
      while num > 0
        num, remainder = num.divmod(58)
        result = BASE58_ALPHABET[remainder] + result
      end

      # Preserve leading zero bytes
      bytes.each_byte do |byte|
        break unless byte == 0
        result = "1" + result
      end

      result
    end

    def self.decode_base58(string)
      num = 0
      string.each_char do |c|
        num = num * 58 + BASE58_ALPHABET.index(c)
      end

      hex = num.to_s(16)
      hex = "0" + hex if hex.length.odd?

      # Count leading '1's (zero bytes)
      leading_zeros = string.chars.take_while { |c| c == "1" }.length
      bytes = [("00" * leading_zeros) + hex].pack("H*")
      bytes
    end

    def self.pubkey_from_base58(address)
      decode_base58(address)
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
