# Arena floor craftsmanship — applied and measured

Bounded implementation of review 06 items 09–10: a restrained fitted combat floor and grounded bulwark receiver vocabulary. Root applied the floor and reported a clean overhead review. This task performed a read-only Server geometry audit during Play; it did not mutate Studio.

## Measured contract

Read-only preview Client measurements identified `RealmCrossroadsR4.CrossroadsActivitiesR7.PatrolGrove.Playfield` as an actual Slate Part, not Terrain: center `(120, 4.23, 8)`, size `(64, 0.3, 102)`, top **4.38**, footprint X88–152 / Z−43–59. The two LowCover parts and two CoverCaps retain their exact CFrames and dimensions. Existing bulwarks, kerbs, routes, cover anchors and CombatBounds remain untouched.

`configs/realm_crossroads_arena_floor.json` owns geometry, palette, materials and expected datum. Evaluate `tools/realm_crossroads/arena_floor.luau`, then call its returned function with the existing world Model and decoded config. It rejects running Play and nonzero PlaceId, and validates source position, dimensions, horizontal orientation and top before construction. Apply after the original activity bake and any arena architecture pass.

## Authored result

- A 0.18-stud mortar foundation fills the bottom of the original volume, ending at Y4.26. Finish stones occupy only Y4.26–4.38; there is no original slab beneath them with a coplanar top.
- Twenty-eight broad staggered panels occupy the interior 61×99 field. Their 0.08-stud joints expose mortar 0.12 below the stone. Panel dimensions are approximately 14–16.5 studs wide and 14.14 deep.
- A subdued 20-stud diameter shared compass/feather/horn crest is genuinely cut into the panel layout. Four final crest solids comprise bronze ring, Heaven stone, Hell stone and bronze motif. All cut operands extend vertically well beyond the finish; no colored skins sit over an intact disk.
- Four inboard 1.5-stud foundations partition the original field perimeter. West receiver at X88/Z−18 and south receiver at Z59/X120 each preserve the existing 14-stud entrance span. Receiver faces sit 0.035 below floor height. Guide shoes remain outside each clear span. No raised edge or footprint expansion is introduced.
- The original `Playfield` is saved once as `ServerStorage.CrossroadsArenaFloorBackup.OriginalPlayfield`. An invisible, noncolliding and nonqueryable `PatrolGrove.Playfield` proxy preserves the original authoring bounds for later integration. All visible construction lives under `PatrolGrove.ArenaFloorCraftR1`.

The output carries PreviewOnly / GameplayConnected=false and revision metadata. Receivers expose GatewaySide, ClearSpan and an intended binding note, but contain no behavior, FX, prompts or gameplay tags. This floor does not connect combat or change 24-stud/s movement.

## Idempotency and rollback

Preparation occurs in a temporary Model. CSG or cover validation failure removes that temporary output and retains the current visible floor. Successful preparation archives the source before replacing the live floor and prior generated output. Reruns use the saved original, preventing cumulative cuts. Rollback: remove the generated output and hidden proxy, then clone the archived original into PatrolGrove as Playfield. Do not destroy the archive until visual review is accepted.

## Validation

StyLua and Selene passed (0 errors, 0 warnings). Config parses as JSON. Expected return: panels=28, receiverFaces=2, foundations=10, medalParts=4, coverPartsPreserved=4, floorTop=4.38. cutPanels records the subset actually intersecting the crest.

Initial acceptance targets: inspect top-down and at avatar height for CSG skins, sample stone tops at 4.38 and mortar joints at 4.26, verify both 14-stud crossings have no raised obstacle, and confirm all four cover parts remain unchanged. The existing surrounding kerb/promenade geometry is outside this replacement scope. This source validation does not certify native collision decomposition or multiplayer performance.

## Applied native audit

Root application returned **28 panels, 6 cut panels, 10 foundations, 4 medal parts, 2 receiver faces, 4 preserved cover parts**, floorTop=4.380000025. Root corrected unsupported Color3 multiplication to explicit per-channel scaling before application; the corrected source was inspected.

Server measurements confirmed the original Playfield proxy center/size `(120,4.23,8)` / `(64,.3,102)`, transparency1, CanCollide=false and CanQuery=false. Both cover centers remain `(102,5.5,-2)` and `(138,5.5,18)`, size6×3×4. Caps remain atY7.15, size6.6×.3×4.6. Stone ray tops=4.3800001, mortar=4.2600002, receiver faces=4.3450003. Thus receivers are recessed, not raised obstacles.

Rectangle partition inspection confirms east/west borders occupy the full depth while north/south borders omit those corner widths. Receiver cuts are ordered and partition each selected border; guide shoes lie beyond the14-stud clear span. Interior panels subtract half the0.08 joint on each neighboring side. No rectangular positive-area same-plane overlap was identified. Rays on exact shared boundaries can hit both adjacent solids, which alone does not imply area overlap.

A **1,740-point** offset grid plus three radial rings around the crest produced1,739 single finish hits and **one localized double hit**: `(X129.137,Z4.183)` hit CombatStonePanel atY4.3800001 and WeatheredCrestRing atY4.3800006. This is radius9.903, near the outer radius10 join. Moving0.1stud west or north returned ring alone; moving0.1east or south returned panel alone. Source uses the same radius10 cylinder for panel removal and outer ring. The observation is consistent with a localized CSG collision-decomposition boundary discrepancy, but rendered-mesh overlap was not independently ruled out. Root's overhead visual review was clean; no source change was made based only on this collision result.

Explicit seam probes at `(120,-2.2)` and `(120,22.142857)` hit only recessed mortar, as intended. Crest center/arms, cardinal ring samples and receiver interiors returned their expected single upper finish. Full renderer/collision equivalence, every boundary point, long-session performance and multiplayer movement are not certified by this bounded audit. Camera remained owned by the Heaven review agent throughout.
