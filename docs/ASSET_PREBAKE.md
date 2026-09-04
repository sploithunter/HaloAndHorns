# Asset Pre-Baking (boot speed)

## Why

At boot, `AssetPreloadService` populates `ServerStorage.Assets.Models` (pets / eggs / breakables).
The configs reference ~168 distinct model asset ids; any id **not** cached falls through to a
synchronous `InsertService:LoadAsset` **network fetch** — measured at **0.45–1.0s each** vs **0.0005s**
for a local clone. With ~100 uncached, that was a **~26s boot stall** (for owner *and* non-owner alike —
a network fetch is slow regardless of who owns the asset).

The fix: ship the **finished** model folder in the repo so there is **no `LoadAsset` at boot**.

## How it works

- `assets/place/Models.rbxm` is a snapshot of `ServerStorage.Assets.Models`, captured from a
  **fully-booted runtime** (where every model is loaded and processed — welded / normalized / system
  components added). `default.project.json` Rojo-maps it to `ServerStorage.Assets.Models`, so the
  finished models exist on the server from the start without retaining all texture references on
  every client.
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
   `[EggStandPlacement] placed eggs on N/N` appears, so every model is in the server catalog.
2. In the Server Explorer, confirm there is exactly one **`ServerStorage.Assets.Models`** folder and
   no `ReplicatedStorage.Assets.Models`. A legacy replicated folder may survive an older place save;
   merge any newer content into the server copy, then delete the replicated folder before publish.
   Right-click **`ServerStorage.Assets.Models`** in the running server DataModel → **Save / Export →
   Save to File** → save as `Models.rbxm`
   (anywhere, e.g. `~/Documents`).
   - MCP `execute_luau` **cannot** write files, so this save is manual. (MCP can still *traverse* and
     *validate* — it just can't export.)
   - After you drop the sanitized file into the repo, delete any leftover Studio `Models` in **Edit**
     so Rojo owns the only copy. `Images` and `Sounds` can stay; they are not Rojo-mapped.
3. Sanitize runtime caches/duplicate Studio copies, validate, then drop it in and commit:
   ```sh
   mise exec -- lune run scripts/prebake/sanitize_prebake.luau ~/Documents/Models.rbxm /tmp/Models-clean.rbxm
   mise exec -- lune run scripts/prebake/summarize_prebake.luau /tmp/Models-clean.rbxm
   # expect ASSET_ROOTS ... EMPTY=0 and RIGGED_ASSET_ROOTS ... invalid=0
   cp /tmp/Models-clean.rbxm assets/place/Models.rbxm
   git add assets/place/Models.rbxm && git commit -m "chore(prebake): refresh Models cache"
   ```

The sanitizer removes the runtime-generated `MissionTiles` cache and resolves duplicate asset paths
left by repeated Studio rebuilds. When duplicate folders exist, it merges their unique children before
keeping the newest copy, so static Golden/Rainbow catalog variants are not lost. The validator uses
Lune 0.10.5 because current Studio exports contain properties older Lune versions cannot deserialize.

### Critical: a stale bake SILENTLY KILLS RIGGED PETS

2026-07-14 post-mortem: `assets/place/Models.rbxm` had been committed ONCE
(July 2, initial import) — hours BEFORE the first rigged pet landed. Every
Rojo (re)connect re-served that file as the canonical model catalog,
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
come out **empty** (`parts=0`). The validator flags this under `ASSET_ROOTS ... EMPTY=N`; empty nested
organizational models are informational. Always capture the **running server's** `Assets.Models`, where
geometry is materialized.

## Images (thumbnails) — optional, same pattern

`ReplicatedStorage.Assets.Images` holds the pre-rendered pet/egg card thumbnails. These are **deferred
off the boot critical path** already (generated in a background pass after `ModelsReady`), so baking
them is a nicety, not a boot-speed fix. If wanted, save `Assets.Images` the same way and Rojo-map it to
`ReplicatedStorage.Assets.Images`. Re-uses `summarize_prebake.luau` for a sanity check (though Images
are ViewportFrames, not Models, so the empty-check doesn't apply the same way).
