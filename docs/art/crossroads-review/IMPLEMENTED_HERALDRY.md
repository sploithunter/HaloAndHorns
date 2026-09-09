# Arrival seal and native Bragg heraldry

2026-09-08. Source ready; root owns Edit application. This agent made only read-only Client queries during Play for current positions/native mesh bounds. No live mutation or asset upload.

## Exact contract

Config `configs/realm_crossroads_polish_heraldry.json`; ModuleScript-shaped source `tools/realm_crossroads/polish_heraldry.luau` returns `function(world,cfg)`.

```lua
local result = require(module)(workspace.RealmCrossroadsR4, cfg)
print(game:GetService("HttpService"):JSONEncode(result))
```

Run in Edit **after** shared core and Bragg geometry/polish passes. Requires `CrossroadsCraftR11.ArrivalSeal.SealInset` (or its prior retained backup) and `BraggRotundaR6.PodiumAlcoves`. Native Client query measured current seal center (0,0.29,100), radius3.75, thickness0.3, top0.44; cornice top19.6. Config matches these measured values. The original `SealRing` and `SealSurround` pieces are never changed.

Generated output `workspace.RealmCrossroadsR4.CrossroadsHeraldryR1`. Only the replaced original `SealInset` moves to `ServerStorage.CrossroadsHeraldryBackup`. All CSG/emblem preparation completes before that move or removal of previous output. A failure destroys the temporary assembly and preserves the live inset/current output. Reapplication computes from the original inset and replaces output, avoiding cumulative cuts. If core is rebuilt first, a fresh `SealInset` takes priority and supersedes the backup after successful preparation.

## Arrival seal

Three fitted visible pieces replace one blank inner disk:

- Negative-X ivory Heaven stone.
- Positive-X dark Hell stone.
- A bronze compass cross and central meeting diamond, plus geometric feather strokes left and cleft horn strokes right.

The strokes are abstract architectural inlay, not fabricated pet meshes or typography. Four booleans: unite all metal strokes; subtract that union from the disk; split remaining disk into west/east halves. Every rectangular motif corner is validated within the inset radius before CSG. No new top face rests on the old disk: it is removed only after all three disjoint replacements exist. All three have the same top0.44 and simplified static authored behavior. Existing outer gold ring, fitted surrounding pavers and invisible spawn remain unchanged. No glow, prompt, pulse or runtime geometry.

## Bragg category sculptures — revision 3 completes the eight identities

The same small cornice-top envelope is used for all eight existing categories. The first three remain unchanged; the next three reuse actual Farm assets copied by the root into `ServerStorage.CrossroadsHeraldryAssets`; the two wave emblems are controlled Blender reliefs authored through the existing native glyph/CSG technique.

| Existing BoardId | Actual visual source | Orientation |
| --- | --- | --- |
| crystal_crusher | Cached pearl_quartz | yaw0 |
| eggs_hatched | Cached wayfinder_egg | yaw180 |
| bosses_defeated | Cached animal_skull | yaw180 |
| most_dragons | Farm `ServerStorage.PlaceAssets.120821607721730.Dragon`, native pet Model asset120821607721730 | yaw180, confirm face from promenade |
| enemies_defeated | Farm `ServerStorage.MissionProps.CrossedSwords`, existing shield and crossed sword assembly | yaw180 |
| team_power | Farm `ServerStorage.MissionProps.WallShieldOrnate`, actual ornate armor shield | yaw180 |
| siege_highest_wave_cleared | `WavePeakRelief`: one flowing wave beneath an upward chevron, within bronze medal | native front+Z / yaw0 |
| siege_waves_cleared | `WaveTotalRelief`: three stacked flowing wave strokes within bronze medal | native front+Z / yaw0 |

Stacked wave strokes denote accumulation, not a score or assertion that three waves were cleared. The single wave with up-chevron denotes highest cleared. The existing complete titles/scope remain the authoritative labels; no highest-reached/cleared conversion or fake counts.

Source library inspection measured Dragon5.993×3.141×2.820, CrossedSwords5.189×7.168×1.666 and WallShieldOrnate5.167×8.933×0.939. Root copied those native Models by serialization without modifying the source Studio. No generic primitive pet or invented weapon replaces the real art. Common bounds fit still limits height2.4/width3/depth2.4 and total roof height23. Assets are stripped of scripts/prompts/tags before placement; all podiums and title geometry remain unchanged. Missing assets or insufficient mounting bounds return explicit skips rather than placeholders.

### Reproducible Blender wave relief pipeline

Added `tools/realm_crossroads/build_wave_heraldry.py`, authorized as the dedicated recipe. Geometry parameters live in `emblems.relief_recipe`; the Python reads them, builds two planar stroke silhouettes and triangulates with Blender's geometry library. It writes 52 peak triangles and144 total triangles to `emblems.relief_geometry` in this same config, plus a local source scene at `output/realm_crossroads/heraldry-wave-reliefs.blend`. The latter is a contour/extrusion review scene, not a rendered proof of Roblox appearance.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/realm_crossroads/build_wave_heraldry.py
```

The Edit baker uses the already established crest glyph triangle-to-WedgePart extrusion algorithm, unions each shape into one noncolliding relief, and mounts it on a recessed dark face within a solid bronze rim. Temporary triangle pieces are destroyed. Relief intersects its face slightly, with distinct visible depth; it is not coplanar lettering. Rim inner cuts use a taller cutter than the visible rim. This requires no new image, external upload, font, ImageGen or Meshy generation, while retaining Blender-controlled exact geometry. The wave motifs are abstract architectural symbols, not pets.

All eight use the existing cornice guards: header clearance0.2, sufficient base width/depth, and top<=23. Any unclear facing/clutter in the actual native view must be corrected in config before acceptance. No production tags, ranking data or interactions are introduced.

## Results and review

Returned table: `sealParts` (expected3), `emblems` (up to8), `skipped` with reasons. No external dependency is inferred from a skipped asset; report it explicitly. Approximate additions are three floor unions, eight tiny mounts, six native models and two small authored medals, minus the old disk. No extra lights, particles, Humanoids or client loops.

StyLua and Selene executed on the owned source: zero errors/warnings/parse errors. JSON parsed with Python. Native application is not claimed.

Root native checks: top-down and eye-height seal capture; verify gold strokes read as one design, ivory is left/negative-X, dark is right/positive-X, and no metal reaches into the retained outer ring. Orbit at shallow angle to check no blinking. Walk all cardinal/diagonal crossings at24. Inspect all eight emblem bays from the promenade and the entrance, ensuring no title overlap or odd asset orientation; skip/remove an emblem if it appears cluttered despite numeric checks. Reapply once in Edit, compare counts, unchanged routes and figure transforms. Shared frame-time/FX budget is unaffected by new animation because none is introduced.

Revision3 source checks: Blender5.1.2 recipe completed (52/144 triangles), Python compilation passed, and StyLua/Selene returned zero errors/warnings/parse errors. Root has imported the three additional native cache assets. Eight-emblem native application and screenshot review remain pending at this handoff; the earlier three-emblem map result is not treated as evidence of this expanded pass. All revision2 tall seal-cutter fixes are retained.

## Revision 4 — wave medal orientation correction

Root's native close review found both wave medals edge-on. Read-only inspection confirmed their local bounds were approximately0.303×2.4×2.4 and the rim's local-X normal aligned with the cornice's local-X axis. The authored relief was being normalized through a noncanonical model pivot basis rather than retaining its XY/+Z face contract.

The generated template now explicitly clears PrimaryPart and sets `WorldPivot=CFrame.new()` **without moving its children**, before cloning/scaling/placement. A runtime bounds assertion rejects a template whose X span is not larger than twice its depth. The existing yaw0 for both wave bindings is retained; now +Z correctly faces inward with the cornice frame. Expected final envelope is about2.4×2.4×0.303, same height/maximum width and no title movement. All tall seal-cutter and earlier geometry fixes remain.

Two read-only native close captures from the court independently verified that `WallShieldOrnate` and `CrossedSwords` already face inward: the ornate shield's decorated face and the crossed-sword assembly's front heater shield are visible. Their yaw180 bindings remain unchanged. No native mutation was made by this agent. Revision4 passes StyLua/Selene; root must reapply the full heraldry function with revision4 config and verify both wave faces from the promenade before final acceptance.
