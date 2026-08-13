# Models.rbxm mapping is DISABLED (2026-08-13)

`default.project.json` no longer maps `assets/place/Models.rbxm` into
`ReplicatedStorage.Assets.Models`. **This is deliberate and temporary**, for the
duration of the rigged-pet migration (see `docs/wiki/PET_RIGGING_PIPELINE.md`).

## Why

The committed snapshot was captured before most rigged prebakes existed. Every
Rojo re-serve replaced hand-dropped rigged prebakes in Studio with that stale
snapshot — bones and AnimationController gone, pets silently fell back to the
procedural gait (post-mortem in `docs/ASSET_PREBAKE.md`). While dozens of models
are being onboarded, serially re-capturing a multi-MB binary after every batch
is the failure-prone option; unmapping it makes Studio the owner of
`Assets.Models` so drops persist across re-serves.

## Implications while disabled

- Studio owns `ReplicatedStorage.Assets.Models`; whatever is dropped there
  survives Rojo syncs (unknown instances are preserved).
- A fresh checkout / `rojo build` has an empty `Assets.Models`; pets fall back
  to their `mesh_asset` path (the same path 100 of 114 pets already use).
- **Publishing the game place must go through `mise run publish-studio`** (it
  already must — `scripts/release.sh` denylists the game place from
  rojo-upload). release.sh additionally refuses while this file exists.
- The stale `assets/place/Models.rbxm` remains committed but unserved. Do not
  re-add the mapping without re-capturing first.

## Re-enable checklist (after the migration, or before any rojo-upload release)

1. In Studio: run `scripts/studio/rebuild_rigged_prebakes.luau`, Play until
   booted, verify rigged pets animate.
2. Export `ReplicatedStorage.Assets.Models` → save as `Models.rbxm`.
3. `lune run scripts/prebake/summarize_prebake.luau ~/Documents/Models.rbxm`
   → expect `EMPTY=0`.
4. `cp ~/Documents/Models.rbxm assets/place/Models.rbxm`
5. Restore in `default.project.json` under `ReplicatedStorage.Assets`:
   ```json
   "Models": { "$path": "assets/place/Models.rbxm" }
   ```
6. Delete this file. Commit all of it in the SAME commit.
