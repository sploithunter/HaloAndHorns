# Hall of Worlds

The Hall of Worlds is the guided first world and the long-term directory for larger worlds,
challenge spaces, and calendar events. It is baked Studio geometry under
`Workspace.Maps.FuturePath`; runtime code binds authored markers and never generates structural
tiles during play.

## Level 1–5 Entry Route

```text
Wayfinder Landing
  tutorial + Egg Bay 1
        |
  tutorial complete + earned Level 2
        v
Gilded Gallery
  Egg Bay 2 + Waycoin caches
        |
      750 Waycoins
        v
Vanguard Walk
  Egg Bay 3 + richer Waycoin caches
        |
     2,500 Waycoins
        v
Worlds Plaza
  Egg Bay 4 + Hall spokes + gate to Crystal World
```

- Fresh profiles begin in `Hall_1`. The authored pad is `Workspace.Maps.FuturePath.HallSpawn`
  (invisible, tagged `PlayerSpawn`). Find it by name in Explorer and move it to retarget
  spawn; the wire pass adopts it in place and does not snap it. Config `spawn_position`
  is fallback only.
  Existing live profiles are grandfathered into Crystal World
  so this migration does not move established players unexpectedly.
- Brand-new tutorial records write `Tutorial.track = 2` (`configs/tutorial.lua` `hall_track`).
  Legacy saves have no `track`. Hall tutorial walls and LastArea Spawn locks check completion
  only when that stamp is present. Do not put `Tutorial` on the ProfileStore template —
  Reconcile would backfill legacy profiles. `Tutorial.version` remains the step-schema
  (currently 3) and is migrated independently. Admin Reset to Beginning (and
  `tutorial.reset`) writes a fresh track-2 record and clears `GameData.TutorialCompleted`.
- Sidekick / team follow can pull an unfinished-Hall player into Crystal World as a
  session guest (`HallGuestVisit`). That does not stamp `entered_crystal_world` and does
  not persist `LastArea` as Spawn. Leaving the team or rejoining returns them to Hall.
  Follow will not warp them into Heaven/Hell.
- Join and death respawn use `GameData.LastArea`, written only from portal travel /
  zone placement — never from the player-list `CurrentArea` (that becomes `mission_*`
  inside a trial). Hall tiles resume on that tile. Crystal World biomes, Heaven/Hell
  layers, and trials all collapse to Crystal World `Spawn`. Admin Reset to Beginning
  clears `LastArea`. In-trial deaths stay in the mission instance.
- The tutorial completion award supplies earned Level 2; crossing the first translucent wall
  requires both tutorial completion and claimed Level 2 for track-2 players.
- Current tutorial completion is `Tutorial.done`; `GameData.TutorialCompleted` is reconciled as a
  persisted compatibility flag. Hall gates accept either representation so profiles that finished
  the event-driven tutorial before the compatibility write was restored are not stranded.
- `hall_coins` display as **Waycoins** and are independent of every origin currency.
- The Hall HUD shows only **Gems** and **Waycoins**. The four origin-currency panes belong to
  Crystal World and stay hidden throughout `Hall_1`–`Hall_4`.
- Hall Waycoin bags, Gold Fern nuggets, coin troves, and gilded chests use the generic breakable
  pipeline. Breakable definitions select `spawn = { method = "drop", height, duration }`; ordinary
  crystals use the default immediate strategy. `SpawnAnimating` is the shared server guard for
  clicks, automatic targeting, and pet mining until a dropped target lands. Do not create a
  separate Hall-only farming path.
- Loose single coins and the shallow coin pile are pickup presentation only. They belong to the
  shared `DropService`/Magnet reward path and must not be added back to a Hall mining spawn table.
- Waycoin GLBs require their embedded UV atlases, not the promotional card renders. The uploaded
  Decal ids are recorded in `scripts/waycoin_texture_atlas_decals.json`, and their resolved IMAGE
  ids are in `scripts/waycoin_texture_images.json`. Explicit textures normalize the MeshPart tint
  to white. The imports also opt into `normalize_part_pivots`: their rotated GLB pivots otherwise
  make Roblox report a false 2.4-stud model height and leave the visible piles floating. The
  authored Hall field top is `Y = 0.6`; `SpawnArea` remains centered at `Y = 2` only as a sampling
  volume.
- Physical Hall rewards use the small Waycoin pile through the shared `DropService` pipeline and
  retain `hall_coins` as their authoritative saved currency. Runtime mesh construction requires
  the Studio-resolved raw MeshPart id; supplying the uploaded Model id fails construction and
  intentionally falls back to the generic green gem. Orientation is resolved once while preparing
  the stored pickup template; the current mesh already imports horizontally and therefore uses a
  neutral correction. Every runtime clone then follows the same pop, ground spin, and Magnet path
  as gems without changing orientation during collection.
- The shared `models_ready` gate includes breakable templates as well as pets and eggs. Hall fill
  must not begin before its Waycoin bag/nugget/trove templates exist; otherwise the failed first
  attempts wait for the slow safety reconciler and make targets appear roughly 20–30 seconds late.
- Hall mineable population is `field_area / 1000 * targets_per_1000_studs` (`2.6` on every Hall
  world). Cap tiles are 304×304 (~92k studs²) → ~240 targets; Hall_2/Hall_3 union the playfield
  plus corner (~42k studs²) → ~108. `worlds.Hall_*.max` is only a safety ceiling. Do not go back
  to fixed 14/18/20 counts — those left Worlds Plaza looking empty. Hall 1 samples a uniform
  random candidate pool inside the authored green-field outline; the shared slot registry still
  enforces occupied minimum distance. Do not replace this with a jittered grid—the grid remains
  visible as rows at this field scale.
- The six `SpawnZone` parts baked into `Tile01`, `Tile03`, `Tile04`, `Tile06`, `Tile07`, and
  `Tile09` are the single source of truth for Hall gameplay footprints. The wiring pass adopts each
  part in place, assigns its route `AreaId`, and tags it for both breakable spawning and
  `HallPlayAreaMarquee`. The marquee **and** breakable drop slots follow the authored white
  `FieldKerb` / `FieldKerbCorner` outline of the green field — the same loop already built into
  the tile — not the smaller `SpawnZone` rectangle. Corner tiles are pentagons whose field
  extends well outside the inscribed spawn marker; sampling the marker box left the 45° cut and
  the far lobe empty. Corridor bends use two markers with the same area id. Never replace these
  with a broad synthetic circle: it admits sidewalks and makes the visible perimeter disagree with
  legal spawn positions.
- `ZoneTrackerService` resolves the Hall's synthetic area bounds when no legacy biome baseplate is
  beneath the player. This keeps `CurrentArea` on `Hall_1`–`Hall_4`, which is required for Farm Near
  to search the correct world's breakable folder after a Hall teleport.
- Four authored `HallEggBay` markers reserve five choices each. The approved egg/pet roster and
  model-safe art prompts live in [Hall World 1 Asset Prompts](../HALL_WORLD_1_ASSET_PROMPTS.md).
- Egg Bay 1 is live with the Hall-specific stand asset `124799395948890` and the
  `wayfinder_egg`. The stand is cached at `assets/place/PlaceAssets/124799395948890.rbxm`, so boot
  does not depend on a live insert. Hall stands are authored map fixtures, same as Crystal World:
  `scripts/studio/wire_hall_of_worlds.luau` seats **new** stands on the real `NookPad`/`Anchor_egg`
  floor (or the nearest walkway when a tile has no nook). An already-placed stand is left where
  you moved it. Runtime and wire snap `UIanchor` to the visible `hall_egg_stand` mesh cup
  (mesh-top + hover), not a stale model pivot or fossilized ground/nook Y. `HallEggBay`
  markers parent to the stand so hatch UI follows the
  pedestal. Do not spawn or re-sit Hall stands during play; sitting them on the invisible
  `HallEggBay` marker top is what left every Hall pedestal floating. Hall egg meshes import at
  ~1 stud; `egg_stand.egg_scale` is `8` so they fill the 12-stud pedestal cup. Do not reuse the
  Crystal World `egg_stand_defaults.scale` of `3.5` here. The client gives only the displayed egg
  a subtle 0.3-stud, 3.4-second vertical float.
- Egg Bay 3 is live as `vanguard_egg`: a 1,000-Waycoin hatch containing Blade Lynx (melee),
  Bastion Ram (tank), Bolt Hawk (ranged), Banner Hare (support), and Chain Serpent (control).
  Runtime placement can resolve the configured route egg even when an older baked marker still
  lacks `EggId`, and it retires the former preview before installing the interactive stand.
- Egg Bay 2 is live as `hall_gilded_egg`: a 400-Waycoin hatch containing Keytail Raccoon
  (melee), Vault Beetle (tank), Crownwing Falcon (ranged), Fortune Wisp (support), and
  Lockbox Imp (control). The uploaded Gilded model was not in the Hall stand package, so
  runtime builds it from `egg_sources.hall_gilded_egg` like the other Hall eggs.
- Egg Bay 4 is live as `worldheart_egg`: a 2,500-Waycoin hatch containing Rift Panther
  (melee), Atlas Golem (tank), Portal Drake (ranged), Star Moth (support), and
  Clockwork Spider (control). Star Moth gold 3D is not delivered; golden/rainbow reuse
  the basic mesh and never the flat card as a texture.
- Hall hatch targeting uses the closest of 3D-to-UIanchor, ground-plane-to-UIanchor, and
  distance to the stand AABB, then clamps the hatch card on-screen. Hall `PlacedEgg`s
  also get a world-space `E HATCH` billboard so a tall pedestal cannot hide the prompt.
- The final Hall gate (Worlds Plaza) travels to Crystal World's `Spawn` and is
  the first-time exit (`HallExitToCrystalWorld`). Hall 1 `Archpad` holds a
  second copy of that arch (`CrystalWorldReturnPortal`) that is **not** a Hall
  exit: it opens only when `HallOfWorlds.entered_crystal_world` is already
  true (v16-grandfathered live accounts, or anyone who later used the Plaza
  door). New Hall players see "Finish the Hall" and cannot skip. Home's
  return arch sits on the `Portal_Home` footprint: copy `Heaven_1.Portal_Home`
  and drop it **2000** studs on Y (same XZ as every layer's back-to-base gate).
  Copied Home `Gate` meshes keep a stale WorldPivot; the travel trigger is
  snapped to the visible arch so the doorway actually fires.
- Hall progression walls keep a lock prompt only while their target area is locked.
  `ForcePrompt` must not keep "Unlock N hall_coins" up after `UnlockedAreasJson` already
  contains that area — the wall is already locally transparent. Crystal World travel
  portals are not `HallGate` and still keep their Travel prompt.
- World Travel does not expose the non-Hall catalog to a fresh player before the Hall exit.

## Authority and Studio Binding

`scripts/studio/wire_hall_of_worlds.luau` is an idempotent Edit-mode wiring pass. It authors four
area/spawn bindings, three translucent progression barriers, four egg-bay anchors, and the three
travel triggers (Plaza Crystal World exit, Hall 1 Archpad return, Home Hall arch). Rerunning it updates these bindings rather than duplicating them. It also adopts
the authored landing barn and its 21 Hall fence sections into `Tile01_cap`, anchors them, and binds
the invisible `BaddieSpawnerHallBarn` marker just inside the field-facing doorway. The marker uses
the normal proximity-wave lifecycle and group gate; its only Hall-specific binding is Earth-family
enemy selection plus the established current-area currency fallback, so defeats pay Waycoins.
Progression-wall prompts are parented to authored Attachments 4.5 studs above each wall's bottom,
placing the E/tap affordance at player height instead of at the center of a 28-stud barrier.

Progression is enforced twice:

1. `HallRouteGates` presents each wall per player, hiding and disabling local collision only after
   that player's target area is unlocked.
2. `ZoneService` validates tutorial, level, currency, route order, and Hall-exit state on the
   server. Client changes cannot unlock or cross a stage.

The authored map currently occupies the positive-X lane, away from the repeating Heaven/Hell
layer stack. See [Map Integration Contract](MAP_INTEGRATION_CONTRACT.md) for placement and terrain
constraints.

Hall `ZoneLandmark` mills sit on ShoulderDeck: plinth bottom at Y=-3. Tile01's
mill was authored 3 studs higher (Y=0), which left a garden-bed gap under the
base. Keep new copies on the deck, not the walkway.

The baked route has two separate perimeter systems. `InvisibleWall` parts are authoritative safety
collision, while `BarrierBank`, `GrassPedestal`, and `AccentPiece` template placements provide the
visible screening cliffs. The latter depend on persistent prototypes in
`ReplicatedStorage.GenMap.Assets`; a missing asset library makes the map generator skip them without
removing the invisible walls. The current Studio place restores all 842 authored placements (779
screening banks and 63 accents/pedestals), tagged `HallTemplateRepair`, at the Hall's positive-X
offset. Do not replace or delete those tags during Hall wiring passes.

## Hall Pets

Hall pets use the `hall` element rather than a Crystal World origin. In Crystal World they begin at
80% elemental effectiveness. This reuses the existing element-effectiveness seam while keeping the
Hall roster portable and leaving room for later Hall-specific strengths. Their Meshy meshes import
at about 1 stud, so `asset_transform.scale` is `3.2` — the same silhouette lane as the tester
exclusives and the ~3-stud homeworld pets. Do not copy the generic `1.6` used by larger imported
Crystal World meshes or Hall followers stay half-size.

The complete art roster for Bays 2–4 is staged under `assets/source/references/pets`, with resolved
Roblox mesh/texture assets in `scripts/pet_mesh_ids.json`. Pet `texture_asset` must use that
manifest's `imageId`, never `textureDecalId` — MeshPart textures ignore Decal ids and render gray.
Cleaned transparent card art is under `assets/exports/hall_world/thumbnails`, and its resolved
image ids are isolated in `scripts/hall_pet_thumbnail_assets.json` until gameplay definitions are
authored. All delivered
normal and gold models are present except for the Star Moth gold GLB: Downloads supplied its normal
model and both card images, but no separate gold 3D source. Do not substitute the flat card image as
a mesh texture or silently treat the normal model as gold.

## Range and Training Ground

The reserved Challenge Field lives on **Hall_2 Tile04_corner Field**, not Worlds Plaza. Room
1–99 is a difficulty index **and** a fixed layout sequence: everyone's Room N is the same map
(`seed_policy = "gauntlet_room"`, Range `room#N`, Training Ground `train#N`). Early rooms
are one chamber. Late rooms cap at entry + up to 3 (`tile_budget = 4`). Settings Enemy
Level and Trial Enemy Group Size do not apply. Advancing
restamps Room N at the same slot, then restocks. Pets warp to the entrance
with the player — they do not stay in the last chamber and pull the new pack.
Do not stamp 99 tiles; the mission slot
envelope cannot hold that. Do not use `shared_sequence` here — that advances Trial `MissionSeq`.

- **The Range** (`RangePad`, `MissionId = range`): catalog pets and powers (GhostPet loaned squad,
  temporary powers). **Solo only** — a teamed player is refused at the door and on start
  (`range_solo_required`). Everyone fights at **level 50** for the run
  (`effective_level` → `ChallengeLevel` → `EffectiveLevel`); real levels
  restore on exit. Entry is two menus you can flip between: **Inventory** (same pet cards,
  badges, Best Pets) and **PowerChoice** (origin chooser, tooltips, up to 6 loaned powers).
  Closing either menu (X or ESC) abandons the draft, clears the open-menu flag,
  and re-arms the pad E so you can open it again without leaving the pad.
  Every visit can pick an archetype and tweak powers; those picks persist as four Range
  defaults (`GameData.RangeDefaults.by_origin`, one kit per origin) plus the last pet
  squad, so the next visit loads the last settings instead of a blank chooser. Do **not**
  put `RangeDefaults` on the ProfileStore template. Enter from either screen starts the
  run and does not change the owned squad or live powers. Owned inventory is parked and
  restored on exit. Ranks the run. Catalog loans basic Exclusive Colorado and Kade plus a Hall mix — no
  huges, never `colorado_creator`. Saved `RangeDefaults` drop illegal pets
  and take variant/huge from the current catalog. Catalog variants use
  `golden` / `rainbow` (not `gold`) so cards and GhostPets resolve the real
  models. Loaned powers are the **only** legal kit
  for the run (server `ChallengePowers` allowlist): owned Swift/Magnet/Resonance and any
  other unselected power stay off, including on the server. They are auto-slotted — Hasten
  gets 6 recharge (perma); every other power gets 3 recharge + 3 focus. Players do not
  slot by hand; optional custom slotting can come later. Entering or leaving The Range
  clears every hotbar auto-cast lock (the lock is on the slot, not the power). Next Room
  warps you to the new map's entrance. Trials density settings and team pack-scale do
  not apply. Farmable crate / crystal-node debris is off — those slots
  were the SmallBlueCrystal crate placeholder (sideways crystals). Magma Wyrm
  waits until `boss_at` (room 25). Genie and Revive are not in the catalog.
- **Training Ground** (`TrainingGroundPad`, `MissionId = training_ground`): your own pets and
  powers, same loop, easier curve.
- No downed-pet summons, Genie/Djinn revives, or `ResurrectPet` inside a gauntlet. A downed
  slot stays down for the run (HUD shows **Down**, no Ready/Summon). Pet equip is
  allowed on the stamped **entry** tile for **white** slots only — a red slot cannot
  take a new pet. Fight rooms refuse roster changes. Overworld slot lock is 60s
  (same reserve: unequip does not free it). After you leave a gauntlet the run-long
  slot lock becomes a 60s overworld lock. Squad wipe
  (every squad pet down) records the last **cleared** room and tears down, same as leaving
  through the entrance.
- Persist `GameData.ChallengeRuns.<mode>.best_room` and a sliding-window `recent`
  attempt list only when a run exists. Do **not** put `ChallengeRuns` on the
  ProfileStore template (same Reconcile trap as Tutorial). Current boards
  `range_current` / `training_ground_current` publish the windowed best
  room when a run ends (and on join). Window expiry sweeps at server
  start, every 5 minutes, and BindToClose. Internal IDs still write;
  `hide_internal_accounts` only omits them from the visible top 10
  (TEMP off for Macros testing). Window is TEMP 2 hours (production 48).
  Backend only — no HUD yet.
- Wire adopts named pads in place and does not snap a user-moved pad back to fallback
  coordinates. After a gate rotate, move the pad to that arch (`scripts/studio/align_challenge_pads.luau`)
  — the E-prompt parents to the pad. Save the place after the pads/arches exist.
- Hall gate lightning is client ambience driven by the saved `ArchLightning/lightning1…18`
  marker groups under the Range, Training Ground, both Crystal World directions, Home, and
  Hell test arches. `ArchLightning` rescans streamed hosts, hides the marker parts, and fires
  rapid jamb-to-jamb bolts only near the player. The supplied 0.48-second buzz is group-owned
  audio `80802960194213`; it is a separate positional Effects-bus sound at volume `0.12`,
  throttled to one nearby arch every 0.65–1.1 seconds. If an arch is rebuilt, run
  `scripts/studio/stamp_arch_lightning.luau` in Edit and save the place.
- Gate signs: `RangeLeaderboard` / `RangeGuide` live on Hall_2
  `Tile04_corner`; `TrainingGroundLeaderboard` / `TrainingGroundGuide`
  live on `Tile07_corner`. Tag `LeaderboardBoard` (`BoardId` =
  `range_current` / `training_ground_current`) or `ChallengeGuide`
  (`GuideMode`). SurfaceGuis use Front (optional `SurfaceFace`). Range
  signs face +X into the field; Training Ground signs face the other
  way (−X) so Front faces the same field. Do not yaw all four the same
  direction. Do not snap a user-moved sign.

## Reserved Plaza Spokes

These remain design contracts, not active Plaza gameplay:

- **Mirror Missions:** the player's chosen squad is frozen at entry; a clone/future-self ally runs
  the mission with no pet revives or mid-run squad changes.
- **Luck Egg:** a server-authoritative timing/stacking interaction that grants luck-focused pets or
  tokens. The client may animate timing, but the server owns the result and rate limits.
- **Event Gate:** one stable Hall destination that routes to the currently active calendar area.

## Hoverboard Travel

The Hall awards a standard hoverboard when the player completes the tutorial and earns Level
2. It is a traversal graduation reward for the Hall and later large worlds, not a combat power,
developer product, or second permanent-speed entitlement. Press **H** or the **Board** button
to the right of Powers (same BaseUI + pill + HotbarFlank path as Powers).
There was no implementation before 2026-08-19. V1 is
`HoverboardService` + `HoverboardController` with one skin per Meshy colorway
(`configs/hoverboard.lua` `skins`; default `black_gold`). Each skin is its own
mesh + matching albedo via MeshAssembly — Meshy re-unwraps recolors, so a
shared mesh kaleidoscopes. Five hoverboards, five Chevron surfboards, and
six rocket boards. Per-skin `pitch_degrees` / `roll_degrees` /
`deck_yaw_degrees` override the global hoverboard flatten so surf/rocket
meshes can lie deck-up. Locked surf flatten is sole -0.2, pitch 90, roll
0.5, yaw 180. Rockets are length 8.1 (150% of 5.4) with yaw 90; sole/pitch/roll
start at -0.2 / 0 / 0 and may move after the resize. Tuner roll is a rail bank around the long axis;
it is not composed as world-Z after pitch (that duplicated yaw at 90°).
IDs live in `scripts/hoverboard_assets.json`. The HUD Board button uses the
keyed black-gold icon (magenta stills → RGB+alpha). Procedural deck remains
the fallback if the mesh fails to load.

V1 intentionally does not enable the dormant mount-inventory category:

- one standard hoverboard is available to every eligible player;
- a HUD mount button and keyboard binding toggle it, with a mobile button beside the movement
  controls;
- the server owns eligibility and mounted state while the client owns hover pose, lean,
  ride trails, and board animation. Skate and surf keep one deck wake. Rockets emit
  two nozzle trails tinted with each skin `accent_color`;
- mounted speed is `max(normal effective movement speed, configured hoverboard cruise speed)`
  (cruise is 64, about 4× default walk);
- hover height is ground → deck clearance (`hover_height` 3.6) plus hip. The
  downward probe is a fixed 28-stud search; skipped steep/underside hits must
  not shrink that budget or the mount hop freezes in the air until the rider
  moves. No floor → fall until one is found;
- mounting is a short vertical hop in place (avatar `Animate.jump`/`fall` at
  2.2×, ~11 studs apex, 0.36s) so a mid-stride pose cannot pin the deck. After
  the leap, the rider
  stands sideways on the deck (Root joint yaw 90°). The deck welds only
  after idle has posed the feet, then restamps once more — otherwise the
  hop-to-idle blend parks the board under a low foot pose and the rider
  floats until something restamps (Admin used to do that). Tuner attrs
  apply only while Admin is on. Live R15 avatars use
  `AnimationConstraint` for Root, not `Motor6D`; the stance weld disables that
  constraint. The deck welds to `HumanoidRootPart`, not the feet. Ride uses
  `PlatformStand` + `LinearVelocity` so walk/run animations never play;
- combat engagement, taking damage, trials/missions, death, and precision interactions
  such as eggs or the Ascension Altar dismount or suppress the board. Crossing
  Hall_1–Hall_4 (the old progression-wall seams) only changes `CurrentArea` and
  does not dismount;
- mounting never changes pet identity, player progression, or saved combat statistics.

Kade (`536245038`) sells the five hoverboards, five Chevron surfboards, and six rocket boards from the Hall 1 fisherman shack
(`Tile01_cap.Shack`). A gold neon block-letter sign (`KADE'S` / `BOARDS`)
sits on the roof. The client builds it from `shop.location.sign` via
`BlockLetterSign` and runs the rainbow cascade locally.
Talking to him opens a square-icon grid catalog (keyed skin
icons; no 3D board lineup) and his Colorado story: he asked for boards for
three years, then paid for them himself so he could give some away and open
the shop. Owned skins show **OWNED** / **EQUIPPED** and never offer Take,
Buy, or Robux again (`canBuy` returns `already_owned`).
All five skate hoverboards are free. Surfs cost gems (900–1100). Rockets
are on sale; the card shows Roblox's live `PriceInRobux` (regional /
managed pricing), not the config baseline of 19. Each rocket is a permanent,
personal game pass sold only through Kade: rocket passes are hidden from the
Pet Shop, cannot be traded, and cannot be purchased again after the matching
board is owned. A live pass uses `PromptGamePassPurchase`, including Roblox's
Studio purchase simulator; rocket passes do not auto-grant through ordinary
Studio `test_mode`. All six group-owned pass IDs are live as of 2026-08-21.
Rockets cruise at 2× skate (`cruise_speed` 64 → 128).
Ownership is `GameData.Hoverboard` (`owned` + `equipped`); the dormant
mounts inventory bucket stays off. Owned boards also replicate into
`Inventory.hoverboards` and appear on the Items tab for equip. Free
catalog skins are granted only when the rider is eligible (tutorial +
Level 2). Admin **Reset to Beginning** wipes `GameData.Hoverboard` and
the Items-tab folder so kept unique pets do not keep Kade's boards.
Black Gold is also granted with the Level-2 board unlock. The HUD
mounts whichever skin is equipped.

Four client-built award podiums bind to tagged `AwardPodium` hooks in
`Workspace.Maps.FuturePath.AwardPodiums` (a Folder, not inside a tile
Model — click-select and Explorer search work). Names:
`AwardPodium_MostDragons`, `AwardPodium_CrystalCrusher`,
`AwardPodium_EnemiesDefeated`, `AwardPodium_TeamPower`. Each hook's
`BoardId` is one origin board. Each pad has a white arrow for front
(name plates and figures face that way). Move the hook in Studio; do
not hardcode pose. Stamp helper: `scripts/studio/stamp_award_podiums.luau`.
