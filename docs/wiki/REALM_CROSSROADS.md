# Realm Crossroads

Status: R11 imported into Farm and Fight and saved to Roblox (2026-09-09). Root: `Workspace.RealmCrossroadsR4`, translated (-8192, 0, 0). Visual companions, spaced Crossroads arrivals and the local Farm gate run. Homeworld’s former Merge doorway now returns locally to Crossroads using its existing E prompt. Arena combat, the coin garden, featured egg hatching, fishing, and Pet Siege routing are connected. Crossroads owns the arrival introduction; the Farm gate releases ordinary Farm onboarding. See [import contract](../art/crossroads-review/FARM_IMPORT.md).



## Arena combat — 2026-09-09

`CrossroadsArena` starts one shared encounter when a loaded player with a live squad enters
`CrossroadsActivitiesR7.PatrolGrove.CombatBounds`. That authored 64×102 outer floor footprint
is the boundary; the surrounding promenades, stands and gathering terrace are outside it.
`configs/crossroads_arena.lua` owns teams, early-level stat scaling, spawn grid, timing and FX.
The first eligible entrant opens the round; their team lead supplies effective level and menu
settings. Nearby strangers can fight inside, but do not inflate the opener's team count.
Only the opener's eligible teammates inside the floor contribute population/HP team scaling.
Menu changes apply to later encounters; the existing level-offset path also applies during spawn.

Composition uses `MissionPopulation` and `PackScale`: the Trial / Arena Enemy Group Size slider
controls density, extra bosses and the max-slider villain chance. Species keep their combat kits;
rank uses the Trials ladder and EnemyService's numerical level offset. The early Woodland team
is available at levels 1–4; Frostlight/Blight teams cover 5–50. All teams have a frontline boss.
Arrival bolts use `EnchantLightning` client-side at server-timed markers (12 segments per bolt,
no second core, 220-stud visibility, no strike under Crossroads reduced motion). An encounter
caps at 24 enemies. It rests 12 seconds after clear and cancels after 8 seconds with no eligible
fighters, after 10 minutes, or when its authored map hooks disappear.

EnemyService's per-spawn movement leash clamps chase, retreat, loiter, knockback and scripted
moves. An extra conservative body-radius inset keeps the mesh inside the outer edge during yaw;
oversize enemies fail closed. Territory and targeting exclude owners outside the floor, including
assist selection and spectator team-credit sharing. These flags are opt-in; ordinary Trials and
Home leashes keep their contracts. Physical visitor access and bulwark visuals stay authored.

Normal play uses the existing contributor/team combat award path and actual defeat deduplication.
Bosses receive the source Trials egg definition: 0.5% Celestial/Obsidian per credited player;
archvillains use the existing 2% premium and event modifiers still apply. There are no fabricated
mission clears, first-clear bonuses or Pet Siege wave counts. Studio arena rewards default off.
`tools/realm_crossroads/arena_combat_qa.luau` runs only as a temporary Server Script in Play,
checks scaling/bounds/clear lifecycle without profile setting writes, then restores player attributes.
Solo runtime and simulated team-density tests are not a multiplayer performance validation.

Arena audio uses the supplied “Let's go” clip once when each player crosses into the floor,
with an 8-second re-entry debounce, through the Voices bus. The server stamps a fresh per-player
`CrossroadsArenaEntryCue`; remaining inside or starting another round does not repeat the voice.
The thunder source is trimmed by 3.51 seconds, leaving its main impact at approximately 14 ms.
Only the first arrival marker carries `ThunderCue`, so a whole team makes one clap through Effects.
Audio is preloaded and remains enabled with reduced motion; volume/mute preferences still apply.
Source/edit provenance and upload IDs live in `assets/audio/crossroads_arena/`.

## Coin garden and featured egg — 2026-09-09

`configs/crossroads_garden.lua` owns the coin asset, silver HUD art/palette, wallet definition,
spawn cadence/value/cap, collection radius, and pavilion egg source/price/height. The initial
`crossroads_featured_egg` offer clones Wayfinder's content at 100 **Crossroad Coins**; changing
`egg.source` selects another configured egg's art, odds, variants and hatch behavior without
changing that egg's original shop price. Restart the server after changing the offer config.

`CrossroadsGarden` binds the authored `CoinGarden` floor/field and pavilion anchor, replaces
its visual preview at runtime, and registers the offer with the existing EggStand query. Shared
EggService handles proximity, locks, player hatch choices, affordability, pet storage and debit.
Crossroad Coins use the normal `Currencies` profile map and generic zero-start migration.

The garden drops mineable blue-and-silver chests through the same BreakableSpawner strategy
as Hall targets. `CrossroadChest` (120 HP / 25 base coins / 3.5 studs wide) and
`CrossroadStrongbox` (400 HP / 75 base coins / 5 studs wide) have 3:1 weights. One falls every
2 seconds while a loaded player is nearby, capped at 12 shared targets, with a 12-stud spacing
budget. They are unmineable during their 0.9-second descent. No currency is emitted on spawn;
normal pet mining, contribution credit, Boost and reward modifiers produce the silver pickups
on destruction. Magnet and Auto Collector collect those released rewards. Empty-garden cleanup
destroys targets without payout. Targets are shared, while awarded pickups remain owner-only.

`breakables.activity_worlds` maps the dedicated `CrossroadsGarden` target folder to Spawn's
mining unlock gate. AutoTarget respects the player's normal targeting mode/range and PetFollow
checks that same mapped gate. Activity callers own lifetime, so automatic world fill/respawn does
not populate the garden. `SpawnMissionBreakable` remains a compatibility wrapper around
`SpawnActivityBreakable`. Per-target placement and explicit floor overrides are merged before
bounds alignment; otherwise the global floor at zero buried the new chest models.

CurrencyStack follows `CrossroadsAtmosphereZone` and shows only Gems and Crossroad Coins
throughout Crossroads, restoring the ordinary area's HUD after departure. The UI icon uses a
transparent ImageGen PNG; matching Meshy coin/chest meshes use their UV albedos, not HUD renders.
Asset provenance lives beside `assets/exports/crossroad_coin/` and `crossroad_chest/`.

Native QA confirmed a persistent wallet, a successful 100-coin egg hatch granting a Golden Pack
Tortoise, configured hatch odds/entitlements, live pet mining, and the correct two-currency HUD.
A controlled native check filled exactly 12 targets, observed no HP loss or free currency before
mining, then assigned pets through BreakableService and confirmed destruction/reward. All 12
bounds bottoms matched the authored floor at Y=4.38. All 2,860 headless tests pass, including
the offer/wallet/content and managed-world routing contracts. Full CI remains blocked by the
pre-existing CrossroadsArena.lua arrival task.wait architecture finding.

## Nine Lives card identity — 2026-09-09

Rainbow Kitty's inventory/equipped/trade card now carries a lower-right purple `9` badge.
`PetBadge.createReviveBadge` resolves the variant through `PetAbilityRuntime`; the numeral is
its configured maximum revives, not a remaining-lives counter. Basic and Golden Kitty have no
badge. `inventory.buckets.pets.card_visuals.revive_badge` owns its palette and relative layout.
The shared InventoryPanel card renderer supplies the same badge to trade previews.

## Live Bragg podiums — 2026-09-09

Eight configured alcoves now consume canonical filtered `leaderboard.snapshot` and
`LeaderboardUpdated` data through `CrossroadsPodiums`; the six garden/relic alcoves stay art.
All 24 authored rank attachments and nameplates are reused. Original preview figures and
168 PREVIEW letters are archived under `CrossroadsAuthoringR11.BeforeLivePodiums`.
Replay `tools/realm_crossroads/bind_live_podiums.luau` with leaderboard config after importing R11.
No AwardPodium tags or duplicate platforms are created. Runtime labels identify GLOBAL or
THIS SERVER, show real names/scores, and distinguish empty/loading/unavailable data.
At most 12 nearby noncolliding dancing avatars load, one appearance request at a time;
32 descriptions are cached. Stream-out and distance cleanup invalidate pending figures.
The stands now mirror these eight categories, rank 1/2/3 in configured category order,
across the 24 explicitly reserved `PodiumSpectatorSlot` IDs. Repeated members retain each
category placement. Eight enabled aisle visitor Seats are untouched; absent rankings leave
reserved seats empty. The audience shares the serial appearance loader and 32-description
cache, with its own 24-figure/150-stud budget (combined maximum 36 with podiums).
Seated R15 poses support Motor6D and AnimationConstraint rigs, freeze their joint tree,
and disable Humanoid state evaluation/animation. Keep the Humanoid: removing it makes
Roblox lose the member's rendered clothing/body appearance. Accessory placement resolves
matching attachments directly because newly created AccessoryWeld endpoints may still be unset. Streaming podium geometry
out retains ranking state so nearby spectator seats still populate. Preview audience art is
archived by the same binding helper; the client also hides legacy preview parts on old imports.
Config owns reserved slots, scale, pose angles and budgets. No audience ranking writes occur.

`leaderboards.bragg_tracking` registers three new lifetime counters and ordered stores:
`siege_highest_wave_cleared`, `siege_waves_cleared`, and `bosses_defeated`.
The Merge successful-settlement boundary records clears with a unique wave-attempt GUID;
overruns and escaped final objectives do not clear. Replayed successful attempts add totals.
EnemyService's existing credited kill-award boundary counts boss/archvillain tiers. Farm team
eligibility is unchanged; Merge retains its durable Full-mode pet owner plus completed Combat
Training requirement for broader kill-stat credit. NPC hatchers, nearby spectators, and escapes
receive no boss credit. Both modes use one boss boundary, not an extra Merge callback.

`BraggProgress` mutates counters and a bounded 512-receipt deduplication queue in the same
owned profile, schedules the existing debounced save, and signals leaderboard updates.
Online/offline provenance totals live in `GameData.BraggProgress`; offline actors use their
leased profile. No history is inferred from reached-wave records. General Studio global reads,
score tracking, and writes remain disabled. An internal-account-only, read-only Crossroads preview
can fetch the eight displayed boards so authorized map reviews show the real public winners.
These changes must be deployed to both places before both contribute new production scores.
Native QA covered all 24 labels, temporary client-display avatar fixtures, cap-height/facing,
and memory-only offline facade save/signals. Full CI includes deduplication, replay, provenance,
invalid outcome, bounded receipts and no-backfill tests. No fabricated score was persisted.

## Spatial atmosphere — 2026-09-09

`RealmAtmosphere` is the sole global lighting/sky controller. `areas.crossroads.atmosphere`
owns the imported origin, bounds, 1.2-second lighting tween, polling, and neutral exclusions.
Negative local X uses Heaven 1; positive X uses Hell 2, matching the existing Merge looks.
The 40-stud center corridor, 66-stud Bragg radius, and both side-ramp approaches remain
Purgatory (captured base sky/light). Exclusions win over side selection; a two-stud
neutral exit margin prevents boundary chatter. All outer side activities inherit their side.
Sky textures switch at the boundary; lighting, tint and atmospheric haze tween. No second
Sky or competing controller is added. Leaving the map restores CurrentLayer behavior.
Classification uses config bounds rather than streamed geometry or camera position.
Native QA: 12 region/boundary assertions; Heaven/Hell sky and light changes; Bragg east
edge restores base sky/tint; Homeworld clears the override. Full CI: 2,846 tests pass.

Crossroads ambient music follows the same `CrossroadsAtmosphereZone` attribute and neutral
exclusions. `sounds.crossroads_music_areas` references `Heaven_2_Grass` (Grass Meadow) and
`Hell_2_Grass` (Lava Homeworld B), so edits to those source mappings carry through. The neutral
center/Bragg area keeps its normal area music. AreaMusicController retains its existing fade,
music-volume bus, combat priority and load fallback; leaving the hub restores normal area music.

## R8: realm landscape and outer safety boundary

Heaven occupies negative X (left) and Hell positive X (right), matching the gates.
Config-named Edit baker `bake_landscape.luau` themes terrain and structural surfaces,
keeps the center neutral, and places 225 existing textured perimeter flora models, plus two Hell accent trees around the rim:
pale/pink/cyan trees, flowers and quartz left; dark/coldfire/lava-eye trees, ash/brush,
bones and spires right. Staggered canopy and understory rows leave activity floors,
Bragg and the central overlook approach clear. Native templates are cached under
ServerStorage.CrossroadsLandscapeAssets. Landscape bake follows the activity bake.

Eight overlapping invisible collidable walls follow an inset clipped rectangle around
the island. They extend from Y=-32 to +68, behind perimeter vegetation, preventing ordinary
walking/jumping off the outer edge. These global safety walls are separate from the future
combatant-only arena containment rule. Cardinal approach tests blocked at all four outer sides, including the front away from
the overlook rail. The arena entry remains walkable in this map preview.

## R7: side activities — map only

The hub will live inside Farm & Fight. User explicitly deferred gameplay integration.
The two +4 garden terraces now contain a west **Coin Garden** and east **Patrol Grove**:

- Coin Garden: 64×90 open drop lawn, perimeter circulation (coin specimens removed after scale review),
  original Hall stand and Wayfinder egg as display-only specimens under an open pergola.
  The physical title is **Egg of the Week**; no weekly schedule, roster or price is set yet.
- Patrol Grove: 64×102 combat footprint, low staggered cover, four invisible route markers,
  and the existing tier-2 Impaler Palisade bulwarks. Lightning was removed at user request.
  Two 14-stud entry spans are shown retracted; each segment stores DeployedPivot/RetractedPivot
  for later rise animation. Bulwark meshes are currently noncolliding;
  combatant-only containment belongs to later gameplay integration,
  rear encounter anchor and Heaven/Hell banner ruins. Southern gathering terrace and benches
  keep waiting players outside the marked combat footprint. Temporary alliances remain
  the existing gameplay system to bind later; none are simulated by the map.
- Both retain the existing +4 garden stairs and 1:8 ramps. Both stair and ramp routes, plus the egg-pavilion approach, passed walking checks at speed 24. Existing flowers, saplings, skulls,
  quartz and bone rocks decorate edges instead of replacing the playable floor.
- Both fields are now 64 studs wide, centered at X=±120. Inner edges remain X=±88.
  Symmetric terrain extensions keep +4 terraces through |X|=160 and rise to the +12 rim
  by |X|=176; the island remains 360×320. Original flank terrain is backed up in
  ServerStorage.ActivityTerrainWestBefore/EastBefore. Multiplayer squad crowding still
  needs a live gameplay test; this is the authored space, not a capacity guarantee.
- `configs/realm_crossroads_activities.json` names `tools/realm_crossroads/bake_activities.luau`.
  `ServerStorage.CrossroadsActivityAssets` caches original textured geometry from Farm & Fight
  and Merge. Author after the terrain/crest/Bragg passes. Geometry is not generated in Play.
- Markers have `IntendedBinding` metadata only, no active gameplay tags. All example assets
  are static, noncolliding and stripped of scripts/prompts/tags. Bind Hall-style shared
  BreakableSpawner/DropService/Magnet, existing EggStand hatch logic, bounded patrols and
  RealmAllianceService when integrating into Farm & Fight. Do not revive Hall entry routing.
- Patrol bounds and alliance engagement radii need an explicit integration review: current
  realm engagement radii are much larger than this compact garden. Keep recruitment and
  chase/leash behavior inside the activity; do not pull hub bystanders into fights.

## R6: Bragg Rotunda and Siege ranking plan

User accepted the R5 gate artwork and requested more Bragg capacity plus Siege-specific
rankings using existing leaderboard rules. The [R6 design](../REALM_CROSSROADS_BRAGG_PLAN.md)
now has a +4 circular court, 116 studs across, with a low 18-stud fountain, fourteen
2/1/3 alcoves, eight initial categories, and six reserve bays. Shared stairs/ramp landings
avoid routing visitors through podiums. Geometry is built; production tracking remains pending. Eight podium groups have physical PREVIEW nameplates; six reserve bays at positions 2/4/6/9/11/13 alternate among the rankings, with three Heaven flower displays alternating with three Hell skull displays. These reuse Merge's field_flower_bush, softglow_bloom, crystal_bloom and horned animal_skull meshes, plus the catalog hell_skull_lantern. Improvised flowers and floral medallions were removed. No FUTURE signage remains. A low halo-and-horns fountain anchors the center.

The source already saves **highest wave reached** when a wave starts. New Highest Wave
Cleared and Total Waves Cleared require durable server-side settlement counters. User replaced
the redundant boss-wave proposal with **Bosses Defeated — All Realms**, counting actual
boss defeats in both Farm & Fight and Pet Siege; do not relabel or migrate reached-wave values as clears. The plan defines receipt
idempotency, legitimate offline provenance, reset/migration behavior, existing internal-ID
exclusions and publication cadence, and bounded winner-avatar loading before expansion.
`configs/realm_crossroads_bragg_plan.json` names the Edit-only `bake_bragg.luau` art companion.
Regenerate in order: TerrainBake, CrestBake, BraggBake. No runtime geometry generation.
`BeforeBraggR6` retains original terrain and superseded gallery geometry. Stairs, both ramps
and the fountain-side aisle passed walk tests at speed 24. Reuse the existing Studio instance.

## R5: Pet Siege naming and architectural gate titles

User accepted **Pet Siege** as the mode name, with **SIEGE** as the large gate title.
The internal Merge place/key is unchanged. User rejected simple billboard-style labels
and approved paired architectural crests with sculpted lettering, contrasting materials,
and separately controllable lighting/ornaments. Blender and Meshy were authorized tools.

The first built pass uses Blender 5.1.2 to sample Georgia Bold outlines, then authors
extruded native CSG letter solids in Studio Edit. The sampled geometry is tracked in
`configs/realm_crossroads_glyphs.json`; no font binary is redistributed. This gives exact
spelling and editable native geometry without external asset uploads. Meshy was not needed
for this precise typography pass. Each letter, border, ornament and light remains separate.

- Farm & Fight: two-line bronze lettering in a pale stone field, gold border, halo and feathers.
- Siege: large warm-metal lettering in a dark field, ember border, horn silhouette and crown.
- Physical information panels: Grow / Hatch / Fight and Merge / Share / Defend, with relief
  icons and extruded captions. Zero title/relief GUIs.
- Crest mounting straps connect to the arch shoulders. Face key lights and crest lights use
  restrained six-second pulses and an approach boost; static geometry never animates or
  rebuilds at runtime. The engineering overlay is hidden for judging the arrival view.

`configs/realm_crossroads_crests.json` names the font geometry and Edit-only art companion
`tools/realm_crossroads/bake_crests.luau`. Blender generator:
`Blender --background --factory-startup --python tools/realm_crossroads/build_crest_glyphs.py`.
The seed preparer now embeds both bakers; require TerrainBake first, then CrestBake in Edit.
Do not run the seed preparer over an existing saved authored preview. Crests may be rebuilt
in the existing local preview; that replaces only `GateCrestR5` under each gate. Native
letter templates are cached in ServerStorage. Copy edits that introduce new letters require
regenerating the glyph config first.

Verified in Play: both gate paths pass at speed 24; new art has zero colliders; 50/40 native
solids in Farm & Fight/Siege; zero title GUIs; proximity light brightness changes; no console
errors. Full repo CI passes 2,842 headless tests and native crest baker passes Selene.
Saved in the same `RealmCrossroads-R4-Terrain.rbxl` local file, without opening another copy.
`output/realm_crossroads/Gate-Crests-R5.jpg` records the arrival view. This is the first
architectural art pass, not finished whole-island art or production routing integration.

Native serialization exports over 100 KB exceed the MCP response cap. Store export text
in temporary 50 KB StringValue chunks (a single StringValue caps at 200 KB), transfer all
chunks, join/decompress locally, then wrap the native payload with `save_native_terrain.luau`.
Remove the temporary export folder afterward; exclude it from its own serialization.

## R4: authored terrain and elevation walkthrough

The user requested assessing every elevation change before shaping the Roblox map.
`configs/realm_crossroads_terrain.json` owns the grading plan; its named
`tools/realm_crossroads/bake_terrain.luau` authors real Terrain once in **Edit**, only
in a local PlaceId=0 preview. No runtime geometry builder is installed.

| Area | Elevation | Transition |
| --- | --- | --- |
| Spawn, court, both gate landings | 0 | Level choice routes |
| Side gardens and Champions terrace | +4 | Vertical stone retaining faces; stairs and alternate ramps |
| Lower arrival overlook | -4 | Central stair and paired ramps |
| Planted outer/rear rim | +12 target | Landscape slopes around 1:2 to 1:2.5; not primary routes |
| Island underside | -24 | Steep voxel rock perimeter cliff |

Each stair rises/drops 4 across eight 0.5-stud risers with 2-stud treads. Each
alternate ramp runs 32, giving 1:8, and is 16 wide. Terrain supports raised
landings and the grades under stairs. Stone skins give precise risers and
vertical retaining faces where Roblox's 4-stud voxel reconstruction rounds edges.
The +12 planted rim is approximate; the rear marker raycasts near 11.6. Primary
terraces raycast exactly 0/+4/-4. A half-cell occupancy adjustment was necessary
to prevent Terrain from burying the paths 2 studs above the intended datum.

The saved preview uses the actual Merge bay arches at 30%, native SurfaceAppearance,
and 5-stud noncolliding inset faces. The demon mesh is natively upright: use identity
mesh rotation plus 180-degree facing yaw. The older source-placement matrix tilted it
sideways/down and was removed after visual verification in the gate. Spawn-to-gate distance remains 70.5 studs,
about 2.9 seconds at the configured Merge default speed of 24. Client-local
proximity tint demonstrates the 26-to-10-stud Heaven/Hell lighting transition.
Travel, dialogue, live leaderboards, and finished landscaping remain unimplemented.

Validation: direct Humanoid MoveTo tests at speed 24 passed both arch openings,
gallery stairs/ramp, garden stairs/ramp, and overlook stairs/ramp. Testing found a
center gallery column obstructing the stair entrance; columns now leave the
center approach open. These are representative routes with the current avatar,
not a claim that all avatar scales and every terrain edge are tested. Repo CI
passed 2,842 headless tests; native bake passed targeted Selene.

Artifacts under `output/realm_crossroads/`:
- `RealmCrossroads-R4-Terrain.rbxl`: saved native terrain/art in a standalone place.
- `Realm-Crossroads-Grading-R4.svg`: grading plan, transition key and stair/ramp section.
- `R4-Saved-Terrain.jpg`: saved-place overview.

Rebuild: `mise exec -- lune run tools/realm_crossroads/prepare_terrain.luau` creates
an **unbaked seed** (overwrites the local output, so preserve an existing baked file).
Open that seed once in Studio, then require `ServerStorage.CrossroadsTerrainBake`
in Edit. Save locally. The alternate native export flow serializes Terrain and
non-service art with SerializationService, wraps children in service-named folders,
then runs `save_native_terrain.luau` on `native-r4-export.rbxm`. This preserves the
native Terrain payload instead of approximating it with Parts. Saved-file reopening
verified terrain heights and speed. **Do not open a second copy of the same local
place to verify it:** duplicate Studio windows lock editing. Reuse the current
instance; the user explicitly flagged this workflow issue.

R1/R2 drawings below remain historical. R4 supersedes the R2 +12 Champions level
with a +4 usable terrace and reserves +12 for the planted rim.

## R3: existing Merge arches, inset faces, separated lighting

The user requested evaluating the large gates at the enemy-spawn end of each Merge bay,
plus the circular Farm & Fight return portals. They prefer reusing the larger detailed meshes,
scaled down, with the angel/demon **inside** the doorway to talk to or walk through. This replaces
the earlier face-above-gate arrangement. They also requested separated Heaven/Hell approach
lighting like Merge, while preserving short walks from spawn.

Read-only inspection in the active Merge **Server** datamodel on 2026-09-08 found:

| Family | Native mesh W × H × D | Evaluation |
| --- | --- | --- |
| Heaven bay arch | 99.5 × 94.0 × 40.0 | Preferred matched architectural pair; at 30% becomes 29.8 × 28.2 × 12.0 |
| Hell bay arch | 99.8 × 93.5 × 43.4 | At 30% becomes 29.9 × 28.1 × 13.0 |
| Celestial return ring | 23.6 × 24.0 × 22.1 | Usable fallback; raised base and deep platform |
| Infernal return ring | 34.7 × 34.9 × 32.0 | At 24 high becomes 23.8 wide × 22.0 deep; coordinated travel-station pair |

Exact source paths, mesh/SurfaceAppearance IDs, dimensions, and measurement caveats live in
`configs/realm_crossroads_gate_study.json`. Source captures are under
`docs/art/realm_crossroads/gate-study/`. `tools/realm_crossroads/draw_gate_study.py` generates
`output/pdf/Realm-Crossroads-Gate-Study-R3.pdf`: A-04 asset comparison, A-05 inset-face elevation,
and A-06 wider entrance spacing / lighting plan. The elevation is diagrammatic, not replacement art.

### Scale and fitting constraints

- Trial the bay arches at 25%, 30%, and 35%, with identical player references. The 30% example
  is a sizing proposal, not a completed scale test. A roughly 5-stud face centered at Y=6.5
  fits within the arch; keep it non-colliding and fit by visible bounds.
- Coarse full-depth raycasts of the current **Default collision**, in 1-stud horizontal /
  2-stud vertical samples, found native base openings around 18–20 studs, widening to about 32.
  At 30%, that is only **5.4–6 at the base**, widening to 9.6. R2's 10 × 12 clear opening is
  **not established for these meshes**. Test a real character at the smaller scale, including
  the base/stair lips, before accepting passage width or final landing height.
- Hell gate Model bounds include high lightning hooks and report ~414 studs of height;
  scale using the visible mesh, not that Model bound. Preserve SurfaceAppearance maps:
  all four inspected gate meshes have empty `TextureID`.
- Clone art only. Do not import Merge bay attributes, enemy spawn hooks, existing return
  prompts, or lightning marker towers into Crossroads. No existing Merge assets were edited.

### Revised placement and lighting proposal

Keep the 360 × 320 island proposal. Spawn remains X=0/Z=100; move gate centers to X=±40/Z=42
(**80 studs apart**) and turn each ~34.6° toward spawn. Direct spawn-to-center distance is
70.5 studs, about **2.9 seconds at Merge's default 24 studs/s**; the entrance threshold is
slightly closer. The user selected the Merge default speed for Crossroads on 2026-09-08.
Its source is `configs/places.lua` → `roles.merge.walk_speed`, consumed by
`PlaceRuntime.walkSpeedFor`; this excludes movement buffs. Use that configured speed for the
next walkthrough, even if the hub ultimately lives inside Farm & Fight. This is a hub-specific
design requirement, not authorization to increase all Farm & Fight movement speeds.
This supersedes R2's gate positions and the R3 study's earlier 16-stud/s / 4.4-second estimate.
R1/R2 historical drawings and the rejected preview remain unchanged.

Each gate gets a proposed 26-stud outer lighting radius, easing to full theme within 10 studs.
The circles leave a **28-stud neutral gap** along the line joining their centers. Spawn and the
gallery remain outside these regions. Heaven uses pale/gold light; Hell uses darker ambience
with ember highlights. Preserve floor, face, and sign readability. Final camera visibility and
walking times still need a Roblox pass; do not claim the wider layout is verified in Play.

`src/Client/Systems/RealmAtmosphere.lua` already owns client-local realm looks. In Merge it
selects spatial zones with hysteresis and tweens numeric lighting; elsewhere it follows
`CurrentLayer`. Extend that ownership when implementing hub proximity later, rather than
adding a competing lighting controller. Restore the neutral/base look on leaving a gate zone;
handle sky swaps deliberately instead of assuming sky textures blend like numeric properties.

Interaction proposal: a Talk / Enter prompt plus optional threshold crossing; no required
dialogue and no teleport merely for standing nearby. Face recedes/fades as the player enters.
These remain design proposals, with no new production routing or lighting implemented.

## R2 takes precedence over the first blockout

The user walked/reviewed the initial scale and found the **doorways too large and the island
too small**. Stop adjusting the existing Roblox build by eye. Develop and review dimensioned
architecture before the next bake. The concept's composition remains approved; R2's numeric
dimensions are proposed, not yet approved or implemented in Roblox.

`configs/realm_crossroads_design.json` records R2 dimensions separately from the superseded
`realm_crossroads.json` first-bake parameters. `tools/realm_crossroads/draw_architecture.py`
produces three landscape architectural sheets in `output/pdf/Realm-Crossroads-Architecture-R2.pdf`:

- **A-01 site plan:** 360 × 320 island; 290 × 270 walkable terrace. Spawn X=0/Z=100;
  gate centers X=±26/Z=54, angled 29.5° toward spawn. Each gate is approximately 53 studs
  from spawn, or 3.3 seconds at the 16-stud/second reference speed.
- **A-02 elevation and passage section:** 10 × 12 clear openings; structure 18 wide,
  18 high, 6 deep; avatar envelope 9 high, starting at Y=19. Total height 28. Reference
  player height 5.5; actual Roblox avatar sizes vary. Match visible mesh bounds, not pivots.
- **A-03 longitudinal section and iteration contract:** court Y=0; side gardens +4 via
  32-stud ramps at maximum 1:8; rear terrace +12; cliff base -16. Low central landmark
  20 diameter / 12 high. Gallery 120 × 28 × 22, front Z=-88; target walking route 12–15 sec.

The approved generated concept is retained at `docs/art/realm_crossroads/approved-concept.png`.
It is an aesthetic reference, not a source for exact dimensions or the real avatar mesh identity.
Render the PDF and inspect all three sheets after drawing changes. The drawing script requires
Python with ReportLab. Its detailed drafted geometry is part of the design source; update the
drawings and dimension registry together when a dimension changes.

### Instructions for the next Roblox revision

1. Ground/camera pass: only terrain footprint, paths, spawn, doorway placeholders, and 5.5-stud
   player references. Confirm both entrances fit a default third-person arrival view.
2. Architectural pass: follow A-02. Keep the complete 10 × 12 clear opening, level thresholds,
   readable mode labels, 18-stud clear routes, and matched avatar/gateway envelopes.
3. Landscape/art pass: add terraces, art meshes, planting, and water outside the arrival
   sightline. Keep four podium alcoves, each ordered 2 / 1 / 3. Measure walking times.
4. Compare the same three cameras after every revision: arrival eye level, overhead plan,
   and gallery looking toward spawn. Change one dimension family at a time; save revisions
   separately. Obtain the user's scale feedback before production spawn/travel integration.

Do not claim R2 is walk-tested based on the first build. R2 remains a paper proposal.

## Approved direction

A neutral arrival courtyard inside Farm & Fight lets players choose Farm & Fight, Merge,
or future modes. Voxel terrain and mesh landmarks follow Merge's art direction. An angel
and demon sit over equally prominent mode entrances. The optional rear champions arcade
contains ranked 2 / 1 / 3 podiums. Side gardens reserve future mode entrances.

The initial concept was approved in conversation. Footprint and walking distances remain
subject to the user's Roblox walkthrough. First pass: 240 × 220 studs, 20-stud paths,
18-stud gateway openings, roughly 65 studs from spawn to each gateway center. Gallery
is approximately 160 studs beyond spawn, with paths around the central landmark.

## Superseded first local preview (R1)

Run from repository root:

```sh
mise exec -- lune run tools/realm_crossroads/build.luau
```

Outputs (local, reproducible; not deployed):

- `output/realm_crossroads/RealmCrossroads-Preview.rbxl`: standalone place, default avatar
  controls at 16 studs/second, enabled spawn, and Return to spawn button.
- `output/realm_crossroads/RealmCrossroads.rbxm`: authored map model with its preview spawn
  disabled. No runtime scripts, active game tags, or automatic travel are in this model.

`configs/realm_crossroads.json` owns layout parameters, palette, gate labels, and the exact
angel/demon mesh references inspected in Merge Edit. Those are the existing Watcher face
meshes, not the full-body stand-ins depicted by the generated concept image. Preview figures
on the podiums are placeholders; ranking categories and periods are deliberately unassigned.

The baker only creates local files. It does not overwrite a live Studio map, Terrain, game
spawn, profile, or place setting. Geometry is baked once for Studio editing, not built at
runtime. Import as a separate Model; choose the final Farm & Fight location and wire the
spawn and travel contracts after the scale walkthrough. Do not enable the preview spawn
in the production game without reconciling Homeworld's forced spawn and tutorial rules.

## Next decisions

- Walkthrough feedback on footprint, gateway proportions, and gallery distance.
- Final Farm & Fight placement and terrain/mesh art pass.
- Ranking categories and periods; real avatar displays.
- Production spawn, tutorial entry, return routing, and future mode registry.

See [Hall of Worlds](HALL_OF_WORLDS.md), [Map Integration Contract](MAP_INTEGRATION_CONTRACT.md),
and [Studio Workflow](STUDIO_WORKFLOW.md).

Existing Bragg decor is cached in ServerStorage.CrossroadsExistingDecor, preserving the Merge mesh/textures. Model IDs, scaled heights, placements and yaw live in the Bragg config; the Edit baker loads catalog models only if the template cache is missing. All decorative mesh collisions are disabled.

## Standalone Confluence fountain candidate (2026-09-08)

A separate agent completed the user-requested ImageGen → Meshy → Blender → Assets → Roblox
pipeline for a circular Heaven/Hell fountain. It remains outside the map for review.
`configs/confluence_fountain.json` owns the contract and IDs; `assets/place/Confluence.rbxm`
is the 22-stud diameter, 7.8-stud height native assembly with 24 textured MeshParts and nine
scrolling fluid Beams. The group-owned raw geometry Model is recorded in config. Raw FBX
import reverses the horizontal orientation; the native companion corrects Heaven to negative X
and Hell to positive X. Source, provenance, checks and placement limitations are documented in
`assets/source/props/confluence/README.md`. The shared Models/MissionProps libraries and
all open maps were left unchanged. Production placement and visual effect review are pending.

The Confluence is now placed in the existing isolated Bragg map at (0,4.44,-88),
seated on the actual court surface. Prior fountain is retained under ServerStorage.FountainBeforeConfluence.
Both side routes passed at speed 24; native nine Beam effects are enabled for in-map review.

Confluence pool tops now use 383 conservative rectangular masks sampled from the original
Blender pool meshes. Original pool meshes are hidden; colored noncolliding surfaces carry
tiled textures. StarterPlayerScripts.ConfluenceSurfaceFlow scrolls them locally at 15 Hz
within 100 studs (water U=.25, lava U=.075 studs/sec, config-owned). Both rates were measured
in Play. No stone/metal geometry or production gameplay is animated. Copy the client companion
when integrating the native fountain into Farm & Fight; a standalone model alone does not run it.

Paving junctions now receive an Edit-time CSG trim after all art/theme bakes. Config
`realm_crossroads_paving.json` names the selected floor patches and footprint priority;
`trim_paving.luau` subtracts higher-priority footprints through lower-priority slabs.
Twelve overlapping pieces were cut in the current preview, including arrival/gate branches
and garden links. Original slabs are backed up in ServerStorage.CrossroadsPavingBeforeTrim.
Rebuild floor geometry before rerunning this finishing pass. Do not solve floor intersections
by stacking nearly coplanar faces; adjacent materials need cleaved, non-overlapping boundaries.

## Spectator stands and fishing pond (2026-09-08)

`configs/realm_crossroads_leisure.json` and its Edit baker extend the side lobes to
X±228 (safety boundary ±224), locally around the activity gardens. East has four
ascending rows of eight native Seats, a central stair aisle and rear/end rails.
Twenty-four static seated copies of podium height references preview the audience;
eight aisle-side seats remain enabled for visitors. These are dummies, not rankings.
West has a 48×80 oval Terrain-water pond with a walkable bank and two wooden fishing
platforms. Existing flora was moved to the new outer edge; 16 invisible wall segments
replace the old footprint boundary. Terrain backups remain in ServerStorage.

Fishing is layout only: fish and rods need assets; land-shark code reuse needs review.
Possible catches/rewards are Enhancements, potions and eggs, with economy unspecified.
No fishing or automatic podium-audience gameplay has been added.

The arrival path now continues from Z6 through Z120 to the rear stair landing. The
visible raised spawn pad is removed (spawn remains enabled but invisible/noncolliding).
`finish_arrival.luau` prepares the continuous footprint before the paving trim, then
replaces the center with individual stone pavers and separate edge strips. Its returned
finish function must run after trim. Floor intersections share a common surface height.

After paving trim, run the configured `side_junction.bake_source` finishing repair.
The garden-ramp links reach inward to |X|16; their former |X|20 endpoints missed the
outside diagonal edge at Z88, leaving small mirrored notches. The repair subtracts
the existing diagonal solid, preserving a clean shared boundary with no stacked faces.

## Fishing capacity revision (R10, 2026-09-08)

`configs/realm_crossroads_fishing.json` and `bake_fishing.luau` supersede the small R9
pond after the leisure pass. Heaven is now 88×112 studs with ten 10×12 platforms
around the bank. Hell has a 56×96 pool behind the stands with eight platforms.
Both use real Terrain water. Water color is global to the place and is left unchanged;
the Hell setting comes from the surrounding landscape. Catches are not wired. Existing flower/quartz and
bone/brush assets decorate spaces between stations. Perimeter flora is relocated,
with matched side land extensions reaching |X|300 and invisible walls at |X|296.
Terrain and old pond/boundary backups are preserved in ServerStorage. Fishing assets,
rod interaction, catch tables and rewards remain future gameplay work.

Hell water now has a local green mist layer: `hell_mist` in the fishing config and
`bake_pool_mist.luau` author 20 noncolliding sources across the ellipse. Native particle
emitters animate without a gameplay script. Reviewed at the fishing bank in Play;
water reflections and fishing platforms remain visible. Run this after the fishing bake.

## Premium design review (2026-09-08)

[Eight-section design package](../art/crossroads-review/README.md) retains 37 screenshots,
independent section reviews and a coordinated implementation plan. Each area receives 20
specific improvements, phased build steps, asset briefs and acceptance criteria. This is
planning evidence, not implemented geometry. The screenshot atlas preserves the current
preview before the proposed art pass; distant overview omissions are documented.

The user explicitly supports modest new FX built in `~/Documents/RBX-FX-GEN` when useful.
Its current crystal-only scope is not a creative ceiling. The package identifies narrow
ambient/ripple/burst extensions and separates them from larger editor/platform investments.

## Premium construction checkpoint (R11, 2026-09-08)

The review now has a native first construction pass: 300 fitted approach pavers,
36 arrival plants, rear sculpted gate titles, Bragg masonry/24 figure fixes, a
fitted two-realm arrival inlay, a supported garden arch pavilion with four Seats,
32 crafted stand chairs, recessed rear masonry, and 18 detailed fishing docks.
Two source-first Blender rods are uploaded and mounted, with actual tip anchors.
The retained map remains a local PlaceId0 preview; production content is unchanged.

`configs/realm_crossroads_polish.json` lists seventeen authoring passes in application
order. The native exporter refreshes their embedded modules/configs from disk,
without rebaking serialized CSG/terrain. Apply core before heraldry and fishing
polish before rod placement/interaction setup. Source and uploaded rod provenance
are named by `configs/realm_crossroads_fishing_rods.json`.

The standalone RBX-FX-GEN ambient extension is locally committed at `503334d`; a
config-named bundle is vendored into this preview. It replaces the old Hell mist
with one client-owned field at the approved 20×4/s density, adds restrained gate
embers, and supports distance/quality/reduced-motion lifecycle controls. Native
full/off/stop/restart/destroy checks passed. Screenshot capture does not reliably
show the particle cloud, so property checks are not a new visual approval.

A Studio-only local cast/reel rehearsal uses the 18 station attachments and leaves
no catches or rewards. Cast height is sampled from actual Terrain water (currently
Y0), correcting the older nominal Y2 assumption. Leaving the station/respawning
cleans the bobber and line. Gates and the weekly egg remain disabled authored stubs.

[Implementation status](../art/crossroads-review/IMPLEMENTATION_STATUS.md) records
completed craft and remaining art/device QA. [Gameplay integration contract](../art/crossroads-review/GAMEPLAY_INTEGRATION.md)
details server authority, fishing reservations/settlement, authored podium binding,
wave-clear versus reached metrics, global boss deduplication and future cutover.
Do not enable production podium tags directly: the existing AwardPodium renderer
would generate duplicate geometry unless adapted to these authored anchors.

The ambient bundle also includes the small pooled ripple extension (`bcd1619`):
a cast emits one 32-segment Beam ring, expanding/fading above sampled water,
with no texture plane. The two-ring pool and reduced/off/reduced-motion cleanup
passed native smoke checks; the integrated cast and water contact were viewed.

The R11 lossless native checkpoint is retained under
`assets/source/maps/realm_crossroads/RealmCrossroads-R11.rbxl`, named by the polish
registry and deliberately absent from production Rojo mappings. It retains Terrain, cached source assets, authoring modules and cosmetic scripts.
The latest additions are saved in the native checkpoint; round-trip verifies17,593instances,18rods,18stations and16enabled visitorSeats.
The dry-bank route finish changes only SolidMaterial, verifies both occupancies
unchanged, and widens the Heaven dock-wall passage to12.3studs without reducing
the64-stud coin field. Both bank passages passed native navigation.

The latest native additions include a22×14 bowed timber fishing shelter with four
genuine Seats, two inert dry pet/display bays, two small bushes and three cached
backdrop trees. Its roof tops atY14.2; the18-cell material spur changes neither
terrain occupancy channel. Lead verified RestSeat_1_1 Humanoid sit and exit in Play.
Both pond approaches now have physical sculpted FISHING signs. The version2
textured fossil is placed using `configs/crossroads_fossil.json`; eight Bragg
category emblems are installed; the corrected wave medal orientation passed a native close view. Remaining
whole-map/device QA and the east-annulus collision-query ambiguity are retained
in the linked status/audit. Pet bays perform no automatic pet placement.

The follow-up arena floor pass replaces only the measured64×102Playfield with
fitted stone and a cut crest, preserving top4.38 and a hidden authoring-bounds proxy.
The fossil setting adds12cached grounded meshes; pier posts now extend into sampled
solid bed while preserving their tops. Temporary sightline fixtures are isolated in
`arena_sightline_qa.luau` and excluded from the saved authoring registry. Native Seat
smoke tests cover all8visitor slots; rendered target visibility is a separate check.

A native route sweep reached 49 recorded endpoints at speed 24, including the
larger fountain walking loop and both fishing connectors. All 37 bulwarks now
have stable config-owned side/segment IDs for future containment binding; this
adds no gameplay. The outer 12-wall collision loop passed 1,080 radial samples
at three heights, with no sampled gap. See ROUTE_QA.md, BOUNDARY_QA.md and
INTERACTION_STUB_AUDIT.md under the section-review directory for evidence and limits.

Original pearl/gold pond fish are retained through ImageGen→Meshy→Blender source,
with a two-bone skin and native texture verification. `realm_crossroads_pond_life.json`
owns the shallow paths, local tail/surfacing motion and quality controls. The companion
reuses RBX-FX-GEN WaterRipple; visual FX must be installed before pond life. Both ponds
passed appearance and lifecycle checks without water changes. All18station approaches
and eight social Seats also passed sequential native checks. Decorative fish are not
catch targets; future catches remain server-authorized integration work.

The completion audit and dimensioned as-built drawing now live in the review
folder. All 18 standard-body fishing proxies fit simultaneously; both rear-bank
loops remained navigable. These noncolliding fixtures establish layout clearance,
not multiplayer load or server reservation correctness. The 17 finishing passes
also replayed twice on the existing authored preview. Retained landscape grounding
uses a fixed world-height ray to prevent small cumulative vertical shifts on rerun.
A replay still requires the original native geometry and cached assets; it is not
an empty-place build. See REBUILD_QA.md for inputs and verification limits.

Checkpoint saving now archives the ordered registry and supplementary glyph,
FX-bundle and client sources in inert `ServerStorage.CrossroadsAuthoringInputs`
StringValues. This does not rerun installers or refresh installed runtime code.
`tools/realm_crossroads/validate_checkpoint.luau` compares both source archives and
installed runtime sources/configs, native caches and accepted paving count, and
rejects temporary whole-world QA backups. Use explicit input/output paths from
`tools/realm_crossroads/CHECKPOINT_WORKFLOW.md`; the legacy wrapper defaults still
name R4. Five deliberately broken checkpoint fixtures verify stale/missing input
rejection without altering the saved map.

The alternate spectator access is now built: two 8-stud-clear, 1:8 flights reach
existing tier Y12 from ground Y4, with a 7.5-stud-clear underpass. It is pass 18,
after arena polish; two interfering native flora and two end rails are retained
in its dedicated original archive. All 32 Seats and the 12-stud pond passage stay
in place. Direct up/down/underpass movement passed without sampled jumping,
falling or swimming. The latest 17,695-instance save passes source/runtime/cache
validation; its hash and precise limits are in IMPLEMENTATION_STATUS.md.

## Final-terrain foliage grounding — 2026-09-09

The imported perimeter retained old raised-ground elevations in 51 placements after the side
terrain was flattened: 25 Heaven and 26 Hell, with a maximum 7.8-stud air gap. The Edit-only
`tools/realm_crossroads/ground_foliage.luau` post-import pass consumes
`configs/realm_crossroads_foliage_grounding.json` and lowers only floating models under
`CrossroadsLandscapeR8.PerimeterFlora` onto final Terrain with a 0.35-stud root embed. It preserves
scale, yaw, X/Z positions and original pivots as attributes. Raised-bed/platform decor is excluded.
Run after terrain/import edits; fixed-height terrain rays and the positive-gap gate prevent drift.
Native verification: all 225 perimeter models checked, 51 lowered, zero moves on second run;
69 matching non-perimeter landscape models checked against supporting surfaces with no gaps
above 0.3 studs. Ground-level Heaven/Hell views verified trunk and bush contact.
The saved place retains the helper, config and change report in ServerStorage.

## Client-timed fishing — 2026-09-09

`CrossroadsFishing` binds all 18 existing stations on both sides. It retains authored Cast/LineTip
attachments and the local cast, bobber, ripple and reel presentation. E / controller X / on-screen
Hook stops the last rendered luck value; Q / controller B / Cancel releases the station. The bar,
bite delay, timeout and catch/escape roll run entirely on the client. The user explicitly accepts
client manipulation to avoid server latency affecting timing. No reservation lease, server clock,
minimum cast duration or reaction validation is part of this design.

`configs/crossroads_fishing.lua` owns all tuning, colors, controls, copy and weighted reward bundles.
Ordinary casts peak between 65 and 94; 2% of casts get a brief surge to 100 (0.08-second plateau).
Higher stopped luck selects better reward tiers and lowers escape chance from 72% at zero to 2%
at 100. Initial rewards are Crossroad Coins and gems; no separate fish inventory was introduced.
The design adapts the link between bar control and catch quality described in
[Stardew Valley fishing](https://stardewvalleywiki.com/Fishing) to a single timed button press.

Only after a successful local hook, `fishing.claim` sends station, attempt GUID, score and caught.
`CrossroadsFishingService` validates finite input and station proximity, selects a configured
reward through RewardService and saves it through DataService. It trusts the local timing and
escape result. `GameData.CrossroadsFishing` retains the latest 24 attempt receipts in the profile;
retrying a retained attempt returns its receipt without another grant. This bounded retry window
is not general exploit prevention or a cross-save transaction guarantee. Existing garden coin
currency is reused. Cancellation, death, stream-out, walk-away and menu opening clean up local FX.

Validation: 2,866 headless tests passed, including ordinary/rare peaks, elapsed-time scoring,
escape odds and reward tiers. Native Heaven keyboard catch at 43 awarded 50 Crossroad Coins;
Hell on-screen Hook at 45 awarded 2 gems. Replayed receipt did not add currency; NaN rejected.
iPhone 17 Pro landscape and portrait HUD checked, minimum Hook height 49 pixels. Keyboard cancel,
walk-away, timeout and menu blocking passed. Controller X cast passed; Studio's virtual input
blocked B, so physical controller cancellation remains unverified. Full CI still encounters the
preexisting CrossroadsArena line 185 task.wait architecture gate.

## Trail Pup shepherd replacement — 2026-09-09

Trail Pup keeps its catalog ID, name, stats and Wayfinder/Crossroads egg weights, but now uses an
adult German Shepherd with a trail pack, authored via ImageGen and Meshy. Basic/Rainbow share
new shepherd geometry and texture; Golden uses the corresponding new Golden source. Flat card
icons were updated in both pet configs and thumbnail overrides. The final closed 4,958-triangle
mesh passed integrity checks before and after retexturing. Provenance and group-owned IDs live in
`assets/exports/trail_pup_shepherd/README.md`. Config scale 5.2 follows the user's body-width reference: the shepherd must be taller than the
short-legged AutoDog. The user rejected both the 3.4 height match and the original 4.4 preview as
too small. Final shepherd bounds are 1.893 × 3.797 × 5.2 studs.

`drops.auto_collector.visual` independently retains the original dog mesh/texture/scale.
DropService prebuilds that visual through MeshAssembly and clones it outside PlayerPets; it no
longer derives collector appearance from the hatchable Trail Pup. Missing dedicated assets do
not silently substitute the egg dog. Old configs without a dedicated visual keep their template
fallback. No inventory species or hatch variants were added. Native Basic/Golden/Rainbow prototype
sources and original auto dog verified; 2,867 headless tests pass, including collector separation.

## Arrival introduction and connected gates — 2026-09-09

`crossroads_tutorial.lua` owns the optional welcome, captions, angel/demon sequence, layout,
and narration deadline. `crossroads_voice_assets.lua` binds seven new original recordings;
source copy, MP3s, alignment and validation live under `assets/audio/voices/crossroads_tutorial/`
and `configs/voice_comments/crossroads.json`. Existing voice models, character gains, and the
Voices volume preference are reused. These new lines currently use English fallback for all
language preferences; existing destination tutorials retain their localized recordings.

Each client session welcomes the player with the angel, explains Farm & Fight and Pet Siege,
and explicitly offers free exploration. The first hell-side crossing queues an uninterruptible
angel → demon → angel → demon exchange after the welcome. The demon then owns hell guidance.
Returning to heaven gives one short angel greeting. Neutral ground retains the previous guide;
subsequent border crossings change guide without replaying the exchange. Optional Coin Pup
comments use this same hub guide, so the angel does not take over on the hell side. Side detection uses
RealmAtmosphere's existing hysteresis attribute, independent of CurrentRealm/level progression.
Movement stays available and captions progress even with muted/unavailable audio.

`CrossroadsOnboarding` suppresses the Farm starter chooser, tutorial guidance, tutorial event
advancement and step grants until the Farm gate is used, and suspends guidance on hub returns.
PrologueService defers its first eligibility decision until that gate; ZoneService can place a
Crossroads arrival while this decision is pending. Saved tutorial/prologue progress is retained.
The dedicated Pet Siege place keeps its own existing onboarding.

The shared narrator reserves the voice channel for the entire conversation, including gaps.
Other tutorial speech retains only its latest deferred cue; obsolete/cleared lessons are dropped.
`CrossroadsDialogueActive` is a bounded cosmetic client-to-server signal. While narration owns
the channel, each player may queue one gate intent. Completion releases it, after rechecking the
character, life and gate proximity; disconnection clears it. A config-owned 150-second deadline
releases a stalled client. This signal does not grant pets, currency or tutorial completion.

The Crossroads Pet Siege marker routes to the configured merge place. A per-character touch
latch survives failed teleports: waiting inside never repeats attempts, leaving the padded gate
volume rearms touch, and E permits a deliberate retry after the five-second cooldown. Both Pet
Siege endcaps and the Quartermaster return to the main place's Crossroads arrival. Their visible
copy says Crossroads; the existing internal `main` role and `farm_fight` action remain compatible.

Native Studio verification: all seven Sounds loaded; the four handoff cues ran in order; a gate
entered during the demon's final line made zero attempts during speech and one after completion.
Standing inside after simulated failure stayed at one; an explicit prompt retry made the second.
The Farm gate resumed saved tutorial step 6; returning to Crossroads hid that guidance again.
Both endcap prompts and Quartermaster dispatch resolved main place 77766176054993; actual
cross-place teleport completion cannot be tested in Studio. The older unsynced Pet Siege snapshot
also needed existing collector_voice/BraggProgress and matching leaderboard/stats config copies
before clean Play startup. Runtime QA stubs are discarded when Play stops.
