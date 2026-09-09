# Trail Pup — adult German Shepherd replacement

The user retained the Trail Pup catalog ID, name and Wayfinder egg slot, requesting an adult
large-breed dog distinct from the existing puppy and Auto Collector dog. ImageGen authored
transparent Basic and Golden concepts in `assets/concepts/pets/trail_pup_shepherd/`.
The concept uses mature shepherd proportions, pointed ears, black/tan markings and a green pack.

Meshy Smart Topology T2 task `01a0880d-d4d8-72eb-85bf-747229ac6258` generated the initial 4k mesh.
Local seam filling left non-manifold junctions, so the final geometry uses a 0.003 diagonal voxel
repair with a 5k triangle ceiling (4,958 triangles). `model_solid.glb` passes the strict closed-mesh
gate. Meshy retexture reapplies each concept to that geometry:

- Basic: `01a08812-5cbb-75ed-b52b-b088da8a78ae`.
- Golden: `01a08812-5cc4-749a-863c-dcda9dd1ecee`.

The initial experimental upload Model 123065965320630 / Mesh 101514841109499 is unused.
The earlier Golden retexture task `01a08810-35b5-724c-9d58-25255b941292` is superseded.
Final exports normalize longest dimension to one stud; runtime scaling remains in pet config.
Basic/Rainbow share the shepherd source, while Golden uses its matching retextured source.

The auto collector now has an independent `drops.auto_collector.visual` source containing the
old dog mesh/texture/scale. DropService builds this template once through MeshAssembly, then
clones it outside PlayerPets. No new inventory pet or hatch variant was introduced for the collector.

## Final group-owned assets and verification

| Variant | Model | Mesh | Albedo Image | UI Image |
|---|---|---|---|---|
| Basic / Rainbow | 124782143082973 | 117920748271522 | 112908745315187 | 108678031613905 |
| Golden | 84445740057707 | 110380464319135 | 126423160315367 | 128345293781447 |

Both final textured GLBs pass the strict geometry gate. `export_fbx.py` imports each final GLB,
extracts its albedo, centers the mesh and normalizes its longest dimension to one stud. Run via
Blender `--background --python export_fbx.py -- <final_basic-or-final_golden-directory>`.
The exported FBX uses baked Y-up coordinates; runtime orientation is zero. Config scale 5.2 gives
Trail Pup 1.893 × 3.797 × 5.2-stud bounds. The user rejected matching AutoDog by height:
its short legs are not the shepherd size reference. The final scale uses body breadth and exceeds
the original 4.4 preview, which the user also considered too small. The auto dog's old
mesh, texture and scale remain unchanged. Basic and Golden icons retain PNG alpha transparency.
Native startup replaced all three old Trail Pup prototypes with their configured new sources.
