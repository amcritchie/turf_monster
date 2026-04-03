# Load Rails-specific extensions to Solana::Keypair (from solana_studio gem).
# The gem defines Solana::Keypair at boot, so Zeitwerk won't autoload the app's
# reopening file — we require it explicitly.
require Rails.root.join("app/services/solana/keypair")
