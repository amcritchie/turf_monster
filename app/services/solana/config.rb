module Solana
  module Config
    PROGRAM_ID = ENV.fetch("SOLANA_PROGRAM_ID", "7Hy8GmJWPMdt6bx3VG4BLFnpNX9TBwkPt87W6bkHgr2J")
    RPC_URL = ENV.fetch("SOLANA_RPC_URL", "https://api.devnet.solana.com")
    NETWORK = ENV.fetch("SOLANA_NETWORK", "devnet")

    # Devnet test mints (created via spl-token create-token --decimals 6)
    USDC_MINT = ENV.fetch("SOLANA_USDC_MINT", "222Dcu2RgAXE3T8A4mGSG3kQyXaNjqePx7vva1RdWBN9")
    USDT_MINT = ENV.fetch("SOLANA_USDT_MINT", "9mxkN8KaVA8FFgDE2LEsn2UbYLPG8Xg9bf4V9MYYi8Ne")

    # Admin keypair path for signing settlement transactions
    ADMIN_KEYPAIR_PATH = ENV.fetch("SOLANA_ADMIN_KEYPAIR", File.expand_path("~/.config/solana/id.json"))

    DECIMALS = 6

    def self.devnet?
      NETWORK == "devnet"
    end

    def self.mainnet?
      NETWORK == "mainnet-beta"
    end

    def self.dollars_to_lamports(dollars)
      (dollars * 10**DECIMALS).to_i
    end

    def self.lamports_to_dollars(lamports)
      lamports.to_f / 10**DECIMALS
    end
  end
end
