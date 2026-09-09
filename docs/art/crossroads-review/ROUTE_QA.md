# Crossroads route QA — 2026-09-08

**49 native navigation calls reached their requested horizontal endpoints. No blocked segment was identified in this bounded sweep.** WalkSpeed remained24, speed_multiplier1. Existing Play preview only; no Edit/map mutations, no new Studio and no stop/start. All requested area connections were sampled, not every possible route or full pond perimeter.

Evidence: [complete actual endpoints](route-qa/endpoints.md), [raw tool results](route-qa/navigation-results.json), [fountain](route-qa/fountain-loop.jpg), [Hell shore](route-qa/hell-north-shore.jpg), [Heaven connection](route-qa/heaven-connector.jpg). XYZ values are HumanoidRootPart endpoints, not foot heights; requested Y values describe destination ground. The character's standing root is approximately3.4 studs above supporting ground.

## Method and reset boundaries

Used native `character_navigation` for every within-segment movement, then queried actual root XYZ. Most endpoints were sampled after0.35s settling; the first gate/gallery/tight-loop endpoints were immediate. A navigation Success is not a guarantee the path contained no jump, so abnormal vertical results are explicitly separated below. No final positions were forced by teleport.

Three documented resets started independent segments:

1. Initial spawn reset to(0,4,100). Continuous navigation then reached both gates, central gallery, fountain loop, Coin Garden and Heaven north shore/shelter.
2. Reset to east stair foot(60,4,−18) to independently test the east activity connection. Continuous navigation then reached arena entrances/interior, stand aisle up/down, southern stand-end connection, Hell rear passage and north shore.
3. Reset to Heaven south connector(−158,8,82), then physically navigated the eastern pond-bank corridor northward to(−156,4,−61).

Config/source authority: R4 terrain markers/transitions and current native gate travel anchors; Bragg center(0,−88)/current fountain diameter22; activity field/entrance construction in `bake_activities.luau`; current leisure row aisle geometry; shore-route connector polylines; shelter center/approach. Earlier R2 conceptual gate coordinates were rejected in favor of current native anchors approximately(±38.865,3,43.646).

## Coverage

| Route group | Native result and limit |
| --- | --- |
| Spawn → Heaven → spawn → Hell | Threshold endpoints near(−38.963,3.846,44.320) and(38.072,3.846,43.419). Both reached; no travel is enabled. |
| Hell → gallery approach/entry | Reached central approach(0,−48), entry(0,−62) and court near(0,−72). Current gallery/Bragg floor supports rootY7.846. |
| Fountain loop | Tight initial four-point loop triggered elevated endpoints; wider eight-point loop completed at stable court rootY7.846, detailed below. |
| Gallery → Coin Garden | Descended toward west stair foot(−60,0,−18), climbed to activity entrance(−88,4,−18), continued north to pavilion-side connection. |
| Coin → Heaven shore → shelter | Followed configured northern connector(−156,−61)→(−188,−61), then shore(−213,−63), shelter approach(−213,−78), interior(−213,−84) and back. Last interior root(−212.996,7.406,−83.320). No seating was invoked during this route. |
| East stairs → arena | From(60,−18), reached(80,−18), true west opening(88,−18), interior(120,8), true front opening(120,59). The authoring bulwarks remain visual/noncontainment; this is not a test of future combat isolation. |
| Stand access/aisle | Reached front(157,8), mid(174,8), rear(194,8), descended to front, then navigated south end(157,51). Rear root(193.232,14.506,8.001). No row-height changes. |
| Stand → Hell shore | Followed(190,51)→(205,51), rear strip north through(205,30)/(205,−20)/(205,−35), then northwest(211,−54)→north shore(244,−57). Final root(243.151,7.406,−56.911). |
| Heaven eastern bank passage | From south connector, reached(−158,50),(−158,10),(−158,−20),(−156,−61). Native endpoint rootY7.526–7.821 reflects existing mixed-surface paving. Passage remained traversable. |

## Tight fountain loop observation

The first loop used four cardinal points16 studs from fountain center. Diagonal travel between these points passes much closer to the22-stud-diameter rim than its endpoints imply. Tool calls reported Success, but north/west/closing endpoint root heights were14.960/14.046/11.569, consistent with navigation jumping near/over rim geometry. After1s settling the character was Running at rootY7.846; downward ray hit `FittedInnerCourt` atY4.44. This is not recorded as an unobstructed walking loop or a map defect.

Retest used cardinal radius22 and diagonal offsets(±16,±16), keeping chords comfortably outside the fountain: south(0,−66), southeast(16,−72), east(22,−88), northeast(16,−104), north(0,−110), northwest(−16,−104), west(−22,−88), southwest(−16,−72), south close. Every settled endpoint stayed rootY7.846. The available wider court route works; no fountain or floor change is recommended from the overly tight initial path.

Stand-front return also briefly reported root aroundY9.1 near the first step rather than the general bankY7.4; subsequent south-end endpoint settled normally. This is retained as navigation/step behavior, not a failure or proof of jump-free traversal. Tool navigation may choose pathfinding jumps and does not reproduce every manual input choice.

## Limits and release

No obstacle-induced timeout/failure occurred, so no speculative obstacle repair is proposed. Endpoint success does not certify two-way crowd clearance, every individual dock, full western/eastern outer shoreline loops, controller/touch routes, absence of all visual seams, or future gameplay containment. The Mac foreground was locked during this session; no frame-rate/performance inference is valid. Static native images support location/context, not a continuous movement trace.

Final native query: WalkSpeed24, camera typeCustom, no ArenaSightlineQA root, player at(−156.378,7.526,−60.492). Screenshot tool uses temporary camera overrides; no persistent custom camera was installed. Player/camera control was released to the lead with Play left running. No requested map edits were made.
