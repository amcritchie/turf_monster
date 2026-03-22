# Turf Monster (turf_monster)

Peer-to-peer sports pick'em game focused on team-based over/under props for the World Cup.

## Tech Stack

- Ruby 3.1 / Rails 7.2 / PostgreSQL 14
- Tailwind CSS via CDN (no build step)
- Alpine.js via CDN for interactivity
- Montserrat font (Google Fonts CDN)
- ERB views, import maps, no JS frameworks
- No authentication, no background jobs, no external APIs

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

## Models

- **User** — name, email, balance_cents
- **Contest** — name, entry_fee_cents, status, max_entries, starts_at
- **Prop** — belongs_to contest, description, line, stat_type, result_value, status
- **Entry** — belongs_to user + contest (unique pair), score, status
- **Pick** — belongs_to entry + prop (unique pair), selection (more/less), result

## Key Business Logic

- `Contest#enter!(user, picks_params)` — validates and creates entry + picks in transaction
- `Contest#grade!` — grades picks, scores entries, splits pool among winners, settles contest
- `Pick#compute_result` — compares result_value to line to determine win/loss/push

## UI

- Dark mode default (html class="dark"), navy background
- Mint = OVER/positive, Red = UNDER/negative, Violet = accents/lines
- Status badges: mint=open, yellow=locked, gray=settled, violet=draft
- Cards: rounded-xl, shadow, hover:shadow-mint/10, border border-navy-300/20
- JSON blocks: bg-navy-800, text-mint, font-mono

## Session Protocol

- **End-of-session refactoring**: When the user signals the end of a session, review and refactor ALL CLAUDE.md files in the project tree. Update them to reflect the current state of the project — remove outdated info, add new patterns discovered, document decisions made, and keep instructions accurate and concise. The user will be clear about when they are ending a session.
