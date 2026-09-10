# Decorative pond fish — asset delivered

Original pearl-and-gold living fish Model107641909625364 uploaded to group15872767. Config is `configs/realm_crossroads_pond_fish.json`; dedicated source/provenance is `assets/source/props/crossroads_pond_fish/README.md`; manifest is `assets/manifest/realm_crossroads_pond_fish.json`. No Studio changes or gameplay code in this asset pass.

Source/export measurements:4716triangles, one material with verified packed1024atlas, dimensions0.85×1.2×3studs. Expected front−Z, up+Y, centered pivot. Blender skin has Root/Tail bones and a smooth distal-body weight transition. Independent FBX import retains both bones, normalized weights and zero UV conflicts; strict geometry checks pass. Tail localZ produces lateral bending. There are no animation clips or animation IDs. Both fish sides/front/top and posed tail were visually inspected.

Local/native inventory and approved [Polyfork fish catalog](https://polyfork.dev/asset/firefish-goby-18d0dd) were checked first. Public repo/license/access constraints made original generation the selected route; no catalog source or derivative is used. Two geometry candidates and exact-input retexture consumed20Meshycredits. Source-local repairs are documented and reproducible without further API jobs.

Await lead native Model/Texture/Bones validation and underwater readability at actual waterY0, fish centerY−0.9…−1.3. Preserve global Terrain watercolor/transparency/reflectance. The intended low-count cosmetic controller should own distance/quality/reduced-motion behavior; this asset does not implement catching, bites, loot, reservations or travel. Do not describe bones as natively functional until that check is recorded.


Native import update: lead temporary ServerPlay load verified one PearlPondFish MeshPart with dimensions0.85000002×1.19999981×3, Mesh86628776776675, Texture92346256478119, and Root/Tail Bones retained. The temporary model was destroyed after query. This closes asset-loading/bone-preservation checks; underwater facing, visibility and live tail motion remain pending. Root's cosmetic controller uses localTailZ oscillation14degrees; no animation clip is asserted.

## Native pond-life installation

The native cache is `ServerStorage.CrossroadsPondFishAssets.PondFish`. The separate `realm_crossroads_pond_life.json` config owns two shallow swim loops, depth, timing, tail bend, quality and distance settings. Its Edit installer validates 96 real water/bed samples before installing the local companion. The retained model has Root/Tail bones; the tail bends about its local Z axis. No animation asset or catch authority is required.

Two fish per nearby pond swim and briefly surface once per approximately45-second circuit; their half-cycle separation produces one visible leap about every22seconds. The short arc makes the existing pearl/gold asset readable through the reflective water. Entry/exit use the existing RBX-FX-GEN pooled WaterRipple module. Underwater and both pond surfacing views were inspected. The current water color, transparency, reflectance, waves and terrain remain unchanged.

Native lifecycle checks: full quality2visible fish, reduced1, off0, far0. Entry triggered1ripple; off and reduced motion cleared ripples. Reduced motion froze the pose underwater atY−1.09955. Tail transform changed between sampled times. Removing the runtime removed all its local fish and its ripple pool; the unrelated fishing-preview pool remained. Repeated cleanup was harmless and the final console was empty.

The config-owned `CrossroadsPondLifePreviewTime` player attribute supports a local artist pose/arc inspection; it was cleared after QA and is not a gameplay trigger. Natural animation timing and foreground performance still require an unlocked/focused Studio review; pose captures and lifecycle tests do not replace that check. Production integration must adapt the preview-only world/quality ownership and must not treat these decorative fish as catchable instances.
