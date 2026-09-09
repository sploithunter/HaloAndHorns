# Native replay and checkpoint source contract

Run from the repository root. These offline tools never open Studio, run installers, regenerate geometry, or update installed runtime clients. Keep the existing native backup before the lead replays the registry against the already-open unpublished Edit preview.

1. Refresh each ServerStorage registry ModuleScript/Config StringValue from the checked-in files. Preserve all native asset caches and authored original backups. Avoid requiring a previously cached ModuleScript function after changing its Source; use a fresh module instance for the replay.
2. Apply `configs/realm_crossroads_polish.json.application_order` to the existing `Workspace.RealmCrossroadsR4`. Every pass receives `(world, decodedConfig)`. Supply these four additional arguments from their config-named files:

| Config field | Pass | Third argument |
| --- | --- | --- |
| `font_source` | Fishing wayfinding | Decoded glyph JSON |
| `bundle_source` | Visual FX | Decoded ambient bundle JSON |
| `client_source` | Pond life | Raw client Luau source string |
| `client_source` | Interaction preview | Raw client Luau source string |

After this archive exists, those same values are available as inert StringValues under `ServerStorage.CrossroadsAuthoringInputs/<registry module name>/<config field>`. Decode the two JSON values; pass client Value strings directly. Each entry records `SourcePath` and `PayloadKind`. The `Registry` StringValue preserves the complete ordered registry. The archive is authoring data, never client runtime code.

3. Confirm the native replay reports, including the accepted300pavers. Core/preview passes are not transactionally isolated: do not continue past a failure and call that a successful full replay. Recheck station tips/water, bound barrier pivots and actual walk/collision behavior separately.
4. Exclude/remove the temporary `ServerStorage.CrossroadsReplayBackup` snapshot from the final export; retain the smaller authored per-pass original caches/backups. The validator rejects that temporary whole-world backup. Serialize a **fresh** native model payload using the existing lead-owned SerializationService export process. Include Terrain, the authored world, Lighting, ServerStorage caches/backups/installers, ReplicatedStorage runtime folders, and StarterPlayerScripts. Give the joined native payload an explicit file name; do not assume an old `native-r4-export.rbxm` is fresh.
5. Wrap that fresh payload and archive current sources:

```sh
mise exec -- lune run tools/realm_crossroads/save_native_terrain.luau --input output/realm_crossroads/native-r11-export.rbxm --output assets/source/maps/realm_crossroads/RealmCrossroads-R11.rbxl
mise exec -- lune run tools/realm_crossroads/validate_checkpoint.luau --expected-pavers 300
```

The wrapper keeps the existing raw-export service-folder convention. Its legacy default input/output remain R4 paths for compatibility; use explicit paths for R11. The registry's `native_checkpoint` selects the validator's default checkpoint. Source synchronization does **not** prove the native export was produced after replay. The validator compares installed runtime sources/configs to disk and rejects stale client code rather than replacing it.

For an existing native checkpoint that only needs the supplementary source archive added, write a separate candidate first:

```sh
mise exec -- lune run tools/realm_crossroads/save_native_terrain.luau --place-input assets/source/maps/realm_crossroads/RealmCrossroads-R11.rbxl --output /tmp/crossroads-source-validation.rbxl
mise exec -- lune run tools/realm_crossroads/validate_checkpoint.luau --checkpoint /tmp/crossroads-source-validation.rbxl --expected-pavers 300
```

`--place-input` preserves native geometry, Terrain, services and Lighting; it refreshes authoring sources/payloads only. If installed runtime checks fail, replay the appropriate installers in the existing native preview and export again. Do not patch the candidate's runtime source to make a stale export appear fresh.

Validator coverage: every registry ModuleScript source, decoded config, archived registry and supplementary byte string; FX modules/config and generated literal client; pond/preview client sources and decoded runtime config; measured pond waterline presence; configured native cache/template inputs; fish Root/Tail Bones; unique named runtime containers/scripts; nativeTerrain,300pavers, no legacy GreenPoolMist or ArenaSightlineQA. It is a source/structure audit, not a native physics/render/performance test. The accepted paver count is an explicit CLI acceptance input, so the validator embeds no art tuning default.

Regression checks create deliberately broken copies only in the supplied scratch directory:

```sh
mise exec -- lune run tools/realm_crossroads/test_checkpoint_validation.luau /tmp/crossroads-source-validation.rbxl /tmp/crossroads-checkpoint-negative-tests
```

The tests must reject stale installer source, supplementary client payload, installed client source, missing fish cache template, and a missing paver. Do not overwrite the real checkpoint with a negative-test fixture.
