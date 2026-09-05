# Merge online autoplay

Status: implemented and branch-verified (2026-09-04).

Release correction (2026-09-04): the online autoplay button/controller, server toggle handler,
and service Start are now explicitly `RunService:IsStudio()`-gated. The toggle remote is omitted
from the production manifest. Live players do not receive this online test control. The intended
paid feature is **offline play** for disconnected accounts; its shared eligibility pool,
cross-server login cancellation, spare-bay workers and durable reward handoff are separate work
and are **not enabled by this UI-only release**. The online production contract below describes
the original implementation and now applies only to the Studio test runner.

Baseline before work: clean main `a8c20b65`, published Merge **v594**. Studio stays open.

`configs/merge_autoplay.lua` owns strategy order, navigation budgets, UI, and the symbolic
`offline_gaming` pass. `configs/monetization.lua` maps it to the existing pass **1963628754**.
Despite the dashboard name, this is **online character autoplay**, not offline accrual or an
anti-idle system. Owners opt in per session; joining/rebirthing never silently enables it.

## Production contract

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
