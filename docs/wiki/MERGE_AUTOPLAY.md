# Merge offline play and Studio autoplay

Status: offline workers implemented and Studio-verified (2026-09-05); publish both places together.

The online autoplay button/controller, server toggle handler and service Start remain
`RunService:IsStudio()`-gated. Live players never receive that test control. The paid feature is
now **offline play**: server-owned characters work for disconnected accounts in spare Merge bays.

## Offline production contract

- `configs/merge_offline.lua` enables automatic filling in live Merge **and Studio**, up to five
  otherwise-empty bays. One candidate is started per fill cycle (20 seconds plus service latency),
  not five synchronous loads at boot. Farm & Fight tracks login presence but does not host workers.
- Eligibility is exact IDs from `internal_accounts`, excluding Colorado Plays `3200870803`, plus
  verified `offline_gaming` pass owners (`1963628754`). Existing pass owners enter the persistent
  pool on their first join to an updated server; Roblox ownership cannot be globally enumerated.
  Purchase completion registers immediately and ownership is rechecked before a worker starts.
- A randomized pivot/wrap query samples the global pool; a shuffle includes internal accounts.
  Workers rotate after 30 minutes and are not guaranteed continuous time or a particular server.
- Real Players preempt offline occupants when claiming their bay, and random allocation can
  reclaim an offline bay when all bays are occupied. Cleanup checks exact claimant identity so
  delayed cleanup cannot release another player's replacement session.
- Login in either place writes online presence and publishes cancellation before profile load.
  Messaging is the fast path; a 15-second renewal checks the 90-second fenced lease as fallback.
  Lease loss, expiry, shutdown, death or runtime failure stops the worker. No new workers start
  when profile storage or presence acquisition fails. Normal ProfileStore locking remains the
  final authority even if presence/messaging is unavailable.
- Server-only `OfflineActors` are table facades, never artificial Roblox Player instances.
  `MergeOfflineRuntime` reuses ordinary Merge/autoplay methods with private session maps, real
  walking/pathfinding, ordinary prices and owner-scoped encounters. It fields equipped, owned,
  unlocked pets and preserves survivors; it does not fabricate a second combat simulation.
- Only Waycoins are spent. Existing unlocked egg/defense options are used; no Gem purchases,
  automatic rebirth, ascension, level claims or destructive defense-family replacements. Natural
  combat XP and ordinary drops still accrue. An empty bay deploys an egg before saving for upgrades.
- Offline actors do not emit online onboarding/funnel events or receive personal UI remotes.
  Shared world models remain visible to nearby actual clients.

## Ownership and earnings

`MergeOfflinePresence_v1` (MemoryStore hash) stores fenced online/offline/cooldown leases;
`MergeOfflinePool_v1` (OrderedDataStore) stores randomized eligible account IDs;
`MergeOfflineLogin_v1` (MessagingService) accelerates login cancellation.

There is **no second balance or replayable reward grant**. A worker exclusively acquires the
existing `PlayerData_v2_mixedPets` / `Player_<id>` profile and ordinary economy/inventory/XP services
mutate that canonical profile. Ending the worker persists Merge playstate and calls ProfileStore
EndSession. The next actual login obtains those already-earned balances and inventory.

`NonPreemptiveProfileStore` wraps the pinned ProfileStore 1.0.3 backend on a dedicated store
instance. A read-only preflight skips absent/locked accounts; the UpdateAsync transform is the
authoritative guard. Background work never creates a missing profile, requests force-load, steals
an existing session, or writes after its exact session token is replaced. It depends on pinned
private `data_store`, `template`, and `is_ready` fields: preserve adapter contract tests when
upgrading ProfileStore. Template tracking: issue #456.

Profile root `OfflineMerge` contains a cosmetic summary (`seconds`, `xp`, `gems`, `lastEnded`,
`reason`, `presented`). The welcome-back receipt acknowledges that summary, not a second payout;
repeated receipt delivery cannot duplicate earnings. Coins spent/collected and actions remain
available in runtime reports; normal wallet and Merge checkpoint persistence retain their results.

## Offline verification and diagnostics

Studio-only `ServerStorage.MergeOfflineStudioControl` is a server BindableFunction, not a remote.
Actions: `status`, `enable`, `pause_filling` (keep existing workers), `disable` (save/stop all),
`fixture_start` with a real source Player, `fixture_step`, `fixture_stop`, and `fixture_preempt`.
Fixtures use a negative account ID and an in-memory copy, never the source player's profile.
`ServerStorage.MergeOfflineWorkers` attributes expose filling state, count, candidates, last
start/stop/reason/error. Disabling through this control applies only to that Studio session.

Verified in Studio: isolated start/stop/preemption; a real alternate advanced waves 30–32 and
earned 250 XP, then an independent DataStore read confirmed saved XP/highest wave/summary and
released profile ownership. Another alternate created/deployed its first egg, advanced wave 0–10,
and upgraded production with zero navigation failures. Automatic filling reached five workers;
all five stopped and released their bays successfully. Cannon and bulwark installs/upgrades also
ran through normal purchases. A simulated cross-server online lease plus
login message stopped only the matching worker. Actual two-server/account login and production
load behavior still need a published smoke test; Studio tests are not evidence of those results.

## Existing online Studio test runner

Baseline before work: clean main `a8c20b65`, published Merge **v594**. Studio stays open.

`configs/merge_autoplay.lua` owns strategy order, navigation budgets, UI, and the symbolic
`offline_gaming` pass. `configs/monetization.lua` maps it to the existing pass **1963628754**.
Despite the dashboard name, this is **online character autoplay**, not offline accrual or an
anti-idle system. Owners opt in per session; joining/rebirthing never silently enables it.

### Studio runner contract

- Client sends only on/off intent through `MergeAutoplayToggle`. The server owns every target,
  price, action, and per-player state. Client walking uses pathfinding and normal humanoid input;
  there is no teleport, speed override, screenshot recognition, or synthetic idle input.
- Ordinary Merge purchase methods still validate ownership, currency, distance, tutorial/slot
  access, and balance. Only Waycoins (`hall_coins`) are allowed. Gem unlocks, management upgrades,
  ascension, level claiming, rebirth, and arbitrary commands are not in the action whitelist.
- Supply available eggs to hatchers before combining spare board eggs. Buy eggs and raise their
  production tier; install already-owned cannon/bulwark families and upgrade installed families.
  Production never replaces a different installed family and destroys its upgrades.
- The rotating configured strategy saves for its selected expense rather than spending every
  coin on cheap eggs. Only the player's own Merge coin drops are pursued; normal DropService
  proximity collection remains responsible for awards.
- Stop, death, leaving, losing ownership, bay-record replacement, pending transit, or repeated
  navigation/action failures cancels automation. Camera ceremonies stop it rather than fighting
  their controls. Players can opt back in afterward. Normal waves and XP continue naturally.
- Nothing automatically unlocks Gem-gated content or bypasses tutorial checkpoints. Such gates
  remain manual. Surviving pets and other players' bay sessions are not reset.

## Testing and data

`ServerStorage.MergeAutoplayStudioControl` exists **only in Studio**, bound to the running service.
Invoke with a Player and one of:

```lua
{action = "start", strategy = "balanced"} -- also egg_first / control
{action = "start", strategy = "control", allowReplacement = true}
{action = "report"}
{action = "plan"} -- read-only current candidate prices/locations
{action = "stop"}
{action = "rebirth", confirmRebirth = true} -- explicit; must already be near the board
```

Testing still needs the pass and real funds/owned families; it grants no money or unlocks.
Explicit testing replacements use the same stale-state confirmation identity as the workshop.
Test rebirth stops autoplay first, checks its currency is Waycoins, and calls the ordinary
confirmation/proximity/requirement-checked rebirth method. It is never exposed as a player remote.

Reports contain strategy, elapsed time, starting/current wave, earned XP, Waycoins collected/spent,
successful actions, navigation failures, and a bounded recent-action history. An aggregate report
is logged at the configured interval; no per-frame tracing or player profile snapshots.
Reports are diagnostic session data, not persistent analytics or a claim of optimal strategy.

Headless coverage: policy whitelist, bad prices/config, real pass mapping, line priority,
defense savings, per-player cooldown isolation, catalog family IDs. `MergeAutoplaySmoke.run()`
uses isolated actors and wallets to verify non-owner denial, near/far execution, Gem rejection,
ignored production testing flags, stale-record cancellation, and independent player stops.

Verification: 2,624 headless tests pass. Isolated Studio fixture also checks cannon preservation,
owned-only bulwark planning and ordinary workshop dispatch. A live normal-entitlement run walked
the real bay, made three production-tier purchases and two cannon installs, advanced wave 42–68,
and stopped cleanly with zero navigation failures. Existing auto-collection left no loose coins in
that run; coin pursuit remains dependent on normal DropService proximity, not remote grants.
The compact purchase card renders, and HUD status is contained above the hotbar. Management signs
are elevated: pathfinding retries at the player's floor height when the sign surface is NoPath;
the authoritative station-distance check remains unchanged.
