# Measured arena tier proposal

2026-09-08. Source/design only; no Studio mutation. Read `realm_crossroads_leisure.json`, `bake_leisure.luau`, `realm_crossroads_polish_arena.json`, `polish_arena.luau`, and surveyed the existing Edit hierarchy. This proposal does not certify a sightline improvement.

## What the measurement says

Proposed deck tops 7.5/10/12.5/15 replace 6/8/10/12: row deltas+1.5/+2/+2.5/+3. Native Seat centers are deck+1.75; sampled avatar eye is deck+5.0868. Thus new eye heights approximately 12.587/15.087/17.587/20.087. X and Z stay unchanged.

Native chair cushion centers sit at preceding seatX+1.45, with full chair-back top deck+4.75. Cushions are CanQuery=false. Dummy bounding-box tops are deck+5.491; these are conservative envelopes rather than opaque silhouettes. Audience remains at columns 1/2/3/6/7/8, while visitor columns 4/5 remain empty.

For a center target atX 120, ray elevation at the preceding back plane is `eyeY+(targetY-eyeY)*(eyeX-backX)/(eyeX-120)`. This ignores lateral clipping and uses the full chair top, a conservative height bound. Clearance in studs:

| Observer row | Target Y | Existing clearance | Proposed clearance | Gain |
| --- | --- | --- | --- | --- |
| 2 | 4.5 / 7.5 / 11.5 | 0.951 / 1.435 / 2.081 | 1.128 / 1.612 / 2.258 | 0.177 |
| 3 | 4.5 / 7.5 / 11.5 | 0.894 / 1.303 / 1.848 | 1.054 / 1.462 / 2.007 | 0.159 |
| 4 | 4.5 / 7.5 / 11.5 | 0.853 / 1.207 / 1.678 | 0.999 / 1.353 / 1.824 | 0.146 |

Moving the observer up also moves the chair ahead up, so the effective clearance gain is modest. Current center target heights already clear the preceding chair in this calculation. Foreground chair pixels in the screenshots mostly hide nearer/lower ground; they cannot alone establish hidden center combatants. The fixed near bulwark does not rise with the audience, so higher rows can gain more there, but actual near-edge targets must be rendered to prove that. Raising rows may also expose more arena floor while retaining audience/head obstructions on oblique entrance views. **Do not claim that these four elevations solve all visibility.**

## Native ownership and migration

Existing `CrossroadsLeisureR9.ArenaSpectatorStands` holds 32 Seats and two Tier Parts each for rows 1–3. Row 4's two original Tier 4 Parts are archived in `ServerStorage.CrossroadsArenaPolishBackup.RearTiers`; polished retaining cores replace them. The 32 shell models are under `ArenaPolishR11.CraftedChairs.Shell_Seat_rr_cc`. The 24 static models are siblings under `CrossroadsLeisureR9.SeatedPodiumPreview`, namedSpectator_1…24. Their source placement is six per row; native centers confirm X163.34/173.34/183.34/193.34. Do not move the whole leisure root: it includes obsolete pond/scenery content.

Needed exclusive source ownership before implementation:

1. `configs/realm_crossroads_leisure.json`: canonical row tops and explicit aisle flights/landings. Keep terrain/pond keys unchanged.
2. `tools/realm_crossroads/bake_leisure.luau`: source parity for future fresh bake only, consuming new row stairs. **Do not rerun this full baker against the current map**; its earlier terrain/pond bake would overwrite later fishing work.
3. `configs/realm_crossroads_polish_arena.json` + `polish_arena.luau`: row migration, matching rails/stairs/façade and source synchronization. Prefer consuming one canonical configured row-height table through the existing authoring invocation; if registry cannot provide that dependency, explicitly synchronize the two named config records and assert agreement before applying.
4. Parent owns registry/export changes if the config dependency requires them, and all native applications/QA. Do not assume these shared paths are free while parent edits them.

Migration should assert Edit PlaceId 0 and zero occupied visitor Seats. Save original row CFrames, sizes and dummy pivots once under dedicated attributes/backup. Compute every delta from the saved baseline, never add repeatedly. Move each native Seat and matching static dummy by its row delta; retain 32 original Seat instances, Disabled flags, slot attributes and 24 dummy models. Validate dummy row through both saved slot/name order and native position, reject ambiguous matches. Rebuild shells from moved Seats with existing `polish_arena` method. Legs then still touch the raised deck because their relative lengths remain unchanged.

Grow row 1–3 Tier heights upward from bankY 4 (new thickness 3.5/6/8.5), keeping X/Z and bottom fixed. Grow the two archived Tier 4 reference boxes to 11 thick centeredY 9.5, using baseline attributes, then rebuild the existing recessed façade at the new top 15. Its footing remainsY 4 and entire outer face staysX<=199. Rebuild end/rear rails at the corresponding tops, including rear_top15. No independent vertical translation of wall footings, detached rear panels or buried floating bases.

## Stair solution that reaches the actual rows

Current baker creates 16 uniform steps acrossX 159–199; blindly changing only terminal height produces 22 steps but does not create level row accesses. Proposed eight-wide aisle remainsZ 4–12. Use disjoint structural step bodies and cut 0.3 nosings, no coplanar overlays:

| Flight / landing | X interval | Rise / top |
| --- | --- | --- |
| Flight 1:7 treads,1 each | 159–166 | Y4→7.5 in 0.5 rises |
| Row 1 landing | 166–169 | Y7.5 |
| Flight 2:5 treads,1.4 each | 169–176 | Y7.5→10 |
| Row 2 landing | 176–179 | Y10 |
| Flight 3:5 treads,1.4 each | 179–186 | Y10→12.5 |
| Row 3 landing | 186–189 | Y12.5 |
| Flight 4:5 treads,1.4 each | 189–196 | Y12.5→15 |
| Row 4 landing | 196–199 | Y15 |

Each three-stud landing adjoins its own tier behind the seat/back plane, with no outside footprint expansion. First flight's1-stud tread is the tightest; native walk/jump/controller testing is required before accepting it. This preserves the seven-stud front corridorX 152–159 and twelve-stud rear corridorX 199–211, plus existing side passage geometry. Do not extend the rear landing/rail into that pond passage. Reset only the archived AisleStep reference set, preserving originals separately; stale 16-step backups must not silently regenerate old stairs on rerun.

## Required rendered target grid

No full rendered grid has been performed. Previous CanQuery rays remain diagnostics only. Before adopting heights, capture baseline and proposed variants at all eight actual seated-eye positions with identical camera projection and 24 dummies retained. Parent-authorized temporary Play-only targets should be opaque 5×7 vertical panels, billboarded geometrically toward each observer, grounded at local field height, with a5×7 checker-ID grid. They are test fixtures removed after capture, never production UI/art. Sample center(120,8), near edge(148,8), far edge(92,8), true west entrance(88,−18), true front entrance(120,59), plus near-edge lateral positions(148,−28)/(148,44). No rear-boundary-as-entrance substitution.

For each view, record visible target cell fractions and any fully hidden middle/upper body cells. Use rendered pixels/depth masking where available, not bounding-box hits as opaque geometry. Exclude Transparency 1/LocalTransparencyModifier 1 markers and archived/hidden instances; visible MeshParts/CSG and CanQuery=false cushions/dummies MUST remain in the rendered scene. Keep full transparent FX consistent between variants. Native collision rays may identify candidate occluders but cannot produce the acceptance percentage. Actual target visual capture is the authoritative test; no custom renderer/OBB approximation should be reported as native pixel visibility.

Report baseline→candidate deltas separately for each seat/target, with named occluders and screenshots. Accept only after the near-edge/entrance benefit is evident without worsened center upper-body visibility, stairs/row exits work, and the unchanged 32/24/8 inventory and 7/12 corridors are remeasured. If the gain is weak, evaluate a specifically measured chair-back reduction, seat lateral stagger or spectator-side bulwark treatment as a separate proposal. No such secondary geometry change is authorized by this plan.

## Runnable temporary target helper

`configs/realm_crossroads_arena_sightline_qa.json` and `tools/realm_crossroads/arena_sightline_qa.luau` provide a parent-run Client/Play-only helper, deliberately absent from the authoring/export registry. Invoke the returned function with the current world/config. It rejects Edit, Server and nonzero PlaceId. `action=build` replaces its own temporary root with exactly one 5×7-stud target of 35 opaque colored cells, facing the configured visitor seat. `observer_seat` and `active_target` select one of eight Seats and seven positions; only one target exists per capture, avoiding target-to-target occlusion. Rows are one stud high, indexed bottom-up; centers at floor+0.5 through+6.5 make the lower/torso/upper bands measurable, including the floor+2 and+4.5 regions. Small 0.04 gaps distinguish cells. SmoothPlastic avoids glow bloom; target is anchored/noncolliding/nonquery, no UI/gameplay.

The helper returns eye/focus vectors for the lead to set a temporary camera. It does not move the avatar/camera or change any existing instance. Clear the observing avatar from the camera or hide only its local body for screenshots; do not hide the 24 audience figures/chairs. Confirm `floor_y` against the newly applied field before running: current source default 4.45 is configurable, not a newly measured floor. Compare the returned eye offset to the current seated avatar when testing a different body.

Run `action=remove` after QA (and before checkpoint/export), verify no ArenaSightlineQA remains, restore camera. Temporary cells are intentionally visible even though CanQuery=false, directly demonstrating why rendered screenshots are needed. No automatic visibility score is claimed. Native target captures remain lead-owned; source helper lint/style passed.

**Hold current tiers** if center and both actual entrances show an unobstructed middle/upper target band for all eight Seats and near-edge loss is acceptable to the lead. A visible foreground chair alone is not a failure. Record lower-body occlusion separately; if a target torso is hidden, identify the exact chair/dummy/bulwark before choosing an intervention. Do not apply the raised-tier plan on weak evidence.

For the requested baseline overview, config now defaults `active_target=all`: seven targets/245 cells, focus at Center, all individually face the observer. Capture eight seat views with unchanged field. Use a single named target for follow-up wherever one target overlaps another in the image; all-target occlusion is not evidence of arena geometry obstruction. No raised-tier construction is included.

Baseline rendered follow-up is now complete in [ARENA_SEAT_QA.md](ARENA_SEAT_QA.md):8 overview/8 focused captures support **holding current tiers**, with localized lower near-edge occlusion retained. No height migration should proceed from this provisional plan without new evidence.
