# Coin Garden pavilion — native construction pass

2026-09-08. Code is ready for root application; this section agent made no Studio changes. This is a native architectural replacement and usable seating pass, not the completed 20-item garden design or weekly-egg gameplay.

## Application

Files: `configs/realm_crossroads_polish_garden.json` and `tools/realm_crossroads/polish_garden.luau`. Decode JSON, load script as a ModuleScript through the existing authoring workflow, then call in **Edit**:

```lua
local stats = require(module)(workspace.RealmCrossroadsR4, cfg)
print(game:GetService("HttpService"):JSONEncode(stats))
```

Requires `CrossroadsActivitiesR7.CoinGarden`, with unchanged native `PavilionFloor`, `EggTitlePanel`, `wayfinder_egg` and `hall_egg_stand`. It uses the authored pavilion datum (-120,4,-61) and floor top Y=4.6. No terrain, floor, gate, field or shared corridor is modified. If the existing floor has been moved, adjust the config datum before applying rather than moving that floor from this pass.

Output: `CoinGarden.CelestialPavilionCraftR1`. Original `PavilionColumn`, `Capital`, `PergolaBeam`, `PergolaSlat` children move to `ServerStorage.CrossroadsGardenCraftBackup` only after full replacement preparation succeeds. Existing physical title panel and every letter stay at their exact transforms, as do native stand/egg/WeeklyEggAnchor. Reapplying replaces the generated output; it does not accumulate arches, seats or prompt hosts. Restoring the original is explicit: remove the output, return archived source members to CoinGarden. Do not restore archives on top of the new geometry.

The pass prepares its new Model under Workspace for CSG execution. Any preparation exception destroys that temporary Model and leaves the prior pergola/output unchanged. Two CSG operations total: one half-elliptical annular arch profile (cloned front/rear) and one horizontal halo annulus. No runtime geometry builder.

## Construction delivered

- Four properly seated column assemblies at existing X±19/Z±10 offsets: plinths, narrower shafts, bronze collars, stone capitals and diagonal gold brackets.
- Two open shallow sculpted arch ribs replace the ladder-like pergola. Front and rear both receive finished geometry. Front/back arch spring Y=20.8 and outer crown Y=24.9; overall halo top about Y=25.8. No opaque roof or giant secondary gateway.
- A six-and-a-half-stud-radius open gold halo, physically connected by two short structural supports to the arch crowns. The center stays open to sky; native egg is not intersected or enclosed.
- Stone side reveals and thin upper/lower metal strips frame the existing physical title. They have separate thickness/placement, preserving letter faces and wording without a new billboard.
- Two 7×15 raised planting beds in the pavilion's outer wings at X=-148/-92, centered Z=-61. Each uses exact separate side walls and recessed soil, with no coplanar soil/stone faces. They end before the floor's outer edges, preserving 5.5 studs along each floor side.
- Ten native cached plant/quartz clones total, provided caches are present. Model choices: field_flower_bush, softglow_bloom and pearl_quartz. Footing alignment seats plants on soil; quartz is partly embedded. Width/depth fitting keeps clones inside each bed. Existing small planters and landscape are retained.
- Four actual native Seats at local X=-13/-9/+9/+13, Z=-9, facing south toward the lawn. Stone feet meet the floor; backs face the rear. Rear-side locations avoid the central egg/stand footprint and the 18-stud approach.
- One disabled `WeeklyEggPreviewPrompt`, on a noncolliding/invisible host, with `PresentationCamera` and `PresentationFocus` Attachments and PreviewOnly/GameplayConnected=false metadata. No event handler, price, schedule, purchase, inventory mutation, real hatch or auto-motion is added.

Assets are found only in the existing `CrossroadsActivityAssets`, `CrossroadsExistingDecor`, `CrossroadsLandscapeAssets` caches. Missing Models return warnings; no new mesh, upload, InsertService load or fake substitute occurs. Scripts, prompts, GUI layers and tags are stripped from decorative clones. Seats are intentionally functional; other decoration has no touch/query/physics behavior except simple column/planter collision.

## Design coverage and remaining work

| Original proposal | Coverage |
| --- | --- |
| 1 Sculpted open pavilion | Main native structure complete in source; native review pending. Organic feather brackets remain optional art work. |
| 2 Architectural title | Preserved exact title/letters; new frame. Curved replacement lintel not attempted because it would change the approved title mount. |
| 3 Rosette | Deferred; no floor layering or CSG floor alterations here. |
| 4 Forecourt | Deferred to shared paving owner. |
| 5 Paving circuit | Unchanged intentionally. |
| 6 Field edging | Unchanged intentionally. |
| 7 Lawn finish | Unchanged intentionally; protects the 64×90 field. |
| 8 Flower beds | Two substantial pavilion beds authored; south entrance beds remain. |
| 9 Embedded quartz | Embedded native quartz in new beds; original southern quartz untouched. |
| 10 Orchard backdrop | Existing trees retained; redistribution requires landscape owner. |
| 11 Bragg relief | Deferred to facade/asset coordination; no neighboring geometry touched. |
| 12 Social room | Four usable seats in pavilion; larger southern terrace rearrangement remains. |
| 13 Conversation nook | Pavilion's rear seating offers shelter; separate arbor deferred. |
| 14 Pond connection | Preserved; no corridor/water/dock changes. |
| 15 Wayfinding | Existing physical garden title unchanged. |
| 16 Lighting | Deferred to shared lighting/FX budget. |
| 17 Petals | Deferred to FX owner. |
| 18 Egg motion | Native egg unchanged; attachment stubs only. |
| 19 Hatch flourish | Disabled inspect stub only; no claim of hatch integration. |
| 20 Sound | Deferred to audio owner. |

If the native silhouette needs more organic detail, author a small pair of feather capital ornaments using ImageGen → Meshy → Blender → Assets → Roblox. Preserve separate decorative pieces and simple structural kit; do not regenerate the native egg or stand, or fuse the open pavilion into a single expensive mesh. The existing scripted structure is the reviewable first construction result, not a dependency on generation succeeding.

## Validation

Executed: StyLua formatting and Selene on the owned Luau file; **0 errors, 0 warnings, 0 parse errors**. JSON parsed/reserialized with Python. No Studio or visual-performance result is claimed.

Root acceptance: apply in existing editable instance; expect four seats and up to ten native plants, inspect all warnings. Verify native CSG arch ellipse orientation, column/capital contact, support-to-halo contact, title legibility, rear view and unobstructed egg silhouette. Confirm no new geometry inside X[-152,-88]/Z[-27,63] collection lawn. Walk south/side approaches at 24 studs/s, check pond corridor unchanged, sit and exit all four Seats, inspect camera near rear arch. Check low/high graphics and native mobile cost before adding FX. Reapply in Edit and compare generated counts to ensure idempotency; original egg/stand/title CFrames must match pre-pass values. Prompt remains disabled unless a later explicit root-owned preview controller supplies the intended behavior.

## Revision 2 native correction

Root's first native application revealed that the Cylinder boolean primitive did not produce the requested anisotropic cross-section: the front arch Union measured only 8.2 studs across despite the 41.2-stud requested input. Read-only native screenshot/instance inspection confirmed this; the first visual result is rejected. Source now cuts a full circular arch first, with the inner circle vertically offset to retain a substantial crown, then explicitly scales the resulting UnionOperation to 41.2×4.1 studs in its profile plane and seats its lower bound on Y=20.8. Front/rear arch ends therefore reach the existing columns. This must still be checked in the next native reapplication.

The halo was correctly 13 studs in diameter but too thin edge-on. Revision 2 increases its vertical section to one stud, broadens the rim and structural supports, and lowers its center to Y=25.3 so its overall top remains Y=25.8. No new height/footprint/egg transform change. StyLua/Selene pass again. This correction was source-only; root owns reapplication.
