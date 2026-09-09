# R11 independent native geometry QA

2026-09-08. Read-only Edit queries and screenshots against the existing Studio instance `3c01a32c-1ba9-4e11-b43e-133bdf27dacb`. This section agent performed no native mutation or mode change. Root applied corrections. This is a focused geometry audit, not complete Play/capacity/performance acceptance.

## Defects identified and correction evidence

### Arrival seal — confirmed coplanar skin, corrected

Initial elevated screenshot showed the compass's east arm absent. Per-instance raycasts at world (1,4,100) and (2,4,100), pointing downward, hit both `CrossroadsHeraldryR1.SealCompassInlay` and `.SealHellStone` at Y≈0.440000. The geometry source subtracted a metal motif with the same0.3 thickness as the floor, leaving a thin coplanar stone skin on one side. This was a rendering defect, not stylistic asymmetry.

Heraldry revision2 now clones/extrudes the subtraction operand to4 studs while leaving visible gold at0.3. Root reapplied. Reverification at X=-2,-1,0,1,2 / Z100 hits **only the gold atY0.44**; no stone hit remains beneath those rays. Matching screenshot now shows both east/west arms and the complete central diamond. Existing ring and surrounding pavers unchanged. This focused sample does not certify every pixel, but directly retests the observed failure.

### Hell fishing passage — two visual obstructions, archived

Initial visible-part AABB scan of X199–211 / Z-49..65 / Y4.65..10 found two noncolliding native props protruding into the proposed twelve-stud strip:

| Native child under `CrossroadsFishingR10.HellFishingPool` | World bounds |
| --- | --- |
| `bone_rock.bone_rock` | X207.185–210.613, Z28.324–32.053, topY6.650 |
| `dead_brush.dead_brush` | X207.627–210.154, Z-15.129–-13.273, topY6.050 |

No colliding obstruction was found by that scan. Rather than moving these props into nearby water/docks, source `polish_fishing.luau` now archives ground-name native Models whose bounds intersect the protected strip after grounding. Root archived precisely these two under `ServerStorage.FishingPolishR11PassageBackup`, retaining `FishingPolishPassagePivot` and `FishingPolishOriginalParent`. Requery confirms no remaining matching props in the strip. No water, station or road footprint changed. Source passes StyLua/Selene.

### Overlook balusters — measured support gap, corrected

Thirty new balusters originally stopped atY-1.2800, while their stone rail's underside wasY-1.1050: a0.175-stud gap. Root updated live geometry and core source/config to2.475-stud balusters with bottoms held atY-3.58. Requery measures baluster topsY-1.10500002 and rail undersideY-1.10499996, equal within float tolerance. Their bases remainY-3.57999992. No railing footprint change.

### Bragg annular floor — boolean operand issue hardened; native recheck pending

The polished promenade visually reads as a continuous stone annulus in the inspected screenshot. A focused raycast at (35,8,-88) nevertheless hit both `CircularCourt` and `FittedViewingPromenade` atY4.4400015. AtX20 andX45, only court was hit. This may include collision decomposition behavior and was **not** enough to independently claim visible flicker.

Source inspection found the annular cutting tool itself used equal4-stud outer/inner cylinder heights. Bragg revision2 now subtracts an8-stud inner cylinder from the4-stud outer cylinder, ensuring no coplanar tool caps; the visible runner remains0.42 thick. An explicit height guard prevents regression. StyLua/Selene pass. Root is responsible for applying this revision; follow-up native results will be appended rather than silently treating this as fully accepted.

## Other measured checks

- **Pavilion corrected geometry:** front/rear arch Union sizes1.55×4.1×41.2 with Y90 orientation. Centers(-120,22.85,-51/-71) produce full41.2-stud span; springY20.8, crownY24.9. Capitals atX-139/-101, Z-71/-51, centerY20.8, size3.2×0.55×3.2 support the ends. Halo size1×13×13, horizontal center(-120,25.3,-61), top25.8; support beam sizes0.9×0.75×3.821 connect arch crowns to ring. Earlier undersized8.2-wide primitive result was rejected and replaced before this audit.
- **Seat inventory:** garden has4 enabled native Seats. Spectator stands retain32 seats:8 enabled and24 disabled for occupied preview figures. Inventory is not a sit/exit test or a32-live-player capacity claim.
- **Dock construction inventory:** all18 stations (10 Heaven/8 Hell) have five planks, two under-deck beams and four diagonal braces. Every plank top isY4.5000001. Native post counts40/32 remain, all topsY4.25 and bottomsY-3.75. Frame beams intersect post elevations; no missing station assembly identified.
- **Minor submerged pier footing limitation:** downward Terrain-only rays ignoring water at post centers found all72 ground samples. Maximum post-bottom clearance above bed is0.1231stud at Heaven station3 near(-207.135,0.25,59.642), and0.25stud at Hell station5 near(221,0.25,4). Many other posts penetrate bank Terrain (minimum gap-7.75). These are small retained underwater footing gaps, not blocked routes; no geometry change made for them in this audit.
- **Overlook stairs:** eight authored steps have contiguous two-stud Z footprints, centersZ121..135. Tops descend0.5stud from0.24 to-3.26. Landing transitions are separate from the eight regular risers; this audit did not replace the established staircase or assert its full avatar test.
- **Limited flat-Part overlap screen:** compared visible horizontal `Part` floors/planks/pavers/landings underY6 with matching tops within0.001 and overlapping central samples. No candidate overlap pairs found. This deliberately excludes complex CSG/MeshParts and is not a proof that the whole map has no overlap. The seal/Bragg CSG-specific tests above are separate because bounding boxes alone cannot establish holes.

## Remaining acceptance limits

No scripted walking, jumping, seating, multiplayer crowding, reduced-FX/mobile frame-time or long-duration camera-orbit test was executed by this agent. Root's earlier/local checks remain separate evidence. Current screenshots establish shape and some visible joins, not temporal absence of z-fighting everywhere. The small submerged post gaps are recorded for a later finishing pass. Recheck the revised Bragg floor before the checkpoint and preserve actual failure/results in this log.

### Bragg revision2 follow-up

After root applied revision2 (14 bays/24 figures/13 closures), repeated samples at radius35 found only runner hits west/north/south, but east(35,-88) still hit both court and runner atY4.4400015. Radius20 and45 east hit only court. The screenshot remains visually clean. Therefore the root cause is not proven to be remaining rendered overlap; a localized collision-decomposition bridge between the compound court's disconnected inner disk and outer ring remains plausible. Proposed stronger isolation: separate inner disk, outer ring and promenade into three independent floor solids. Do not mark this test completely resolved based on the revised cutter alone.

### Bragg revision3 prepared

At root direction, replaced the compound disconnected court boolean with three independent connected CSG solids: outer court from radius38 outward, promenade radius34–38, and inner court radius34. The inner circle is baked with a fully contained helper union (helper adds no external volume), matching the CSG circle representation used for the adjacent cut. Original backup, colors and Y4.44 remain. Total boolean operations remains three. Pending root application and retest: radius20 should now hit `FittedInnerCourt`, radius35 only `FittedViewingPromenade`, radius45 only `CircularCourt`.

### Final revision3 native measurement — audit complete, one query ambiguity retained

Root applied revision3 and the independent Edit query was repeated before the root's Play/FX test. Radius20 east now hits only `FittedInnerCourt`; radius45 east hits only `CircularCourt`; radius35 west/north/south each hits only `FittedViewingPromenade`. Radius35 east still reports both outer court and runner atY4.4400015. This persists despite separate connected geometry and the source's full radius38 tall cylindrical subtraction. The inspected rendered ring remains visually continuous, with no obvious missing strip. The remaining double **collision-query** hit is therefore recorded as unresolved engine/geometry ambiguity, not silently upgraded to a confirmed render defect or a clean test. No further native changes were made by the auditor. Root may proceed to its Play test; this document does not claim full absence of z-fighting everywhere.

Focused audit complete: confirmed seal coplanar skin, rail contact gap and two passage props were corrected and remeasured. Garden support dimensions, seat/dock inventories, limited flat-Part overlap screen and submerged-post limitations are recorded above. Outstanding item is the localized east-annulus collision query; full crowding, motion/performance and traversal belong to root verification.

## Lead-reported later checkpoint verification

The following records explicit lead results, not a repeated independent audit:

- Rest shelter applied with four genuine Seats, roof top Y14.2 and 18 dry Cobblestone spur cells; both terrain occupancy channels stayed unchanged. Native screenshots showed the bowed roof/benches, followed by three existing native backdrop trees and the retained two small bushes. `HeavenFishingRestShelterR11.RestSeat_1_1` accepted the Humanoid and the player exited in Play. Remaining three Seats, supported avatar sizes and controller/touch egress are not covered by that sample.
- Physical fishing signs were installed on both approaches. Version 2 fossil Model116671594170630 with texture105991804065229 was placed. Eight category emblems still await lead orientation correction and final visual acceptance; their count does not establish correct facing.
- Registry contains13 authoring passes. Latest [native checkpoint](../../../assets/source/maps/realm_crossroads/RealmCrossroads-R11.rbxl) refresh is pending; retain the artifact link without stale size/hash/instance totals.

These additions do not resolve the east-annulus double collision-query hit, certify temporal absence of z-fighting, or substitute for aggregate FX/CSG/avatar performance, whole-route traversal and device coverage. No production gameplay was activated.

### Final R11 source/native checkpoint

Revision4 wave medal pivot corrected and close screenshot inspected facing the court. Native export/deserialize validation passes:17,471instances,18rods,18stations,16enabled visitorSeats,Terrain and cosmetic scripts retained. Checkpoint2,564,444bytes; SHA256 `71e9adec234ab717cafba3ab6b7c00dfac0c14c6db8d6daa5c117e32249989cf`. No duplicate Studio opened. Additional native screenshots09–11 show fossil,shelter and wave heraldry. Broad crowd/device QA and the previously recorded east-annulus collision-query ambiguity remain open.
