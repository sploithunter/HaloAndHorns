# Bragg first construction pass

2026-09-08. Authored source is ready for root-agent inspection and application. No Studio tool was called by this section agent. Static analysis passed; native appearance, boolean execution, figure count, collision and repeated application still require the root's existing-preview checks.

## Files and exact application contract

- `configs/realm_crossroads_polish_bragg.json` — revision-one art/tuning, palette, named model contract.
- `tools/realm_crossroads/polish_bragg.luau` — ModuleScript-shaped source returning `function(world, cfg)`.

Run only in Edit, against the existing `workspace.RealmCrossroadsR4`. Decode the JSON into `cfg`, load the Luau as a ModuleScript with the root's normal code-loading path, then call:

```lua
local stats = require(polishModule)(workspace.RealmCrossroadsR4, cfg)
print(game:GetService("HttpService"):JSONEncode(stats))
```

Expected preconditions: `BraggRotundaR6.PodiumAlcoves`, `.TerraceAndEntry.CircularCourt`, native bay `RearWall`/`Cornice`/`Podium1..3`/`PodiumCap1..3` names. Expected figures: direct Model children of `BraggRotundaR6.PodiumHeightDummies`, 24 in total. Missing root/floor structure fails clearly; unknown bays skip with warnings; absent/wrong figure count returns a warning for root to resolve before claiming completion. This pass does not discover or open a new Studio place.

Run after the existing Bragg bake and other geometry/paving passes. A future whole-Bragg rebuild destroys its output and local backup, so reapply after that rebuild. **Do not run the whole terrain/Bragg builder just to apply this polish.** Root retains ownership of shared baker ordering and any art in neighboring sections.

Returned statistics: `figures`, `bays`, `cornerClosures`, `floor`, `warnings`. Nominal results should include 24 figures and 14 bays; exact closure count depends on actual joints and configured distance guard. A closure is only created between numbered consecutive bays, never across the intentional entry.

## What is built

- A true cut-in four-stud-wide stone promenade at radius 34–38 replaces the two thin raised gold rings. Original court material is cut out of exactly the same annular volume; the runner's top matches the original floor. This is disjoint geometry, not a surface overlay.
- Three Edit-time `SubtractAsync` operations prepare the runner/cutter/court before replacing anything. A failure destroys only temporary CSG and errors before original floor removal. Geometry is not generated in Play. The original disk and old ring pieces are retained invisibly/noncolliding under `BraggCraftsmanshipBackup` for repair.
- Fitted corner infills span short adjacent rear-wall gaps, limited to less than six studs; under-height supported cornice connectors bridge those same joints. They do not bridge the main opening or intentionally broad routes. Native inspection must establish whether all inferred rear gaps need the closures.
- Every existing column gains a stone foot and a restrained bronze collar. Existing podium bodies/caps gain a coherent stone/metal palette and a low bronze foot. Their dimensions, 2/1/3 layout, existing rank numerals and figure placement do not change.
- Existing native flower/skull beds gain grounded feet; no replacement flower, skull or fountain mesh is fabricated. Existing wall/inset/cornice materials become coherent ivory/stone with dark Hell exhibits.
- All 24 preview figures receive consistent BodyColors and matching authored part materials, resolving the black-on-Play source issue rather than applying an every-frame recolor. No figure transform changes. Existing Humanoids are retained, without new runtime behaviors.
- Twenty-four invisible noninteractive anchor hosts store stable rank/BoardId/PreviewOnly metadata. Their Attachments represent cap-top transforms. No CollectionService tags, leaderboard calls, scores, production hooks, profile fields or audience population are enabled.

All palette/material edits record original Color/Material attributes once. BodyColors record original per-region values. The output Model is replaced on rerun, preserving original-name hosts and original placement. Floor is rebuilt from the preserved original, preventing cumulative boolean subtraction. Backups live under the Bragg model, hidden/noncolliding; do not unhide them while comparing because that would deliberately create overlapping floors.

## Coverage of the 20 design items

| Item | First pass status |
| --- | --- |
| 01 Fitted court | Partial: clean inset annulus and removed raised rings. Full radial paver/joint mesh kit remains. |
| 02 Ceremonial threshold | Deferred; arrival interface unchanged. |
| 03 Gallery promenade | Partial: readable four-wide annular stone lane, open center preserved. Six-wide design and flush medals remain for spatial review. |
| 04 Preview champions | Implemented source: proper BodyColors plus readable neutral clothing; poses remain unchanged. Native Play check pending. |
| 05 Crafted podiums | Partial: coherent metal caps and bronze feet. Bevel/flute mesh and medals remain. |
| 06 Plaques | Deferred; existing physical PREVIEW copy unchanged, anchors prepared only. |
| 07 Category heraldry | Deferred; eight icons need art generation/modeling review. |
| 08 Title hierarchy | Deferred; player-facing labels/scope preserved exactly. |
| 09 Supported crown | Partial: column feet/collars and short corner supports; complete custom mitered mesh kit remains. |
| 10 Rear slots/exterior | Partial: guarded short corner infill and material unification. Root must inspect camera/collision and exterior. |
| 11 Heaven exhibits | Partial: bed footing; all native flowers preserved, compositions unchanged. |
| 12 Hell exhibits | Partial: dark material and footing; native skull/lantern geometry preserved. |
| 13 Exhibit life | Deferred to aggregate FX-budget pass. |
| 14 Portrait lighting | Deferred; evaluate repaired figures before adding lights. |
| 15 Fountain setting | Partial: stronger surrounding court composition. Fountain silhouette, mesh, pivot, nine falls and scrolling mask geometry untouched. |
| 16 Contact FX | Deferred. |
| 17 Fountain audio | Deferred pending audio catalog/shared mix. |
| 18 Social benches | Deferred; no clutter added to current circulation. |
| 19 Landscape skirt | Deferred to shared landscape coordination. |
| 20 Confluence sequence | Deferred; optional after the aggregate FX budget. |

## Required native review before accepting

Apply once and inspect returned warnings. Inspect the new annulus from a grazing camera angle and walk across its inner/outer edges at 24 studs/s. Check CSG triangle/collision cost in the actual place: PreciseConvexDecomposition is used for correct ring holes, so root may substitute collision geometry after verifying the visible cut. Verify fountain height and motion are unchanged, and all 24 figures have correct colors after starting Play. Inspect rear joints and principal entrance from both sides; close-joint filling is not a substitute for a camera sweep. Apply a second time in Edit and verify no instance-count growth, unchanged figure pivots, and no duplicate rings/hosts.

Run validation performed here: `mise exec -- stylua tools/realm_crossroads/polish_bragg.luau`, then `mise exec -- selene tools/realm_crossroads/polish_bragg.luau` → zero errors, zero warnings, zero parse errors. JSON was parsed and reserialized with Python. No live native/Play results are claimed.

## Revision 3 floor isolation after native QA

A radius35 east ray still found a double collision hit after the taller inner cutter change, although the screenshot appeared clean. Revision3 removes the ambiguity by separating the court into three connected CSG pieces. `TerraceAndEntry.CircularCourt` is now the outer ring only; `BraggCraftsmanshipR1.FittedInnerCourt` is the central disk; `FittedViewingPromenade` remains the annulus between them. All visible surfaces retain their original colors and Y4.44. The original full disk backup remains unchanged, and reruns still replace the generated output cleanly. This supersedes descriptions above that assume the court remains one compound disconnected union. Return `floor` now reads `three_disjoint_court_solids`. See NATIVE_QA.md for the native evidence and final application status.
