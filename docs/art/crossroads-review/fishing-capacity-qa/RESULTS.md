# All-station access and social-seat results

2026-09-08. **All18 stations were physically reached and exited; all8 social Seats accepted the Humanoid and allowed jump exit.** Existing isolated Play preview, WalkSpeed24, native character_navigation speed_multiplier1. No map/Edit mutation, no mode change, no fishing/economy activation. Control released to lead after completion.

## Access evidence

[All55 navigation attempts/raw actual endpoints](native-access-results.json), [18 Standing endpoint table](standing-endpoints.md), [prepared surveyed route](prepared-route.json). Fifty-four navigation calls returnedSuccess. The remaining initial no-route response is explained below rather than hidden. Maximum horizontal distance from intended Standing was0.872stud; every station root settled atY7.906 on the4.5-high deck, inRunning state. Most station FloorMaterial samples explicitly returnedWoodPlanks; first Heaven station recorded position/state without FloorMaterial. Every return to its bank and both loop closures succeeded.

Only two pond resets were used: Heaven(-157,8,8), Hell(203,8,8). Heaven sequence1→10→1; Hell5→6→7→8→1→2→3→4→5. At each, navigate bank→original Standing Attachment position→same bank before moving onward. No direct Standing-to-Standing shortcuts through the water and no intermediate teleports. Initial Hell bank-arrival no-op was omitted because that was already its reset location; actual station5return and loopclosure were walked.

No sampled endpoint wasSwimming/Freefall or supported on water. All recorded states wereRunning; bank height followed existing surfaces. Hell station1eastback reached rootY8.279 / returnedY8.101 on the already surveyed mild bank grade, while station deck remainedY7.906. Endpoint sampling after0.3s is not a continuous state trace: short intermediate jumps/swims cannot be ruled out solely by these samples. Native navigation/pathfinding chooses its own movement; this is not every manual-input route.

## Initial navigation diagnostic

First command requested Heaven station1back at(-157,4,8) immediately after the authorized reset placed the character directly above that sameXZ. It returned“Can not find a route to the destination.” Actual root was(-157,7.821,8), Running on `CoinGarden.SidePromenade`, supporting surfaceY4.415. Thus no horizontal journey had begun and the requested groundY4 lay below the actual paving. [Native screenshot](initial-no-route.jpg) shows the character on the existing dry promenade facing the unobstructed station approach.

Without another reset or map change, navigation to station1Standing succeeded. Its return to the same bankXZ and the final loopclosure also succeeded. This isolated start/no-op pathfinding response is retained as a tool/start-target issue, not evidence of a physical obstruction requiring a map edit.

## Eight social Seats

[Native seat results](native-seat-results.json). Four shelter seats atX−219.5/−216.5/−209.5/−206.5,Z−87.5 and four gardenSeats atX−133/−129/−111/−107,Z−70 all returned seated=true/jumpExited=true/finalstateRunning. Garden instances share the nameVisitorSeat and were individually collected/sorted by position; none was tested repeatedly in place of the others.

Each Seat setup used the authorized character reset above that exactSeat, then native `Seat:Sit(Humanoid)`,0.65s confirmation of Occupant/SeatPart, then Jump+Jumpingstate and0.7s exit confirmation. These are eight scripted native sit/jump smoke tests. They are not eight walking approaches, manual touch-entry tests, controller tests or support for every avatar size. No Seat geometry/Disabled flags or preview audience were changed.

## Scope and recommendation

Sequential one-player physical access now covers all10Heaven+8Hell stations and both complete surveyed bank loops. This strengthens the earlier connector-only route sweep, but does not prove simultaneous18-player crowd capacity, shared reservation logic, rods in actual hands, production catches or multiplayer collision behavior. Keep the current dock/bank dimensions for now; no actual access obstruction was established. Device, crowd and gameplay-authority tests remain separate.

No temporary QA geometry/scripts were added during this pass. Camera was not persistently changed; the one evidence capture used the tool's temporary camera override. Play remained running when player/camera control was released to the lead. No further native operations were performed afterward.
