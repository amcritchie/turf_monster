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

## Tech Stack

- Ruby 3.1 / Rails 7.2 / PostgreSQL 14
- Tailwind CSS via CDN (no build step)
- Alpine.js via CDN for interactivity
- Montserrat font (Google Fonts CDN)
- ERB views, import maps, no JS frameworks
- bcrypt password auth + Google OAuth (OmniAuth)
- Playwright for UI smoke tests (standalone Node.js, no build step)
- **Studio engine gem** — `gem "studio", git: "https://github.com/amcritchie/studio.git"`

## Studio Engine

Shared code lives in the [studio engine](https://github.com/amcritchie/studio). This app includes it via `config/initializers/studio.rb`:

```ruby
Studio.configure do |config|
  config.app_name = "Turf Monster"
  config.welcome_message = ->(user) { "Welcome to Turf Monster, #{user.display_name}!" }
  config.registration_params = [:email, :password, :password_confirmation]
  config.configure_new_user = ->(user) { user.balance_cents = 0 }
end
```

**From the engine:** `Studio::ErrorHandling` concern (in ApplicationController), `ErrorLog` model, `Sluggable` concern, auth controllers (sessions, registrations, omniauth_callbacks, error_logs), error log views, generic login/signup views (overridden by app-branded versions).

**Overridden locally:** `sessions/new.html.erb` and `registrations/new.html.erb` (mint-branded with logo).

**Routes:** `Studio.routes(self)` in `config/routes.rb` draws `/login`, `/signup`, `/logout`, `/auth/:provider/callback`, `/auth/failure`, `/error_logs`.

**Updating:** After changes to the studio repo, run `bundle update studio` here.

## Branding

- **Primary**: `#06D6A0` Mint — used for OVER, positive values, balances, CTAs, success states
- **Background**: `#1A1535` Deep Navy — body bg, card bg uses navy-400/navy-600
- **Accent**: `#8E82FE` Violet — O/U lines, scores, links, draft badges, Grade button
- **Text**: `#FFFFFF` White — headings, primary text
- **Negative**: Red (Tailwind default) — UNDER, losses
- **Font**: Montserrat (all weights 400-900)
- **Logo**: `/public/logo.jpeg` — green monster mascot, shown in header at 48px rounded
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

## Models

- **User** — name, email, balance_cents, slug
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
- **Auth + error log controllers**: Provided by studio engine. Do not recreate locally.
- ContestsController: all 4 write actions (toggle_pick, enter, clear_picks, grade) wrapped with `target: entry, parent: @contest`
- **Error logs UI**: Search with ILIKE (message, target_name, parent_name, target_type), Esc to clear, 500ms minimum loading animation, backtrace first frame in index, target_name badge. Show page has copyable `Model.find_by(id: X)` commands for target/parent.
- **Turbo prefetching gotcha**: Turbo 8+ prefetches links on hover. Test raises on show actions will fire for hovered-over links, not just clicked ones. This only affects test raises — normal pages don't error on prefetch.
- Auto-prune old logs eventually

## Seeds / World Cup Data

- 48 teams seeded with real World Cup 2026 draw (42 confirmed + 6 TBD playoff placeholders)
- 72 group stage matches with real dates, kickoff times (ET/EDT), venues across 16 host cities
- 67 notable players across 21 teams
- Props wired to teams/games via slug columns (team_slug, opponent_team_slug, game_slug)
- TBD playoff teams: UEFA Playoff A/B/C/D (decided March 26-31, 2026), IC Playoff 1/2
- Seed is idempotent (`find_or_create_by!`) — safe to re-run

## UI

- Dark mode default (html class="dark"), navy background
- Mint = OVER/positive, Red = UNDER/negative, Violet = accents/lines
- Status badges: mint=open, yellow=locked, gray=settled, violet=draft
- Cards: rounded-xl, shadow, hover:shadow-mint/10, border border-navy-300/20
- JSON blocks: bg-navy-800, text-mint, font-mono
- **Prop cards**: Show team emoji VS opponent emoji, team name, line, "Total Goals vs OPP". Opponent info shown everywhere: main grid, cart sidebar, mobile cart, leaderboard pills, grading section, prop show page.
- **Long-press button** (`_hold_button.html.erb`): reusable partial with three states — idle (violet), holding (`.process`, mint glow builds), success (`.success`, mint gradient + checkmark). Params: `default_text`, `hold_text`, `success_text`, `duration`, `hold_id`, `guard`, `on_success`.
- **Nudge animation**: JS-driven cycle. Big nudge (scale 1.06, ±2deg) fires 3s after button appears. Soft nudge (scale 1.03, ±1deg) repeats every 10s after. Hold start resets the cycle; hold release restarts with soft-only 10s cycle. Nudge suppressed during `.process` and `.success` states.
- **Clear All button**: In both desktop sidebar and mobile cart. Clears local picks and marks cart entry as `abandoned` server-side via `POST /contests/:id/clear_picks`.
- **Blur overlay**: fires once per page load when 3 picks selected (`blurUsed` flag prevents repeat)
- **Pick order**: `pickOrder` array in Alpine state tracks insertion order; `pickSlots` renders from it. Server-rendered initial state uses `picks.order(:created_at)`.
- Alpine state pattern: optimistic UI updates with server sync rollback (restore both `picks` and `pickOrder` on error)

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
- `/contests/:id/grade` — POST, grade contest
- `/teams` — teams index (clickable grid → show)
- `/teams/:slug` — team show (players, games, JSON debug)
- `/games` — games index
- `/props/:id` — prop show
- `/error_logs` — error logs index (search, loading animation)
- `/error_logs/:slug` — error log detail (backtrace, target/parent with copy-to-clipboard console commands, JSON)

## Workflow Preferences

- **Debugging**: When hitting a bug, STOP — show the issue and ask before fixing. Document the root cause and decision in CLAUDE.md files for future reference.
- **Testing**: Write tests as we go alongside features. We move fast and break things — when tests fail, it may be a dead part of the app, so assess before fixing.
- **Database**: Migrate and seed freely without asking.
- **Git**: Small frequent commits after each logical change. Always push immediately after committing.
- **UI**: Style as we build using the brand palette — make it look right the first time.
- **Decisions**: Present 2-3 options briefly with a recommendation for architectural choices.
- **Refactoring**: Proactively clean up code smells when spotted.

## Testing

- **Rails tests**: `bin/rails test` — 48 minitest tests with fixtures
- **Playwright smoke tests**: `npx playwright test` — 9 UI tests, auto-starts Rails on port 3001
  - Config: `playwright.config.js`, tests in `e2e/`, seed data in `e2e/seed.rb`
  - Covers: index load, login, pick toggling, cart persistence, confirm button, second entry after confirm, contest show
  - `npx playwright test --ui` for interactive debugging
- Playwright runs against the test DB; `e2e/seed.rb` creates users (alex/sam@turf.com, password: "pass"), 1 open contest, 4 props

## TODO

- [ ] Set up Google OAuth credentials (console.cloud.google.com) — create OAuth client ID, configure consent screen, set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` env vars, add redirect URI `http://localhost:3000/auth/google_oauth2/callback`
- [ ] Update TBD playoff teams once results are in (March 26-31, 2026)

## Session Protocol

- **End-of-session refactoring**: When the user signals the end of a session, review and refactor ALL CLAUDE.md files in the project tree. Update them to reflect the current state of the project — remove outdated info, add new patterns discovered, document decisions made, and keep instructions accurate and concise. The user will be clear about when they are ending a session.
