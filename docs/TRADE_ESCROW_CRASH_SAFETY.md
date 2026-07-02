# Trade Escrow — Crash Safety (research + recommended design)

Research-backed design notes for hardening `TradeService`'s escrow against a server crash
mid-pending-trade. Feeds the flagged task "Persist trade escrow to DataStore (crash recovery)".

## Build it TEMPLATE-side (generic, reusable) — not a TradeService bolt-on
This crash-safe, exactly-once pattern is generic infrastructure, so it belongs on the **template**
side of the repo (reusable by any game built on it), with trading as the *first consumer*:

- **`src/Shared/Game/TransactionJournal.lua`** (pure, game-agnostic) — the state machine + pure
  reconciliation: given a set of persisted holds + their states + a processed-set, decide which
  holds to re-credit on load. Headless spec covers pending/committed/cleared transitions,
  idempotency (no double-credit), and crash-mid-flip cases. No Roblox APIs.
- **A thin DataStore-backed journal service** (the WAL writer/reader) — `open(holdId, ownerId,
  payload)`, `commit/clear(holdId)`, `pendingFor(userId)`. Knows nothing about pets/gems/trades —
  it persists opaque `payload` blobs.
- **Game-side consumers** wire the domain in: `TradeService` opens a hold per escrowed bucket and
  passes its descriptors as the payload; the DataService load path calls `pendingFor(userId)` and
  hands each unresolved payload back to its owning service to re-credit. Other future consumers
  (offline gifting/mail, shop grant-then-fail rollback, reward fanout) reuse the same primitive.

This matches the repo's template-vs-game convention: pure reusable core + thin infra on the
template side, domain wiring on the game side.

## Context
Roblox has **no native in-experience trading/escrow API** and **no multi-key atomic
transaction** — only single-key `UpdateAsync`. So a crash-safe escrow must be a hand-built
**write-ahead journal (WAL)** with **idempotent re-credit on rejoin**. Our trade is
**single-server** (both traders in one server) on **ProfileStore**, so full N-key two-phase
commit is overkill — a per-owner durable DataStore journal is the right size.

## Recommended architecture (single-server escrow + crash-catch)

**Happy path (already how we work):** both players same server; each offer mutates a
session-locked `Profile.Data` synchronously (no yield mid-swap) → commits atomically per
profile. `_deliver` (both confirmed) / `_refund` (cancel/disconnect) handle the swap.

**Crash-catch layer (new):**
1. **On escrow add** — when an item leaves a player's inventory/balance into `session.escrow`,
   write a hold to a dedicated trade DataStore keyed by the *owner's* UserId:
   `{ holdId = UUID, sessionId, descriptors = [...], state = "pending", ts }`.
2. **On deliver/refund** — clear that owner's hold (state→`cleared`/delete) in the same flow as
   the existing in-memory `_deliver`/`_refund`.
3. **On next player load** (next to `CurrencyKeys.normalize` in `DataService`) — read holds for
   that UserId; any still `pending` (a crash interrupted the trade) → re-credit the descriptors
   to the owner, then clear. The journal flip and the credit ride the **same `UpdateAsync`** so
   they commit together.
4. **Idempotency** — gate re-credit on `state == "pending" AND holdId ∉ processedSet`. The
   `holdId` UUID is generated **once** at escrow time, **never** regenerated on reload — that's
   the dedup primitive. Bound `processedSet` by TTL / low-water-mark.

Net: a crash mid-pending-trade refunds the owner on next join; can't double-credit (cleared /
processed guard), can't vanish (`pending` survives the crash).

## Key decisions

| Decision | Recommendation | Why |
|---|---|---|
| Journal store | **DataStore** (dedicated trade store) | MemoryStore is ephemeral with a hard TTL — wrong for crash-durable holds. The whole point is surviving a crash. |
| Re-credit mechanism | **Direct DataStore hold + re-credit on the owner's own reload.** Use ProfileStore `MessageAsync` only to deliver to a *now-offline partner* | `MessageAsync` sends to a profile online-or-offline (two `UpdateAsync` calls) — the modern replacement for ProfileService GlobalUpdates; overkill for same-player crash-catch. |
| Atomicity primitive | **`UpdateAsync` (read-modify-write), never `SetAsync`**; flip journal + credit in one call | `UpdateAsync` ordering avoids the classic trade dupe / lost update. |
| Idempotency key | **Per-hold UUID generated once + bounded processed-set** | Exactly-once receiver: commit side-effect + dedup record together; never regenerate the id. |
| Graceful shutdown | **`BindToClose`** to flush/resolve pending trades | ~30s budget; covers graceful restarts, **not** hard crashes — why the persistent journal is still required. |

## Pitfalls / anti-patterns (dupe vectors)
- **Persist *after* delivering** → crash between = re-credit on reload AND recipient kept it = DUPE.
  Order: remove-from-owner → journal `pending` → deliver → journal `cleared`.
- **Regenerating the hold/UUID on reload** → breaks dedup, double-credits.
- **`SetAsync` instead of `UpdateAsync`** → lost / out-of-order updates = classic trade dupe.
- **No session lock** → two servers load the same profile = item loss / dup loophole (ProfileStore
  gives us this already).
- **Trusting the client** → validate server-side at start/middle/end; client does visuals only.
- **Unbounded processed-set** → grows forever; bound by TTL / low-water-mark.

## Sources
- Roblox: [DataStore best practices](https://create.roblox.com/docs/cloud-services/data-stores/best-practices),
  [Player data & purchasing (session locking)](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing),
  [MemoryStore best practices](https://create.roblox.com/docs/cloud-services/memory-stores/best-practices)
- ProfileStore: [docs](https://madstudioroblox.github.io/ProfileStore/) · [API](https://madstudioroblox.github.io/ProfileStore/api/) · [DevForum thread](https://devforum.roblox.com/t/profilestore-save-your-player-data-easy-datastore-module/3190543)
- ProfileService: [overview](https://madstudioroblox.github.io/ProfileService/) · [API (GlobalUpdates lifecycle)](https://madstudioroblox.github.io/ProfileService/api/)
- DevForum: [How would I make my trading system safe?](https://devforum.roblox.com/t/how-would-i-make-my-trading-system-safe/2593565)

**Flagged (not fully corroborated):** no single canonical *open-source* crash-safe escrow module
exists (WAL recipe above is synthesized from the 2PC/journal pattern); boyned's "Committing to
Safety" article 403'd (paraphrased only); "exactly-once" is the documented *effect* of the
active→locked→cleared contract, not loleris's verbatim wording.
