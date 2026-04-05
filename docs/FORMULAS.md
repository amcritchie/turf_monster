# Centralized Formulas & Slate System

## Formula Source of Truth (SlateMatchup Model)

All scoring/ranking formulas live as class methods on `SlateMatchup` — single source of truth. JS mirrors in `slates/show.html.erb` and `slates/formula_report.html.erb` with comments noting the model as authoritative.

- **Multiplier**: `SlateMatchup.multiplier_for(rank, n)` — `1.0 + 3.0 * Math.log(rank) / Math.log(n)`. Logarithmic curve, x1.0 at rank 1 to x4.0 at rank N.
- **DK Score**: `SlateMatchup.dk_score_for(line, over_odds)` — `max(0, (line - 0.5) + (prob - 0.5) * 3)` where prob is derived from American odds.
- **Goals Distribution**: `SlateMatchup.goals_distribution_for(rank, n)` — `0.2 + 4.3 * Math.log(n / rank) / Math.log(n)`.
- **Interactive DK Score** (show page sliders): `A * line^lineExp * prob^probExp` with defaults A=1.65, lineExp=1.24, probExp=1.18, where prob = 1/OverDecimalOdds.

## Formula Color System

Chart/formula visualization colors are defined once at the top of `slates/show.html.erb`:
- **CSS custom properties** (`--fc-mult`, `--fc-goals`, `--fc-dk-score`, `--fc-dk-total`, `--fc-dk-odds`) for inline styles
- **JS `FC` object** (`FC.mult`, `FC.goals`, `FC.dkScore`, `FC.dkTotal`, `FC.dkOdds`) for Chart.js datasets
- Colors: Multiplier = violet `#8E82FE`, Goals Distribution = light violet `#B8B0FF`, DK Score = dark green `#15803D`, DK Total = green `#4BAF50`, DK Odds = faint green `rgba`

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

## Slate Routes

- `/slates` — redirects to next upcoming slate (or most recent)
- `/slates/:id` — show (chart + sliders + rank list)
- `/slates/:id/update_rankings` — PATCH, save drag-reordered ranks + recalculated multipliers
- `/slates/:id/update_multipliers` — PATCH, save slider-computed multiplier values
- `/slates/:id/update_formula` — PATCH, save formula slider values to this slate
- `/slates/formula_report` — DK Score formula iterations page with comparison charts + playground
- `/slates/admin_formula` — GET, admin page for editing Default slate formula variables
- `/slates/update_admin_formula` — PATCH, save Default slate formula variables
