# Turf Monster (turf_monster)

Peer-to-peer sports pick'em game focused on team matchup selections with multipliers for the World Cup.

## Topic Files

Load these when working on specific areas:

| File | When to read |
|------|-------------|
| `docs/AUTH.md` | Authentication, account management, admin authorization, SSO |
| `docs/SOLANA.md` | Solana integration, wallet types, onchain flows, rake tasks |
| `docs/FORMULAS.md` | Scoring formulas, slate system, Chart.js patterns |
| `docs/UI_PATTERNS.md` | Branding, theme colors, matchup grid, hold button, animations |
| `docs/world_cup_2026.md` | World Cup format, groups, matchday structure |

## Game Rules

- Each contest has a set of **matchups** — team/opponent pairs with multipliers based on rank
- Players select **5 matchups** per entry
- Each selection is scored: **team goals x multiplier**
- Entry score = sum of all selection scores
- Entries ranked by score DESC; ties get the same rank
- **Payouts**: 1st-6th = $40 each. Rank 1 also gets $50 bonus. Ties split the combined prize pool for their spanned ranks evenly.
- Multiple entries per user per contest allowed (different selection combos required)
- Entry fee deducted from user balance on confirm

## Contest Lifecycle

```
draft → open → locked → settled
```

- **draft**: Contest created, not yet accepting entries
- **open**: Players can submit entries (toggle selections, hold-to-confirm)
- **locked**: No new entries, waiting for game results
- **settled**: All games scored, entries ranked, payouts distributed

### Contest Targeting (root page)

- `Contest.ranked` scope: contests with non-nil `rank`, ordered by rank ASC
- `Contest.target`: first open contest by lowest rank — displayed on root `/`
- Rank values use increments of 100 (Matchday 1=100, 2=200, 3=300)
- If no target contest exists, root redirects to `/contests`
- `load_contest_board_data` — shared private method used by both `world_cup` and `show` actions

### Admin Actions (contest show page + navbar)

- **Fill Contest** — generates random entries (5 random matchups each). Cycles through seeded users. Deduplicates against existing entries.
- **Lock Contest** — transitions open → locked
- **Jump** — simulates all game results and settles the contest in one click
- **Grade Contest** — scores entries based on game results, assigns ranks, distributes payouts
- **Reset** (navbar) — clears all entries/selections, resets games, sets contest back to open

### Key Model Methods

- `Contest#fill!(users:)` — random entries, 5 random matchups each, no duplicate combos
- `Contest#jump!` — simulate game results + grade in one transaction
- `Contest#grade!` — score entries → rank → distribute payouts → settle. Persists `rank` and `payout_cents` on each entry.
- `Contest#reset!` — destroy entries, reset game scores, reopen contest
- `Entry#confirm!` — validates exactly 5 selections, checks for locked games, deducts entry fee, cart → active

## Dev Server

- **Port 3001** — `bin/rails server -p 3001`
- `bin/dev` starts web (port 3001), CSS watcher, and Sidekiq worker via Procfile.dev
- **Redis required** — `brew services start redis` before running. Sidekiq connects to `redis://localhost:6379/0` by default.

## Deployment

- **Heroku app**: `turf-monster`
- **URL**: https://turf.mcritchie.studio
- **Database**: Heroku Postgres (essential-0)
- **Redis**: Heroku Redis mini (`redis-clear-09691`) — `REDIS_URL` set automatically
- **Deploy**: `git push heroku main` (then `heroku run bin/rails db:migrate --app turf-monster` if needed)
- **Env vars**: `RAILS_MASTER_KEY`, `RAILS_SERVE_STATIC_FILES`, `DATABASE_URL` (auto), `REDIS_URL` (auto), `SOLANA_ADMIN_KEY`, `SOLANA_RPC_URL`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`

## Tech Stack

- Ruby 3.1 / Rails 7.2 / PostgreSQL 14
- Tailwind CSS via `tailwindcss-rails` gem (compiled, not CDN)
- Alpine.js via CDN for interactivity
- ERB views, import maps, no JS frameworks
- Stimulus infrastructure ready (pinned, eager-loaded, no controllers yet)
- bcrypt + Google OAuth + Solana wallet auth (Phantom)
- **Sidekiq** + Redis for background jobs (web UI at `/admin/jobs`, admin-only)
- **Studio engine gem** — `gem "studio", git: "https://github.com/amcritchie/studio.git"`
- **SolanaStudio gem** — `gem "solana_studio", git: "https://github.com/amcritchie/solana_studio.git"`

## JS Modules (importmap)

- `solana_utils` — shared Solana/crypto utilities: `encodeBase58`, `lockedFetch`, `refreshBalance`, `refreshBalanceDelayed`, `CONFETTI_COLORS`. All attached to `window` for backward compatibility with inline scripts/onclick handlers. Single source of truth — do not duplicate these functions in views.

## Studio Engine

Shared code from [studio engine](https://github.com/amcritchie/studio). Configured in `config/initializers/studio.rb`.

**From the engine:** `Studio::ErrorHandling`, `ErrorLog` model, `Sluggable` concern, auth controllers, error log views, theme system.

**Overridden locally:** `sessions/new.html.erb`, `registrations/new.html.erb`, `sessions/_sso_continue.html.erb`, `omniauth_callbacks_controller.rb` (merge support), `layouts/_navbar.html.erb` (app-specific nav links, mobile sub-navbar with duplicate gear+moon fix).

**Routes:** `Studio.routes(self)` draws `/login`, `/signup`, `/logout`, `/sso_continue`, `/sso_login`, `/auth/:provider/callback`, `/error_logs`, `/admin/theme`.

**Updating:** After changes to the studio repo, run `bundle update studio` here.

## Architecture

- Money stored in cents, displayed in dollars via `dollars()` helper
- **5 selections per entry** — hardcoded in Entry model, Contest model, index view JS, cart slots partial. Search "< 5", "=== 5", "in 5", "Exactly 5" when changing.
- **Balance system**: `balance_cents` (real, withdrawable) + `promotional_cents` (bonus, non-withdrawable, used first). `deduct_funds!` uses promo first.
- **Slug-based foreign keys**: Teams, Games, Players use slug columns as FKs (e.g. `team_slug`, `home_team_slug`). Associations use `foreign_key: :*_slug, primary_key: :slug`.
- **Multiplier formula**: `1.0 + 3.0 * ln(rank) / ln(N)` — x1.0 at rank 1 to x4.0 at rank N. Centralized on `SlateMatchup.multiplier_for(rank, n)`.
- **Seeds system**: 60 seeds per entry on-chain. No DB columns. See `docs/SOLANA.md`.
- Entry slug includes `id` — requires `after_create` callback
- Every page shows JSON debug block of its primary record

## Models

- **User** — name, username, email (nullable), solana_address, wallet_type, balance_cents, promotional_cents, role, slug. See `docs/AUTH.md`.
- **Contest** — name, tagline, entry_fee_cents, status, max_entries, rank (priority for root page), slate association, onchain fields, slug
- **ContestMatchup** — team_slug, opponent_team_slug, rank, multiplier, status. Belongs to contest + teams via slug FKs.
- **Entry** — user + contest, score, status (cart/active/complete/abandoned), rank, payout_cents, onchain fields, slug (includes id)
- **Selection** — joins entry + contest_matchup (unique pair)
- **Team** — name, short_name, emoji, color_primary/secondary, slug
- **Game** — home_team + away_team via slug FKs, kickoff_at, status, scores, slug
- **Player** — name, position, jersey_number, team via slug FK, slug
- **Slate** — formula variables (7 nullable floats), 3-tier resolution. See `docs/FORMULAS.md`.
- **SlateMatchup** — team/opponent/game via slug FKs, rank, multiplier, scoring data. Formula class methods.
- **GeoSetting** — admin geofencing config
- **TransactionLog** — admin onchain transaction audit
- **ErrorLog** — polymorphic, from engine

## Error Logging

Every write action MUST use `rescue_and_log` with target/parent context. See top-level `CLAUDE.md` for full pattern docs.

- ContestsController: toggle_selection, enter, clear_picks → `target: entry, parent: @contest`. Grade, fill, lock, jump, reset, update → `target: @contest`.
- AccountsController: update, unlink_google, change_password → `target: current_user`

## Routes

### Public
- `/` — contests#world_cup (branded landing page, matchup grid from target contest)
- `/contests` — contests#index (all contests card grid)
- `/contests/:id` — contest show (leaderboard + admin actions)
- `/contests/:id/edit` — admin contest editor (name, tagline, status, rank)
- `/teams`, `/teams/:slug` — team index/show
- `/games` — games index
- `/faucet` — public faucet page (GET marketing, POST mint USDC)
- `/geo/check` — geo detection JSON (no auth)

### Contest Actions (POST)
- `toggle_selection`, `enter`, `clear_picks` — player actions
- `prepare_entry`, `confirm_onchain_entry` — Phantom onchain entry flow
- `prepare_onchain_contest`, `confirm_onchain_contest` — admin onchain contest creation
- `grade`, `fill`, `lock`, `jump`, `reset` — admin actions

### Account & Auth
- `/account` — profile, password, Google link/unlink. See `docs/AUTH.md`.
- `/auth/solana/nonce`, `/auth/solana/verify` — Phantom wallet auth
- `/wallet` — balance, deposit (quick/Stripe/MoonPay), withdraw, sync
- `/webhooks/stripe`, `/webhooks/moonpay` — payment webhooks (skip CSRF/auth)

### Admin
- `/slates/*` — formula editor. See `docs/FORMULAS.md`.
- `/admin/theme` — theme editor (from engine)
- `/admin/jobs` — Sidekiq dashboard (admin-only, mounted via route constraint)
- `/admin/geo` — geo settings
- `/admin/transactions/:slug/complete` — mark approved withdrawal as fiat-sent
- `/error_logs` — error log browser

## Seeds / World Cup Data

- 4 seeded users (password: "password"), Alex is admin
- 48 teams, 72 group stage matches, 85 players
- 3 matchday contests with rank 100/200/300 (seeds assign ranks idempotently)
- Seed is idempotent (`find_or_create_by!`) — safe to re-run
- See `docs/world_cup_2026.md` for format details

## Testing

### Rails Tests
- `bin/rails test` — **81 tests** total (minitest + fixtures)
- Test fixtures: 6 contest_matchups, 6 teams, 2 games
- Test password: `"password"` (min 6 chars)
- Test helper: `log_in_as(user)` defaults to password "password"

### Playwright E2E Tests
- `npm test` — 19 tests across 4 spec files
- `npm run test:headed` / `npm run test:ui` — visual modes
- Config: `playwright.config.js` — Chromium only, port 3001
- Seed: `e2e/seed.rb` — 2 users, 1 contest, 6 matchups (idempotent)
- Helper: `e2e/helpers.js` — `login(page, email, password)`
- **Dev server gotcha**: Local runs hit dev DB, not test seed

## Known Gotchas

- **Theme toggle store**: Engine refactored `Alpine.store('theme')` to an object with `toggle()` method and `isDark` getter. Toggle icons now use Heroicons v2.
- **Hold button guard**: Use `<%== %>` (raw output) in `<script>` tags, NOT `<%= %>` which HTML-escapes `>` to `&gt;`
- **Selection count = 5**: Hardcoded in multiple places — see Architecture section
- **Tailwind class compilation**: New utility classes won't compile unless already used elsewhere. Use inline `style` for one-offs.
- **Chart.js + Alpine.js**: Never store Chart.js instances as Alpine reactive properties (Proxy infinite loops). See `docs/FORMULAS.md`.
- **Cross-component Alpine**: Use global functions/variables instead of `$dispatch`/`$store` for shared state.

## Workflow

- **Debugging**: STOP and show the issue before fixing
- **Testing**: `bin/rails test` before every commit. Pre-commit hook enforces this.
- **Database**: Migrate and seed freely without asking
- **Server**: Restart proactively after gems/initializers/routes changes
- **Git**: Small frequent commits, push immediately after committing
- **UI**: Style as we build — make it look right the first time

## TODO

- [x] Google OAuth, Solana integration Phases 1-6, remove Ethereum, remove Over/Under, deploy Anchor
- [ ] Deposits & withdrawals — ON ICE. Code written (Stripe, MoonPay, vault withdraw, admin 3-step flow), not committed. See `memory/deposits-withdrawals.md` for resume checklist.
- [ ] Update TBD playoff teams once results are in (March 26-31, 2026)
- [ ] Test Phantom wallet auth end-to-end on Devnet
