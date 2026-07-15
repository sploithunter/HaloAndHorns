# Roblox bug report draft — Studio session cache renders valid meshes as corrupted

Paste-ready for devforum.roblox.com (Bug Reports → Studio Bugs) or a
support ticket. Attach screenshots from the saga (Studio-shattered vs
production-clean of the same place version).

---

**Title:** Studio viewport renders valid MeshParts as shattered/kaleidoscope
geometry; persists within a session; cleared by restarting Studio

**Summary:** During long Studio sessions with heavy asset churn (many
InsertService:LoadAsset / AssetService:CreateMeshPartAsync /
CreateEditableMeshAsync calls, large places), previously-fine MeshParts
begin rendering as torn/shattered geometry with smeared UVs — looking
exactly like a corrupted asset. The asset is NOT corrupted:

- The same place, published and played in the production Roblox client,
  renders perfectly (verified against place version history — property
  dumps identical between "clean" and "corrupted" versions).
- create.roblox.com asset previews render correctly.
- `AssetService:CreateEditableMeshAsync` returns identical vertex data
  (hash-verified) before and after the visual "corruption".
- Fully quitting and reopening Studio clears the corruption with no
  place or asset change.

**Impact:** We spent a week and four full re-uploads of a 20-asset decor
set chasing what looked like server-side asset corruption ("meshes rot
hours after upload"). Different upload lanes (Open Cloud API, Studio 3D
Import), seam-split geometry, and skinned-vs-static packaging all
appeared to matter — all of it was this Studio rendering artifact. The
failure mode strongly imitates asset/CDN corruption and will mislead any
developer who trusts the Studio viewport.

**Repro (as best we can tell):**
1. Long-running Studio session (hours) on a large place; repeatedly load
   many mesh assets (LoadAsset / CreateMeshPartAsync / EditableMesh).
2. Observe some textured MeshParts begin rendering shattered (torn
   shells, degenerate spike triangles, smeared UVs). Untextured/grey
   rendering of the same mesh often looks fine.
3. Publish the place → production renders correctly.
4. Quit + reopen Studio → same place renders correctly.

**Environment:** macOS (Apple Silicon), Studio version current as of
2026-07-15. Place: large (300+ mesh assets, StreamingEnabled). Corruption
observed across group-owned assets uploaded via both Open Cloud
(assetType=Model, model/fbx) and Studio 3D Import.
