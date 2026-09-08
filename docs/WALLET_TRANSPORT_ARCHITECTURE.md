# Wallet Transport Architecture

**Status:** Design — not yet implemented
**Written:** 2026-09-07
**Task:** https://mcritchie.studio/tasks/wallet-transport-architecture-doc
**Spans:** turf-monster · solana-studio · studio-engine

---

## The problem in one paragraph

`window.walletProvider` models exactly one way of reaching a wallet: an object
injected into the page. That is true of a desktop extension and of a wallet's own
in-app browser, and it is false of every ordinary mobile browser. On iOS Safari
and Android Chrome there is no injected provider, `detect()` returns `null`, and
every call site that does `provider.connect()` throws. The result is not a
degraded mobile experience — it is a **crash with a JavaScript error string in a
user-facing modal**, and it reaches every on-chain flow the app has.

This is not a bug in any one flow. It is a hole in the abstraction, and each
feature built on that abstraction falls through it in turn.

## How it presents

Reported 2026-09-07 from iPhone Safari on `turfmonster.media`, on a contest the
user was entering **with a free entry token**:

```
Preparing Transaction
null is not an object (evaluating 'provider.connect')
```

Confirmed in the LogRocket replay: four identical failures across two page loads
(so not a race), preceded by `Navigated to /auth/phantom/callback?…` — the user
had signed in successfully **through the Phantom deeplink** minutes earlier.

That pairing is the whole diagnosis. Sign-in took the redirect road. Entry tried
to take the injection road. Only one of the two roads is modelled.

## The two transports

| | Inline | Redirect |
|---|---|---|
| Where it works | Desktop extension, Wallet Standard, wallet in-app browser | iOS Safari, Android Chrome |
| Shape | `await provider.op()` resolves in the same page | The page is **destroyed**; the result returns on a callback URL |
| State lives in | JS closures | Must be serialized to survive navigation |
| Modelled today | ✅ `wallet_provider.js` | ❌ one-off, Phantom-only, outside the registry |

A promise cannot survive a navigation. That single fact is what the design has to
be built around; everything below follows from it.

## Current state

### What exists and works

- `app/javascript/wallet_provider.js` — `KeypairProvider`, `PhantomProvider`,
  Wallet Standard discovery (`_wsWallets`), and the `walletProvider` registry.
  `detect()` at `:427` is keypair → Phantom → first Wallet-Standard wallet → `null`.
- `solana-studio/app/views/solana_studio/_phantom_deeplink.html.erb` —
  `startPhantomDeepLink(linkMode, currentUserId)`. Generates an x25519 keypair,
  fetches a nonce, journals to `phantom_dl_*` in localStorage, redirects to
  `https://phantom.app/ul/v1/signIn`.
- `studio-engine/app/views/solana_sessions/phantom_callback.html.erb` — the
  return leg, 344 lines. Reads `phantom_dl_step` at `:149`, decrypts with
  `nacl.box.open.after` at `:205`, POSTs the verify.
- `window.nacl` — loaded from a **blocking, SRI-pinned** tag in
  `app/views/layouts/application.html.erb`. Deliberately not the async
  `deeplink_assets` loader, because the callback reads nacl at parse time.

### The three defects

1. **`startPhantomDeepLink` never enters the provider registry.** It is wired
   straight into the wallet picker. `detect()` cannot return it, so no flow
   except sign-in can use it.
2. **It implements `signIn` only.** There is no deeplink `signTransaction` or
   `signAndSendTransaction` anywhere in any of the three repos.
3. **It is Phantom-hardcoded**, down to the global's name. The picker's
   `canDeepLink` getter tests `typeof startPhantomDeepLink === 'function'`, and
   `showPhantomDeepLink` names Phantom in its identifier.

### A factual correction

`solana-studio/app/views/solana_studio/modals/_wallet_connect.html.erb:197-198`
states:

> *"Solflare and Backpack keep their install rows either way — there is no deep
> link for them, so the download page is still their only path."*

**This is false**, and it is why a Solflare or Backpack user on an iPhone is sent
to a **desktop extension download page** — a silent dead end, arguably worse than
Phantom's crash, which at least produces an error. Verified against vendor docs
2026-09-07; see the adapter table below.

---

## Design

### 1. Transport is a first-class property of a provider

```js
provider.transport  // 'inline' | 'redirect'
```

`detect()` stops returning `null` on mobile and returns the appropriate redirect
provider. Call sites stop needing to know what platform they are on.

### 2. Providers declare capabilities, and the UI gates on them

```js
provider.can('signTransaction')   // → true | false, for THIS wallet on THIS device
```

**This is the single most valuable rule in the document.** Tonight's crash
happened because a button rendered without anyone asking whether the wallet
behind it could do the thing. The Solflare download dead end has the same root
cause. Capability-gated rendering means an unsupported combination shows an
honest message instead of a button that throws — including for wallets that do
not exist yet.

Every entry point that leads to a signature owes this check before it paints.

### 3. Wallet operations become declarative intents with static handlers

The thing that cannot survive a redirect is the closure. So the resume handler
must be registered at page load, keyed by name:

```js
walletOps.define('contest_entry', {
  prepare:  async (ctx)               => { /* POST prepare_entry → { ptx_slug, tx } */ },
  complete: async (ctx, { signature }) => { /* POST confirm_entry */ }
});

// call site — identical on every platform and every wallet:
walletOps.run('contest_entry', { contestId, currency });
```

- **inline transport** — `run` executes prepare → sign → send → complete as one
  async function, exactly as the code does today.
- **redirect transport** — `run` executes prepare, journals the intent, and
  redirects. The callback page reads the journal, looks the op up **by name**,
  and calls `complete`.

Naming the handler statically is the one discipline this imposes on call sites,
and it is the price of surviving page destruction.

### 4. Only a slug crosses the redirect

The entry flow already creates a server-side prepared-transaction record
(`ptx_slug`, via `prepare_entry`, retired by `discard_prepared_entry`). So the
client never carries transaction bytes across the redirect — only a slug. The
journal stays small, non-sensitive, and cheap to validate server-side.

**This is the piece that makes the whole design tractable**, and it already
exists. It was built for blockhash freshness, not for this, but it is exactly the
right shape.

### 5. On mobile, `signAndSendTransaction` — not `signTransaction`

All three wallets expose a deeplink method that signs **and broadcasts**,
returning a signature. Using it deletes the client-side `sendRawTransaction` and
`pollConfirmation` steps entirely on mobile — fewer moving parts on the platform
where we have the least debugging reach.

### 6. The journal is a state machine, not a single-shot record

Only Phantom has `signIn` (connect + SIWS in one trip). Solflare and Backpack
must do `connect` **then** `signMessage` — two round trips, two app switches. And
every wallet needs an established encrypted session before it will sign anything,
so a lapsed session inserts a `connect` hop ahead of any transaction.

```
Phantom sign-in:    [signIn] → done
Solflare sign-in:   [connect] → [signMessage] → done
Backpack sign-in:   [connect] → [signMessage] → done
Any transaction:    [connect if no live session] → [signAndSendTransaction] → done
```

So today's `phantom_dl_*` keys generalize to `wallet_dl_*` carrying: the wallet
key, a **step cursor**, the persisted shared secret, the session token, and the
pending intent. The callback's dispatch at `phantom_callback.html.erb:149`
becomes a step-machine advance rather than a single `signIn` branch.

---

## Per-wallet adapters

All three share **one encryption core**: an x25519 keypair per session,
Diffie-Hellman shared secret, `dapp_encryption_public_key` out,
`<wallet>_encryption_public_key` back, payloads encrypted with nacl.box. Solflare's
documented scheme matches Phantom's architecture almost line for line.

Which means the crypto already in `_phantom_deeplink.html.erb` and
`phantom_callback.html.erb` **is not Phantom-specific** — it is the shared half of
all three protocols. An adapter is mostly a base URL and a method table.

| Wallet | Base URL | connect | signIn | signMessage | signTransaction | signAndSend | browse |
|---|---|---|---|---|---|---|---|
| Phantom | `phantom.app/ul/v1/` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Solflare | `solflare.com/ul/v1/` | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Backpack | `backpack.app/ul/v1/` | ✅ | ❌ | ✅ | ✅ | ✅ | ❓ |

Sources: [Phantom deeplinks](https://phantom.com/learn/blog/the-complete-guide-to-phantom-deeplinks) ·
[Solflare deeplinks](https://docs.solflare.com/solflare/technical/deeplinks) ·
[Solflare encryption](https://docs.solflare.com/solflare/technical/deeplinks/encryption) ·
[Backpack deeplinks](https://docs.backpack.app/)

**Verify during implementation**, do not trust this table alone: exact parameter
names per wallet, and whether Backpack ships `browse`. Vendor deeplink surfaces
change, and this table is a snapshot taken 2026-09-07.

---

## The three-tier mobile strategy

| Tier | Path | Covers | Work |
|---|---|---|---|
| 1 | Already inside a wallet's in-app browser → injected provider | **Every wallet** | None — works today |
| 2 | Redirect adapter (deeplink) | Phantom, Solflare, Backpack | The build |
| 3 | `browse` handoff — "Open in \<Wallet\>", which lands the user in tier 1 | Any wallet with a browse link | Small |

Tier 3 is the safety net. A wallet with no adapter still gets a working path by
being handed into its own browser, where the inline transport already works.

**Interim mitigation, available immediately:** guard `detect()` at the five
unguarded call sites and tell mobile users to open the page in their wallet's
browser. That is tier 1 by hand, needs no new architecture, and stops the crash
while tier 2 is built.

---

## Scope: which flows

Enumerated from every `connect` / `signTransaction` call site.

### Must work on all platforms

| Flow | Location |
|---|---|
| Contest entry — turf totals | `app/views/contests/_turf_totals_board.html.erb:1631` |
| Contest entry — world cup survivor | `app/views/contests/_world_cup_survivor_board.html.erb:142` |
| Create contest | `app/views/contests/new.html.erb:424` |
| Contest generator | `app/views/contests/generator.html.erb:94` |
| Username rename | `app/views/shared/_alpine_factories.html.erb:787` |
| Wallet export | `app/views/wallet_exports/show.html.erb:132` |
| Sign-in | `app/views/layouts/application.html.erb:244` — *mobile path exists, Phantom only* |

### Desktop-only is a legitimate answer

| Flow | Location |
|---|---|
| Vault init | `app/views/admin/vault_init/show.html.erb:160` |
| Vault state | `app/views/admin/vault_state/show.html.erb:207` |
| Lock / conclude contest | `app/javascript/lock_contest.js:37` |
| 2-of-3 cosign | `app/javascript/cosign.js:72` |

An admin signing a 2-of-3 vault operation from a phone is not a use case. These
declare `inline` only and render an honest "desktop required" message under the
same capability gate as everything else — which is the point: the rule handles
both the supported and the unsupported case with one mechanism.

`app/javascript/solana_stores.js:232` already guards correctly
(`!provider || !provider.connect`) and degrades cleanly. It needs no change.

---

## Cross-gem sequencing — the real risk

| Repo | Owns | Constraint |
|---|---|---|
| `turf-monster` | Call sites, the blocking SRI-pinned tweetnacl tag | Engine floor `~> 0.72` |
| `solana-studio` | `startPhantomDeepLink`, the wallet picker | Rails::Engine, joins the view lookup path |
| `studio-engine` | **The callback view** — step dispatch at `:149` | Where the resume contract lives |

The callback lives in the engine and the deeplink lives in solana-studio, so any
change to the resume contract must land in **both gems before turf-monster can
use it**, with a floor bump. The Gemfile's floor notes record several rounds of
silent failure from exactly this shape of drift.

**Freeze and version the journal format before anything ships.** A `wallet_dl_v`
field in the journal, checked by the callback, means an old callback meeting a new
journal fails loudly instead of decrypting garbage. That single field is the
cheapest insurance in the design.

---

## Phasing

| Phase | Work | Proves |
|---|---|---|
| **0** *(optional, ~1 day)* | Guard `detect()`; capability-gated messaging; tier-3 handoff copy | Stops the crash today |
| **1** | Encryption core + `walletOps` + all three adapters, wired to **contest entry only** | The transport abstraction, end to end, on the flow that is bleeding |
| **2** | Migrate the remaining five user-facing flows; admin flows get desktop-only messaging | Mobile parity |
| **3** *(optional)* | Android Mobile Wallet Adapter | Better Android UX — no page destruction |

Phase 1 covering all three wallets was chosen deliberately: they share the
encryption core, so adapters two and three are largely a base URL and a method
table, and it fixes the Solflare/Backpack mobile dead end in the same pass.

Android MWA is intent-based and does **not** destroy the page, so it is a strictly
nicer transport — but it is Android-only and a much heavier dependency. The
universal-link adapters cover iOS and Android on one code path, which is why they
come first.

---

## Open questions

1. Exact per-wallet parameter names — verify against each vendor's live docs at
   implementation time.
2. Does Backpack ship a `browse` method? Not listed on its provider-methods index.
3. Session lifetime per wallet — how long does a `connect` session stay valid
   before a transaction needs a fresh one? Drives how often mobile users eat the
   extra hop.
4. How many real users are affected? Searching LogRocket sessions for
   `provider.connect` gives the distinct-user count, which should size phase 1's
   urgency against the rest of the backlog.
