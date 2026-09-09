# Alternate upper-tier access — applied and walked

A compact northern switchback resolves section06's explicit alternate-route requirement using the existing Y12 rear tier. Installed under root authorization in the existing native preview; direct walking review completed.

## Measured layout

Native Edit survey found Terrain Y4 at24points over X164–204 / Z−32…−88. Existing upper row topY12, north endZ−28, outer stand planeX199. Thirty-two Seats/eight visitor Seats remain unchanged.

Two8-stud-wide flights:

- Lower: centerline `(182,4,-44)` → `(182,8,-76)`,32horizontal run /4rise,1:8.
- Turn: X178–198, Z−84…−76, topY8. Two8×8 turning zones connected across the20×8 landing.
- Upper: `(194,8,-76)` → `(194,12,-44)`,32run /4rise,1:8.
- Bridge: X190–198, Z−44…−28, topY12; joins the existing upper deck without moving it.

The two flights are separated by4studs. Metal guards/stringers remain west ofX199 (maximum198.67); no piece enters the protected Hell passage X199–211. The north ground promenade Z−42…−28 continues beneath the flat upper bridge: undersideY11.5 above groundY4 gives7.5studs clearance. Abutments stay centeredZ−44 and extend only0.35toward the promenade, outside its north edge. No supports stand in the bridge crossing. Native avatar/headroom tests still required.

There is no island expansion, Terrain rewrite, tier elevation change, seat move or arena-entry change. Native upper end posts lie outside the new8-stud opening X190–198. Only the two horizontal EndRails centered(194,13.5/15,−28) are archived and replaced with fitted outer returns. Other rails/posts remain.

The two intersecting decorative models are preserved in the dedicated backup: lava_eye_tree pivot(172.799,26.368,−79.409), bone_rock(172.818,14.005,−79.010). Their measured envelopes intruded into the lower flight/turn headroom. Adjacent existing specimens remain; no substitute generated flora is introduced.

## Architectural construction

Charcoal Slate walking plates, warm Limestone stringers, grounded support columns and slim dark metal guards reuse the stand palette. All tuning is config-owned. Sloped plates meet flat landings at their edge; there are no flat decorative skins laid over route floors. Duplicate guard posts at adjoining run endpoints are suppressed. The8-stud width is clear between outside guard positions, not an overall width reduced by rails. The alternative path is optional and does not redirect ordinary ground traffic.

## Application and integration

- Config: `configs/realm_crossroads_arena_access_ramp.json`.
- Installer: `tools/realm_crossroads/arena_access_ramp.luau`, returned function `(world,cfg)`.
- Requires stopped PlaceId0 preview. Apply after activity/leisure and arena polish, before final checkpoint/route acceptance. Root adds registry entry.
- Output: `world.ArenaAccessRampR1`; archived originals: `ServerStorage.CrossroadsArenaAccessBackup`.
- Preflight validates seats, exact original endrail positions/dimensions, both surveyed flora and seven Terrain samples. It prepares geometry and checks every new corner remains X<199 before archiving anything.
- Reapplication replaces only its output; originals are retained once, including after an upstream arena polish recreates the original rails. Existing seats/transforms are rechecked before commit.
- Rollback: remove output; restore each archived object to its ArenaAccessOriginalParent. Restore the two original full endrails only when removing the ramp, as otherwise they close its entry.
- No gameplay, prompts, navigation agents or runtime behavior installed. Config route points support the root's walking QA only.

StyLua/Selene pass with zero errors/warnings. Native acceptance pending: forward and reverse traversal without Jump/Swimming at24,8-stud turn clearance, upper seam/rail opening, ground promenade crossing under bridge, side/grazing composition, preserved12-stud Hell passage, and32unchanged Seats. Source preparation is not native acceptance or a crowd test.

## Native application and acceptance

First application:74parts,2flights,32Seats preserved,4originals archived. Immediate rerun:74parts,0additional archived objects. Native centerline ray heights: lower midpointY6, turnY8, upper midpointY10, bridgeY12. The exact lower edge can miss a point ray at its mathematical boundary; direct walking crosses it smoothly. The native oblique view from(224,35,-99) toward(185,8,-55) was captured and inspected: supported switchback, clear opening, retained stand/pool composition. A matched after-atlas capture follows under the section review agent.

Character-navigation tool calls reached all requested targets but selected an off-route shortcut nearX189/Z−45, producing Jump/Freefall states. This does not support a jump-free pathfinder claim. A separate direct physical test then reset the normal character once to the lower approach, preserved WalkSpeed24 and natural Humanoid states, and used16 sequential MoveTo segments along the actual route: lower approach→flight→turn→upper flight→bridge→stand, reverse route back toground, then north promenade under bridge towardX204/Z−35. All16 MoveToFinished values were true;634Heartbeat samples and StateChanged monitoring recorded **zero Jumping, Freefall or Swimming events**. Every recorded endpoint wasRunning. No jump disabling, intermediate teleports or geometry changes were used. Upper-deck rootY15.406 and ground rootY7.406 agree with the avatar's existing3.406root offset above12/4surfaces.

Console output was empty after the final Play test. Returned to Edit and released camera/mode to the after-atlas reviewer. Registry now includes the pass immediately after arena polish (18total). Root must refresh authoring payloads and checkpoint after this new module; earlier saved map hashes predate this ramp. No root replay backup was removed.

This closes normal-avatar alternate-route physical access and ground-underpass smoke acceptance. Simultaneous pedestrians, other supported avatar dimensions and controller/touch input remain part of whole-map acceptance.
