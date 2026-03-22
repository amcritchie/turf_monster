# Turf Picks (turf_monster)

Peer-to-peer sports pick'em game focused on team-based over/under props for the World Cup.

## Tech Stack

- Ruby 3.1 / Rails 7.2 / PostgreSQL 14
- Tailwind CSS via CDN (no build step)
- Alpine.js via CDN for interactivity
- ERB views, import maps, no JS frameworks
- No authentication, no background jobs, no external APIs

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

- Dark mode default (html class="dark")
- Green = OVER/positive, Red = UNDER/negative
- Status badges: green=open, yellow=locked, gray=settled, blue=draft
- Cards: rounded-xl, shadow, hover transitions

## Session Protocol

- **End-of-session refactoring**: When the user signals the end of a session, review and refactor ALL CLAUDE.md files in the project tree. Update them to reflect the current state of the project — remove outdated info, add new patterns discovered, document decisions made, and keep instructions accurate and concise. The user will be clear about when they are ending a session.
