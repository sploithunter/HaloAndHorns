# Client Performance

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

- **Batch/cull combat presentation packets.** A separate 10-second client listener counted
  ~173 `Combat_Result`, ~86 `Combat_PetHit`, and ~37 `Combat_EnemyHit` deliveries per second.
  Batch visual notifications and restrict observers by distance/bay; preserve server damage,
  XP, contribution, and authoritative results. These are gameplay presentation, not trace spam.
- **UI/transparent batching.** The sampled view spent 289 draws on UI plus transparent passes
  despite low triangle counts. Audit stacked BillboardGuis, status overlays, and transparent
  effects before reducing the detail of every model.
- **Bay-aware visual work.** Extend distance budgets to distant flora/effects and observer
  presentation, with prefetch for approaching bays. Surviving pets retain their authoritative
  lifetime even after their egg family falls behind the unlock frontier.

See [Architecture](ARCHITECTURE.md), [Merge](MERGE_EGG_PROTOTYPE.md), and
[Studio Workflow](STUDIO_WORKFLOW.md).
