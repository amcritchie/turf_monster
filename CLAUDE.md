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
  config.registration_params = [:email, :password, :password_confirmation, :username]
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
- **Consolidated migrations**: 9 clean migrations (one per table) + 2 incremental (add admin to users, add rank/payout to entries) + 3 Solana-related (solana fields on users, promotional_cents, onchain fields) + 1 drop migration (picks/props) + 1 role migration (replace admin boolean with role string) + 1 username migration. Fresh DB via `db:drop db:create db:migrate db:seed`.
- **Balance system**: Users have `balance_cents` (real, onchain-backed, withdrawable) + `promotional_cents` (bonus, non-withdrawable, used first on deduction). `total_balance_cents` = sum of both. `deduct_funds!` uses promo first.
- **Multiplier formula**: `1.0 + 3.0 * ln(rank) / ln(N)` — logarithmic curve, x1.0 at rank 1 to x4.0 at rank N. Integers display without decimal (x1 not x1.0). Centralized on `SlateMatchup.multiplier_for(rank, n)` — see "Centralized Formulas" section below.

## Authentication

Three auth methods, all optional — user needs at least one:

- **Email + password** — traditional signup/login via studio engine controllers
- **Google OAuth** — via OmniAuth, links to existing email users automatically
- **Solana wallet (Phantom)** — Ed25519 signature verification, `SolanaSessionsController`

### User Model Auth Design

```ruby
has_secure_password validations: false  # wallet users have no password
has_one_attached :avatar
validates :email, uniqueness: true, allow_nil: true
validates :username, uniqueness: { case_sensitive: false }, allow_nil: true
validates :username, length: { in: 3..30 }, format: { with: /\A[a-zA-Z0-9_]+\z/ }, allow_nil: true
validates :password, length: { minimum: 6 }, if: -> { password.present? }
validates :password, confirmation: true, if: -> { password_confirmation.present? }
validate :has_authentication_method  # must have email, solana_address, or provider+uid
```

- `email` is **nullable** — wallet-only users have no email
- `username` — 3-30 chars, alphanumeric + underscore, case-insensitive uniqueness, nullable
- `password_digest` keeps `null: false, default: ""` (has_secure_password needs it)
- Predicate helpers: `google_connected?`, `has_password?`, `has_email?`, `profile_complete?` (username present)
- `display_name` fallback chain: username → name → email prefix → truncated_solana → "anon"
- `has_one_attached :avatar` — user profile avatar via Active Storage
- `profile_complete?` — returns `username.present?`, used by `require_profile_completion` before_action
- `require_profile_completion` in ApplicationController — redirects incomplete profiles to `/account/complete_profile` (skips auth routes, API, account completion itself)

### Account Management (`/account`)

- **AccountsController** — show, update, unlink_google, change_password, complete_profile, save_profile
- **Complete Profile page** (`/account/complete_profile`) — shown when `profile_complete?` is false. Collects username (+ optional avatar). `save_profile` action saves and redirects back to original destination.
- **UserMergeable concern** — merges accounts when linking reveals overlap (lower ID survives)
- **OmniauthCallbacksController** (app override) — merge support when linking Google while logged in. Uses `rescue ActiveRecord::RecordNotUnique` in `from_omniauth` to handle race conditions on concurrent OAuth callbacks.
- Merge transfers entries, sums balances, fills blank auth fields, updates ErrorLog references

### Admin Authorization

- `role` string column on User (default `"viewer"`)
- `admin?` predicate: `role == "admin"`
- `require_admin` before_action in ApplicationController — redirects non-admins to root with alert
- Admin-gated actions on ContestsController: `grade`, `fill`, `lock`, `jump`, `reset`
- Seed admin: `alex@mcritchie.studio` (role: "admin")

### Solana Auth Security

- **Nonce replay prevention**: Solana nonces include timestamp, enforced 5-minute expiry window. Nonce is deleted from session before verification (delete-before-verify pattern) to prevent replay attacks.

### Passwords

- Minimum 6 characters (enforced in model validation)
- Seed/fixture password: `"password"` (not "pass" — too short for min 6 validation)

## Centralized Formulas (SlateMatchup Model)

All scoring/ranking formulas live as class methods on `SlateMatchup` — single source of truth. JS mirrors in `slates/show.html.erb` and `slates/formula_report.html.erb` with comments noting the model as authoritative.

- **Multiplier**: `SlateMatchup.multiplier_for(rank, n)` — `1.0 + 3.0 * Math.log(rank) / Math.log(n)`. Logarithmic curve, x1.0 at rank 1 to x4.0 at rank N.
- **DK Score**: `SlateMatchup.dk_score_for(line, over_odds)` — `max(0, (line - 0.5) + (prob - 0.5) * 3)` where prob is derived from American odds.
- **Goals Distribution**: `SlateMatchup.goals_distribution_for(rank, n)` — `0.2 + 4.3 * Math.log(n / rank) / Math.log(n)`.
- **Interactive DK Score** (show page sliders): `A * line^lineExp * prob^probExp` with defaults A=1.65, lineExp=1.24, probExp=1.18, where prob = 1/OverDecimalOdds.

### Formula Color System

Chart/formula visualization colors are defined once at the top of `slates/show.html.erb`:
- **CSS custom properties** (`--fc-mult`, `--fc-goals`, `--fc-dk-score`, `--fc-dk-total`, `--fc-dk-odds`) for inline styles
- **JS `FC` object** (`FC.mult`, `FC.goals`, `FC.dkScore`, `FC.dkTotal`, `FC.dkOdds`) for Chart.js datasets
- Colors: Multiplier = violet `#8E82FE`, Goals Distribution = light violet `#B8B0FF`, DK Score = dark green `#15803D`, DK Total = green `#4BAF50`, DK Odds = faint green `rgba`

## Models

- **User** — name, username (nullable, unique case-insensitive), email (nullable), solana_address (nullable), encrypted_solana_private_key, wallet_type (custodial/phantom/nil), balance_cents, promotional_cents, provider, uid, password_digest, role (string, default "viewer"), first_name, last_name, birth_date, birth_year, slug. `has_one_attached :avatar`.
- **Contest** — name, entry_fee_cents, status, max_entries, contest_type, starts_at, onchain_contest_id, onchain_settled, onchain_tx_signature, slug. Has many contest_matchups, entries.
- **ContestMatchup** — belongs_to contest. team_slug, opponent_team_slug, rank, multiplier, status. Has many selections. Belongs_to team + opponent_team via slug FKs.
- **Entry** — belongs_to user + contest (multiple entries allowed), score, status (cart/active/complete/abandoned), rank, payout_cents, onchain_entry_id, onchain_tx_signature, entry_number, slug (includes id for uniqueness). Has many selections.
- **Selection** — belongs_to entry + contest_matchup (unique pair). Joins entries to matchups.
- **Team** — name, short_name, location, emoji, color_primary, color_secondary, slug. Has many players, home_games, away_games.
- **Game** — belongs_to home_team + away_team (Team via slug FKs). kickoff_at, venue, status, home_score, away_score, slug.
- **Player** — belongs_to team (via slug FK, optional). name, position, jersey_number, slug.
- **Slate** — name, starts_at, status, slug, formula_a/line_exp/prob_exp/mult_base/mult_scale/goal_base/goal_scale (all nullable floats). Has many slate_matchups, contests. `FORMULA_DEFAULTS` constant, `default_record` class method, `resolved_formula` instance method (3-tier resolution). "Default" slate is a config record for global formula defaults.
- **SlateMatchup** — belongs_to slate, team (slug FK), opponent_team (slug FK), game (slug FK). rank, multiplier, status, expected_team_total, team_total_over_odds, over_decimal_odds. Has many selections. Class methods: `multiplier_for`, `dk_score_for`, `goals_distribution_for`.
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
  - **Filter input**: Text input in the sort toolbar filters matchup cards by team name (both teams). Uses `matchesFilter()` Alpine method with `x-show` on wrapper divs. Clear X button appears when text is entered.
- **Cart slot cards** (`_turf_totals_cart_slots.html.erb`): Emoji + Team Name + "vs OPP" on first line, "Goals" + multiplier on second line.
- **Long-press button** (`_hold_button.html.erb`): reusable partial with four states — idle (green), holding (`.process`, mint glow builds), success (`.success`, mint gradient + checkmark), error (`.error`, red background). After hold completes, stays in `.process` for 500ms while resolving before transitioning to success or error. Params: `default_text`, `hold_text`, `success_text`, `error_text`, `duration`, `hold_id`, `guard`, `on_success`, `validate`, `validate_at`. The `on_success` callback is responsible for setting the final state via `setHoldSuccess()` or `setHoldError()`.
- **Hold validation** (`validate`/`validate_at` params): Optional mid-hold validation. `validate` is a JS expression returning `Promise<boolean>`, called at `validate_at` ms (default 1000) during the hold. If the promise resolves `false`, the hold aborts (clears completion timer, snaps progress circle back). The validate function is responsible for setting error state (via `setHoldError()`) and showing a modal. Both desktop and mobile hold buttons use `validate: "d.runHoldValidations()"` which checks geo-blocking (fresh `GET /geo/check`) then login status. Network errors on geo check are swallowed (don't block the user).
- **Solana wallet connect** (`_solana_wallet_connect.html.erb`): Phantom connect with ghost logo PNG (`/phantom-white.png`). Accepts `link_mode` local for /account use.
- **Solana modal** (`shared/_solana_modal.html.erb`): Alpine.js store component (`Alpine.store('solanaModal')`) for onchain operation feedback. Three states: processing (spinner), success (checkmark + TX signature link to Solana Explorer), error (red icon + message). Triggered by `showProcessing()`, `showSuccess(txSignature)`, `showError(message)` methods.
- **Login page SSO**: When SSO session available, shows "Easy sign in" button prominently. Fallback options blurred behind click-to-reveal overlay (inline `backdrop-filter` style, not Tailwind class — won't compile).
- **Navbar**: Sticky, scroll-responsive. Full-width `sticky top-0 z-50 bg-page` with Alpine `scrolled` state (triggers at 20px). On scroll: logo shrinks `w-12→w-8`, title `text-3xl→text-xl`, padding `py-6→py-2`, adds `shadow-lg border-b border-subtle`. All transitions 300ms. Content: Logo + brand, My Contests (auth), Rules, Faucet (devnet only, yellow text), DEV toggle, admin gear dropdown, theme toggle. Right side: user info/auth. Username links to `/account`. Balance links to `/wallet` — shows user's Phantom wallet USDC on devnet, DB balance otherwise.
- **Soccer dropdown** (`components/_soccer_dropdown.html.erb`): App-local partial with soccer ball emoji trigger, links to Teams and Games pages. Alpine.js `x-data` with outside-click dismiss.
- **Admin dropdown** (`components/_admin_dropdown.html.erb`): Gear icon partial with links to Theme (`/admin/theme`), Slates (`/slates`), Formula (`/slates/formula_report`), Error Logs (`/error_logs`).
- **Theme page** (`/admin/theme`): Engine-provided combined page — color editor with live preview at top, styleguide below (logos, semantic tokens, typography, buttons, components).
- **Account page** (`/account`): Three sections — Profile (name/email), Password (set/change), Google (link/unlink). Solana Wallet section shows connected Phantom address + onchain SOL/USDC/USDT balances.
- **Faucet page** (`/faucet`): Public marketing page with hero, "How It Works" cards, and USDC claim form. Mints SPL USDC tokens directly to user's Phantom wallet via `Vault#mint_spl(to: wallet)`. Claim button uses `fetch()` + Solana modal (spinner → success with TX link → error). Controller returns JSON (`{ success, tx, amount }` or `{ success: false, error }`). Three view states: wallet connected (amount picker + claim), logged in no wallet (connect CTA), logged out (login/signup CTAs). Preset amounts $10/$50/$100/$500, custom input $1-$500. Recent claims feed as social proof.
- **Leaderboard** (contest show): After settling — paid rows get mint left border + payout badge ($100.00 etc), divider line after last paid position, unpaid rows dimmed. Rank column shows actual rank (from entry.rank) when settled.
- **Redirect modal**: When hold-to-confirm hits a blocker (geo-blocked, not logged in, insufficient funds), a centered modal appears with icon, title, message, progress bar countdown (5s), and CTA button. Hold button flips to red `.error` state ("Entry Blocked"). Geo-blocked → "Location Restricted" → `/`. Not logged in → "Log In Required" → `/login`. Insufficient funds → "Insufficient Funds" / "Top Up Wallet" → `/wallet`. `showRedirectModal(title, message, icon, url, seconds, cta)` method on Alpine component.
- **Pick slot animations**: `pick-pulse` (gentle glow, picks 3-4), `pick-pulse-shimmer` (glow + sweep, picks 2 and 5), `pick-pulse-urgent` (fast intense glow + scale + sweep, pick 5 after a selection is removed). `pickUrgent` flag set when going from 5→4 selections, cleared when reaching 5 again or clearing all.
- **After confirming entry**: redirects to contest show page (leaderboard)

## Slate Show Page (`/slates/:id`)

Admin-only interactive page for tuning multiplier formulas. Key sections:

1. **Slate tabs** — navigate between slates (shown when multiple exist)
2. **Multiplier Formula chart** — Chart.js line chart with 5 datasets (Multiplier, Goals Distribution, DK Total Score, DK Total, DK Total Odds). Updates live as sliders change.
3. **Formula variable sliders** — 7 interactive Alpine.js sliders (A, lineExp, probExp, multBase, multScale, goalBase, goalScale) grouped into formula variable cards with colored left accent bars and math notation.
4. **Ranking list** — sortable table of all slate matchups. Score/Multiplier columns update dynamically when sliders change. Drag-to-reorder via SortableJS library.
5. **Save buttons** — "Save Rankings" (persists rank order + computed multipliers), "Save Multipliers" (persists arbitrary slider-computed values), and "Save Formula" (persists current slider values to this slate's DB columns). All appear at top and bottom of the rank list.

### Chart.js + Alpine.js Proxy Avoidance Pattern (Critical)

Chart.js instances **must not** be stored as Alpine reactive properties. Alpine wraps objects in ES6 Proxies, which triggers infinite re-render loops when Chart.js reads/writes its internal state. Solution: store Chart.js instances and shared state as plain globals outside Alpine:

```javascript
var _fcChart = null;       // Chart.js instance
var _fcLastData = null;    // last dataset snapshot
var _fcSliders = {};       // current slider values
```

Alpine components read/write these globals directly. Never use `this.chart` or `$data.chart` for Chart.js objects.

### Cross-Component Communication Pattern

Two Alpine components on the slate show page (`formulaCurves` for the chart/sliders, `rankManager` for the ranking list) communicate via global functions:

- `_fcUpdateRankList(sliders)` — called by `formulaCurves` when sliders change, updates rank list scores
- `_fcSliders` — global object holding current slider values, readable by `rankManager` for save

This avoids Alpine `$dispatch`/`$store` complexity for components that need to share computed state.

### Persisted Formula Variables

7 nullable float columns on `slates`: `formula_a`, `formula_line_exp`, `formula_prob_exp`, `formula_mult_base`, `formula_mult_scale`, `formula_goal_base`, `formula_goal_scale`. Resolution chain (3-tier, like ThemeSetting):

1. **Slate column** — per-slate override (nullable)
2. **Default slate record** — `Slate.find_by(name: "Default")` — global defaults
3. **Hardcoded constant** — `Slate::FORMULA_DEFAULTS`

`Slate#resolved_formula` returns a hash with resolved values. Sliders on the show page initialize from this. "Save Formula" button persists current slider values to the slate. "Default" slate is a config record (filtered out of index/tabs via `where.not(name: "Default")`).

**Admin Formula Defaults page** (`/slates/admin_formula`) — number inputs for editing the Default slate's formula variables. Linked from admin dropdown.

### Slate Routes

- `/slates` — redirects to next upcoming slate (or most recent)
- `/slates/:id` — show (chart + sliders + rank list)
- `/slates/:id/update_rankings` — PATCH, save drag-reordered ranks + recalculated multipliers
- `/slates/:id/update_multipliers` — PATCH, save slider-computed multiplier values
- `/slates/:id/update_formula` — PATCH, save formula slider values to this slate
- `/slates/formula_report` — DK Score formula iterations page with comparison charts + playground
- `/slates/admin_formula` — GET, admin page for editing Default slate formula variables
- `/slates/update_admin_formula` — PATCH, save Default slate formula variables

### Admin Dropdown

The admin gear dropdown (`components/_admin_dropdown.html.erb`) includes links to: Theme (`/admin/theme`), Slates (`/slates`), Formula (`/slates/formula_report`), Formula Defaults (`/slates/admin_formula`), Error Logs (`/error_logs`).

## Dev Mode

- Global `Alpine.store('devMode')` persisted to `localStorage`
- `<body x-data :class="{ 'dev-mode': $store.devMode }">` — adds `dev-mode` class to body when active
- **DEV toggle** in header nav bar — yellow badge when active, subtle dark button when off
- Debug tools hidden by default, visible when `.dev-mode` is on body:
  - **Nudge countdown ring**: small circular SVG on hold button showing seconds until next jiggle
- Future debug tools should use `.dev-mode` ancestor selector or `$store.devMode` in Alpine

## Routes

- `/` — contests#index (main dashboard, selection toggling, cart, hold-to-confirm). Shows first contest (ordered by `created_at: :asc`).
- `/contests/:id` — contest show (leaderboard + admin actions)
- `/contests/:id/toggle_selection` — POST, toggle a matchup selection on cart entry
- `/contests/:id/enter` — POST, confirm cart entry → redirects to contest show
- `/contests/:id/clear_picks` — POST, abandon cart entry
- `/contests/:id/grade` — POST, grade contest (admin only)
- `/contests/:id/fill` — POST, fill contest with random entries (admin only)
- `/contests/:id/lock` — POST, lock contest (admin only)
- `/contests/:id/jump` — POST, simulate results + settle (admin only)
- `/contests/:id/reset` — POST, reset contest to open (admin only)
- `/slates` — slates#index (redirects to next upcoming or most recent slate)
- `/slates/:id` — slate show (formula chart, sliders, drag-to-reorder ranking list)
- `/slates/:id/update_rankings` — PATCH, save rank order + recalculated multipliers (admin only)
- `/slates/:id/update_multipliers` — PATCH, save slider-computed multipliers (admin only)
- `/slates/:id/update_formula` — PATCH, save formula slider values to this slate (admin only)
- `/slates/formula_report` — DK Score formula iterations + playground (admin only)
- `/slates/admin_formula` — GET, edit Default slate formula variables (admin only)
- `/slates/update_admin_formula` — PATCH, save Default slate formula variables (admin only)
- `/teams` — teams index (clickable grid → show)
- `/teams/:slug` — team show (players, games, JSON debug)
- `/games` — games index
- `/account` — GET account settings, PATCH update profile
- `/account/complete_profile` — GET, complete profile page (username + avatar, shown when `profile_complete?` is false)
- `/account/save_profile` — POST, save profile completion form
- `/account/unlink_google` — POST, unlink Google OAuth
- `/account/change_password` — POST, set or change password
- `/admin/theme` — theme editor + styleguide (engine-provided: color editor, logos, tokens, typography, buttons, components)
- `/faucet` — GET, public faucet page (marketing + claim UI). POST, mint SPL USDC to user's Phantom wallet (requires login + connected wallet)
- `/wallet` — GET wallet/balance page
- `/wallet/deposit` — POST deposit funds
- `/wallet/withdraw` — POST withdraw funds
- `/wallet/faucet` — POST mint test USDC to DB balance (Devnet only, legacy — prefer `/faucet`)
- `/wallet/sync` — GET sync onchain balance
- `/auth/solana/nonce` — GET, generate Solana nonce (JSON)
- `/auth/solana/verify` — POST, verify Phantom Ed25519 signature (JSON)
- `/geo/check` — GET, fresh geo detection JSON (public, no auth required). Returns `{ state, blocked }`. Used by hold validation.
- `/admin/geo` — GET, geo settings admin page (admin only)
- `/admin/geo` — PATCH, update geo settings (admin only)
- `/admin/geo/toggle` — POST, toggle WA geo override (admin only)
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

Separate project at `/Users/alex/projects/turf_vault/`. PDAs: VaultState, UserAccount, Contest, ContestEntry. Instructions: initialize, create_user_account, deposit, withdraw, create_contest, enter_contest, settle_contest, close_contest, force_close_vault.

**Deployment status**: v0.2.0 deployed to devnet. Vault initialized with dual admin + test SPL mints.
- Program ID: `7Hy8GmJWPMdt6bx3VG4BLFnpNX9TBwkPt87W6bkHgr2J`
- Vault PDA: `7z313HTVNcxhvCBkkDQv794RpXeRrfCLb5WJ4dFAQQeh`
- Admin (primary): Alex Bot — `F6f8h5yynbnkgWvU5abQx3RJxJpe8EoQmeFBuNKdKzhZ`
- Admin (backup): Alex Human — `7ZDJp7FUHhuceAqcW9CHe81hCiaMTjgWAXfprBM59Tcr`
- IDL Account: `DCP2XRu8ZwzsCpXBgu5xa4vTYdYQhKUZRU49iJuFv8Lf`
- USDC Mint: `222Dcu2RgAXE3T8A4mGSG3kQyXaNjqePx7vva1RdWBN9`
- USDT Mint: `9mxkN8KaVA8FFgDE2LEsn2UbYLPG8Xg9bf4V9MYYi8Ne`

### Navbar Balance

`display_balance` helper shows the logged-in user's Phantom wallet USDC balance on devnet (cached 60s), falling back to DB `total_balance_dollars` for non-wallet users or non-devnet. The `/admin/usdc_balance` JSON endpoint (used by `refreshBalance()` JS) follows the same logic. Both use `fetch_user_usdc` → `Vault#fetch_wallet_balances(current_user.solana_address)`.

**Balance refresh system**: `refreshBalance()` fetches `/admin/usdc_balance` and updates all `[data-balance-display]` elements. `refreshBalanceDelayed(ms)` waits (default 10s) then calls `refreshBalance()` — spins the navbar refresh icon (`[data-balance-refresh]`) during the wait as a visual cue. Called automatically after Solana operations (faucet, create_onchain, payout). Manual refresh button (circular arrows icon) next to the balance in navbar (desktop + mobile).

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
- **Chart.js + Alpine.js proxy conflict**: Never store Chart.js instances as Alpine reactive properties. Alpine wraps objects in ES6 Proxies which causes infinite re-render loops with Chart.js internals. Store Chart.js instances as plain `var` globals (e.g. `var _fcChart = null`) outside Alpine components. See Slate Show Page section for full pattern.
- **Cross-component Alpine communication**: When two Alpine components need shared state, use global functions/variables instead of `$dispatch`/`$store`. Example: `_fcUpdateRankList(sliders)` lets the formula chart component push updates to the rank manager component.

## Workflow Preferences

- **Debugging**: When hitting a bug, STOP — show the issue and ask before fixing. Document the root cause and decision in CLAUDE.md files for future reference.
- **Testing**: Write tests as we go alongside features. We move fast and break things — when tests fail, it may be a dead part of the app, so assess before fixing. **Always run `bin/rails test` before committing** — if tests fail, fix the issues before creating the commit. A pre-commit hook enforces this automatically, but proactively run tests after completing changes rather than waiting for the hook to catch failures.
- **Database**: Migrate and seed freely without asking.
- **Server**: Restart Rails servers proactively whenever warranted (e.g. after adding gems, changing initializers, modifying routes). Do not ask — just restart.
- **Git**: Small frequent commits after each logical change. Always push immediately after committing. Run `bin/rails test` before every commit — fix failures before committing.
- **UI**: Style as we build using the brand palette — make it look right the first time.
- **Decisions**: Present 2-3 options briefly with a recommendation for architectural choices.
- **Refactoring**: Proactively clean up code smells when spotted.

## Testing

### Rails Tests
- `bin/rails test` — minitest tests with fixtures, **67 tests** total
- **Test fixtures**: 6 contest_matchups (m1-m6), 6 teams (team-a through team-f), 2 games (past_game, future_game), all on contest :one
- **Test password**: All fixtures use `"password"` (minimum 6 chars required)
- **Test helper**: `log_in_as(user)` defaults to password "password"

### Playwright E2E Tests
- `npm test` — runs all Playwright tests (19 tests across 3 spec files)
- `npm run test:headed` — runs with visible browser
- `npm run test:ui` — opens Playwright UI mode
- **Config**: `playwright.config.js` — Chromium only, port 3001, auto-starts test Rails server
- **Seed**: `e2e/seed.rb` — 2 users (alex@turf.com / sam@turf.com, password: "password"), 1 contest, 6 contest matchups. Idempotent via delete_all.
- **Helper**: `e2e/helpers.js` — `login(page, email, password)`
- **Spec files**: `e2e/smoke.spec.js` (core flows), `e2e/theme.spec.js` (dark/light toggle), `e2e/navigation.spec.js` (page loads), `e2e/geo_hold_validation.spec.js` (geo blocking + hold validation)
- **Dev server gotcha**: Playwright `reuseExistingServer: !process.env.CI` means local runs hit the dev server (port 3001) with dev DB users (`alex@mcritchie.studio`), not the test seed users (`alex@turf.com`). The `geo_hold_validation.spec.js` uses dev credentials directly.
- **Known failure**: "second entry after confirming" test — blur overlay + entry state interaction issue

## TODO

- [x] Set up Google OAuth credentials
- [x] Solana integration Phases 1-6 (program, services, wallet auth, deposit/withdraw, contest onchain, reconciliation)
- [x] Remove Ethereum wallet auth (eth gem, ethers.js CDN, wallet_sessions_controller)
- [x] Remove Over/Under game mode (picks, props) — Turf Totals only
- [x] Deploy Anchor program to Devnet + initialize vault
- [ ] Update TBD playoff teams once results are in (March 26-31, 2026)
- [ ] Test Phantom wallet auth end-to-end on Devnet

## Session Protocol

- **End-of-session refactoring**: When the user signals the end of a session, review and refactor ALL CLAUDE.md files in the project tree. Update them to reflect the current state of the project — remove outdated info, add new patterns discovered, document decisions made, and keep instructions accurate and concise. The user will be clear about when they are ending a session.
