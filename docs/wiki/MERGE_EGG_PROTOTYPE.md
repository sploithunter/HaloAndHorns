# Merge an Egg Prototype

Status: Phase 1 Studio prototype

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

## Source and authoring

- Runtime/config: `configs/merge_egg_prototype.lua` and
  `src/Server/Services/MergeEggPrototypeService.lua`.
- Repeatable Edit-mode world pass: `scripts/studio/build_merge_egg_prototype_world.luau`.
- The service is registered only when `RunService:IsStudio()` and map binding is enabled. A missing
  authored world fails closed and logs the exact expected Workspace path; runtime never fabricates
  or tiles the venue.

## Production direction after Phase 1

- The Phase 1 ghosts remain player-principal pets only as a fast combat test. Production defense
  teams belong to stationary hatcher NPC principals, so their formation and return anchor is the
  hatcher—not the moving player.
- A hatcher fields four or five independent teams through a deployment queue. Each team needs its
  own lifecycle (queued, deploying, engaged, returning, ready/down) and combat/formation ownership;
  exact capacity, timing, and replacement rules wait for the queue phase.
- Tank/melee drive-back that pushes the whole frontline away from the hatcher is desirable lane
  behavior. A legitimately advanced team travels back to its hatcher after combat rather than
  teleporting at the generic catch-up distance.
- The player remains free to move between hatchers, merge eggs, and manage the board while these NPC
  teams fight asynchronously. Player position must not be a combat leash or scheduling input.

## Explicitly deferred

- Tile generation or tile streaming.
- Merge recipes, board slots, currency, rewards, persistence, or monetization.
- Wave selection UI, production difficulty curves, matchmaking, or more than one active player.
- Stationary hatcher principals, the four/five-team deployment queue, and production team state UI.
- Reopening Hall of Worlds in production.
