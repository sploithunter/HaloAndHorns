# Normalization & Single-Path Audit

Jason's directive (2026-06): stop re-implementing the same thing N times. Every asset/visual should have
**one** canonical builder — source-agnostic, made once, stored, then just instantiated. This page is the
fine-tooth-comb audit + the consolidation plan. Update it as phases land.

## Principle

> Pull a mesh, pull a texture (or load a packaged Model), make a normalized thing, store it, then
> instantiate it — regardless of source. Same for icons (disc + ring + symbol) and UI widgets
> (pill / fill-bar / card / badge). Fill in details + connect scripts; never rebuild the shape.

## Domain 1 — Models (3D)  ✅ DONE

One path, no parallels left (verified 2026-06-16):
- `src/Shared/Assets/MeshAssembly.lua` — mesh + texture → textured Model (`CreateMeshPartAsync` + `TextureID`).
- `src/Shared/Utils/AssetFetch.lua` — packaged Model loads (`InsertService`, PlaceAssets cache-first).
- `src/Server/Services/AssetPreloadService.lua` — the store: builds everything into
  `ReplicatedStorage.Assets.Models.{Pets,Eggs,Breakables.Crystals}`; consumers clone from there.

Consumers (pets, enemies, gems/drops, eggs, crystals, portals, summons, previews) all route through these.

## Domain 2 — Icons  (~95% consolidated)

Canonical: `src/Client/UI/PetBadge.lua` (disc + ring + symbol) + `configs/power_icons.lua` /
`power_icons_assets.lua` (the generated registry). Remaining leftovers to retire:
- `HotbarBar` re-does ring-centering math instead of `PetBadge.create` (HotbarBar.lua ~604-613).
- `TACTICAL_BADGE` map hardcoded in HotbarBar (~66-68) → move to `configs/power_icons.lua`.
- Legacy flat-icon fallbacks `POWER_ICONS.powers/.status/.actions` → deprecate once all powers have badge art.
- Hardcoded fallback disc ids in `SquadHud` PET_EFFECTS / `EnemyHud` ENEMY_EFFECTS / `EnemyService` HELD_DISC
  → resolve dynamically so a config change propagates.

## Domain 3 — UI components  (bars/cards/badges mostly shared)

Canonical: `OverheadBar` (world fill bars), `HudCard` + `StatusBadges` (combat cards), `PetBadge`
(icon badges), `PetCardStyle` (pet-card chrome), `Pill` (capsule primitive: corner+gradient+stroke,
`button`/`frame`/`applyTo`), `FillBar` (on-screen fill bars). Consolidation targets:

> **Pattern to extract on next use — "icon-pill"** (Jason, 2026-06): round `Pill` + a circular icon
> lapping over the left edge + a value label = the labeled-stat-with-icon capsule. Currency capsules
> are the reference look (CurrencyStyle). Only one consumer today, so NOT yet extracted (avoid a
> one-user abstraction); add `Pill.iconPill` the moment a 2nd stat readout needs it, and retrofit
> currency then. Note: the buff-stats HUD is NOT this — those are FillBar rows.

- 🎯 **`BreakableSpawner` crystal health/boost overhead bars are hand-rolled** (BreakableSpawner.lua
  ~1713-1746) — pets+enemies use `OverheadBar`, crystals don't. NOTE: migrating also means moving the
  breakable bar UPDATE/bind path (it finds Frames named `Health`/`Boost`) onto OverheadBar's
  `fillOf`/`setFraction`, AND keeping authored-crystal billboards working. Careful pass + live verify.
- On-screen fill bars → shared `FillBar` (`src/Client/UI/FillBar.lua`). DONE: QuestPanel tracker,
  EffectsPanel duration, BaseUI on-screen quest tracker. DELIBERATELY LEFT: PlayerBar **XP bar**
  (bespoke — glossy, area-tinted live-recolored gradient + 10-segment level mechanic; a distinct
  widget, not a generic bar), SettingsPanel **slider** (an input control, not a status bar),
  SquadHud **shield bar** (small; migrate when next touched). New generic bars use FillBar.
- **~6 hand-rolled pills/capsules** (AdminController, BootLoader, CurrencyStyle, HotbarBar,
  PowerChoiceMenu, InventoryPanel) → a shared `Pill` component.
- `InventoryPanel` still carries an inline copy of `PetCardStyle` → use the shared module.

## Plan (each phase = its own verified commit)

1. `BreakableSpawner` → `OverheadBar` (create + update + authored-crystal path) + live verify.
2. `FillBar` component → migrate the 5 on-screen bars.
3. `Pill` component → migrate the ~6 capsules.
4. Icon cleanup: `TACTICAL_BADGE` → config; retire flat fallbacks; dynamic effect-table discs.
5. `InventoryPanel` → shared `PetCardStyle`.

Verification per phase: `mise run ci` + a live Studio render check that the migrated surface looks identical.
