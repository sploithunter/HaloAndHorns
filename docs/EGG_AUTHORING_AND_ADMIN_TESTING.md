# Egg Authoring And Admin Testing

This page captures the current config-first workflow for authored egg stands and the admin/testing path for hatch features that do not have a full shop UI yet.

## Egg Authoring Contract

Egg behavior is config-owned. The map supplies a visible object and interaction anchor; Rojo supplies hatch odds, costs, UI behavior, distance checks, animation rules, and entitlement gates.

Configure egg behavior in:

- `configs/pets.lua` under `egg_sources`
- `configs/egg_system.lua` for proximity, hatch count, animation, hatch modes, and UI
- `configs/auto_systems.lua` for hatch-time auto-delete protection

On authored maps, tag the actual player-facing egg/rock part, not the whole decorative hatcher container. For example, the NewWorld map uses:

```text
Workspace.Maps.Home.LegacyEggHatchers.BasicEarth.EggModel
```

Stamp that part/model with:

- CollectionService tag: `EggStand`
- `EggId = "basic_egg"`
- `EggType = "basic_egg"`
- `AreaId = "Spawn"`
- `SpawnId = "BasicEarth"`
- `AuthoredVisual = true`
- `SpawnMode = "authored"`

Use `scripts/studio/stamp_authored_egg_stands.luau` for repeatable setup. Edit the mapping table, run with `dry_run = true`, confirm the exact path, then set `dry_run = false` and save the place.

## Blank Template Fallback

Blank/template maps still need to run without authored art. In `map.mode = "auto"`, the engine can synthesize `EggStand` hooks and spawn configured placeholder visuals when no authored hook exists.

When any authored contract hook is present on a real map, the engine should avoid generating duplicate visible fallback content. That keeps imported maps from getting an extra baseplate, default eggs, or placeholder props on top of the builder's world.

## Proximity And Anchoring

The hatch UI and server validation both use `configs/egg_system.lua`:

```lua
proximity = {
    max_distance = 18,
}
```

If a player has to climb onto a hatcher to trigger the UI, first check that the `EggStand` tag is on the egg/rock interaction part itself. If the anchor is correct but still feels too tight, adjust the proximity config instead of moving gameplay logic into the model.

The hatch billboard and animation should use the authored egg visual when `AuthoredVisual = true`. World scale and animation framing are separate concerns:

- `egg_system.hatching.animation.authored_visual_scale` is the global hatch-animation scale.
- Per-egg animation overrides can live on the configured `egg_sources.<eggId>.animation`.
- The world model can remain the builder's intended size.

## Two-Stage Hatching

Current hatching is two-stage:

1. Roll the pet family/species from the egg source table.
2. Roll the variant, such as Basic, Golden, or Rainbow.

Egg previews should show species in basic form. Golden and rainbow outcomes are hidden variant rolls, not separate map eggs. For a premium/no-basic mode, configure the egg or hatch mode to disallow basic variant rolls and apply the configured cost multiplier. The starter Golden mode currently uses a `20x` cost multiplier.

## Admin Hatch Entitlements

Until the shop/purchase UI exists, hatch capabilities are tested through admin tools and player attributes. `HatchEntitlementService` is the server source of truth.

Normal players currently default to a max hatch count of `3`. The template still supports hatching up to `99`, but higher counts are entitlement values, not free defaults. Use admin tools or a future shop/upgrades flow to set `MaxEggHatchCount` for testing or progression.

Admin panel quick actions currently include:

- `Hatch Unlock Status`
- `Unlock All Hatch Modes`
- `Lock All Hatch Modes`
- `Reset Hatch Unlocks`
- `Toggle Golden Hatch`
- `Toggle Charged Hatch`
- `Set Max Hatch 99`

The custom hatch entitlement input accepts:

```text
entitlement:value
```

Valid entitlement ids:

- `autoHatch`
- `goldenMode`
- `chargedMode`
- `fastHatch`
- `skipHatch`
- `maxHatchCount`
- `luckBonus`
- `secretLuckBonus`

Valid values are `unlock`, `lock`, `toggle`, `reset`, `on`, `off`, `true`, `false`, or a number for numeric entitlements. Examples:

```text
maxHatchCount:25
goldenMode:unlock
chargedMode:toggle
luckBonus:2.5
secretLuckBonus:0.5
skipHatch:reset
```

The player attributes behind those stubs are:

- `AutoHatchUnlocked`
- `GoldenHatchUnlocked`
- `ChargedHatchUnlocked`
- `FastHatchUnlocked`
- `SkipHatchUnlocked`
- `MaxEggHatchCount`
- `HatchLuckBonus`
- `SecretHatchLuckBonus`

Do not make future egg code read these attributes directly. New systems should call `HatchEntitlementService`, so the eventual shop can replace these stubs without changing hatch logic.

## Show Hatch Vs Skip Hatch

`Show Hatch` is a free presentation preference and defaults on. Turning it off hides hatch animations without needing a paid unlock.

`Skip Hatch` is an entitlement-backed hard animation suppressor intended for high-volume auto-hatching. The interaction layer and animation service both honor it so future callers cannot accidentally play a skipped hatch animation.

## Studio Smoke Commands

Run these in Play mode through Studio MCP or the command bar:

```lua
return require(game:GetService("ReplicatedStorage").Tests.studio.EggProximitySmoke).runText({
    eggType = "basic_egg",
    timeoutSeconds = 25,
})
```

```lua
return require(game:GetService("ReplicatedStorage").Tests.studio.EggBatchHatchSmoke).runText()
```

```lua
return require(game:GetService("ReplicatedStorage").Tests.studio.EggAutoHatchSmoke).runText()
```

```lua
return require(game:GetService("ReplicatedStorage").Tests.studio.HatchEntitlementAdminSmoke).runText()
```

```lua
return require(game:GetService("ReplicatedStorage").Tests.studio.EggHatchSimulationSmoke).runText()
```

```lua
return require(game:GetService("ReplicatedStorage").Tests.studio.EggHatchHistorySmoke).runText()
```

```lua
return require(game:GetService("ReplicatedStorage").Tests.studio.EggAnimationContractSmoke).runText()
```

```lua
return require(game:GetService("ReplicatedStorage").Tests.studio.EggAnimationMaxBatchSmoke).runText()
```

```lua
return require(game:GetService("ReplicatedStorage").Tests.studio.EggUnlockSmoke).runText()
```

These smokes intentionally restore profile state after they run. If a result looks impossible, confirm Rojo sync before debugging the egg system.
