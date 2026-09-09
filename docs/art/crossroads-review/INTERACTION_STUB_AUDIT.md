# Interaction stub readiness audit

Read-only Server inspection of the existing preview during Play; no camera, source behavior or Studio mutation. Paths below are relative to `Workspace.RealmCrossroadsR4`. This verifies authored references, not production gameplay readiness.

## Native inventory

| System | Measured contract |
| --- | --- |
| Travel | Two Parts: `CrossroadsCraftR11.GateRearCraft.FarmAndFightTravelAnchor` / `MergeTravelAnchor`. Destination values FarmAndFight / Merge; StubAction=travel_preview; GameplayConnected=false. Each default-named ProximityPrompt disabled. |
| Weekly egg | Existing `CrossroadsActivitiesR7.CoinGarden.WeeklyEggAnchor` and new `CelestialPavilionCraftR1.WeeklyEggPresentationHost`. Host contains disabled WeeklyEggPreviewPrompt and PresentationCamera/PresentationFocus Attachments. No EggId or weekly offer assigned. |
| Bragg | 24 rank Attachments, unique BoardId/Rank pairs, ranks1–3 each. Path `BraggRotundaR6.BraggCraftsmanshipR1.AlcoveNN_RankRAnchorHost.AlcoveNN_RankRAnchor`. Metadata lives on the Attachment, not its host. |
| Arena | `ArenaPolishR11.IntegrationAnchors.Battle.Battle`, `.Alliance.Alliance`, `.Stand.Stand`: Parts carry IntendedBinding/GameplayConnected=false; child Attachments carry the transforms. CombatBounds and original patrol references remain separate authorities. |
| Containment art | `CrossroadsActivitiesR7.PatrolGrove.CombatBulwarks`: VisualOnly=true, ContainmentEnabled=false. All37 model pieces have CFrame DeployedPivot/RetractedPivot; four entrance pieces use repeated EntranceBulwark name. No running containment exists. Stable identity companion is source-ready below. |
| Floor entry references | `CrossroadsActivitiesR7.PatrolGrove.ArenaFloorCraftR1` contains2 RetractedGateReceiver Parts, differentiated by GatewaySide=west/south, ClearSpan=14. These are finish solids, not prompts/trigger volumes. Hidden Playfield proxy preserves64×102 authoring bounds. |
| Spectators | `CrossroadsLeisureR9.ArenaSpectatorStands.Seat_rr_cc`:32 Seats with unique PodiumSpectatorSlot1–32. Eight enabled visitor slots:4,5,12,13,20,21,28,29 (columns4/5). Remaining24 disabled for static audience. |
| Fishing | `CrossroadsFishingR10.HeavenFishingPond.FishingStation1`–10 and `HellFishingPool.FishingStation1`–8. All18 unique StationKeys, numeric StationIndex, FishingConnected=false and StubAction=fishing_preview. |
| Station attachments | Every deck has Standing, Cast and LineTip Attachments, Standing.PreviewCast prompt, and RodDisplay ObjectValue. All18 prompts disabled on Server as intended; local rehearsal activation is client-only. All18 cast target downward rays hit Terrain Water; PreviewWaterY=0 and Cast Y≈.18. |
| Mounted rods | All18 RodDisplay values resolve to `FishingRodDisplaysR11.heavenRod_n` / `hellRod_n`. Each model has descendant RodGrip and RodLineTip; all18 of each measured. Maximum deck LineTip-to-rod tip discrepancy0.0000171stud. Models remain anchored decoration, not Tools. |
| Social seats | Four native Seats inside CelestialPavilionCraftR1; four inside HeavenFishingRestShelterR11. |
| Companion display | `HeavenFishingRestShelterR11.WestDryDisplayBay` and `.EastDryDisplayBay`: invisible Parts with DisplayOnly=true, AutomaticPetPlacement=false. No owner or inventory link. |

## Exact Bragg mapping

| Alcove | BoardId | Ranks |
| --- | --- | --- |
| 01 | most_dragons | 1,2,3 |
| 03 | crystal_crusher | 1,2,3 |
| 05 | enemies_defeated | 1,2,3 |
| 07 | team_power | 1,2,3 |
| 08 | eggs_hatched | 1,2,3 |
| 10 | siege_highest_wave_cleared | 1,2,3 |
| 12 | siege_waves_cleared | 1,2,3 |
| 14 | bosses_defeated | 1,2,3 |

The eight active groups are not Alcove01–08 consecutively. Use BoardId/Rank metadata, preserving physical2/1/3 positions. No mapping from these pairs to the24 audience slots is supplied; that remains an explicit product/integration choice.

## Ambiguities and future binding requirements

1. **Containment identity:**37 models reuse two names. Entrance=true identifies four pieces but not which of the two openings or segment ordering. Do not resolve a unique model by FindFirstChild("EntranceBulwark"). The new config-owned identity companion below resolves this authoring ambiguity when applied; a production adapter must still validate identity and map behavior explicitly.
2. **Entry versus encounter:** Battle is an encounter reference; Alliance is outside opt-in; receivers are decorative Parts. No authorized participant trigger, two-way entry volume, reservation or escape policy exists. Bind those deliberately rather than treating art names as executable semantics.
3. **Gate/egg authority:** destinations are symbolic strings; no approved place mapping, offer/EggId/schedule/price or production eligibility data exists. These are intentional unbound stubs.
4. **Rod attachment parent:** attachments live beneath the first native BasePart selected during installation; do not hardcode its mesh name. Resolve via RodDisplay and descendant attachment name, then validate uniqueness. LineTip local offsets from fishing polish are superseded by rods.
5. **Companion bays:** two spaces have no stable inventory/owner contract. Their names support display placement only. Preserve the explicit no-automatic-placement setting.
6. **Marker collision:** Playfield is now hidden and nonqueryable. Use CombatBounds/proxy dimensions for semantic area, generated floor for actual surface raycasts. Do not restore proxy collision when adding combat.

## Authoring order and reference lifetime

Current `realm_crossroads_polish.json` correctly orders fishing polish before rods and the preview interaction installer after both. Fishing polish recreates Standing/Cast/LineTip and resets cast targeting; rerunning it requires rods again, then interaction water correction. Rod installer replaces display models and ObjectValues; caches of prior Instances become stale. Bragg/core/garden polish similarly replaces their generated anchor hosts. Bind production/runtime adapters only after the complete authoring/import transaction, or explicitly re-resolve references after a revision.

The original activity/fishing/leisure/Bragg bake must precede finish passes. Rod and wayfinding construction also require ServerStorage.CrossroadsFishingRodAssets with both heaven/hell templates; importing only workspace geometry does not supply authoring caches. Runtime artwork can use the finished models and references without executing the authoring modules.

No blocking missing native anchor was found among the requested categories. This audit did not enable any prompt, alter a collision, inspect client occupancy behavior, test streaming/multiple players, assign real rankings or certify production APIs. Documentation was corrected for mounted rods, actual LineTip, explicit pet bay names and the floor proxy/receiver contract; no gameplay code was changed.

## Stable bulwark identity companion — applied

`configs/realm_crossroads_interaction_bindings.json` records all37 measured native pivots, bounding-box centers/sizes and expected Entrance classifications. `tools/realm_crossroads/interaction_bindings.luau` returns an Edit/PlaceId0-only function `(world,cfg)`. Apply after original activity creation and arena art; it changes attributes only, with no rename, parenting, collision, transform, tag, prompt or behavior changes.

Each model receives **BulwarkId**, **BulwarkSide**, **BulwarkSegment**, **GatewaySegment**, **BindingRevision**. IDs are explicitly frozen config strings `arena.west.01`…`.11`, `arena.east.01`…`.11`, `arena.north.01`…`.07`, `arena.south.01`…`.08`. Segment ordinal runs north-to-south for west/east and west-to-east for north/south. IDs do not depend on runtime child order. Entrance IDs: west03/west04 with GatewaySegment1/2, south04/south05 with GatewaySegment1/2. All33 static pieces have GatewaySegment0. BulwarkSide identifies both static and entrance sides.

All37 matches must pass before any write: exact count, one-to-one positional match within0.025stud, envelope size/center within0.025stud, rotation vectors within0.0001, matching name/Entrance, both CFrame motion references, unique config IDs, and no conflicting existing semantic attributes. Reruns accept identical values; mismatched geometry or existing identities fail closed. Existing DeployedPivot, RetractedPivot, Entrance and all other attributes remain intact. Expected result bound37 / entrances4 / perimeter33 / revision1.

StyLua and Selene passed with zero errors/warnings. Root applied the companion successfully: bound37 / entrances4 / perimeter33. Parent owns registry insertion. The initial inventory above predates the assignment; these applied counts are the subsequent root native result.
