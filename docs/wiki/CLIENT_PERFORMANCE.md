# Client Performance

## Bounded procedural effect-part reuse (2026-09-06, feature branch)

`combat_fx.part_pool` enables a shared **2,048-idle-Part** cache per execution context.
Only private procedural primitives participate: RangedFX flashes/sparks/shards/rings/
smoke/columns and AreaFX single-stage primitives. Multi-stage projectiles, ricochets,
tar pits, particle hosts, sound holders, and lightning rigs retain their old lifecycle.
No living pet, authored model, hit, effect count, appearance parameter or damage timing
is removed. Capacity bounds idle retention, not active visuals; overflow is destroyed.

`LeasePool` invalidates ownership before cleanup and requires the lease ID on release.
Old timers therefore cannot remove a newer use of the same Part. `EffectPartPool`
resets appearance/transform properties, cancels and destroys owned tweens, destroys
children, clears attributes/tags, and retains idle Parts under a private unparented
folder. Its parent marker detects destroyed idle Parts even with deferred Destroying
signals. Idle parts intentionally appear in retention diagnostics; the cap is explicit.
Disabling the config keeps the same effects while allocating/destroying each use.

Native `tools/effect_part_pool_smoke.luau` tests property/child reset, stale delayed
release, external destruction, cap overflow, cancellation, and disposal. Three identical
batches of real RangedFX/AreaFX calls have matching initial visual-property signatures
and complete normal lifetimes: disabled creates 1,077 Parts; enabled creates 359 and
reuses 718. The first native attempt exposed deferred Destroying and informed the
parent-marker fix; another attempted cleanup assertion ran before the unchanged grass
particle host's two-second lifetime and was corrected to wait 2.2 seconds.

Fresh one-bay Play progressed waves 72→76 with visible combat, no console script errors,
and runtime pool counters of 2,872 created / 174,684 reused after roughly 140 seconds.
The 90-second parenting census recorded 116,992 additions (including reuse), while
BaseParts rose **39.254 MB**, versus **152.714 MB** in the preceding unpooled capture.
Waves and view differ: these are observed shared-Studio counters, not a controlled
whole-game percentage, total-memory cure, deployment budget or FPS claim. Memory still
grows in unmigrated effects/categories. The MCP command environment has a separate module
cache; runtime pool counters must be read through a temporary LocalScript/Bindable probe,
not by requiring a new lazy pool in the command environment.

Full local CI: 2,755 tests / 309 specs. The first combined run sampled the temporary
offline-fill-disabled diagnostic config and failed its policy assertion; rerunning with
the restored production config passed. Evidence: `effect-pool-native.json`,
`effect-pool-one-{probe.luau,result.json,host.jsonl}` and `effect-pool-final-ci.log` in the
durable [stress directory](MERGE_STRESS_TESTING.md).

The subsequent eight-bay run used seven isolated level-50 fixtures plus the viewer,
635–639 pet/objective models and 79 NPC squads. Fixtures advanced wave 60→65/66;
the 120-second cap removed all workers and status reported no harness errors. Across
the 115.9-second populated capture, BaseParts rose **11,521.0→11,578.5 MB** and shared
Studio total **21,618.9→22,021.5 MB**. Weighted client frame interval was **29.43 ms**.
These are warm-process observations with changing combat/view, not a matched FPS gain.
One-bay samples continued after worker teardown and still show growth; no OOM-cure
claim. Both probes were explicitly stopped/destroyed, and Play stopped with Studio open.
Raw `effect-pool-eight-{server,client}-memory.json` and `effect-pool-eight-host.jsonl`
are preserved in the stress directory. No eight-bay pool-counter or visual-parity
claim comes from those memory probes.

Hosted CI caught two new-module issues omitted from the earlier local architecture
scan: that scanner uses `git ls-files --cached`, so untracked source was absent.
The expiration callback is now explicitly classified as an animation lifetime;
enabled pools require the configured capacity instead of a numeric tuning fallback.
The tracked-source full CI and native smoke rerun pass (2,755/309; identical visual
signatures, 359 created versus 1,077). Artifacts: `effect-pool-tracked-ci.log` and
`effect-pool-native-retest.json`. Both hosted fast gates passed for `5478db22`.

A second fresh eight-bay verification loaded the corrected source. The runtime pool
reported **2,985 created / 77,541 reused / 1,500 active / 879 idle**, within the
2,048-idle cap. Census retained **72 eggs, zero hidden eggs**, with 438 of 637
pet/objective models hidden. Captured combat view showed normal pets, effects and
defenses; this visual inspection supplements, not replaces, the native parity tests.
A 20.058 s profile recorded enemy combat ticks 4.316 s inclusive, nested pet aggro
1.632 s, target assignment 1.239 s, engagement 0.818 s, and PetFollow ticks 1.461 s.
29,789 target lookups totaled 0.0294 s. Do not add nested counters or label elapsed
instrumentation script-exclusive CPU. Low-FPS/frame warnings remain; no script error
was identified in this capture. Stop confirmed zero synthetic workers/errors; diagnostic
script/bindable removed, Play stopped, production config restored. Raw
`effect-pool-eight-visual-{profile,census,console}.json` and passive host JSONL are in
the same directory; native capture ID `EffectPool_EightBay_Combat`.
No production publish; Studio stays open.

## Character-local Merge bay detail (2026-09-06)

`MergeBayPresentation` selects the nearest authored bay from the **character's current
position**, with a 16-stud switching buffer. It never reads the player's claimed bay
to choose detail. The current side's immediate left/right columns also remain detailed;
actors within 60 studs and the viewer's personal squad remain visible. Walking across
the mall changes the visible neighborhood without changing any claim.

Other Merge pets/enemies receive a client-local `MergePresentationHidden` attribute.
The existing lifecycle-managed visibility binding composes that with `CombatDowned`,
hides body parts, labels and attached effects, and restores their desired state on
re-entry. Pet rig tracks stop while hidden; NPC movement and enemy presentation skip
hidden actors. Eggs are explicitly exempt; defenses/world props are untouched. A bounded
per-bay impact summary uses existing enemy/bay state, not extra combat remotes. All
settings and colors live in `merge_egg_prototype.distant_presentation`.

This is **presentation culling, not model unloading or replication filtering**. Living
actors, HP, targeting, rewards and server movement remain intact; do not claim that
this alone reclaims replicated model memory. Ordinary pet position relays now use the
nearby/coarse observer budget below. `pet_follow.npc_presentation` additionally budgets remaining distant
NPC formation work to 10 Hz, considering camera/player proximity. The Studio-only
`DisableNpcPresentationBudget` script attribute is an A/B seam for that cadence only,
not the bay visibility policy.

Summary correction: `ActiveEnemies > 0` alone previously triggered decorative impacts
while enemies merely spawned/marched. Summaries now require an observed HP decrease
between bounded client snapshots, and remain excluded for detailed actors. First
observation, unchanged HP and healing are silent. Replacing the snapshot each pass
releases departed models; this uses existing replicated HP, not new remotes. The user
clarified that the premature symptom was effects only, not early damage; damage/report
gating was left unchanged. Isolated production-classifier tests pass and a fresh Play
loaded the correction. The user's remaining pre-contact flashes were subsequently
confirmed as enemy buffs: rebirthing to early enemies without buffs removed them.
The summary defect was real but was not the cause of that remaining symptom. Summary
size has not been increased yet.

Native eight-bay validation before the final offline-personal-squad eligibility addition:
621 pet/objective models, 378 hidden, all 72 eggs retained, zero hidden-body visibility
errors. Visiting Hell 2 changed focus to `hell_02` while the claim remained `heaven_01`;
the visited side's hatchers restored and Heaven 1 hatchers hid. The viewer was returned
to the original position. Offline personal squads carry `OfflineOwnedSquad`, not per-pet
run IDs; that eligibility path now passes an isolated production-classifier test.
Native visibility tests cover distant/downed overlap, particles, late descendants,
flat enemy roots and restoration. Full local CI: 2,725 tests. Full FPS/memory benefit
and final visual acceptance remain to be measured; production is unchanged.

## Frame-scoped pet target lookup (2026-09-06)

`PetFollowController` now constructs a `FrameTargetLookup` inside each render callback.
It traverses each requested enemy/crystal folder once and resolves all pets against that
snapshot. There is no cross-frame model cache or new connection per target. Scope,
identifier and parent are validated; duplicate authored IDs retain traversal-first
semantics. Newly streamed/replaced targets are rebuilt next frame. This changes only
presentation lookup, not server targeting, range, HP or rewards.

`tools/frame_target_live_probe.luau` compares the actual production lookup with its old
traversal on identical live visible-pet target requests, alternating order. Six one-bay
samples (28–30 requests) took 0.036–0.108 ms indexed versus 0.306–0.406 ms traversal.
Six eight-bay samples (37–52 requests) took 0.062–0.229 ms versus 0.608–2.612 ms. Every
target matched; each indexed sample traversed one scope. These are matched lookup
replays, **not** full RenderStepped/FPS measurements; the replay includes visible
targeted pets without reproducing every formation eligibility rule. Actual fresh Play
loaded the new controller, workers advanced, and no client script errors appeared.
The eight-bay run still emitted server-frame warnings. Raw evidence lives alongside
the [stress captures](MERGE_STRESS_TESTING.md) as `frame-target-one-bay.json`,
`frame-target-eight-bay.json`, `frame-target-client-memory.json` and the passive host log.

Headless tests cover one scan per scope, world isolation, duplicate IDs, invalid types,
stale/reparented identifiers, next-frame replacement and callback-local lifetime.
Combined local CI including the summary correction: 2,736 tests / 306 specs.

## Nearby/coarse player-pet position relays (2026-09-06)

`pet_follow.replication.observer` retains the normal owner-report cadence for observers
within 240 studs of the owner **or any reported pet**. Other observers get the latest
snapshot once per second, including an immediate first snapshot. Approaching the fight
resumes full-rate delivery on the next owner report, independent of claimed bay. The
coarse stream avoids frozen remote pets and keeps presentation re-entry positions fresh.
It is not model unloading or complete suppression of distant pet data.

The server still stores every accepted owner report immediately for the existing combat
position gate. Only observer forwarding is budgeted. Payloads are projected to the
existing `{pet, cf}` contract rather than forwarding unrelated client fields. Per-owner /
recipient timing state is removed when either player leaves. Disabling the observer
config restores full-rate delivery. NPC-principal movement is a different channel;
this optimization does **not** claim to reduce the seven-offline-worker simulation cost.

`tools/pet_position_relay_smoke.luau` executes the actual service method with isolated
Instances, eight synthetic viewers and intercepted sends; no real remotes or profiles.
For 100 reports / 11 pets: all-near produces 700 deliveries / 7,700 records; one near
observer and six distant observers produces 160 / 1,760. Moving a distant observer
near halfway gives that observer 55 deliveries (5 coarse + 50 full-rate). A viewer
near pets still receives full rate when their owner is far away. Latest transforms,
unchanged server position timestamps, no owner echo, payload projection and removal
cleanup are asserted. These are deterministic call/record counts, **not measured
transport bytes, real eight-client network results or FPS**.

Fresh Play boot and another eight-bay workload loaded these changes without client
script errors; 654 pet/objective models, 438 hidden, all 72 eggs retained. The server
lookup improvement persisted (27,015 lookups / 29.2 ms over 20 seconds). Enemy combat
ticks still cost 5.008 s inclusive; memory growth remains unresolved. Full local CI:
2,742 tests / 307 specs. Evidence: `observer-relay-native.json`,
`observer-fresh-server-profile.json`, `observer-fresh-client-memory.json`,
`observer-fresh-census.json` and `observer-relay-host.jsonl` in the durable stress directory.

## NPC-amplified player-position reports (2026-09-06)

`PetFollowController.driveAnchor` serves both the local squad and every NPC squad.
Its shared report accumulator previously advanced on **every** invocation, so NPC
presentation accelerated the local player's position-report clock. It now advances
only for the local squad; the configured `pet_follow.replication.interval` remains
unchanged, as do transforms, owner validation, mining and combat authority.

`tools/pet_position_report_smoke.luau` extracts and executes the actual reporting
block in an isolated Studio ModuleScript with intercepted sends. At 500 frames ×
0.02 seconds, zero NPC squads produced 100 reports before and after. With 9, 19,
or 79 NPC squads, each case produced 499 before and 100 after. These are matched
**report-call counts**, not measured packet bytes, live transport timing or FPS.
The server currently relays each accepted report to other players, so fixing the
sender also removes that corresponding source of relay amplification. The later
nearby/coarse observer budget above further reduces distant deliveries.

CI checks the owner-only clock integration and the report/expiry interval contract;
the native smoke verifies the reporting block's behavior. Full CI: 2,712 tests.
Changes remain in draft PR #460 pending the broader load-testing effort.

## Farm & Fight predictive cache (2026-09-05)

`FarmAssetWarmupService` now clones from the prebuilt server catalog into each owner's
`PlayerGui.FarmAssetWarmCache`. `configs/farm_asset_warmup.lua` owns all budgets and intervals.
The closest two distinct egg stands supply current/approaching pools (including rare outcomes
and configured variants); Earth is the pre-world/prologue fallback. This is geographic anticipation,
not a claim that every unlocked egg across distant realms stays resident.

Validated equipped pets, living own pets, nearby player pets, recent owned variants, and bounded
explicit preview requests supplement those pools. Unneeded cache entries expire with a capped
grace set; no live Workspace actor is destroyed. Explicit 3D requests validate ownership/current
prediction, rate-limit, cap retained requests, and never fetch arbitrary client asset IDs.
Flat inventory cards stay virtualized and flat-only. Legacy 3D helpers now select the exact
pet/variant instead of the first model they find, and do not attempt client InsertService loads.

The shared warmup worker (retaining its historical `MergeAssetWarmup` module name) selects the
appropriate place cache and fetches mesh/texture and flat-image dependencies. Failed content has
bounded retries; a replacement PlayerGui cache is not skipped behind an old pending preload.
The four-starter boot shelf below remains available before player-profile readiness.

Feature-branch Farm & Fight Play verified 24 pet types / 2 egg pools, all 56 flat image references
and 158 unique MeshPart mesh/texture references reporting Success, and no replicated global
Models catalog. Profile loading succeeded in that run. This is not a cold-client timing/memory
benchmark. Isolated Studio tests cover two-owner isolation, living-pet retention, unused eviction,
owned-only requests, Merge exclusion, failed-content retries, and replacement-cache loading.

## Starter-picker boot exception (2026-09-05)

Farm & Fight boot publishes only the four `configs/starter_pets.lua.choices` basic models in
`ReplicatedStorage.Assets.StarterPetPreviews`, before `models_ready`. Merge publishes none.
The starter controller independently prefetches each model and flat thumbnail during startup,
before waiting for UI readiness. Its viewport fallback reads this bounded shelf, not the removed
`ReplicatedStorage.Assets.Models.Pets` catalog. This fixes the post-cutscene paw placeholders
without restoring full-catalog replication or changing starter grants. The small shelf remains
available for later joins; normal live pets retain their existing lifetime rules.

`scripts/studio/test_starter_pet_previews.luau` uses actual starter templates and production
publisher/picker functions in isolated Edit fixtures: four models, eight preloads, all four
fallback cameras/models replacing paws, repeat-build cleanup, and Merge exclusion. It does not
claim cold-client network timing or a complete new-account cutscene playthrough.

## Combat presentation batching and audiences (2026-09-04)

`configs/network.lua.combat_presentation` combines `Combat_Result`, `Combat_PetHit`, and
`Combat_EnemyHit` into one reliable, ordered `Combat_PresentationBatch` per recipient.
The registry's logical signal API stays unchanged. Server HP, endurance, XP, loot,
contribution accounting, and attack cadence still resolve immediately.

- Flush every 0.05 seconds (up to roughly 20 normal deliveries/sec/player); 128-record
  envelopes flush early under exceptional load, without coalescing or dropping queued hits.
- Snapshot payloads on enqueue: PetFollowService reuses its owner hit table and subsequently
  sets `foreign = true`. Delayed serialization must not leak that flag into the owner's copy.
- Recipients are selected at publication, not flush. Per-player queues are removed on departure;
  a newly joining player cannot inherit another player's queued records.
- Attack animations retain their existing pet-owner/near-target candidate selection and add
  a 120-stud visibility budget for observers (distance to source or target). Enemy swings no
  longer broadcast globally. Directly involved players retain their own attack feedback.
- Combat results go to source/target owners, the Merge run owner, and players actually helping
  that fight. Server-observed attacks/damage/heals refresh a 10-second participation grace;
  proximity alone does not subscribe a spectator to numbers. Run IDs scope Merge participation;
  other fights use the enemy instance. Expired participation and departed players are removed.
- Clients fan records back into the existing visual listeners. Startup-only buffers retain
  the most recent 128 records per channel before its first listener; normal delivery keeps every
  record. Destroyed targets continue to use the result's captured fallback position.
- Setting `enabled = false` restores the original individual-remotes behavior on a fresh boot.

A pre-change 20.003-second live sample on `c2b0eb5d` counted 3,714 results, 2,731 pet swings,
and 326 enemy swings: approximately **338.5 individual deliveries/sec** in total. This differs
from the earlier 296/sec sample because wave composition changes.

A fresh feature-branch Play sample (20.038 seconds) delivered **2,756 records in 109 batches**
(1,523 results, 1,150 pet swings, 83 enemy swings; largest batch 107). The three legacy remotes
delivered zero events. This is **96.0% fewer wire deliveries than individually sending those
same 2,756 records**, not a 96% bandwidth/FPS claim or a controlled comparison of wave load.
In another 10-second check, all 1,910 received results created floating-text billboards.
Occasional low-FPS/server-frame warnings remain; batching does not remove rendering/GC work.

`ReplicatedStorage.Tests.studio.CombatPresentationSmoke.run()` uses isolated engine-Instance
fixtures to check owner/helper/near/far spectator routing, including a helper retaining its home
run while attacking another bay. It does not alter live pets/profiles. Pure CI covers 2,600 tests.
This fixture check is not a full multi-client load test. Fresh-current-main verification also
passed after PR #433 merged (recorded in its verification comment). A subsequent audit corrected
the audience resolver to recognize enemies' actual `MergeRunId` alongside allied actors'
`MergeEggRunId`; fixtures now use that real enemy attribute and check a second enemy in the same
fight, so helper participation cannot accidentally be scoped to only the enemy initially hit.

## Nearby adaptive shadows (2026-09-04)

`configs/client_graphics.lua` owns the shadow policy and Settings copy. `ShadowController`
runs locally in every place; the server only persists `Settings.ClientPrefs.shadowMode`
through the whitelisted `settings.get` / `settings.set` commands.

- **Auto (default):** nearby shadows, disabled after sustained poor frame rate.
- **On:** nearby shadows regardless of frame rate; not an unlimited-distance mode.
- **Off:** `Lighting.GlobalShadows = false` on that client only.
- Casters activate within 100 studs of the player and deactivate beyond 120 studs.
  Part distances use the nearest point of the oriented bounds, preserving nearby large walls.
  Authored `CastShadow = false` / light `Shadows = false` are never promoted to casters.
- One initial Workspace inventory, then descendant events maintain the registry. A 0.5-second
  pass changes only the shadow flags crossing the distance thresholds. Objects leaving Workspace
  have their original flag restored; no model, pet, animation, or gameplay state is removed.
- Auto ignores startup grace, unfocused windows, Roblox menus, and isolated loading stalls.
  Five sustained seconds below 35 FPS disable shadows; a 60-second cooldown plus 20 sustained
  seconds at 55+ FPS permit recovery. Manual modes bypass adaptation.
- Local `ShadowMode` and `ShadowsActive` player attributes expose the preference and current
  result for inspection. Automatic transitions never overwrite the saved preference.

## One-player Studio baseline, 2026-09-04

Measured the open Merge session on build `00c0d7fd` (PR #431), before the shadow change.
This was a 30-second live sample, not a controlled standalone/device benchmark. The client
and server share a long-running Studio process; waves and view composition change during play.

| Measurement | Mean | 95th percentile |
| --- | ---: | ---: |
| Client frame interval | 23.0 ms (~43.5 FPS) | 38.2 ms |
| Render CPU | 10.3 ms | 14.1 ms |
| Render GPU | 13.3 ms | 18.6 ms |
| Server heartbeat work | 5.95 ms | 8.65 ms |
| Server physics | 0.22 ms | 0.23 ms |
| Server data send (Stats counter) | 88.9 | 151.7 |
| Visible-scene draw calls | 638 | 932 |
| Visible-scene triangles | 2.75 million | 3.09 million |
| Texture memory (Studio tag) | 532.9 MB | 539.4 MB |

The send column is the raw `Stats.DataSendKbps` counter, not a custom packet-size estimate.
Shadow-pass triangles were separately 8.51 million average; they are not added to the
visible-scene geometry budget. Do not infer GPU critical-path cost from triangle count alone.

A separate render-pass snapshot reported opaque geometry 2.30M triangles / 230 draws,
transparent geometry 2,894 triangles / 119 draws, and UI 8,796 triangles / 170 draws.
SceneAnalysisService counted 28,875 client DataModel instances, including 6,877 UI objects.
`Stats.InstanceCount` (~73K) is a different scope and must not be presented as this census.

The full global model catalog is absent on the client after #431. The current texture tag
still exceeds 500 MB; no measured cold-client memory saving is claimed. Studio category
counters included implausible totals (e.g. BaseParts 37GB), while OS RSS for Studio was ~3.4GiB.
Use a cold standalone client for release memory comparison; do not close this user's Studio
to obtain it. Script-memory profiling was unavailable due to a required Studio flag, and
LibMP returned a snapshot with no frame records; neither supports a per-script CPU claim.

An attempted on/off/on shadow benchmark was rejected: the camera moved up to 60 studs and
146 degrees across the test. It is not evidence for a percentage FPS improvement.

After adding nearby shadows, a fresh 20-second stationary-camera sample recorded ~49.6 FPS
(20.15ms mean, 29.16ms p95), 10.35ms render CPU, 12.18ms render GPU, and 528.8MB texture tag.
Shadows remained enabled for all 994 frames. Visible geometry was 5.31M triangles / 662 draws;
shadow-pass geometry was separately 5.79M triangles. The wave/view differed from the earlier
baseline, so these are current-state readings, not a controlled percentage performance gain.

## Next measured opportunities

- **Verify multiplayer combat interest at scale.** A separate pre-batching 10-second listener counted
  ~173 `Combat_Result`, ~86 `Combat_PetHit`, and ~37 `Combat_EnemyHit` deliveries per second.
  The transport now batches and scopes these notifications as described above. Exercise a real
  owner/helper/spectator multi-client session before claiming multiplayer throughput savings.
- **UI/transparent batching.** The sampled view spent 289 draws on UI plus transparent passes
  despite low triangle counts. Audit stacked BillboardGuis, status overlays, and transparent
  effects before reducing the detail of every model.
- **Bay-aware visual work.** Extend distance budgets to distant flora/effects and observer
  presentation, with prefetch for approaching bays. Surviving pets retain their authoritative
  lifetime even after their egg family falls behind the unlock frontier.

See [Architecture](ARCHITECTURE.md), [Merge](MERGE_EGG_PROTOTYPE.md), and
[Studio Workflow](STUDIO_WORKFLOW.md).
