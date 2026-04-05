# Turf Monster

Sports pick'em game for the FIFA World Cup 2026. Players select 5 team matchups with multipliers per entry, scored by actual goals. Features Solana blockchain integration for contest escrow and prize distribution.

**Live**: https://turf.mcritchie.studio

## Prerequisites

- Ruby 3.1+
- PostgreSQL 14+
- Node.js 18+ (for Playwright tests)
- Bundler (`gem install bundler`)
- Solana CLI (optional, for blockchain features)

## Setup

```bash
git clone https://github.com/amcritchie/turf_monster.git
cd turf_monster
bundle install
bin/rails db:create db:migrate db:seed
```

Seeds create 5 users (`alex@mcritchie.studio` / `password` is admin), 48 World Cup teams, 72 group stage matches, and 67 players.

## Run

```bash
bin/dev
```

Runs on **port 3001** (web server + Tailwind CSS watcher via Procfile.dev). Open http://localhost:3001.

## Test

```bash
# Rails unit + integration tests (71 tests)
bin/rails test

# Playwright E2E tests (19 tests across 4 spec files)
npm test

# Playwright with visible browser
npm run test:headed
```

## Key Features

- **Matchup grid** with team selection, multipliers, and animated hold-to-confirm button
- **Contest lifecycle**: draft, open, locked, settled with admin controls (fill, lock, jump, grade, reset)
- **Multiple entries** per user per contest with different selection combos
- **Scoring**: team goals x multiplier per selection, entries ranked, payouts distributed
- **Solana integration**: on-chain contest escrow via [TurfVault](https://github.com/amcritchie/turf_vault) Anchor program (devnet)
- **Phantom wallet** connect, deposit, withdraw, and direct entry
- **Dark/light theme** toggle with green primary palette

## Deploy

```bash
git push heroku main
heroku run bin/rails db:migrate --app turf-monster
```

Platform: Heroku (heroku-24 stack). Required env vars: `RAILS_MASTER_KEY`, `RAILS_SERVE_STATIC_FILES=true`, `SOLANA_ADMIN_KEY`, `SOLANA_RPC_URL`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`.

## Solana Integration

The app connects to the TurfVault Anchor program on Solana devnet for contest escrow. Users with Phantom wallets can deposit USDC, enter contests on-chain, and receive payouts. The `SOLANA_ADMIN_KEY` env var holds the admin bot's base58 private key. See `docs/SOLANA.md` for full details.

## Architecture

- Rails 7.2 with ERB views, Tailwind CSS, Alpine.js
- Shared [Studio engine](https://github.com/amcritchie/studio) for auth, error handling, and theme system
- [SolanaStudio](https://github.com/amcritchie/solana_studio) gem for Solana RPC and transaction building
- Slug-based foreign keys for teams, games, and players
- All monetary values stored in cents, displayed in dollars

## Development Notes

See [CLAUDE.md](./CLAUDE.md) for detailed development context including model schemas, route maps, error handling patterns, and code conventions.

Topic-specific documentation lives in `docs/`:

| File | Topic |
|------|-------|
| `docs/AUTH.md` | Authentication, account management, SSO |
| `docs/SOLANA.md` | Solana integration, wallet types, on-chain flows |
| `docs/FORMULAS.md` | Scoring formulas, slate system, Chart.js patterns |
| `docs/UI_PATTERNS.md` | Branding, theme, matchup grid, animations |
| `docs/world_cup_2026.md` | World Cup format, groups, matchday structure |
