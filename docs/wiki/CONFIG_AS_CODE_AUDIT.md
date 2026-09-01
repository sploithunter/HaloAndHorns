# Configuration-As-Code Audit

Status: current as of 2026-09-01. Tracking: [issue #343](https://github.com/sploithunter/HaloAndHorns/issues/343).

## Enforced boundary

Runtime code under `src/` must not own content asset identifiers or silent numeric defaults for
configuration/tuning. Asset IDs belong in `configs/` or a config-named manifest. Gameplay and
presentation tuning must come from validated config or fail through an explicit required-value
contract.

`scripts/architecture_guard.py` now scans every tracked Lua/Luau runtime file and ratchets two
reviewed inventories:

- `runtime-asset-literal`: 133 existing 8+-digit literals across 33 files.
- `numeric-tuning-fallback`: 1,641 existing `config/tuning lookup or <number>` fallbacks across 239
  files.

The exact per-file counts are checked into `scripts/architecture_allowlist.json`. New files, moved
debt, or increased counts fail CI. A cleanup must reduce the matching budget in the same change.

## First completed remediation slice

Merge cannon and bulwark tier identity now comes from generated `configs/merge_tier_art.lua`, whose
inputs are the three committed art manifests. Menus, model cloning, and stale-instance replacement
consume that same config table. The generated `scripts/merge_tier_runtime_manifest.json` records all
24 cannon mappings, all 24 bulwark mappings, and all 24 bulwark preview mappings.

The duplicated bulwark combat tables were removed from `MergeBulwarkProgression`; all tier values
now come from `configs/merge_egg_prototype.lua` and fail loudly when absent. Cannon shot timing,
range, healing/rage tuning, and Land Shark movement values touched by this slice follow the same
required-config rule.

## Priority debt

The largest tuning-fallback owners are `MergeEggPrototypeService` (213), `EnemyService` (168),
`MergeEggRealmBuilder` (57), `PowerService` (55), and `EggHatchingService` (47). The largest
asset-literal owners are `DecorFingerprints` (40), `LandmarkAssets` (18), `CurrencyStyle` (7), and
`ConfigLoader` (7). These counts identify migration order; they do not imply every match is a
gameplay defect. Each value still needs classification as content/tuning, algorithmic constant, or
an explicit engine/test boundary before it is changed.
