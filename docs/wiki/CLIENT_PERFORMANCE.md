# Client Performance

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
