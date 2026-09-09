# Crossroad Chest

Built-in ImageGen created `assets/concepts/crossroads/crossroad_chest.png` from the silver
paw coin reference. Prompt: a single closed low-poly navy wooden treasure chest, chunky silver
bands and beveled corners, matching silver paw medallion lock plate, domed lid; friendly bright
Roblox game art. Front three-quarter view, transparent PNG alpha, no floor/shadow or loose coins.

Meshy Smart Topology T2 task `01a087de-3707-7039-ae8c-7a72d2ddb00a`, 2,000-triangle target,
texture enabled, GLB/FBX. Source mesh had two open loops (31 boundary edges). The existing
`repair_mesh_integrity.py` filled them while retaining UVs. `model_repaired.glb` passes the
strict geometry gate with 2,122 triangles and no open or non-manifold edges. The final FBX
normalizes width to 0.01 meters so Roblox's import produces a one-stud-wide base; configured
3.5/5 scales are the final chest widths. No geometry regeneration or albedo replacement occurred.

Project group 15872767 owns final Model 127175449944140, Mesh 109255393121052.
UV albedo Decal 138956208263121 resolves Image 125784646482090. Model 95971086818996 was an
intermediate pre-repair upload and is unused. Config uses only the repaired model.

Native check: final imported base is 1 × 0.839844 × 0.675782 studs; all 12 spawned targets sat exactly on the floor at Y=4.38. Pet mining released currency; unmined chests did not.
