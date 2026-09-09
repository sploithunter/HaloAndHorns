# Arena visitor seat QA — 2026-09-08

Bounded native Play check in existing Studio `3c01a32c-1ba9-4e11-b43e-133bdf27dacb`. All eight enabled Seats were tested; four reconstructed seated-eye views were captured, one per row. No map geometry, tier heights, 24 audience dummies, seat settings or Play mode was changed. Player/camera control was released to the lead and the previous camera restored.

## Sitting and jumping out

The current player character was moved above each Seat, then native `Seat:Sit(Humanoid)` was invoked. After0.65s, both Occupant and Humanoid.SeatPart matched. Jump/state change was requested, then after0.7s both were clear. These are native scripted seat/jump smoke tests, not manual touch-entry, controller input, walking egress or all-avatar tests.

| Seat | Position | Sampled eye Y (Head +0.25) | Sit | Jump exit |
| --- | --- | --- | --- | --- |
| Seat_01_04 | (164,7.75,0) | 11.088 | Pass | Pass |
| Seat_01_05 | (164,7.75,16) | 11.087 | Pass | Pass |
| Seat_02_04 | (174,9.75,0) | 13.087 | Pass | Pass |
| Seat_02_05 | (174,9.75,16) | 13.087 | Pass | Pass |
| Seat_03_04 | (184,11.75,0) | 15.087 | Pass | Pass |
| Seat_03_05 | (184,11.75,16) | 15.087 | Pass | Pass |
| Seat_04_04 | (194,13.75,0) | 17.087 | Pass | Pass |
| Seat_04_05 | (194,13.75,16) | 17.087 | Pass | Pass |

Eye X was approximately Seat.X+0.198 (first sample+0.187); eye Z matched seat Z. Camera was then placed at those sampled coordinates looking at(120,7.5,8). The player moved to the front aisle for rear-row captures, avoiding its own body at the camera. This is a reconstructed eye-level composition, not the normal third-person camera. No target mannequins were introduced.

## Captured views and findings

- [Row1 / column4](arena-seat-qa/row1-col4.jpg): center ground and the arena's depth are legible. The near bulwark fills much of the lower view and hides a strip of the near fighting edge. No chair ahead of this first row obstructs the center.
- [Row2 / column5](arena-seat-qa/row2-col5.jpg): center remains visible above the fence. The chair immediately ahead and adjacent dummy visibly occupy the lower foreground; the center-floor view is narrower than a simple collision ray suggests.
- [Row3 / column4](arena-seat-qa/row3-col4.jpg): central aisle provides a useful view corridor, but the chair ahead and adjacent dummy heads/backs obstruct portions of the lower/side field. Bulwark remains between audience and near arena edge.
- [Row4 / column5](arena-seat-qa/row4-col5.jpg): more arena depth is visible, but the chair directly ahead still masks lower portions; adjacent audience occupies side sightlines. Higher tier does not by itself prove all fighting targets visible.

All four views show broad field identity and center activity space. They do **not** establish that a5×7 target is fully visible at all positions or entrances. No speculative tier-height adjustment was made.

## Preliminary ray grid — explicitly limited

A diagnostic grid sampled nine target points (X offsets−2.5/0/+2.5, Y4.5/7.5/11.5:5-wide×7-high envelope) from each of eight row/column eye positions. These were mathematical points, not rendered target silhouettes. Ray eye X used the Seat.X rather than the sampled+0.198 offset. Results were identical across the eight positions:

| Target | Query-clear samples | Hit source |
| --- | --- | --- |
| Center(120,8) | 9/9 | None |
| Rear boundary proxy(120,−43) | 3/9 | Six hits on native PerimeterBulwark mesh |
| Front entrance center(120,59) | 6/9 | Three hits on FieldKerb |

The first diagnostic labeled the rear proxy “NorthEntrance.” Source verification afterward establishes this was **incorrect**: the north/rear boundary is fenced. `bake_activities.luau` places the other actual entrance on west side X88, Z−18, with14-stud width; that entrance was not sampled. The front entrance atX120,Z59 is the correct second opening. Do not use the rear-proxy result as entrance acceptance.

Native rays omit parts with CanQuery=false and use collision geometry for queryable meshes. They therefore cannot quantify visual chair/audience occlusion or prove a9/9 center silhouette is unobstructed. The screenshots visibly demonstrate this limitation. A complete rendered5×7 target visibility grid across center, near/far fighting edges and **both actual entrances**, from all eight visitor seats, remains undone. Four other seated-eye views and actual third-person camera behavior also remain untested.

## Handoff

**Native sit/jump smoke:8/8 passed. Sightlines: partial review with visible foreground obstruction; not a full pass.** Lead should judge the saved compositions and target-based visibility before changing rows, chair backs, audience spacing or bulwarks. Retain32 Seats/24 dummy occupants/eight visitor seats and the existing pond-side clearance while deciding. No more native work was performed after control release.

## Rendered checker-target baseline — completed follow-up

**Recommendation: hold current deck heights6/8/10/12.** The rendered tests do not establish a center/entrance torso visibility defect that warrants rebuilding the tiers. This supersedes the earlier statement that no rendered target grid was performed; the remaining scope limits below still apply.

After the lead applied the field atY4.38, the client-only helper rendered all seven5×7-stud targets as35 distinct checker cells each. Panels were visible in the actual native capture, unlike earlier particle-capture limitations. Captured eight all-target overviews at the existing sampled eye offsets, then eight focused single-target follow-ups to distinguish geometry occlusion from panel overlap/off-screen positions. Target baseline extendsY4.38–11.38, rows1–7 bottom to top. All24 existing audience models and chair/bulwark geometry remained. Player body was locally hidden during captures, restored afterward. Camera projection/FOV was retained; focused follow-ups rotate toward their target without moving the eye.

| Seat / overview | Visible action finding |
| --- | --- |
| [01_04](arena-seat-qa/targets/Seat_01_04.jpg) | Center middle/upper clear; near-center target loses lower cells to bulwark spikes. Some lateral targets are outside the center-facing frame. |
| [01_05](arena-seat-qa/targets/Seat_01_05.jpg) | Mirrored near-center lower-cell loss; center readable. Left lateral target partly clipped by frame. |
| [02_04](arena-seat-qa/targets/Seat_02_04.jpg) | Center/entrance upper/middle readable; near target lower cells behind bulwark; immediate chair stays below center action. |
| [02_05](arena-seat-qa/targets/Seat_02_05.jpg) | Similar center clearance; side targets retain upper cells, with lower fencing/audience interference. |
| [03_04](arena-seat-qa/targets/Seat_03_04.jpg) | Center upper/middle readable; near lateral target partly overlaps audience head in projection. |
| [03_05](arena-seat-qa/targets/Seat_03_05.jpg) | Center upper/middle readable; opposite lateral lower cells overlap audience. |
| [04_04](arena-seat-qa/targets/Seat_04_04.jpg) | Center and far panels overlap each other in overview; single-center follow-up resolves this. Near-corner lower cells encounter audience/bulwark. |
| [04_05](arena-seat-qa/targets/Seat_04_05.jpg) | Same panel-overlap caveat; entrance/upper target action remains legible. Near-corner lower cells partially obscured. |

### Focused evidence

- [Front-row center](arena-seat-qa/targets/Seat_01_04_Center.jpg) and [rear-row center](arena-seat-qa/targets/Seat_04_04_Center.jpg): all seven rows are visually readable; foreground chairs do not mask this5×7 center target.
- [Front-row west entrance](arena-seat-qa/targets/Seat_01_04_WestEntrance.jpg) and [rear-row west entrance](arena-seat-qa/targets/Seat_04_05_WestEntrance.jpg): true opening at(88,−18), target middle/upper clear, lower cells also visible in these focused compositions.
- [Front-row front entrance](arena-seat-qa/targets/Seat_01_05_FrontEntrance.jpg) and [rear-row front entrance](arena-seat-qa/targets/Seat_04_04_FrontEntrance.jpg): true opening at(120,59), target remains readable above/through the opening. Close adjacent dummy is outside the target silhouette.
- [Rear-row near south](arena-seat-qa/targets/Seat_04_04_NearSouth.jpg) and [rear-row near north](arena-seat-qa/targets/Seat_04_05_NearNorth.jpg): upper cells remain visible; lower cells encounter audience heads/chair/bulwark silhouettes. This is localized oblique near-edge loss, not disappearance of the whole target.

The closest centerline target at(148,8) consistently has roughly its lower three rows partly hidden by the spectator-side bulwark, with narrow visible gaps between spikes. Top four rows remain broadly legible. This is qualitative row inspection, not a measured pixel percentage. Audience in rear-row oblique near-corner views can cover lower cells and some side portions; exact per-cell fractions were not computed. These locations should inform future combat staging and any specifically targeted spectator-side barrier adjustment, but do not demonstrate that raising all four rows is the correct fix.

### Acceptance limits and cleanup

Eight all-target views plus eight individual follow-ups are **16 native screenshots**, not56 independent seat×target captures or an automated pixel-completeness result. Some targets overlap or leave the center-facing frame; follow-ups cover the critical center/true entrances at front/rear and oblique rear corners. Mid-row individual entrance silhouettes, mobile/controller cameras, variable-height fighters, crowds and dynamic effects remain outside this bounded check. No raised-tier comparison was constructed.

Native cleanup returned `qaRemoved=true`, `dummies=24`, `cameraRestored=true`. Temporary `ArenaSightlineQA` was destroyed before releasing control. Play was left running for the lead; no Edit geometry, Seat/tier height, map terrain, character position or gameplay state was changed by this follow-up. The earlier8/8 native Sit/Jump pass remains valid as its separately scoped check.
