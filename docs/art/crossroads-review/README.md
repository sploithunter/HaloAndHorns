# Realm Crossroads — premium design review

Design proposals, September 8, 2026. This package audits the current Roblox preview;
it does not authorize every proposed feature or claim that the proposals have been built.
Eight independent section agents each own one design and exactly twenty improvements.

## Current-map evidence

[Open the 37-image screenshot atlas](atlas.html).
The atlas contains overhead, arrival, reverse and player-height views. Click an image
for full size. [Capture manifest](capture-manifest.json) records filenames and camera
coordinates for repeatable comparisons. The distant overview omits some outer scenery;
section captures and current configuration are authoritative for extents.

Screenshots are retained with this review under `screenshots/`.
They are actual current-map captures, not proposed concept renders. A still cannot prove
collision, dynamic FX performance, audience readability or mobile behavior; each plan
calls for relevant in-Studio checks.

## Section ownership

| Section | Design review | Interfaces |
|---|---|---|
| Arrival, central paths and overlook | [01 — Arrival](01-arrival.md) | Both gate approaches, Bragg entry, garden links |
| Heaven / Farm & Fight gateway | [02 — Heaven gate](02-heaven-gate.md) | Arrival, Coin Garden, Bragg-facing route |
| Hell / Pet Siege gateway | [03 — Hell gate](03-hell-gate.md) | Arrival, combat arena, Bragg-facing route |
| Bragg, podiums and Confluence | [04 — Bragg rotunda](04-bragg.md) | Central approach, side terraces, fountain circulation |
| Coin Garden and weekly egg | [05 — Coin Garden](05-coin-garden.md) | Heaven gate, Heaven fishing, gathering terrace |
| Patrol arena and spectator stands | [06 — Arena](06-arena.md) | Hell gate, Hell fishing, audience access |
| Heaven fishing | [07 — Heaven fishing](07-heaven-fishing.md) | Coin Garden, outer landscape, bank circulation |
| Hell fishing | [08 — Hell fishing](08-hell-fishing.md) | Stand rear and ends, outer landscape, mist |

## Lead synthesis

[Coordinated implementation plan](COORDINATED_PLAN.md) resolves shared interfaces,
sets the build order and separates reusable kits from new asset/FX work.

## Shared design rules

1. Preserve the approved gate silhouettes and physical titles, Confluence fountain,
   Heaven-left/Hell-right identity and 24-stud/sec movement. Keep the first mode choice
   immediate. Section working titles are art directions, not automatic player-facing renames.
2. Fix construction and composition before adding FX: fitted paving, complete backs,
   grounded foundations, retaining walls, readable foreground/middle/background layers.
   No decorative slab may conceal an overlapping coplanar floor. Adjacent owners share
   one measured boundary polygon, final surface height and clearance contract.
3. Keep gameplay spaces clear: coin-drop field, arena, entry apertures, fountain loop,
   audience aisle, ten Heaven angler stations and fishing-bank routes. Lighting or color
   cannot be the only navigation cue. Decorations must read with effects disabled.
4. Reuse the native flower, tree, skull, rock, gate and bulwark library first. New organic
   hero props can use ImageGen → Meshy → Blender → Assets → Roblox. Precise pavement,
   stairs, signs, modular walls and mounts should be drafted in Blender/native solids;
   Meshy is not a precision architectural joinery tool. Separate rigid FX/animation pieces.
5. New art, IDs, palettes and tuning remain in config or config-named art companions.
   Prototype inside the existing editable preview; do not open duplicate copies. Live
   travel, rankings, patrol/alliance integration, fishing and reward economy are separate.
6. Local FX should reinforce each destination: Heaven light/petals, Hell gate embers,
   Bragg fluid motion, Hell pond green mist. Avoid eight always-on hero effects fighting
   from one camera. Effects and audio need low-cost and reduced-motion fallbacks.

## Tooling reality

RBX-FX-GEN currently has a native crystal-eruption renderer, deterministic timing,
validated presets, a Studio lab and a limited CombatFX adapter. Its multi-effect editor,
production integration and mobile budgets are unfinished. The agents may adapt its
preview/preset architecture; the package is not a ready-made generator for arbitrary
water, fog, rewards or portals. Native particles, beams, trails, mesh layers and local
lights are the practical building blocks. Source: the project's CURRENT_STATUS,
ARCHITECTURE and VISION wiki pages inspected during this review.

Section budgets and effort estimates are proposals, not measured capacity or delivery
commitments. They must be reconciled at whole-map scale before implementation.

## Small new effects are in scope

The user explicitly supports modest new effects in RBX-FX-GEN.
[Small-effect implementation backlog](FX_IMPLEMENTATION.md) identifies reusable ambient,
ripple, glint and burst additions and their minimal pipeline work. The current crystal-only
scope is a factual starting point, not a restriction on creative designs.

## Implemented construction

The R11 native pass is tracked in [implementation status](IMPLEMENTATION_STATUS.md).
[Gameplay integration](GAMEPLAY_INTEGRATION.md) specifies the disabled authored stubs
and required production code. These documents distinguish actual work from the 160
original review recommendations; the pre-build atlas remains unchanged.
