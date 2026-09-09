# Outer safety boundary — measured Edit audit

Read-only audit of the current isolated preview. No camera, mode, collision or geometry changes. The active boundary is solely `Workspace.RealmCrossroadsR4.CrossroadsFishingR10.InvisibleIslandBoundary`; older landscape/leisure boundaries are archived outside Workspace by the fishing baker.

## Native coverage

All12 OuterSafetyWall Parts are transparent, collidable, Default collision group, width4, height100, centered atY18: vertical extent **−32 to68**. Default collides with Default; all current collidable map parts use Default.

| Wall | Horizontal centerline endpoints (X,Z) |
| --- | --- |
| 1 | (−176,−134) → (−154,−156) |
| 2 | (−154,−156) → (154,−156) |
| 3 | (154,−156) → (176,−134) |
| 4 | (176,−134) → (296,−88) |
| 5 | (296,−88) → (296,104) |
| 6 | (296,104) → (176,134) |
| 7 | (176,134) → (154,156) |
| 8 | (154,156) → (−154,156) |
| 9 | (−154,156) → (−176,134) |
| 10 | (−176,134) → (−296,104) |
| 11 | (−296,104) → (−296,−88) |
| 12 | (−296,−88) → (−176,−134) |

Native positions, orientations and lengths agree with the fishing boundary config. Each length is endpoint distance+4, extending2studs beyond both vertices; its4-stud width and neighboring extension cover the joins. No open terminal exists. These are deliberate overlapping collision walls, not rendered coplanar surfaces.

**1,080 radial raycasts** (every degree around the full loop atY4,20,60) hit the boundary with zero misses. This confirms sampled continuous horizontal collision coverage, including the expanded Heaven/Hell pond flanks, not merely the original smaller island.

## Ground, jump and prop checks

440 Terrain rays sampled the boundary approximately every8studs, at inward offsets4 and12. All found terrain; measured surface heights ranged **−4 to12**. Thus no sampled approach drops beneath the wall bottom before contacting the barrier. Fishing extension config bottom−24 also sits above the boundary bottom−32. Pond swimming does not provide an under-wall opening at the current authored water/bottom elevations.

Highest collidable map-part world corner isY28.2044 at the FarmAndFight Arch. Highest collidable part with center within24studs of the wall isY19.6000 at Bragg Alcove06.Cornice,23.1793studs from the wall. Current StarterPlayer uses JumpPower50 at gravity196.2: ideal unconstrained ballistic rise≈6.371studs. Even the globally highest measured collider plus this rise remains over33studs below the wall top. Terrain near-boundary maximum12 gives56studs of wall above that ground. A normal authored jump cannot clear this boundary from measured structures.

All collidable map-part centers lie inside the loop. All visible BasePart centers also lie inside; zero props with centers beyond the barrier were found. This does not certify every tree crown/mesh vertex lies inside, nor is decorative foliage overhang itself an escape route. No new route exit or intentional gap exists in this closed polygon.

## Source authority and limitations

`realm_crossroads_fishing.json.boundary` supersedes the leisure/landscape loops. `bake_fishing.luau` clones the prior boundary template and extends each wall at both ends. Width/height/Y are inherited from that native template rather than specified in the fishing JSON; an importer must preserve the measured template or supply an explicit reviewed replacement. Rebuilding against an arbitrary template would not reproduce this audit.

No concrete gap or reachable over/under-wall route was found. This is a geometric/native collision audit, not an exhaustive character movement proof. It does not test future dash/flying abilities, teleports, non-Default player collision groups, intentional physics exploits, spawn outside the polygon, or production map relocation. The ground rays are finite samples and cannot certify every terrain voxel. Preserve safety-wall collisions separately from participant-only arena containment.
