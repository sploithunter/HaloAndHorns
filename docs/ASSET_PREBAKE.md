# Asset Pre-Baking (boot speed)

## Why

At boot, `AssetPreloadService` populates `ReplicatedStorage.Assets.Models` (pets / eggs / breakables).
The configs reference ~168 distinct model asset ids; any id **not** cached falls through to a
synchronous `InsertService:LoadAsset` **network fetch** — measured at **0.45–1.0s each** vs **0.0005s**
for a local clone. With ~100 uncached, that was a **~26s boot stall** (for owner *and* non-owner alike —
a network fetch is slow regardless of who owns the asset).

The fix: ship the **finished** model folder in the repo so there is **no `LoadAsset` at boot**.

## How it works

- `assets/place/Models.rbxm` is a snapshot of `ReplicatedStorage.Assets.Models`, captured from a
  **fully-booted runtime** (where every model is loaded and processed — welded / normalized / system
  components added). `default.project.json` Rojo-maps it to `ReplicatedStorage.Assets.Models`, so the
  finished models exist in the place from the start.
- `AssetPreloadService:LoadModelIntoFolder` has a fast path: if the target model is **already present
  with geometry**, it early-returns instead of fetching + processing. So the boot model pass becomes
  ~instant presence checks.
- **Self-healing:** a model NOT in the bake (a newly added pet, a changed `asset_id`) simply falls
  through and loads the old (slow) way — correct, just slower for that one model until you regenerate.

## When to regenerate

Regenerate whenever the model roster changes and you want the boot to stay fast:
- you add a pet / egg / breakable, or
- you change a `asset_id` / `mesh_asset` in `configs/pets.lua` / `configs/breakables.lua`.

**How to tell it's stale at runtime:** the boot log shows `LoadModelIntoFolder: Starting …` lines and
the `AssetReport` lists loaded (not skipped) models — those are the ones missing from the bake.

## Regenerate — 3 steps

1. **Boot the game fully** (Play in Studio) and let it finish loading — wait until
   `[EggStandPlacement] placed eggs on N/N` appears, so every model is in `Assets.Models`.
2. In the Explorer, right-click **`ReplicatedStorage.Assets.Models`** → **Save / Export → Save to File**
   → save as `Models.rbxm` (anywhere, e.g. `~/Documents`).
   - MCP `execute_luau` **cannot** write files, so this save is manual. (MCP can still *traverse* and
     *validate* — it just can't export.)
3. Validate, then drop it in and commit:
   ```sh
   lune run scripts/prebake/summarize_prebake.luau ~/Documents/Models.rbxm   # expect EMPTY=0
   cp ~/Documents/Models.rbxm assets/place/Models.rbxm
   git add assets/place/Models.rbxm && git commit -m "chore(prebake): refresh Models cache"
   ```

### Critical: a stale bake SILENTLY KILLS RIGGED PETS

2026-07-14 post-mortem: `assets/place/Models.rbxm` had been committed ONCE
(July 2, initial import) — hours BEFORE the first rigged pet landed. Every
Rojo (re)connect re-served that file at `ReplicatedStorage.Assets.Models`,
replacing every hand-dropped rigged prebake with the static snapshot: bones
gone, AnimationController gone, pets silently fall back to static/code-gait
("no animation at all"). Normal Play/Stop does NOT trigger it — a Rojo
server restart / plugin reconnect does, which is why it looked random
across sessions. THE RULE: any prebake work that exists only in the live
place is ON A TIMER — capture + commit `Models.rbxm` in the SAME session,
or record a deterministic rebuild script. Recovery:
`scripts/studio/rebuild_rigged_prebakes.luau` rebuilds all rigged prebakes
from the uploaded rig assets (run via MCP in Edit, then capture).

### Critical: save from a FULLY-BOOTED RUNTIME, never Edit mode

`InsertService:LoadAsset` content does **not** serialize through an Edit-mode place save — the models
come out **empty** (`parts=0`). The validator flags this (`EMPTY=N`). Always capture the **running**
game's `Assets.Models`, where geometry is materialized.

## Images (thumbnails) — optional, same pattern

`ReplicatedStorage.Assets.Images` holds the pre-rendered pet/egg card thumbnails. These are **deferred
off the boot critical path** already (generated in a background pass after `ModelsReady`), so baking
them is a nicety, not a boot-speed fix. If wanted, save `Assets.Images` the same way and Rojo-map it to
`ReplicatedStorage.Assets.Images`. Re-uses `summarize_prebake.luau` for a sanity check (though Images
are ViewportFrames, not Models, so the empty-check doesn't apply the same way).
