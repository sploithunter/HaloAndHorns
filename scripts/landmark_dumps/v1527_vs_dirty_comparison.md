# Landmark dump: Place1 v1527 (good) vs Halo and Horns (dirty)

Compared 2026-07-15 via Studio MCP on both open places.

## Verdict

**No property differences** on Heaven_2 cathedral + mission gate MeshParts.

Fingerprints (MeshId, TextureID, Size, MeshSize, Position, Orientation, Anchored, CanCollide, CollisionFidelity, RenderFidelity, Color, full SA maps, AlphaMode) are **byte-identical** across all 8 parts.

Also identical:
- Scale ≈ `43.597` (Size / MeshSize)
- Bounding box sizes
- Model attrs (`CanonicalModelAssetId`, `CanonicalMeshId`, etc.)
- Other parts (BeamCore, door, hosts…)
- Welds: **none on either**
- Lighting Ambient / OutdoorAmbient / Brightness / ClockTime / kids
- EditableMesh on cathedral `part_00`: **9400 verts, 9999 faces, 9400 UVs** (both)

## Ruled out

| Hypothesis | Result |
|---|---|
| Different MeshIds | Same |
| Different ColorMaps / PBR | Same |
| Slightly bigger | Same Size + MeshSize |
| Welds / unanchored | Both anchored, 0 welds |
| CollisionFidelity | Both PreciseConvexDecomposition |
| Lighting env | Same values checked |

## Implication

Serialized place properties do not explain good-vs-shred. Remaining candidates:
1. Dirty place may already be fixed after SA/TextureID restore — re-check visually
2. Instance-local MeshPart state not exposed as properties → replace parts by copy-paste from v1527
3. Studio session / render cache on the dirty window
