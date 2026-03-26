# Turf Monster (turf_monster)

Peer-to-peer sports pick'em game focused on team-based over/under props for the World Cup.

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
- **eth gem native extensions**: Requires `secp256k1`, `automake`, `libtool` on build host. Heroku heroku-24 handles this.

## Tech Stack

- Ruby 3.1 / Rails 7.2 / PostgreSQL 14
- Tailwind CSS via `tailwindcss-rails` gem (compiled with `@apply` support, not CDN)
- Alpine.js via CDN for interactivity
- ethers.js v6 via CDN (wallet connect pages only, loaded via `content_for :head`)
- Montserrat font (Google Fonts CDN)
- ERB views, import maps, no JS frameworks
- bcrypt password auth + Google OAuth (OmniAuth) + Ethereum wallet auth (SIWE)
- `eth` gem (~> 0.5) for server-side signature verification
- **Studio engine gem** — `gem "studio", git: "https://github.com/amcritchie/studio.git"`

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
end
```

**From the engine:** `Studio::ErrorHandling` concern (in ApplicationController), `ErrorLog` model, `Sluggable` concern, auth controllers (sessions, registrations, omniauth_callbacks, error_logs), error log views, generic login/signup views (overridden by app-branded versions).

**Overridden locally:** `sessions/new.html.erb`, `registrations/new.html.erb` (branded with wallet connect), `omniauth_callbacks_controller.rb` (merge support when linking Google from /account).

**Routes:** `Studio.routes(self)` in `config/routes.rb` draws `/login`, `/signup`, `/logout`, `/sso_continue`, `/sso_login`, `/auth/:provider/callback`, `/auth/failure`, `/error_logs`.

**SSO Satellite Role:** This app receives one-way SSO from McRitchie Studio (the hub). Login page shows "Continue as [name]" button (from engine's `_sso_continue.html.erb` partial) when user is logged into Studio. `GET /sso_login` provides one-click SSO from the hub's nav link. Logout only clears this app's session. Wallet-only users (no email) cannot SSO. Hub logo at `public/studio-logo.svg`. Requires shared `SECRET_KEY_BASE`.

**Updating:** After changes to the studio repo, run `bundle update studio` here.

## Branding

- **Primary**: `#06D6A0` Mint — used for OVER, positive values, balances, CTAs, success states
- **Background**: `#1A1535` Deep Navy — body bg, card bg uses navy-400/navy-600
- **Accent**: `#8E82FE` Violet — O/U lines, scores, links, draft badges, wallet connect button
- **Text**: `#FFFFFF` White — headings, primary text
- **Negative**: Red (Tailwind default) — UNDER, losses
- **Font**: Montserrat (all weights 400-900)
- **Logo**: Two files exist — `/public/logo.png` (1.3MB, used in layout navbar) and `/public/logo.jpeg` (272KB, used in auth pages). Both are the green monster mascot. Should be consolidated to one file.
- Tailwind custom colors defined in layout: `mint`, `navy`, `violet` with full shade scales
- Status badges: mint=open, yellow=locked, gray=settled, violet=draft

## Architecture

- Money stored in cents, displayed in dollars
- Contest flow: draft -> open -> locked -> settled
- Picks use "more"/"less" internally (displayed as OVER/UNDER)
- Scoring: win=1, loss=0, push=0.5
- Ties split the pool evenly among all winners
- Every page shows JSON debug block of its primary record
- Every model has a `slug` column — human-readable identifier set via `Sluggable` concern (from studio engine) + `name_slug` method
- Entry slug includes `id` (needs `after_create` callback to re-set slug since `id` is nil during `before_save`)
- Cart pick slots extracted to `_cart_pick_slots` partial (shared between desktop sidebar and mobile bottom sheet)
- **Slug-based foreign keys**: Teams, Games, Players use slug columns as foreign keys (e.g. `team_slug`, `home_team_slug`) instead of integer IDs. Associations use `foreign_key: :*_slug, primary_key: :slug`.
- **Consolidated migrations**: 9 clean migrations (one per table) + 1 incremental (add admin to users). Fresh DB via `db:drop db:create db:migrate db:seed`.

## Authentication

Three auth methods, all optional — user needs at least one:

- **Email + password** — traditional signup/login via studio engine controllers
- **Google OAuth** — via OmniAuth, links to existing email users automatically
- **Ethereum wallet (SIWE)** — Sign-In with Ethereum, no smart contract needed

### User Model Auth Design

```ruby
has_secure_password validations: false  # wallet users have no password
validates :email, uniqueness: true, allow_nil: true
validates :wallet_address, uniqueness: true, allow_nil: true
validates :password, length: { minimum: 6 }, if: -> { password.present? }
validates :password, confirmation: true, if: -> { password_confirmation.present? }
validate :has_authentication_method  # must have email, wallet, or provider+uid
```

- `email` is **nullable** — wallet-only users have no email
- `wallet_address` is nullable, downcased before save, conditional unique index
- `password_digest` keeps `null: false, default: ""` (has_secure_password needs it)
- Predicate helpers: `wallet_connected?`, `google_connected?`, `has_password?`, `has_email?`
- `display_name` fallback chain: name → email prefix → truncated wallet → "anon"
- `truncated_wallet` — `"0x1234...abcd"` format
- `User.from_wallet(address)` — class method, finds by downcased address

### Wallet Auth Flow (SIWE)

1. Frontend: `walletConnect()` Alpine component checks for `window.ethereum`
2. Frontend: connects via `ethers.BrowserProvider`, gets signer + address
3. Frontend: fetches nonce from `GET /auth/wallet/nonce` (stored in session)
4. Frontend: constructs SIWE message, calls `signer.signMessage(message)`
5. Frontend: POSTs message + signature to `POST /auth/wallet/verify`
6. Backend: recovers signer via `Eth::Signature.personal_recover`, verifies address + nonce match
7. Backend: finds or creates user, calls `set_app_session`, returns redirect

### Account Management (`/account`)

- **AccountsController** — show, update, link_wallet, unlink_google, change_password
- **UserMergeable concern** — merges accounts when linking reveals overlap (lower ID survives)
- **OmniauthCallbacksController** (app override) — merge support when linking Google while logged in
- Merge transfers entries, sums balances, fills blank auth fields, updates ErrorLog references
- Wallet connect partial accepts `link_mode` local — POSTs to `/account/link_wallet` instead of verify

### Admin Authorization

- `admin` boolean column on User (default `false`, null: false)
- `admin?` predicate method on User model
- `require_admin` before_action in ApplicationController — redirects non-admins to root with alert
- Grade action on ContestsController is admin-gated (`before_action :require_admin, only: [:grade]`)
- Seed admin: `alex@mcritchie.studio`

### Passwords

- Minimum 6 characters (enforced in model validation)
- Seed/fixture password: `"password"` (not "pass" — too short for min 6 validation)

## Models

- **User** — name, email (nullable), wallet_address (nullable), balance_cents, provider, uid, password_digest, admin (boolean, default false), first_name, last_name, birth_date, birth_year, slug
- **Contest** — name, entry_fee_cents, status, max_entries, starts_at, slug
- **Prop** — belongs_to contest, team, opponent_team, game (all via slug FKs, optional). description, line, stat_type, result_value, status, team_slug, opponent_team_slug, game_slug, slug
- **Entry** — belongs_to user + contest (multiple entries allowed), score, status (cart/active/complete/abandoned), slug (includes id for uniqueness)
- **Pick** — belongs_to entry + prop (unique pair), selection (more/less), result, slug
- **Team** — name, short_name, location, emoji, color_primary, color_secondary, slug. Has many players, home_games, away_games.
- **Game** — belongs_to home_team + away_team (Team via slug FKs). kickoff_at, venue, status, home_score, away_score, slug.
- **Player** — belongs_to team (via slug FK, optional). name, position, jersey_number, slug.
- **ErrorLog** — polymorphic target + parent, message, inspect, backtrace (JSON), target_name, parent_name, slug

## Key Business Logic

- `Entry#toggle_pick!(prop, selection)` — find/destroy/update/create pick, destroy entry if empty, returns picks hash or nil
- `Entry#confirm!` — validates 3 picks, deducts entry fee, moves cart → active
- `Contest#grade!` — grades picks, scores entries, splits pool among winners, settles contest
- `Contest#clear_picks` — marks cart entry as `abandoned` (soft delete, entry preserved in DB but hidden from user)
- `Pick#compute_result` — compares result_value to line to determine win/loss/push
- `ErrorLog.capture!(exception)` (from studio engine) — structured error logging with cleaned backtrace. Target/parent set via ActiveRecord setters after creation.
- Users can enter a contest multiple times; UI focuses on the current cart entry
- Entry status flow: cart → active → complete (abandoned = soft-deleted cart, never shown)

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
- Browse errors at `/error_logs` (link in navbar) or console: `ErrorLog.order(created_at: :desc).limit(10)`
- **Layer 1 (automatic)**: `rescue_from StandardError` via `Studio::ErrorHandling` concern (included in `ApplicationController`). Logs via `create_error_log(exception)` (no context). `RecordNotFound` → 404, no logging. Re-raises in dev/test.
- **Layer 2 (required for writes)**: `rescue_and_log(target:, parent:)` wraps write actions. Logs via `create_error_log`, attaches target/parent via ActiveRecord setters. Sets `@_error_logged` flag. Pair with outer `rescue StandardError => e`.
- **Central method**: `create_error_log(exception)` → `ErrorLog.capture!(exception)` → returns record for context attachment
- **Auth + error log controllers**: Provided by studio engine. Do not recreate locally (except OmniauthCallbacksController, overridden for merge support).
- ContestsController: toggle_pick, enter, clear_picks wrapped with `target: entry, parent: @contest`. Grade wrapped with `target: @contest` (no entry/parent — operates on the contest itself).
- AccountsController: all 5 write actions (update, link_wallet, unlink_google, change_password) wrapped with `target: current_user`

## Seeds / World Cup Data

- 5 seeded users: 4 email users (password: "password") + 1 wallet-only user (vitalik.eth). Alex is seeded as admin.
- 48 teams seeded with real World Cup 2026 draw (42 confirmed + 6 TBD playoff placeholders)
- 72 group stage matches with real dates, kickoff times (ET/EDT), venues across 16 host cities
- 67 notable players across 21 teams
- Props wired to teams/games via slug columns (team_slug, opponent_team_slug, game_slug)
- TBD playoff teams: UEFA Playoff A/B/C/D (decided March 26-31, 2026), IC Playoff 1/2
- Seed is idempotent (`find_or_create_by!`) — safe to re-run

## UI

- Dark mode default (html class="dark"), navy background
- Mint = OVER/positive, Red = UNDER/negative, Violet = accents/lines/wallet button
- Status badges: mint=open, yellow=locked, gray=settled, violet=draft
- Cards: rounded-xl, shadow, hover:shadow-mint/10, border border-navy-300/20
- JSON blocks: bg-navy-800, text-mint, font-mono
- **Prop cards**: Show team emoji VS opponent emoji, team name, line, "Total Goals vs OPP". Opponent info shown everywhere: main grid, cart sidebar, mobile cart, leaderboard pills, grading section, prop show page.
- **Long-press button** (`_hold_button.html.erb`): reusable partial with three states — idle (violet), holding (`.process`, mint glow builds), success (`.success`, mint gradient + checkmark). Params: `default_text`, `hold_text`, `success_text`, `duration`, `hold_id`, `guard`, `on_success`.
- **Wallet connect** (`_wallet_connect.html.erb`): Alpine component with states: Connect Wallet → Connecting → Sign message → Verifying → redirect. Accepts `link_mode` local for /account use.
- **Navbar**: Username links to `/account`, shows truncated wallet address below name in gray monospace when wallet connected.
- **Account page** (`/account`): Four sections — Profile (name/email), Password (set/change), Google (link/unlink), Wallet (connect/display).

## Dev Mode

- Global `Alpine.store('devMode')` persisted to `localStorage`
- `<body x-data :class="{ 'dev-mode': $store.devMode }">` — adds `dev-mode` class to body when active
- **DEV toggle** in header nav bar — yellow badge when active, subtle dark button when off
- Debug tools hidden by default, visible when `.dev-mode` is on body:
  - **Nudge countdown ring**: small circular SVG on hold button showing seconds until next jiggle
- Future debug tools should use `.dev-mode` ancestor selector or `$store.devMode` in Alpine

## Routes

- `/` — contests#index (main dashboard)
- `/contests/:id` — contest show (leaderboard + grading)
- `/contests/:id/toggle_pick` — POST, toggle a pick on cart entry
- `/contests/:id/enter` — POST, confirm cart entry
- `/contests/:id/clear_picks` — POST, abandon cart entry
- `/contests/:id/grade` — POST, grade contest (admin only)
- `/teams` — teams index (clickable grid → show)
- `/teams/:slug` — team show (players, games, JSON debug)
- `/games` — games index
- `/props/:id` — prop show
- `/account` — GET account settings, PATCH update profile
- `/account/link_wallet` — POST, link wallet via SIWE signature
- `/account/unlink_google` — POST, unlink Google OAuth
- `/account/change_password` — POST, set or change password
- `/auth/wallet/nonce` — GET, generate wallet nonce (JSON)
- `/auth/wallet/verify` — POST, verify SIWE signature (JSON)
- `/error_logs` — error logs index (search, loading animation)
- `/error_logs/:slug` — error log detail

**Route name gotcha**: `resource :account` with member routes generates `link_wallet_account_path` (not `account_link_wallet_path`). The action name comes first.

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

- **Rails tests**: `bin/rails test` — 66 minitest tests with fixtures
- **Test password**: All fixtures use `"password"` (minimum 6 chars required)
- **Test helper**: `log_in_as(user)` defaults to password "password"
- **Wallet user fixture**: `wallet_user` — no email, has wallet_address
- **Known failure**: `ContestsControllerTest#test_enter_with_JSON_returns_error_when_no_cart_entry` — pre-existing, returns 302 instead of 422

## TODO

- [x] Set up Google OAuth credentials — `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` set in `.env` (local) and Heroku config vars (production). Redirect URIs: `http://localhost:3000/auth/google_oauth2/callback`, `http://localhost:3001/auth/google_oauth2/callback`, `https://app.mcritchie.studio/auth/google_oauth2/callback`, `https://turf.mcritchie.studio/auth/google_oauth2/callback`
- [ ] Update TBD playoff teams once results are in (March 26-31, 2026)
- [ ] Test wallet auth end-to-end with MetaMask

## Session Protocol

- **End-of-session refactoring**: When the user signals the end of a session, review and refactor ALL CLAUDE.md files in the project tree. Update them to reflect the current state of the project — remove outdated info, add new patterns discovered, document decisions made, and keep instructions accurate and concise. The user will be clear about when they are ending a session.
