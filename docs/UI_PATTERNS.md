# UI Patterns & Branding

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

### Semantic Tokens (required)
- **Surfaces**: Use `bg-page`, `bg-surface`, `bg-surface-alt`, `bg-inset` — never hardcode `bg-navy-*`
- **Text**: Use `text-heading`, `text-body`, `text-secondary`, `text-muted` — never hardcode `text-white` for headings or `text-gray-*` for body text
- **Borders**: Use `border-subtle`, `border-strong` — never hardcode `border-navy-*`
- **CSS var naming**: `--color-cta` / `--color-cta-hover` for singular CTA color. Full `--color-primary-{50..900}` palette with RGB variants for Tailwind `primary-*` utilities.
- **Tailwind config**: `primary` palette is dynamic from shared studio config (CSS vars). `warning` palette defined locally in `config/tailwind.config.js`. Safelist includes `bg`, `text`, `border`, `ring` utilities for brand colors.

### Status Badges
mint=open, yellow=locked, gray=settled, violet=draft

## Button System

CSS component classes in `application.tailwind.css`:
- `.btn` (base), `.btn-primary` (green/white), `.btn-secondary` (violet/white), `.btn-outline` (border/transparent), `.btn-warning` (orange/white), `.btn-danger` (red), `.btn-google` (white/hardcoded gray-700 — uses `color: #374151` for dark mode compat)
- Size modifiers: `.btn-sm`, `.btn-lg`
- Disabled state built into `.btn` base
- Combine: `class="btn btn-primary btn-lg w-full"`

## Component Classes
`.card`, `.card-hover`, `.input-field`, `.empty-state`, `.json-debug`, `.label-upper`, `.badge`, `.matchup-selected`

## Matchup Grid

`_turf_totals_board.html.erb` — two sort modes toggled via Alpine (`sortMode`/`sortDir`):

- **Game view** (default): Paired cards with "vs" divider (`color-mix` background), sorted by lowest multiplier. Uses `_matchup_game_pair.html.erb` partial (locals: `left`, `right`, `locked`). Both-selected: outer `outline` + `box-shadow` glow in primary, "vs" div gets primary tint.
- **Multiplier view**: Flat grid (`grid-cols-2 md:grid-cols-4`) of individual cards sorted by multiplier. Uses `_matchup_card.html.erb` partial (local: `matchup`). Double-click "Multiplier" toggles asc/desc (arrow indicator). Two server-rendered orderings toggled via `x-show` (no JS re-sorting).
- Both views share the same Alpine `selections` state — selections persist across view switches.
- **Filter input**: Text input in the sort toolbar filters matchup cards by team name (both teams). Uses `matchesFilter()` Alpine method with `x-show` on wrapper divs. Clear X button appears when text is entered.

### Matchup Card Layout
Flag emoji (large, negative bottom margin) → Team name (bold, lg/xl) → "Goals vs OPP" (secondary text) → Multiplier (primary, xl/2xl, prefixed with "x", integers show without decimal). Auto-shrink JS for long team names.

### `.matchup-selected` class
Uses `outline` (not border) for selection highlight — avoids layout shift. Dynamic primary color via `rgb(var(--color-primary-rgb))`. Includes `box-shadow` glow. Double-selected game pairs use inline `outline` + `box-shadow` on the wrapper div.

## Cart
- **Cart slot cards** (`_turf_totals_cart_slots.html.erb`): Emoji + Team Name + "vs OPP" on first line, "Goals" + multiplier on second line.
- `pickOrder` array in Alpine state controls display order (insertion order)
- "Clear All" button clears selections locally + abandons entry server-side
- Blur overlay fires once per page load (`blurUsed` flag)

## Long-Press Button

`_hold_button.html.erb` — reusable partial with four states:
- **idle** (green) → **holding** (`.process`, mint glow builds) → **success** (`.success`, mint gradient + checkmark) or **error** (`.error`, red background)
- After hold completes, stays in `.process` for 500ms while resolving before transitioning to success or error
- Params: `default_text`, `hold_text`, `success_text`, `error_text`, `duration`, `hold_id`, `guard`, `on_success`, `validate`, `validate_at`
- The `on_success` callback sets the final state via `setHoldSuccess()` or `setHoldError()`
- Renders in both desktop + mobile cart (2 DOM elements, differentiated by `hold_id`)

### Hold Validation
Optional mid-hold validation via `validate`/`validate_at` params. `validate` is a JS expression returning `Promise<boolean>`, called at `validate_at` ms (default 1000). If false, hold aborts. Both buttons use `validate: "d.runHoldValidations()"` which checks geo-blocking (fresh `GET /geo/check`) then login status.

### Nudge Animation
JS-driven, big nudge at 3s then soft nudge every 10s. Resets on hold, soft-only after release.

## Pick Slot Animations
- `pick-pulse` (gentle glow, picks 3-4)
- `pick-pulse-shimmer` (glow + sweep, picks 2 and 5)
- `pick-pulse-urgent` (fast intense glow + scale + sweep, pick 5 after removal)
- `pickUrgent` flag set when going from 5→4 selections, cleared when reaching 5 again or clearing all

## Redirect Modal
When hold-to-confirm hits a blocker (geo-blocked, not logged in, insufficient funds), a centered modal appears with icon, title, message, progress bar countdown (5s), and CTA button. Hold button flips to red `.error` state ("Entry Blocked").
- Geo-blocked → "Location Restricted" → `/`
- Not logged in → "Log In Required" → `/login`
- Insufficient funds → "Insufficient Funds" / "Top Up Wallet" → `/wallet`
- `showRedirectModal(title, message, icon, url, seconds, cta)` method on Alpine component

## Navbar
Sticky, scroll-responsive. Full-width `sticky top-0 z-50 bg-page` with Alpine `scrolled` state (triggers at 20px). On scroll: logo shrinks `w-12→w-8`, title `text-3xl→text-xl`, padding `py-6→py-2`, adds `shadow-lg border-b border-subtle`. All transitions 300ms.

### Left side
Logo + brand, nav links (Join Contest, My Contests, Rules, Faucet), DEV toggle, Devnet badge, geo state badge.

### Right side — logged in: two-row block + avatar
- **Row 1 (Div 1)**: balance, gear dropdown, theme toggle, refresh button, username. Inline padding via `:style` (Tailwind `px-*` won't compile). Dev mode background via Alpine `:style`.
- **Row 2 (Div 2)**: Seeds progress bar with clip-path text color technique. Wallet address (left) + Level X (right). Green fill bar (`#4BAF50`, 14px height, 4px border-radius) animates via Alpine reading `seedsNavbar` localStorage. Text layers: muted color underneath, white on top with `clip-path: inset(0 X% 0 0)` revealing as bar fills. Level-up: bar fills 100% → Level bounces (`nav-level-pop` keyframe) → resets. Listens for `navbar-replay-level` and `navbar-seeds-update` window events.
- **Avatar**: `_avatar.html.erb` partial, outside the two-row block. Links to `/account`.
- Balance shows whole dollars only (no cents) — JS `refreshBalance` uses `Math.floor`, ERB uses `.to_i`.
- Username and balance link to `/account` and `/wallet` respectively.

### Right side — logged out
- Theme toggle + green "Log in" button, right-aligned in the `w-80` div.

## Leaderboard (Contest Show)
Selection badges are fixed-width (`w-28`), sorted by game kickoff time, showing multiplier (e.g., `x4`) before game completes and points (goals x multiplier) after. Badges float right with score rightmost (`min-width: 4.5rem`). Non-integer values show decimal portion in smaller font. Payout label (`$40.00`) appears on left (after player name) only before settling. Admin payout button says "Payout $X". After settling — paid rows get primary ring, divider line after last paid position, unpaid rows dimmed. Rank column shows actual rank (from entry.rank) when settled.

## Faucet Page (`/faucet`)
Public marketing page with hero, "How It Works" cards, and USDC claim form. Mints SPL USDC tokens directly to user's Phantom wallet via `Vault#mint_spl(to: wallet)`. Three view states: wallet connected (amount picker + claim), logged in no wallet (connect CTA), logged out (login/signup CTAs). Preset amounts $10/$50/$100/$500, custom input $1-$500.

## Solana Modal
`shared/_solana_modal.html.erb` — Alpine.js store (`Alpine.store('solanaModal')`) for onchain operation feedback. Three states: processing (spinner), success (checkmark + TX link + confetti), error (red icon + message). Uses `canvas-confetti` CDN library (`confetti.browser.min.js`) — `fireSuccessConfetti()` fires 4 bursts (center, left cannon, right cannon, delayed shower) on success state via `$watch`.

## Admin Dropdowns
- **Soccer dropdown** (`components/_soccer_dropdown.html.erb`): Soccer ball emoji trigger, links to Teams and Games pages.
- **Admin dropdown** (`components/_admin_dropdown.html.erb`): Gear icon, links to Theme, Slates, Formula, Formula Defaults, Error Logs, Replay Level (dispatches `navbar-replay-level` event), Reset Contest.

## Dev Mode
- Global `Alpine.store('devMode')` persisted to `localStorage`
- `<body>` gets `.dev-mode` class when active
- DEV toggle in header nav bar — yellow badge when active, subtle dark button when off
- Debug tools hidden by default, visible when `.dev-mode` is on body (e.g. nudge countdown ring)
- Future debug tools should use `.dev-mode` ancestor selector or `$store.devMode` in Alpine
- Seeds XP bar has a "Replay" link (left of Level badge) visible only in dev mode — triggers a simulated level-up animation

## Seeds XP Bar (`_slate_progress_xp.html.erb`)
- Progress bar showing seeds toward next level with animated fill, shimmer, and glow
- Bar fill uses 6px border-radius (not fully rounded)
- Level badge pops on level-up (3.2x scale bounce) with firework burst animation
- Firework: 72 particles explode radially from badge center using branding colors (green, violet, mint, orange, red)
- Level-up data stored in `localStorage('seedsLevelUp')` as JSON, consumed on next page load
- Sequence: fill bar to 100% → level pop + firework → reset bar → fill to new progress
- Dev mode "Replay" link simulates level-up for testing
- Contest show page saves seeds data to `seedsNavbar` localStorage for navbar bar
- Entry confirmation dispatches `navbar-seeds-update` custom event with seeds detail

## Login Page SSO
When SSO session available, blur overlay covers the entire card (`absolute inset-0 z-10, rounded-2xl`). The SSO "Continue as" button sits above the blur (`relative z-20`). Click-to-reveal fades out the blur (500ms transition) and focuses the email field. Inline `backdrop-filter` style (not Tailwind class — won't compile).

## Contest Show Layout
- Seeds progress bar and invite card rendered side-by-side on desktop (`display: flex; flex-wrap: wrap; flex: 1 1 300px`), stacked on mobile. Cards stretch to equal height via scoped `<style>` that strips `mb-6` and sets `height: 100%`.
- "+ Add Another Entry" button appears in the admin actions row (next to Lock Contest, Jump, Rank Matchups) rather than as a standalone section.
