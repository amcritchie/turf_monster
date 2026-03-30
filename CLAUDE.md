# Turf Monster (turf_monster)

Peer-to-peer sports pick'em game focused on team matchup selections with multipliers for the World Cup.

## Game Rules

- Each contest has a set of **matchups** — team/opponent pairs with multipliers based on rank
- Players select **5 matchups** per entry
- Each selection is scored: **team goals × multiplier**
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

### Admin Actions (contest show page + navbar)

- **Fill Contest** — generates random entries (5 random matchups each). Cycles through seeded users. Deduplicates against existing entries.
- **Lock Contest** — transitions open → locked
- **Jump** — simulates all game results and settles the contest in one click. Mint button on contest show page.
- **Grade Contest** — scores entries based on game results, assigns ranks, distributes payouts.
- **Reset** (navbar) — red button, clears all entries/selections, resets games to pending/scheduled, sets contest back to open. Has Turbo confirmation dialog.

### Key Model Methods

- `Contest#fill!(users:)` — random entries, 5 random matchups each, no duplicate combos
- `Contest#jump!` — simulate game results + grade in one transaction
- `Contest#grade!` — score entries → rank → distribute payouts → settle. Persists `rank` and `payout_cents` on each entry.
- `Contest#reset!` — destroy entries, reset game scores, reopen contest
- `Entry#confirm!` — validates exactly 5 selections, checks for locked games, deducts entry fee, cart → active

## Dev Server

- **Port 3001** — `bin/rails server -p 3001`
- McRitchie Studio runs on port 3000

## Deployment

- **Heroku app**: `turf-monster`
- **URL**: https://turf.mcritchie.studio
- **Heroku URL**: https://turf-monster-76a543809064.herokuapp.com/
- **Database**: Heroku Postgres (essential-0)
- **DNS**: Google Domains — `turf` CNAME → Heroku DNS target
- **Deploy**: `git push heroku main` (then `heroku run bin/rails db:migrate --app turf-monster` if new migrations)
- **Env vars**: `RAILS_MASTER_KEY`, `RAILS_SERVE_STATIC_FILES`, `DATABASE_URL` (auto from addon)
- **ACM**: Enabled (auto SSL via Let's Encrypt)

## Tech Stack

- Ruby 3.1 / Rails 7.2 / PostgreSQL 14
- Tailwind CSS via `tailwindcss-rails` gem (compiled with `@apply` support, not CDN)
- Alpine.js via CDN for interactivity
- Montserrat font (Google Fonts CDN)
- ERB views, import maps, no JS frameworks
- bcrypt password auth + Google OAuth (OmniAuth) + Solana wallet auth (Phantom)
- `ed25519` gem (~> 1.3) for Solana signature verification
- **Studio engine gem** — `gem "studio", git: "https://github.com/amcritchie/studio.git"`
- **Solana integration** — Devnet, JSON-RPC via `Solana::Client`, Anchor program (`turf_vault`)

## Studio Engine

Shared code lives in the [studio engine](https://github.com/amcritchie/studio). This app includes it via `config/initializers/studio.rb`:

```ruby
Studio.configure do |config|
  config.app_name = "Turf Monster"
  config.session_key = :turf_user_id
  config.welcome_message = ->(user) { "Welcome to Turf Monster, #{user.display_name}!" }
  config.registration_params = [:email, :password, :password_confirmation]
  config.configure_new_user = ->(user) { user.balance_cents = 0 }
  config.configure_sso_user = ->(user) { user.balance_cents = 0 }

  config.theme_logos = [
    { file: "favicon.png",   title: "Favicon" },
    { file: "logo.png",      title: "Navbar Logo" },
    { file: "logo.jpeg",     title: "Auth Logo" },
  ]
  config.theme_primary = "#4BAF50"
  config.theme_accent = "#8E82FE"
end
```

**From the engine:** `Studio::ErrorHandling` concern (in ApplicationController), `ErrorLog` model, `Sluggable` concern, auth controllers (sessions, registrations, omniauth_callbacks, error_logs), error log views, generic login/signup views (overridden by app-branded versions).

**Overridden locally:** `sessions/new.html.erb`, `registrations/new.html.erb`, `sessions/_sso_continue.html.erb` (branded "Easy sign in" header), `omniauth_callbacks_controller.rb` (merge support when linking Google from /account).

**Routes:** `Studio.routes(self)` in `config/routes.rb` draws `/login`, `/signup`, `/logout`, `/sso_continue`, `/sso_login`, `/auth/:provider/callback`, `/auth/failure`, `/error_logs`, `/admin/theme` (GET + PATCH), `/admin/theme/regenerate`.

**SSO Satellite Role:** This app receives one-way SSO from McRitchie Studio (the hub). Login page shows "Continue as [name]" button (from engine's `_sso_continue.html.erb` partial) when user is logged into Studio. `GET /sso_login` provides one-click SSO from the hub's nav link. Logout only clears this app's session. Wallet-only users (no email) cannot SSO. Hub logo at `public/studio-logo.svg`. Requires shared `SECRET_KEY_BASE`.

**Updating:** After changes to the studio repo, run `bundle update studio` here.

## Branding & Theme

- **Theme**: Dynamic — engine-generated CSS custom properties from 7 role colors (see top-level `CLAUDE.md` for full theme docs)
- **Theme config**: `theme_primary = "#4BAF50"` (green), `theme_accent = "#8E82FE"` (violet) in `studio.rb`
- **Admin theme page**: `/admin/theme` — color editor + styleguide (from engine)
- **Primary**: `#4BAF50` Green — brand text, CTAs, buttons, nav hovers, money displays, balances, checkmarks, hold button idle state
- **Mint**: `#06D6A0` — win badges, contest status (open), hold button success glow. Reserved for game mechanics (win), not general selection UI.
- **Accent**: `#8E82FE` Violet — scores, draft badges, `.btn-secondary`, Phantom wallet badge. NOT for CTA-intent elements (use `primary` instead). NOT for multipliers (use `primary`).
- **Primary for selection UI**: Selection count badges, cart slot borders, matchup selection rings/tints, multiplier values, links, sort toggle active state, and FAB buttons all use `primary` (green), not mint or violet.
- **Warning**: `#FF7C47` Orange — warning states, `.btn-warning`
- **Negative**: Red (Tailwind default) — losses
- **Font**: Montserrat (all weights 400-900)
- **Logo**: Two files exist — `/public/logo.png` (1.3MB, used in layout navbar) and `/public/logo.jpeg` (272KB, used in auth pages). Both are the green monster mascot. Should be consolidated to one file.
- **Surfaces**: Use `bg-page`, `bg-surface`, `bg-surface-alt`, `bg-inset` — never hardcode `bg-navy-*`
- **Text**: Use `text-heading`, `text-body`, `text-secondary`, `text-muted` — never hardcode `text-white` for headings or `text-gray-*` for body text
- **Borders**: Use `border-subtle`, `border-strong` — never hardcode `border-navy-*`
- **CSS var naming**: `--color-cta` / `--color-cta-hover` for singular CTA color. Full `--color-primary-{50..900}` palette with RGB variants for Tailwind `primary-*` utilities.
- **Tailwind config**: `primary` palette is dynamic from shared studio config (CSS vars). `warning` palette defined locally in `config/tailwind.config.js`. Safelist includes `bg`, `text`, `border`, `ring` utilities for brand colors.
- **`.matchup-selected` class**: Uses `outline` (not border) for selection highlight — avoids layout shift. Dynamic primary color via `rgb(var(--color-primary-rgb))`. Includes `box-shadow` glow. Double-selected game pairs use inline `outline` + `box-shadow` on the wrapper div.
- Status badges: mint=open, yellow=locked, gray=settled, violet=draft
- **Button system**: `.btn` base + `.btn-primary` (uses `--color-cta`, green), `.btn-secondary` (hardcoded violet), `.btn-outline` (hover uses `--color-cta`), `.btn-warning` (uses `--color-warning`), `.btn-danger` (uses `--color-danger`), `.btn-google` (white). Size: `.btn-sm`, `.btn-lg`. See top-level `CLAUDE.md` for full reference.

## Architecture

- Money stored in cents, displayed in dollars via `dollars()` helper (`ApplicationHelper#dollars` — `"$#{'%.2f' % amount}"`)
- `contest_badge_classes(status)` helper — maps contest status to Tailwind classes (extracted from views)
- Contest flow: draft → open → locked → settled
- **5 selections per entry** — confirm! validates exactly 5
- Scoring: team goals × multiplier per selection, summed across all 5
- Payouts: 1st-6th=$40 each, rank 1 gets $50 bonus. Ties split combined prize for spanned ranks.
- Every page shows JSON debug block of its primary record
- Every model has a `slug` column — human-readable identifier set via `Sluggable` concern (from studio engine) + `name_slug` method
- Entry slug includes `id` (needs `after_create` callback to re-set slug since `id` is nil during `before_save`)
- Cart selection slots extracted to `_turf_totals_cart_slots` partial (shared between desktop sidebar and mobile bottom sheet)
- **Slug-based foreign keys**: Teams, Games, Players use slug columns as foreign keys (e.g. `team_slug`, `home_team_slug`) instead of integer IDs. Associations use `foreign_key: :*_slug, primary_key: :slug`.
- **Consolidated migrations**: 9 clean migrations (one per table) + 2 incremental (add admin to users, add rank/payout to entries) + 3 Solana-related (solana fields on users, promotional_cents, onchain fields) + 1 drop migration (picks/props). Fresh DB via `db:drop db:create db:migrate db:seed`.
- **Balance system**: Users have `balance_cents` (real, onchain-backed, withdrawable) + `promotional_cents` (bonus, non-withdrawable, used first on deduction). `total_balance_cents` = sum of both. `deduct_funds!` uses promo first.
- **Multiplier formula**: `Math.sqrt(rank) * 0.5 + 0.5` — minimum x1, scales with rank. Integers display without decimal (x1 not x1.0).

## Authentication

Three auth methods, all optional — user needs at least one:

- **Email + password** — traditional signup/login via studio engine controllers
- **Google OAuth** — via OmniAuth, links to existing email users automatically
- **Solana wallet (Phantom)** — Ed25519 signature verification, `SolanaSessionsController`

### User Model Auth Design

```ruby
has_secure_password validations: false  # wallet users have no password
validates :email, uniqueness: true, allow_nil: true
validates :password, length: { minimum: 6 }, if: -> { password.present? }
validates :password, confirmation: true, if: -> { password_confirmation.present? }
validate :has_authentication_method  # must have email, solana_address, or provider+uid
```

- `email` is **nullable** — wallet-only users have no email
- `password_digest` keeps `null: false, default: ""` (has_secure_password needs it)
- Predicate helpers: `google_connected?`, `has_password?`, `has_email?`
- `display_name` fallback chain: name → email prefix → "anon"

### Account Management (`/account`)

- **AccountsController** — show, update, unlink_google, change_password
- **UserMergeable concern** — merges accounts when linking reveals overlap (lower ID survives)
- **OmniauthCallbacksController** (app override) — merge support when linking Google while logged in
- Merge transfers entries, sums balances, fills blank auth fields, updates ErrorLog references

### Admin Authorization

- `admin` boolean column on User (default `false`, null: false)
- `admin?` predicate method on User model
- `require_admin` before_action in ApplicationController — redirects non-admins to root with alert
- Admin-gated actions on ContestsController: `grade`, `fill`, `lock`, `jump`, `reset`
- Seed admin: `alex@mcritchie.studio`

### Passwords

- Minimum 6 characters (enforced in model validation)
- Seed/fixture password: `"password"` (not "pass" — too short for min 6 validation)

## Models

- **User** — name, email (nullable), solana_address (nullable), encrypted_solana_private_key, wallet_type (custodial/phantom/nil), balance_cents, promotional_cents, provider, uid, password_digest, admin (boolean, default false), first_name, last_name, birth_date, birth_year, slug
- **Contest** — name, entry_fee_cents, status, max_entries, contest_type, starts_at, onchain_contest_id, onchain_settled, onchain_tx_signature, slug. Has many contest_matchups, entries.
- **ContestMatchup** — belongs_to contest. team_slug, opponent_team_slug, rank, multiplier, status. Has many selections. Belongs_to team + opponent_team via slug FKs.
- **Entry** — belongs_to user + contest (multiple entries allowed), score, status (cart/active/complete/abandoned), rank, payout_cents, onchain_entry_id, onchain_tx_signature, entry_number, slug (includes id for uniqueness). Has many selections.
- **Selection** — belongs_to entry + contest_matchup (unique pair). Joins entries to matchups.
- **Team** — name, short_name, location, emoji, color_primary, color_secondary, slug. Has many players, home_games, away_games.
- **Game** — belongs_to home_team + away_team (Team via slug FKs). kickoff_at, venue, status, home_score, away_score, slug.
- **Player** — belongs_to team (via slug FK, optional). name, position, jersey_number, slug.
- **ErrorLog** — polymorphic target + parent, message, inspect, backtrace (JSON), target_name, parent_name, slug

## New Controller Checklist

See top-level `CLAUDE.md` for the full checklist. Quick summary:

1. Identify write actions (create, update, destroy, state transitions)
2. Wrap each with `rescue_and_log(target:, parent:)` + bang methods inside
3. Add outer `rescue StandardError => e` for response control
4. Ensure model has `to_param` returning `slug` if it appears in URLs
5. Read-only actions are covered by Layer 1 automatically

## Error Logging

Every write action MUST use `rescue_and_log` with target/parent context. See top-level `CLAUDE.md` for full pattern docs.

- All errors logged to `error_logs` table — DB only, no external services
- Browse errors at `/error_logs` (via admin gear dropdown in navbar) or console: `ErrorLog.order(created_at: :desc).limit(10)`
- **Layer 1 (automatic)**: `rescue_from StandardError` via `Studio::ErrorHandling` concern (included in `ApplicationController`). Logs via `create_error_log(exception)` (no context). `RecordNotFound` → 404, no logging. Re-raises in dev/test.
- **Layer 2 (required for writes)**: `rescue_and_log(target:, parent:)` wraps write actions. Logs via `create_error_log`, attaches target/parent via ActiveRecord setters. Sets `@_error_logged` flag. Pair with outer `rescue StandardError => e`.
- **Central method**: `create_error_log(exception)` → `ErrorLog.capture!(exception)` → returns record for context attachment
- **Auth + error log controllers**: Provided by studio engine. Do not recreate locally (except OmniauthCallbacksController, overridden for merge support).
- ContestsController: toggle_selection, enter, clear_picks wrapped with `target: entry, parent: @contest`. Grade, fill, lock, jump, reset wrapped with `target: @contest`.
- AccountsController: write actions (update, unlink_google, change_password) wrapped with `target: current_user`

## Seeds / World Cup Data

- 5 seeded users: 4 email users (password: "password") + 1 Solana wallet user. Alex is seeded as admin. Email users get promotional credits.
- 48 teams seeded with real World Cup 2026 draw (42 confirmed + 6 TBD playoff placeholders)
- 72 group stage matches with real dates, kickoff times (ET/EDT), venues across 16 host cities
- 67 notable players across 21 teams
- ContestMatchups wired to teams via slug columns (team_slug, opponent_team_slug)
- TBD playoff teams: UEFA Playoff A/B/C/D (decided March 26-31, 2026), IC Playoff 1/2
- Seed is idempotent (`find_or_create_by!`) — safe to re-run

## UI

- Dark/light mode toggle — dark is default, toggle in navbar. Uses semantic tokens (see Branding & Theme section)
- Mint = positive/win, Red = negative/losses, Violet = accents/scores
- Status badges: mint=open, yellow=locked, gray=settled, violet=draft
- Cards: `.card` class (bg-surface, border-subtle), `.card-hover` for interactive cards
- JSON blocks: `.json-debug` class (bg-inset, border-subtle), text-mint, font-mono
- **Button system**: CSS component classes in `application.tailwind.css` — `.btn` (base), `.btn-primary` (green/white), `.btn-secondary` (violet/white), `.btn-outline` (border/transparent), `.btn-warning` (orange/white), `.btn-danger` (red), `.btn-google` (white/gray). Size modifiers: `.btn-sm`, `.btn-lg`. Disabled state built into `.btn` base. Combine: `class="btn btn-primary btn-lg w-full"`. All buttons in views use these classes.
- **Matchup card layout**: Flag emoji (large, negative bottom margin) → Team name (bold, lg/xl) → "Goals vs OPP 🏳️" (secondary text) → Multiplier (primary, xl/2xl, prefixed with "x", integers show without decimal). Auto-shrink JS for long team names.
- **Matchup grid** (`_turf_totals_board.html.erb`): Two sort modes toggled via Alpine (`sortMode`/`sortDir`):
  - **Game view** (default): Paired cards with "vs" divider (`color-mix` background), sorted by lowest multiplier. Uses `_matchup_game_pair.html.erb` partial (locals: `left`, `right`, `locked`). Both-selected: outer `outline` + `box-shadow` glow in primary, "vs" div gets primary tint.
  - **Multiplier view**: Flat grid (`grid-cols-2 md:grid-cols-4`) of individual cards sorted by multiplier. Uses `_matchup_card.html.erb` partial (local: `matchup`). Double-click "Multiplier" toggles asc/desc (arrow indicator). Two server-rendered orderings toggled via `x-show` (no JS re-sorting).
  - Both views share the same Alpine `selections` state — selections persist across view switches.
- **Cart slot cards** (`_turf_totals_cart_slots.html.erb`): Emoji + Team Name + "vs OPP" on first line, "Goals" + multiplier on second line.
- **Long-press button** (`_hold_button.html.erb`): reusable partial with three states — idle (violet), holding (`.process`, mint glow builds), success (`.success`, mint gradient + checkmark). Params: `default_text`, `hold_text`, `success_text`, `duration`, `hold_id`, `guard`, `on_success`.
- **Solana wallet connect** (`_solana_wallet_connect.html.erb`): Phantom connect with ghost logo PNG (`/phantom-white.png`). Accepts `link_mode` local for /account use.
- **Login page SSO**: When SSO session available, shows "Easy sign in" button prominently. Fallback options blurred behind click-to-reveal overlay (inline `backdrop-filter` style, not Tailwind class — won't compile).
- **Navbar**: Logo + brand, My Contests (auth), Turf Totals, soccer ball dropdown (Teams/Games), admin gear dropdown (Theme/Error Logs), DEV toggle, admin Reset button. Right side: theme toggle, user info/auth. Username links to `/account`.
- **Soccer dropdown** (`components/_soccer_dropdown.html.erb`): App-local partial with soccer ball emoji trigger, links to Teams and Games pages. Alpine.js `x-data` with outside-click dismiss.
- **Admin dropdown** (`components/_admin_dropdown.html.erb`): Engine-provided gear icon partial, single "Theme" link to `/admin/theme` and "Error Logs" link to `/error_logs`.
- **Theme page** (`/admin/theme`): Engine-provided combined page — color editor with live preview at top, styleguide below (logos, semantic tokens, typography, buttons, components).
- **Account page** (`/account`): Three sections — Profile (name/email), Password (set/change), Google (link/unlink).
- **Leaderboard** (contest show): After settling — paid rows get mint left border + payout badge ($100.00 etc), divider line after last paid position, unpaid rows dimmed. Rank column shows actual rank (from entry.rank) when settled.
- **After confirming entry**: redirects to contest show page (leaderboard)

## Dev Mode

- Global `Alpine.store('devMode')` persisted to `localStorage`
- `<body x-data :class="{ 'dev-mode': $store.devMode }">` — adds `dev-mode` class to body when active
- **DEV toggle** in header nav bar — yellow badge when active, subtle dark button when off
- Debug tools hidden by default, visible when `.dev-mode` is on body:
  - **Nudge countdown ring**: small circular SVG on hold button showing seconds until next jiggle
- Future debug tools should use `.dev-mode` ancestor selector or `$store.devMode` in Alpine

## Routes

- `/` — contests#index (main dashboard, selection toggling, cart, hold-to-confirm)
- `/contests/:id` — contest show (leaderboard + admin actions)
- `/contests/:id/toggle_selection` — POST, toggle a matchup selection on cart entry
- `/contests/:id/enter` — POST, confirm cart entry → redirects to contest show
- `/contests/:id/clear_picks` — POST, abandon cart entry
- `/contests/:id/grade` — POST, grade contest (admin only)
- `/contests/:id/fill` — POST, fill contest with random entries (admin only)
- `/contests/:id/lock` — POST, lock contest (admin only)
- `/contests/:id/jump` — POST, simulate results + settle (admin only)
- `/contests/:id/reset` — POST, reset contest to open (admin only)
- `/teams` — teams index (clickable grid → show)
- `/teams/:slug` — team show (players, games, JSON debug)
- `/games` — games index
- `/account` — GET account settings, PATCH update profile
- `/account/unlink_google` — POST, unlink Google OAuth
- `/account/change_password` — POST, set or change password
- `/admin/theme` — theme editor + styleguide (engine-provided: color editor, logos, tokens, typography, buttons, components)
- `/wallet` — GET wallet/balance page
- `/wallet/deposit` — POST deposit funds
- `/wallet/withdraw` — POST withdraw funds
- `/wallet/faucet` — POST mint test USDC (Devnet only)
- `/wallet/sync` — GET sync onchain balance
- `/auth/solana/nonce` — GET, generate Solana nonce (JSON)
- `/auth/solana/verify` — POST, verify Phantom Ed25519 signature (JSON)
- `/error_logs` — error logs index (search, loading animation)
- `/error_logs/:slug` — error log detail

**Route name gotcha**: `resource :account` with member routes generates `unlink_google_account_path` (not `account_unlink_google_path`). The action name comes first.

## Solana Integration (Devnet)

"DeFi mullet" — Web2 UX front, Solana settlement back. Onchain methods are non-blocking (rescue + log errors) so app works without deployed program.

### Services (`app/services/solana/`)

- `Solana::Config` — program ID, RPC URL, mints, network
- `Solana::Client` — JSON-RPC HTTP wrapper (Net::HTTP), retry logic
- `Solana::Keypair` — Ed25519 key gen, encrypt/decrypt via Rails master key, sign, base58
- `Solana::Borsh` — minimal Borsh serialization
- `Solana::Transaction` — transaction builder, Anchor discriminators, PDA derivation
- `Solana::Vault` — high-level business logic (deposit, withdraw, enter, settle, sync)
- `Solana::Reconciler` — compare DB vs onchain balances, log discrepancies

### Anchor Program (`turf_vault/`)

Separate project at `/Users/alex/projects/turf_vault/`. PDAs: VaultState, UserAccount, Contest, ContestEntry. Instructions: initialize, create_user_account, deposit, withdraw, create_contest, enter_contest, settle_contest, close_contest.

**Deployment status**: Program built, awaiting sufficient Devnet SOL for deployment. Admin keypair: `9Fy8P3DvKBh3awt1wr27g4CDh47oDqmJR2FAAQ1bc69D`.

### Wallet Types

- **Custodial**: Server generates + encrypts Ed25519 keypair, signs transactions on behalf of user
- **Phantom**: User connects Phantom browser extension, signs transactions directly

### Rake Tasks

- `solana:init_vault` — initialize vault on Devnet
- `solana:airdrop` — airdrop SOL to admin
- `solana:check_balance` — read onchain balance
- `solana:faucet` — mint test USDC
- `solana:reconcile` — reconcile all user balances
- `solana:reconcile_contest` — reconcile specific contest

## Known Gotchas

- **Hold button guard**: The `_hold_button.html.erb` partial renders JS inside `<script>` tags. Guard expressions must use `<%== %>` (raw output), NOT `<%= %>`, because `<script>` tags don't decode HTML entities. `>=` gets escaped to `&gt;=` which breaks the entire script block. Use `===` in guards when possible, or `<%== %>` for raw output.
- **Selection count = 5**: Hardcoded in multiple places — `Entry#confirm!` (validation), `Contest#fill!` (combo generation), index view JS (`selectionCount === 5`), cart selection slots partial (`x-for="i in 5"`), mobile cart template. Search for "< 5", "=== 5", "in 5", "Exactly 5" when changing.
- **Tailwind class compilation**: `tailwindcss-rails` only compiles classes it finds in app views. Introducing a new utility (e.g. `bg-red-500`, `opacity-50`, `px-6`) on a single page won't work if no other view uses it. Fix: use classes already in use elsewhere, or use inline `style` for one-off values.

## Workflow Preferences

- **Debugging**: When hitting a bug, STOP — show the issue and ask before fixing. Document the root cause and decision in CLAUDE.md files for future reference.
- **Testing**: Write tests as we go alongside features. We move fast and break things — when tests fail, it may be a dead part of the app, so assess before fixing.
- **Database**: Migrate and seed freely without asking.
- **Server**: Restart Rails servers proactively whenever warranted (e.g. after adding gems, changing initializers, modifying routes). Do not ask — just restart.
- **Git**: Small frequent commits after each logical change. Always push immediately after committing.
- **UI**: Style as we build using the brand palette — make it look right the first time.
- **Decisions**: Present 2-3 options briefly with a recommendation for architectural choices.
- **Refactoring**: Proactively clean up code smells when spotted.

## Testing

### Rails Tests
- `bin/rails test` — minitest tests with fixtures
- **Test fixtures**: 6 contest_matchups (m1-m6), 6 teams (team-a through team-f), all on contest :one
- **Test password**: All fixtures use `"password"` (minimum 6 chars required)
- **Test helper**: `log_in_as(user)` defaults to password "password"

### Playwright E2E Tests
- `npm test` — runs all Playwright tests (19 tests across 3 spec files)
- `npm run test:headed` — runs with visible browser
- `npm run test:ui` — opens Playwright UI mode
- **Config**: `playwright.config.js` — Chromium only, port 3001, auto-starts test Rails server
- **Seed**: `e2e/seed.rb` — 2 users (alex@turf.com / sam@turf.com, password: "password"), 1 contest, 6 contest matchups. Idempotent via delete_all.
- **Helper**: `e2e/helpers.js` — `login(page, email, password)`
- **Spec files**: `e2e/smoke.spec.js` (core flows), `e2e/theme.spec.js` (dark/light toggle), `e2e/navigation.spec.js` (page loads)
- **Known failure**: "second entry after confirming" test — blur overlay + entry state interaction issue

## TODO

- [x] Set up Google OAuth credentials
- [x] Solana integration Phases 1-6 (program, services, wallet auth, deposit/withdraw, contest onchain, reconciliation)
- [x] Remove Ethereum wallet auth (eth gem, ethers.js CDN, wallet_sessions_controller)
- [x] Remove Over/Under game mode (picks, props) — Turf Totals only
- [ ] Deploy Anchor program to Devnet (need ~0.67 more SOL for deployment)
- [ ] Update TBD playoff teams once results are in (March 26-31, 2026)
- [ ] Test Phantom wallet auth end-to-end on Devnet

## Session Protocol

- **End-of-session refactoring**: When the user signals the end of a session, review and refactor ALL CLAUDE.md files in the project tree. Update them to reflect the current state of the project — remove outdated info, add new patterns discovered, document decisions made, and keep instructions accurate and concise. The user will be clear about when they are ending a session.
