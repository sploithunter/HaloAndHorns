# Merge an Egg Prototype

Status: Phase 5 live verified

## Phase 1 contract

Phase 1 answers only the core feel question: hatch a small temporary squad, send it down a long
lane, and watch it fight. It deliberately excludes merging, the board/economy loop, production
progression, procedural layout, and multiplayer occupancy.

- The venue is the persistent Studio-authored Model
  `Workspace.Maps.MergeEggPrototype`: one 96×300 continuous land strip with fixed side/end walls.
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
- At 260 studs from the finish, the defense boundary automatically seeds 250 ordinary threat on both
  sides for every live squad pet. The shortened Phase 4 approach now starts inside that envelope, so
  deployment begins immediately without a click; it still does not write pet targets or create an
  assist pin. Normal damage, decay, proximity, and the Pack Tortoise's tank taunt take over.
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
- A gold Neon `BulwarkLine` spans the strip 43 studs in front of the hatcher anchors. Its label is
  written flat on the ground just behind the line; there is no floating billboard obscuring combat.
  The line is both the visual rule and the authoritative directional plane. Crossing is measured from
  the server-authoritative `MoveTarget` plus the enemy's forward oriented-bounds extent and one stud
  of contact tolerance. It never uses the model pivot: enemy visuals are client-interpolated while
  the server pivot normally remains at spawn. Once an enemy crosses, it becomes an open emergency target and
  every surviving NPC folder receives the same 250 ordinary-threat floor. The floor refreshes every
  0.5 seconds while the enemy remains breached, so a team can finish its current target and still
  acquire the emergency afterward.
  There are no idle reserves behind the bulwark, but existing threat tables still decide whether
  already-engaged pets peel from their current targets.
- While the early prototype trace is enabled, every breached enemy prints each surviving pet's
  current target, threat on the breached enemy, top threat row, reciprocal enemy threat, distance,
  hostility/territory eligibility, and downed state every two seconds. The trace also prints the
  movement, forward-edge, and stale-pivot distances so visual/server disagreement is explicit.
- Team telemetry and lifecycle are independent. One folder can be Ready or Returning while another
  is Engaged, and each publishes its assigned-enemy, target, active, defeated, returned, first-loss,
  and peak-pressure counts. The encounter publishes the first pet-loss wave and active-enemy count,
  and stops as `DefenseOverrun` if all 20 temporary pets are defeated.
- The Studio-only observer renders four columns and 20 stable pet cards plus current/peak pressure
  and first-loss telemetry. A persistent top-center meter spells out each incoming wave (`WAVE ONE`,
  `WAVE TWO`, and so on), briefly brightens on transition, and shows current/total waves, active
  enemy count, encounter state, and the 4× label. It remains read-only and uses folder/world
  attributes rather than a custom network feed.

## Phase 4 contract

Phase 4 adds the smallest useful defeat and reinforcement loop without coupling the prototype to
the unfinished merge board or production economy:

- The strip is compressed from 600 to 300 studs by removing the unused forward half. The complete
  rear arrangement—player controls, hatchers, bulwark, finish line, and objective spacing—stays
  fixed. Enemy spawns move to the new forward end, shortening observation time without changing the
  defensive geometry being tested.
- Five protected reserve eggs are the defense objective. Each enemy that reaches the finish line
  destroys one egg, and losing the fifth ends the run as `ObjectiveLost`. The eggs are currently a
  counter rather than world models; this keeps the test focused on whether forward pressure and
  recovery cadence are readable. An empty defense is no longer an immediate loss because queued
  replacements can recover it.
- Every missing authored pet slot enters that captain's own FIFO. The queue preserves the exact
  species/role/slot instead of randomizing the replacement, so a team's composition remains stable
  and its tank or blaster cannot silently become a third melee unit.
- The four team FIFOs operate in parallel, while each individual captain hatches at most one pet
  every four real seconds. A replacement appears at its stationary captain and travels back into
  combat through the ordinary movement/aggro systems. The rest of the team does not need to return,
  and no pet is teleported directly onto the battlefield.
- Replacement supply is intentionally unlimited in this pass. This separates the combat-side
  questions—queue depth, recovery time, and loss rate—from the later board-side questions of which
  egg finishes next and whether a hatcher has enough inventory.
- World telemetry publishes remaining/starting eggs, objective hits, current/peak queue depth,
  total hatches, longest replacement wait, and reinforcing-team count. Each team publishes its
  queued slots and queued/hatched totals. The wave banner shows eggs, queue depth/peak, and hatches;
  a missing pet card reads `QUEUED` rather than `DEFEATED` while its replacement is pending.

## Phase 5 contract

Phase 5 introduces the first real roster randomness while retaining Phase 4's deliberately simple
team and queue model:

- Every initial NPC team is five independent rolls from the shipping Home `grass_egg` (`Earth
  Egg`) through `pets.simulateHatch`. The prototype builds the same player hatch inputs as ordinary
  hatching, so species luck, Golden/Rainbow channels, event/buff inputs, and the orthogonal Huge
  jackpot all remain active. It bypasses currency, inventory grants, multi-hatch entitlement caps,
  presentation, and persistence; the 20 outcomes are session-only ghost pets.
- A defeated slot still enters only its captain's FIFO, but its replacement is a new roll rather
  than a copy of the defeated species. Each captain starts with Earth and can independently advance
  its future replacement source through Home Ice, Ember/Lava, and Sand/Desert. An upgrade does not
  transform live pets; it changes unrolled queued and later replacements. The slot and captain
  remain stable for observer and formation readability, while species, role, variant, and Huge state
  can change. Each team continues to hatch at most one replacement every four real seconds, and all
  four FIFOs operate in parallel.
- The observer publishes each slot's latest rolled species/variant/Huge result and labels Golden,
  Rainbow, and Huge pets directly on their cards. Team/world telemetry counts total, Golden,
  Rainbow, and Huge rolls, allowing a run's roster quality to be compared with its first-loss and
  terminal wave rather than treating all runs as equivalent.
- Enemies now emerge one at a time at 0.15-second intervals through a temporary purple portal at
  the rear spawn wall. `WaveDeploying` and a pending count remain visible until the complete wave
  has emerged; the portal then disappears and becomes non-queryable. It never replaces or disables
  the solid end wall, which remains available for tank/melee drive-back throughout combat.
- The movement leash extends to one stud inside the authored rear wall so driven-back enemies can
  use nearly the full collision surface instead of snapping forward from the old three-stud inset.
- The endurance ladder now runs 20 waves:
  `3/5/8/12/16/24/32/48/56/64/72/80/96/112/128/144/160/176/192/208`. It is a test ceiling, not a
  promised balance target. The hand-built roster's exciting Wave 8 result is historical context.
  With random and upgradable egg teams, the useful measurement is the distribution of failure waves
  and the roster/variant/source-tier/queue conditions that produced them.
- A camera-facing billboard above each captain shows its current source and one upgrade button. The
  client requests only the captain id through a Studio-only manifest packet; the server validates
  session ownership, tier order, rate, and canonical hatch data before publishing the new source.
- Each wave stamps a unique `CombatMusicCue`. If combat music is being held across the short
  between-wave aggro gap, `AreaMusicController` immediately rerolls from the active realm pool and
  excludes the current track when another choice exists. If combat fully ended, the next ordinary
  combat entry still avoids the last track. This changes only music selection, not wave timing.
- Entry is transactional around streaming: owned pets can be parked while the strip streams, but
  the session and `InMergeEggPrototype` flag are committed only after the character visibly pivots.
  A player can no longer remain in Home while the Hall gate believes the prototype is already active.

## Source and authoring

- Runtime/config: `configs/merge_egg_prototype.lua` and
  `src/Server/Services/MergeEggPrototypeService.lua`.
- Combat telemetry and Studio-only hatcher upgrade UI:
  `src/Client/Systems/MergeEggPrototypeObserver.lua`.
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

A later live run exposed that the one-time emergency seed could decay while those teams finished
other targets, leaving the last Brute forgotten behind the line. After changing the seed to the
0.5-second sustained floor, the same forced Team 3 breach stayed open, repeatedly refreshed all four
folders, and all 20 live pets acquired the Brute. Its HP fell from 1,600 to 632 during the trace and
the group finished it before the next wave.

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

The Phase 4 crossing regression pass held an enemy's authoritative movement position ten studs
behind the bulwark without moving its server model. The published movement distance was `+10`, the
forward bounds edge was `+14.8`, and the stale pivot still read `-324.6`; the enemy nevertheless
latched `CombatTargetOpen` and alerted all 20 pets. The first trace caught the expected heartbeat
boundary with every pet eligible and holding 250 threat but no selected target; the next trace had
all 20 pets targeting the breached enemy. This proves the repeated milling screenshot was caused by
reading the stale pivot, not by hostility, territory, or aggro-table rejection.

The replacement pass removed Team 1's slot-2 Trail Pup. The folder immediately published queue
slot `2`, active count `4`, and queue depth `1`; four seconds later the same species returned in
slot 2, the team returned to five active pets, and its queue cleared. Concurrent combat produced a
world peak queue depth of two and both replacements hatched successfully. In a separate objective
pass, removing all four defender folders left ten wave-four enemies unopposed: exactly five escapes
consumed the five reserve eggs, transitioned the run to `ObjectiveLost`, and despawned the remaining
enemies. Studio reported no runtime errors in either pass.

The Phase 5 live hatch produced 20 shipping Grass Egg outcomes across four teams, including three
Golden pets and one Rainbow Bear from the test player's actual luck inputs. Every folder published
five matching slot outcomes and the observer labeled the variants directly. Team 1 then lost and
replaced two pets: its original slot-1 Doggy and slot-3 Bear became a Bear and Doggy respectively,
proving that replacements are fresh rolls while captain and slot identity remain stable.

At the Wave 2 transition, the world entered `WaveDeploying` with five pending enemies, the portal
core was visible at its authored 0.22 transparency, and enemies emerged at the configured stagger.
After the fifth spawn, pending reached zero, the state changed to `WaveActive`, every portal part
returned to transparency 1, and `SouthEndWall.CanCollide` remained true. The run advanced through
combat with no prototype, config, target-group, hatch, or portal runtime errors.

The 20-wave/upgrade live pass entered through the Hall prompt and did not publish
`InMergeEggPrototype` until the character was at the strip spawn. All four captains rendered an
Earth-to-Ice billboard. Team 1 then advanced independently through Ice, Ember, and Sand while Team
2 remained Earth; its replicated button ended at `SAND EGG • MAX` and the world counted three
upgrades. A live combat cue changed `AreaMusic.SoundId` from `94019382405359` to `80895188313881`
while `InCombat` stayed true, proving the wave rotation crossfades to a non-repeating pool member.
The final restart entered, hatched Wave 1 of 20, rendered all four upgrade controls, and logged no
prototype, network, UI, or music error.

## Production direction after Phase 5

- Four hatcher-owned NPC teams, independent targeting, stable-slot replacement FIFOs, and the
  five-hit rear objective remain separate seams. Phase 5 feeds real Home egg outcomes into those
  queues without creating another team lifecycle or touching owned inventory.
- Keep automatic FIFO assignment as the default until board play proves composition management is
  worth its complexity. Random species make team strength variable, while a stable captain/slot
  still lets the player read where a replacement will appear and concentrate on merging.
- Do not lock queue depth or hatch cadence from this accelerated run. Tune the Ember Brute's
  health/armor and partial out-of-combat regeneration, then compare loss rate against the four-second
  per-team FIFO and five-egg objective. Those are explicit knobs, not final balance values.
- When the merge board supplies physical eggs, define one simple shortage rule before adding queue
  controls. The least complex candidate remains: each team reserves its oldest empty slot, and the
  next completed egg assigned to that captain satisfies it.
- Tank/melee drive-back that pushes the whole frontline away from the hatcher is desirable lane
  behavior. A legitimately advanced team travels back to its hatcher after combat rather than
  teleporting at the generic catch-up distance.
- The bulwark is a secondary engagement boundary, not a new focus system: strict team ownership
  applies in front of it, and ordinary cross-team aggro becomes eligible only for breached enemies.
- The player remains free to move between hatchers, merge eggs, and manage the board while these NPC
  teams fight asynchronously. Player position must not be a combat leash or scheduling input.

## Explicitly deferred

- Tile generation or tile streaming.
- Physical objective eggs, real merge recipes, board slots, egg inventory/compatibility, currency,
  rewards, persistence, or monetization.
- Wave selection UI, production difficulty curves, matchmaking, or more than one active player.
- Player-facing queue reordering, congestion policy, and production team-state controls.
- Production egg-upgrade costs, board recipes, timing, persistence, and unlock requirements. The
  current camera-facing buttons are intentionally free Studio test controls.
- Player-team opt-in deployment and combined NPC/player roster presentation.
- Reopening Hall of Worlds in production.
