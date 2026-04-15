# Devnet E2E Test Runbook

End-to-end tests that exercise Turf Monster against real Solana devnet. These tests create real onchain contests, submit real entries, and mint real devnet USDC.

## Prerequisites

- Node.js + `npx playwright` installed (`npm install` in project root)
- Dev server running on port 3001 (`bin/dev` or `bin/rails server -p 3001`)
- Sidekiq running (`bundle exec sidekiq`) — required for `EnsureAtaJob` after user registration
- `SOLANA_BOT_KEY` env var set to Alex Bot's base58-encoded private key (same as `SOLANA_ADMIN_KEY` in `.env`)
- Alex Bot wallet funded on devnet (see minimum balances below)
- Mack wallet funded on devnet (~1 SOL + ~$100 USDC for Web3 tests 5-6)

## Pre-Flight Balance Check

The tests automatically check balances and fail fast if insufficient. You can also check manually:

```bash
# SOL balance
solana balance F6f8h5yynbnkgWvU5abQx3RJxJpe8EoQmeFBuNKdKzhZ --url devnet

# USDC balance (mint: 222Dcu2RgAXE3T8A4mGSG3kQyXaNjqePx7vva1RdWBN9)
spl-token balance 222Dcu2RgAXE3T8A4mGSG3kQyXaNjqePx7vva1RdWBN9 --owner F6f8h5yynbnkgWvU5abQx3RJxJpe8EoQmeFBuNKdKzhZ --url devnet
```

### Measured Consumption Per Run

| Token | Consumption | Notes |
|-------|-------------|-------|
| SOL | ~0.008 SOL | Transaction fees (contest creation, ATA creation, entries) |
| USDC | ~$49 | Entry fees ($40 per contest entry) + faucet doesn't cost admin USDC |

### Minimum Balances

| Token | Minimum | Why |
|-------|---------|-----|
| SOL | 0.1 SOL | Transaction fees with safety margin |
| USDC | $50 | Entry fee headroom |

### Topping Up

**SOL** — follow the faucet protocol in order:

1. `devnet-pow mine --target-lamports 200000000 -ud` (preferred, no rate limits)
2. https://faucet.quicknode.com/solana/devnet
3. https://faucet.solana.com
4. `solana airdrop 1 --url devnet` (last resort, often rate-limited)

**USDC** — mint via the app's faucet page at `/faucet` or use the admin CLI rake task.

## Running the Tests

```bash
# Full devnet suite (7 tests)
SOLANA_BOT_KEY=<key> npx playwright test --project=devnet

# Using the .env key directly
export SOLANA_BOT_KEY=$(grep SOLANA_ADMIN_KEY .env | cut -d= -f2) && npx playwright test --project=devnet

# Single test by name
SOLANA_BOT_KEY=<key> npx playwright test --project=devnet -g "contest flow"

# Headed mode (see the browser)
SOLANA_BOT_KEY=<key> npx playwright test --project=devnet --headed
```

The `devnet` project in `playwright.config.js` filters tests by the `@devnet` tag in test names. Timeout is 90s per test.

## Test Inventory

| # | Test Name | What It Does |
|---|-----------|-------------|
| 1 | New Contest Flow | Alex logs in via KeypairProvider wallet, creates onchain contest, selects 6 matchups, submits onchain entry. Saves contest URL for later tests. |
| 2 | New Manual Registration | Registers Mason via email/password, completes profile, claims $50 USDC from faucet, verifies wallet balance. |
| 3 | New Entry Submission | Registers a fresh Mason, funds via faucet, enters Test 1's shared contest with 6 picks. Saves Mason's credentials. |
| 4 | Second Entry Submission | Mason logs back in, claims more faucet USDC, enters the same contest with 6 different picks. Tests multi-entry per user. |
| 5 | New Web3 Registration | Mack connects via KeypairProvider wallet (different key from Alex), completes profile. Tests new user creation via wallet auth. |
| 6 | New Web3 Submission | Mack logs in via wallet, enters the shared contest with 6 picks via direct onchain path. Verifies explorer tx link. |
| 7 | Web3 Second Entry | Mack logs in via wallet, re-enters the shared contest with 6 different picks (cards 6-11). Tests multi-entry for Web3 users. |

**Note:** Tests run serially (`workers: 1`). Tests 3-4 and 6-7 depend on Test 1's `sharedContestUrl`. Test 4 depends on Test 3's Mason credentials. Tests use two wallets: Alex Bot (admin) and Mack (Web3 user).

## Pre-Flight Checks (Automatic)

The `beforeAll` hook automatically:
1. Validates `SOLANA_BOT_KEY` env var is set
2. Links Alex's wallet to the bot pubkey in the dev DB (via `bin/rails runner`)
3. Clears Mack's wallet address from existing users (for clean Web3 registration)
4. Snapshots SOL and USDC balances for both Alex and Mack
5. Fails fast if Alex's balances are below minimums

The `afterAll` hook logs post-flight balances and consumption delta.

## Standard Suite Check

After running devnet tests, verify the standard suite is unaffected:

```bash
npx playwright test --project=chromium
```

The `chromium` project excludes `@devnet` tests via `grepInvert`.

## Troubleshooting

### IllegalOwner on Faucet/Entry
Error: `Transaction failed: {"InstructionError"=>[0, "IllegalOwner"]}`

Race condition between Sidekiq's `EnsureAtaJob` and the faucet's `ensure_ata`. The tests include a 5-second wait after registration to allow Sidekiq to create the token account. If this still fails:
- Verify Sidekiq is running: `ps aux | grep sidekiq`
- Restart Sidekiq: `bundle exec sidekiq`

### Insufficient SOL Balance
Error: `Attempt to debit an account but found no record of a prior credit`

Top up SOL using the faucet protocol above. Each test run uses ~0.008 SOL.

### Insufficient USDC Balance
If entry submissions fail with balance errors, mint more USDC via `/faucet` while logged in as Alex Bot.

### RPC Timeout / Rate Limiting
Devnet RPC can be flaky. If tests fail with timeout errors:
- Retry once — devnet congestion is usually transient
- Switch RPC: set `SOLANA_RPC_URL` to a different devnet endpoint (QuickNode, Helius, etc.)
- Check devnet status: https://status.solana.com

### Tests 3-4 or 6 Skipped
`No shared contest URL from Test 1` or `No Mason credentials from Test 3` — dependent tests skip if their prerequisite didn't run. Run the full suite, not individual tests in isolation.

### Stale Server
If tests fail on page assertions (wrong content, missing elements):
- Restart the dev server: kill port 3001, re-run
- Re-seed: `bin/rails runner e2e/seed.rb`
- Check for pending migrations: `bin/rails db:migrate`

### Faucet Claim Timeout
The faucet mints SPL tokens on devnet. If it times out at 60s:
- Check devnet RPC health
- The `solanaModal` will show an error message — check the browser console for details
