module Solana
  module Borsh
    module_function

    def encode_u8(value)
      [value].pack("C")
    end

    def encode_u16(value)
      [value].pack("v") # little-endian u16
    end

    def encode_u32(value)
      [value].pack("V") # little-endian u32
    end

    def encode_u64(value)
      [value].pack("Q<") # little-endian u64
    end

    def encode_i64(value)
      [value].pack("q<") # little-endian i64
    end

    def encode_pubkey(pubkey_bytes)
      pubkey_bytes = Keypair.decode_base58(pubkey_bytes) if pubkey_bytes.is_a?(String) && pubkey_bytes.length != 32
      pubkey_bytes = pubkey_bytes.b if pubkey_bytes.is_a?(String)
      raise "Pubkey must be 32 bytes, got #{pubkey_bytes.bytesize}" unless pubkey_bytes.bytesize == 32
      pubkey_bytes
    end

    def encode_bytes32(bytes)
      bytes = bytes.b if bytes.is_a?(String)
      raise "Expected 32 bytes, got #{bytes.bytesize}" unless bytes.bytesize == 32
      bytes
    end

    def encode_vec(items, &block)
      encoded_items = items.map { |item| block.call(item) }.join
      encode_u32(items.length) + encoded_items
    end

    def encode_string(str)
      bytes = str.encode("UTF-8").b
      encode_u32(bytes.bytesize) + bytes
    end

    def encode_bool(value)
      encode_u8(value ? 1 : 0)
    end

    # Decode helpers

    def decode_u8(bytes, offset = 0)
      [bytes.byteslice(offset, 1).unpack1("C"), offset + 1]
    end

    def decode_u16(bytes, offset = 0)
      [bytes.byteslice(offset, 2).unpack1("v"), offset + 2]
    end

    def decode_u32(bytes, offset = 0)
      [bytes.byteslice(offset, 4).unpack1("V"), offset + 4]
    end

    def decode_u64(bytes, offset = 0)
      [bytes.byteslice(offset, 8).unpack1("Q<"), offset + 8]
    end

    def decode_pubkey(bytes, offset = 0)
      [bytes.byteslice(offset, 32), offset + 32]
    end
  end
end
