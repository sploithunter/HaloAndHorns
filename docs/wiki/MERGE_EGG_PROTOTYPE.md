# Merge an Egg Prototype

Status: Phase 2 live verified

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

## Source and authoring

- Runtime/config: `configs/merge_egg_prototype.lua` and
  `src/Server/Services/MergeEggPrototypeService.lua`.
- Read-only telemetry: `src/Client/Systems/MergeEggPrototypeObserver.lua`.
- Repeatable Edit-mode world pass: `scripts/studio/build_merge_egg_prototype_world.luau`.
- The service is registered only when `RunService:IsStudio()` and map binding is enabled. A missing
  authored world fails closed and logs the exact expected Workspace path; runtime never fabricates
  or tiles the venue.

## Live verification

The 2026-08-26 Studio pass moved the player roughly 250 studs away from the hatcher to recreate the
original long-chase failure. The complete 3/5/8 sequence defeated all 16 enemies with zero escapes.
Five wave-three survivors exercised the re-engagement path at least once; the final survivor was
re-seeded four times before defeat. All five pets then returned to the stationary hatcher and the
team reached `Ready`. Hall exit removed the principal, squad folder, and prototype enemies, disabled
the observer, restored Home, and produced no console errors.

## Production direction after Phase 2

- Phase 2 proves one hatcher-owned NPC team. The next phase instantiates four copies of this same
  contract and adds the deployment queue; it must not create four special-case principal paths.
- A production hatcher will field four or five independent teams through that queue. Exact capacity,
  timing, congestion, replacement, and defeated-slot rules wait for the multi-team phase.
- Tank/melee drive-back that pushes the whole frontline away from the hatcher is desirable lane
  behavior. A legitimately advanced team travels back to its hatcher after combat rather than
  teleporting at the generic catch-up distance.
- The player remains free to move between hatchers, merge eggs, and manage the board while these NPC
  teams fight asynchronously. Player position must not be a combat leash or scheduling input.

## Explicitly deferred

- Tile generation or tile streaming.
- Merge recipes, board slots, currency, rewards, persistence, or monetization.
- Wave selection UI, production difficulty curves, matchmaking, or more than one active player.
- The four/five-team deployment queue, congestion policy, and production team-state UI.
- Player-team opt-in deployment and combined NPC/player roster presentation.
- Reopening Hall of Worlds in production.
