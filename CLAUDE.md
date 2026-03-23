# Turf Monster (turf_monster)

Peer-to-peer sports pick'em game focused on team-based over/under props for the World Cup.

## Tech Stack

- Ruby 3.1 / Rails 7.2 / PostgreSQL 14
- Tailwind CSS via CDN (no build step)
- Alpine.js via CDN for interactivity
- Montserrat font (Google Fonts CDN)
- ERB views, import maps, no JS frameworks
- bcrypt password auth + Google OAuth (OmniAuth)
- Playwright for UI smoke tests (standalone Node.js, no build step)

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
- Every model has a `slug` column — human-readable identifier set via `Sluggable` concern + `name_slug` method
- Cart pick slots extracted to `_cart_pick_slots` partial (shared between desktop sidebar and mobile bottom sheet)

## Models

- **User** — name, email, balance_cents, slug
- **Contest** — name, entry_fee_cents, status, max_entries, starts_at, slug
- **Prop** — belongs_to contest, description, line, stat_type, result_value, status, slug
- **Entry** — belongs_to user + contest (unique pair), score, status, slug
- **Pick** — belongs_to entry + prop (unique pair), selection (more/less), result, slug
- **ErrorLog** — polymorphic target + parent, message, inspect, backtrace (JSON), target_name, parent_name, slug

## Key Business Logic

- `Entry#toggle_pick!(prop, selection)` — find/destroy/update/create pick, destroy entry if empty, returns picks hash or nil
- `Entry#confirm!` — validates 3 picks, deducts entry fee, moves cart → active
- `Contest#grade!` — grades picks, scores entries, splits pool among winners, settles contest
- `Pick#compute_result` — compares result_value to line to determine win/loss/push
- `ErrorLog.capture!(exception, target:, parent:)` — structured error logging with cleaned backtrace and human-readable slugs
- Entry status flow: cart → active → complete

## Error Logging

- All errors logged to `error_logs` table via `ErrorLog.capture!` — DB only, no external services
- Cleaned backtrace (app frames only via `Rails.backtrace_cleaner`)
- Polymorphic `target` (the record that errored) and `parent` (broader context) with human-readable `_name` fields from slugs
- Browse errors in Rails console: `ErrorLog.order(created_at: :desc).limit(10)`
- Auto-prune old logs eventually

## UI

- Dark mode default (html class="dark"), navy background
- Mint = OVER/positive, Red = UNDER/negative, Violet = accents/lines
- Status badges: mint=open, yellow=locked, gray=settled, violet=draft
- Cards: rounded-xl, shadow, hover:shadow-mint/10, border border-navy-300/20
- JSON blocks: bg-navy-800, text-mint, font-mono

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
- **Playwright smoke tests**: `npx playwright test` — 8 UI tests, auto-starts Rails on port 3001
  - Config: `playwright.config.js`, tests in `e2e/`, seed data in `e2e/seed.rb`
  - Covers: index load, login, pick toggling, cart persistence, confirm button, contest show
  - `npx playwright test --ui` for interactive debugging
- Playwright runs against the test DB; `e2e/seed.rb` creates users (alex/sam@turf.com, password: "pass"), 1 open contest, 4 props

## TODO

- [ ] Set up Google OAuth credentials (console.cloud.google.com) — create OAuth client ID, configure consent screen, set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` env vars, add redirect URI `http://localhost:3000/auth/google_oauth2/callback`

## Session Protocol

- **End-of-session refactoring**: When the user signals the end of a session, review and refactor ALL CLAUDE.md files in the project tree. Update them to reflect the current state of the project — remove outdated info, add new patterns discovered, document decisions made, and keep instructions accurate and concise. The user will be clear about when they are ending a session.
