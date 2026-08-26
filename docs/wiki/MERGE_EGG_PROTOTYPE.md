# Merge an Egg Prototype

Status: Phase 3 live verified

## Phase 1 contract

Phase 1 answers only the core feel question: hatch a small temporary squad, send it down a long
lane, and watch it fight. It deliberately excludes merging, the board/economy loop, production
progression, procedural layout, and multiplayer occupancy.

- The venue is the persistent Studio-authored Model
  `Workspace.Maps.MergeEggPrototype`: one 96×600 continuous land strip with fixed side/end walls.
  It is not a tile-kit map and has no chunk or tile-streaming lifecycle. The small Model is
  atomic under ordinary Workspace streaming so its continuous floor and walls arrive together.
- In Studio, Home's otherwise-disabled `HallOfWorldsPortal` becomes the entry prompt. Production
  keeps the Hall route disabled and sealed. Entry streams the authored strip, then directly pivots
  the player without changing `LastArea`, unlocks, or profile state.
- One player may occupy the prototype per server. Their ordinary runtime pet models are parked in
  `ServerStorage` and restored on exit/reset-character cleanup; ownership data is never touched.
- The test hatcher manifests exactly five Wayfinder ghost pets. Every model is stamped before it
  reaches `Workspace.PlayerPets` with `MergeEggUnit`, a run id, and
  `EphemeralDownPolicy = "destroy"`, so a defeated test unit is destroyed before saved-pet downed
  state or slot lockouts can run.
- Three fixed waves field 3, 5, then 8 low-level prototype Cinder Whelps. Every enemy starts at a
  random point in one authored spawn area and receives exactly one randomized destination across
  the shared finish line; that origin-to-finish vector is its whole path. There is no patrol graph.
- The finish line sits behind the hatcher and manifested squad. Enemies therefore enter guaranteed
  engagement range before they can score; reaching it means they actually passed the defenders.
- Normal aggro owns movement while an enemy is engaged, so pets can pull it off its forward line and
  tank threat/implicit taunt remain authoritative. If the pets fall or aggro clears, a surviving
  enemy resumes toward the same finish from its displaced position. The prototype does not pin all
  five pets to one target; normal pet/enemy threat tables decide who responds to whom.
- At 260 studs from the finish—roughly mid-strip—the defense boundary automatically seeds 250
  ordinary threat on both sides for every live squad pet. This begins combat without a click and
  survives the longer approach, but does not write pet targets or create an assist pin; normal
  damage, decay, proximity, and the Pack Tortoise's tank taunt take over immediately.
- Existing above-floor threat remains eligible outside the ordinary ambient acquisition radius, so
  live tracing measured alert-to-target assignment at about 0.1–0.25 seconds. Distant combat pursuit
  and post-combat return both use bounded pet travel rather than the formation catch-up teleport;
  principal/portal teleports, Rally, and explicit teleport abilities retain their snap behavior.
- Enemies use `rewardPolicy = "none"`, so defeat grants no loot, XP/progression event, tracked
  counter, potion, enhancement, or exclusive egg. Defeat and finish-line arrival are counted
  separately; after every enemy in a wave is resolved, the next larger wave starts automatically.
- The red control resets every prototype unit/enemy and makes the hatch repeatable. The blue control
  exits, restores the parked squad and prior combat-assist attributes, streams Home, and returns the
  character to their exact gate-entry transform. Player leave and character reset use the same
  scoped cleanup.

## Phase 2 contract

Phase 2 changes ownership and observability without expanding to the production queue:

- Deploying the test egg creates exactly one stationary `NpcPrincipalService` principal named
  `Merge Hatcher Team 1`. It uses the existing Future Self/Colorado principal runtime with the
  player's avatar as a temporary visual stand-in; its root remains anchored at `HatcherSpawn`, it
  never follows or teleports to the player, it does not enter `TeamMembers`/alliance state, and it
  has no timer. Reset, exit, character removal, and player leave explicitly despawn it.
- The same five Wayfinders now live only in the NPC's `NpcSquad` folder. `NpcOwner` retains the
  real player for combat attribution and cleanup, but formation, return, and leash ownership use the
  stationary principal. The player's real squad remains parked only to isolate this test.
- Defense alerts call `AlertPetFolderToEnemy` for that one folder. They cannot draft the parked
  player squad or another manifested principal. After the seed, ordinary bilateral aggro, tank
  taunt, target distribution, drive-back, and threat decay remain authoritative. Because a single
  seed can legitimately decay during a long chase, the lane boundary seeds ordinary threat again
  only when both the enemy has dropped its aggro owner and no hatcher pet still targets it. This
  closes the marcher's breakaway gap without pinning a target or overriding the aggro tables.
- NPC pets now have bounded server-authoritative combat positions at the same travel-speed cap as
  their client presentation. Damage range and enemy pursuit use that position rather than treating
  every pet as if it were still standing on the NPC root.
- One team exercises the reusable lifecycle `Ready → Deploying → Engaged → Returning → Ready`,
  plus `Defeated` when every ephemeral pet is down. Folder/world attributes publish active,
  defeated, targeted, and returned counts without adding a custom network feed.
- A Studio-only, read-only `NPC Team 1` rail shows all five stable slots, live endurance percentage,
  defeated tombstones, current enemy targets, team state, active count, and wave progress. Enemy HP
  remains on the existing enemy rail. The observer sends no focus or combat-control remotes.

## Phase 3 contract

Phase 3 scales the verified single-principal seam to four simultaneously active, independently
commanded NPC teams. It still does not add the production deployment queue.

- One hatch creates four stationary principals around `HatcherSpawn`, each with its own five-pet
  folder and the same Ready/Deploying/Engaged/Returning/Defeated lifecycle. All 20 pets remain
  attributed to the real player for combat and cleanup, while movement and return stay anchored to
  their own principal.
- Every principal fields the same readable test roster: two Trail Pup melee units, one Beacon Finch
  ranged/blaster, one Pack Tortoise tank, and one Compass Fox controller. The Finch replaces the
  third melee unit so all four NPC teams exercise independent ranged positioning.
- The prototype stamps a 4× attack-cadence multiplier on both its pets and enemies, and the observer
  displays that rate. This accelerates direct swings only; movement, regeneration, aggro decay, and
  wave gaps remain at real speed. Actors outside this prototype retain the default 1× cadence.
- Every run gives each team a unique `CombatTargetGroup`. Once either an enemy or pet opts into a
  group, bilateral acquisition requires the other actor to publish the same group. Ungrouped combat
  retains the existing global behavior, so this partition does not change normal realm fights.
- The endurance ladder contains 3, 5, 8, 12, 16, 24, 32, and 48 enemies. Each wave assigns enemies
  round-robin across the four teams; the first assignment in every non-empty group is an Ember
  Brute tank and the remainder are Cinder Whelps. This keeps the pressure composition comparable
  even when a small wave leaves one team idle.
- Defense alerts and re-alerts address only the assigned team's folder. Ordinary bilateral threat,
  tank taunts, target choice, drive-back, disengagement, and bounded return still own behavior after
  the seed; an assignment scopes eligible combatants rather than pinning five targets.
- A gold Neon `BulwarkLine` spans the strip 13 studs in front of the hatcher anchors. The line is
  both the visual rule and the authoritative directional plane. Once an enemy crosses it toward the
  finish, that enemy becomes an open emergency target and every surviving NPC folder receives the
  same 250 ordinary-threat seed. There are no idle reserves behind the bulwark, but existing threat
  tables still decide whether already-engaged pets peel from their current targets.
- Team telemetry and lifecycle are independent. One folder can be Ready or Returning while another
  is Engaged, and each publishes its assigned-enemy, target, active, defeated, returned, first-loss,
  and peak-pressure counts. The encounter publishes the first pet-loss wave and active-enemy count,
  and stops as `DefenseOverrun` if all 20 temporary pets are defeated.
- The Studio-only observer renders four columns and 20 stable pet cards plus current/peak pressure
  and first-loss telemetry. A persistent top-center meter spells out each incoming wave (`WAVE ONE`,
  `WAVE TWO`, and so on), briefly brightens on transition, and shows current/total waves, active
  enemy count, encounter state, and the 4× label. It remains read-only and uses folder/world
  attributes rather than a custom network feed.

## Source and authoring

- Runtime/config: `configs/merge_egg_prototype.lua` and
  `src/Server/Services/MergeEggPrototypeService.lua`.
- Read-only telemetry: `src/Client/Systems/MergeEggPrototypeObserver.lua`.
- Repeatable Edit-mode world pass: `scripts/studio/build_merge_egg_prototype_world.luau`.
- The service is registered only when `RunService:IsStudio()` and map binding is enabled. A missing
  authored world fails closed and logs the exact expected Workspace path; runtime never fabricates
  or tiles the venue.

## Live verification

The 2026-08-26 Phase 3 Studio passes established three separate baselines:

- Four independent teams cleared the original 3/5/8 sequence: all 16 Whelps were defeated, none
  escaped, no cross-group target mismatch occurred, and all four teams returned to `Ready`.
- In the quantity-only endurance calibration (fixed Whelps, before enemy tanks), all 20 pets
  survived through wave 7 at 32 simultaneous enemies, or eight assigned per team. The first loss
  occurred in wave 8 with 37 enemies still active. The run defeated all 148 enemies with zero
  escapes and ended with 16 of 20 pets alive. This provides only a provisional lower bound for
  raw head-count pressure.
- Adding one 1,600-HP/80-armor Ember Brute to each non-empty assignment group moved the first pet
  loss to wave 1 with only three enemies active. By wave 2 two NPC tanks had fallen and the clear
  took roughly a minute. Enemy role composition is therefore a much stronger balance knob than raw
  wave size at the current values.

A deterministic breach pass moved Team 3's Brute five studs past the gold bulwark. The enemy latched
`CombatTargetOpen`, all four folders and all 20 live pets received the emergency alert, and Team 4—
which had no assigned enemy—put all five pets on the Brute. Teams already fighting largely retained
their higher-threat targets, confirming that the breach removes idle reserves without hard-pinning
the active teams. The final authored roster also rendered one Beacon Finch in each of the four
observer columns, and the runtime log contained no prototype or target-group errors.

One balance caveat remains visible: generic per-pet regeneration starts at 15 endurance per second
after that individual pet has gone five seconds without a hit, even while its team is still in
combat. Low-damage Whelps can be out-healed by this behavior. Healing was deliberately left
unchanged so tank composition and wave quantity remained separately measurable knobs.

Subsequent early-balance passes run direct pet and enemy attacks at 4× cadence to make the full
ladder observable in a shorter session. Because regeneration and other wall-clock mechanics remain
at 1×, results from this mode measure accelerated-combat pressure and must be labeled 4× rather than
treated as production-time survival numbers.

The first 4× smoke pass stamped all 20 pets and all three wave-one enemies correctly. It recorded
the first pet loss in wave 1 with two enemies active, then advanced into wave 2 in roughly 15 seconds
with four enemies defeated, four active, zero escaped, and 19/20 pets alive. All four teams remained
independently engaged and the runtime log was clean.

## Production direction after Phase 3

- Four hatcher-owned NPC teams and independent targeting are now proven. The production queue is the
  next separate mechanic; it should feed this common team contract rather than create special-case
  principal paths.
- Do not derive egg queue depth from the 8-enemies-per-team Whelp baseline alone. First tune the
  Ember Brute's health/armor and the partial out-of-combat regeneration delay/rate, then repeat the
  endurance ladder. That controlled run should determine replacement cadence and minimum ready-egg
  buffer.
- Tank/melee drive-back that pushes the whole frontline away from the hatcher is desirable lane
  behavior. A legitimately advanced team travels back to its hatcher after combat rather than
  teleporting at the generic catch-up distance.
- The bulwark is a secondary engagement boundary, not a new focus system: strict team ownership
  applies in front of it, and ordinary cross-team aggro becomes eligible only for breached enemies.
- The player remains free to move between hatchers, merge eggs, and manage the board while these NPC
  teams fight asynchronously. Player position must not be a combat leash or scheduling input.

## Explicitly deferred

- Tile generation or tile streaming.
- Merge recipes, board slots, currency, rewards, persistence, or monetization.
- Wave selection UI, production difficulty curves, matchmaking, or more than one active player.
- The four/five-team deployment queue, congestion policy, and production team-state UI.
- Player-team opt-in deployment and combined NPC/player roster presentation.
- Reopening Hall of Worlds in production.
