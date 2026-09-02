# Merge an Egg Prototype

Status: Phase 6 endless defense running in the dedicated Studio-authored Merge place; durable
Wave-10 checkpoints and 56 egg tiers await live balance verification

## Phase 1 contract

Phase 1 answers only the core feel question: hatch a small temporary squad, send it down a long
lane, and watch it fight. It deliberately excludes merging, the board/economy loop, production
progression, procedural layout, and multiplayer occupancy.

- The Phase-1 fixture is one 96×300 continuous land strip with fixed side/end walls. In the current
  map, ten copies are permanent atomic bay Models under `Workspace.Maps.MergeEggRealm.Bays`; the
  temporary `Workspace.Maps.MergeEggPrototype` source exists only between the explicit source-build
  and realm-bake authoring passes. The bays are not tile-kit maps and have no chunk lifecycle.
- In Studio, Home's otherwise-disabled `HallOfWorldsPortal` becomes the entry prompt. Production
  keeps the Hall route disabled and sealed. Entry streams the authored strip, then directly pivots
  the player without changing `LastArea`, unlocks, or profile state.
- One player may occupy the prototype per server. Their ordinary runtime pet models are parked in
  `ServerStorage` and restored on exit/reset-character cleanup; ownership data is never touched.
- The test hatcher manifests exactly five Wayfinder ghost pets. Every model is stamped before it
  reaches `Workspace.PlayerPets` with `MergeEggUnit`, a run id, and
  `EphemeralDownPolicy = "destroy"`, so a defeated test unit is destroyed before saved-pet downed
  state or slot lockouts can run.
- The original Phase 1 fixture used three fixed 3/5/8 Whelp waves. The current Phase 6 plan is
  described below. Every enemy starts at a
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
- Enemies use `rewardPolicy = "none"`, so the ordinary contributor/team combat award path grants no
  shared XP or loot. The prototype's server-only defeat callback provides physical Waycoin/Gem
  pickups, while a separate reward definition supports the narrowly attributed trained Full-mode
  durable-pet final-hit exception described below.
  Defeat and finish-line arrival are counted separately; after every enemy in a wave is resolved,
  the next larger wave starts automatically.
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
- Every run gives each team a unique opening `CombatTargetGroup`. Once either an enemy or pet opts
  into a group, bilateral acquisition initially requires the other actor to publish the same group.
  Ungrouped combat retains the existing global behavior, so this partition does not change normal
  realm fights. After a wave is fully deployed and has settled for two seconds, an initialized team
  with no live target may become an open reinforcement and duplicate the hardest engaged enemy
  (boss, then lieutenant, then tank/durability). At most one idle team stays in reserve. If active
  enemy groups meet or exceed active defender teams, every team commits instead.
- The endurance ladder contains 3, 5, 8, 12, 16, 24, 32, and 48 enemies. Each wave assigns enemies
  round-robin across the four teams; the first assignment in every non-empty group is an Ember
  Brute tank and the remainder are Cinder Whelps. This keeps the pressure composition comparable
  even when a small wave leaves one team idle.
- Opening defense alerts and re-alerts address only the assigned team's folder. A later idle-team
  reinforcement seeds that explicitly opened folder against the chosen duplicate target. Ordinary
  bilateral threat, tank taunts, target choice, drive-back, disengagement, and bounded return still
  own behavior after either seed; an assignment scopes eligible combatants rather than pinning five
  targets.
- A gold Neon `BulwarkLine` spans the strip 43 studs in front of the hatcher anchors. Its label is
  written flat on the ground just behind the line; there is no floating billboard obscuring combat.
  The line is both the visual rule and the authoritative directional plane. Crossing is measured from
  the server-authoritative `MoveTarget` plus the enemy's forward oriented-bounds extent and one stud
  of contact tolerance. It never uses the model pivot: enemy visuals are client-interpolated while
  the server pivot normally remains at spawn. Once an enemy crosses, it becomes an open emergency
  target and every surviving NPC folder receives the same 250 ordinary-threat floor. The floor
  refreshes every 0.5 seconds while the enemy remains past the bulwark, so a team can finish its
  current target and still
  acquire the emergency afterward.
  The one allowed idle reserve is released immediately and remains open for the rest of the wave,
  but existing threat tables still decide whether already-engaged pets peel from current targets.
- While the early prototype trace is enabled, every past-bulwark enemy prints each surviving pet's
  current target, threat on that enemy, top threat row, reciprocal enemy threat, distance,
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
- Five protected reserve eggs remain the defense's terminal health. Each active hatcher now also
  manifests its installed source as a real stationary combat objective at that captain. The source
  has 5,000 endurance, no movement, no attack components, no natural regeneration, and cannot
  receive pet support. It is excluded from pet counts, formation movement, drafting, and slot cards.
- Enemies cannot target an installed egg before crossing the red breach line. Crossing makes eggs
  valid targets, then the ordinary enemy threat table owns the result: nearby pressure can turn onto
  an egg while a pet tank's normal taunt can peel the attacker back off. There is no direct scripted
  target pin and no head-count-to-damage conversion.
- Combat destruction removes that captain's source, consumes one protected reserve egg, leaves its
  surviving pets in combat, and blocks replacement rolls until the player buys its first egg again.
  A marcher that somehow reaches the legacy finish line uses the same destruction as a safety
  fallback. Losing the fifth reserve ends the run as `ObjectiveLost`.
- Every missing authored pet slot enters that captain's own FIFO. The queue preserves the exact
  species/role/slot instead of randomizing the replacement, so a team's composition remains stable
  and its tank or blaster cannot silently become a third melee unit.
- The four team FIFOs operate in parallel, while each individual captain hatches at most one pet
  every four real seconds. A replacement appears at its stationary captain and travels back into
  combat through the ordinary movement/aggro systems. The rest of the team does not need to return,
  and no pet is teleported directly onto the battlefield.
- Replacement rolls remain automatic and per-team, but their supply now depends on that captain
  retaining an installed egg. Destroying the source preserves queued slots but clears their pending
  definitions; rebuilding resumes ordinary draft rolls without duplicating the surviving squad.
- World telemetry publishes remaining/starting eggs, objective hits, current/peak queue depth,
  total hatches, longest replacement wait, and reinforcing-team count. Each team publishes its
  queued slots and queued/hatched totals. The wave banner shows eggs, queue depth/peak, and hatches;
  a missing pet card reads `QUEUED` rather than `DEFEATED` while its replacement is pending. Each
  team header also shows installed egg current/max HP and cumulative damage so objective pressure is
  visible without selecting the world model.

## Phase 5 contract

Phase 5 introduces the first real roster randomness while retaining Phase 4's deliberately simple
team and queue model:

- The encounter deploys exactly four stationary hatcher positions with no egg and no pets. Their
  first control reads `CREATE EARTH EGG`; installing that shipping Home `grass_egg` produces the
  captain's initial independent rolls through `pets.simulateHatch`. Until then the team state
  is `NO EGG`, its pet positions remain visibly empty, and no replacement queue is created.
  Deployment remains in `AwaitingFirstEgg` at Wave 0 with the enemy portal sealed. The first
  successful Earth installation starts Wave 1, so the player has an unpressured setup window but
  cannot begin the endurance test without at least one working team.
  The prototype builds the same player hatch inputs as ordinary hatching, so species luck,
  Golden/Rainbow channels, event/buff inputs, and the orthogonal Huge jackpot all remain active. It
  bypasses inventory grants, multi-hatch entitlement caps, presentation, and persistence; all
  outcomes are session-only ghost pets. Core egg progression itself is now Waycoin-funded.
- A defeated slot still enters only its captain's FIFO, but its replacement is a new roll rather
  than a copy of the defeated species. After its initial Earth team exists, each captain can
  independently advance its source through Home Ice, Ember/Lava, and Sand/Desert. This is egg
  progression, not a permanent upgrade system. The current source supplies unrolled replacements;
  experimental modes may also add one live slot or apply a runtime origin multiplier on a tier
  change. Species, role, variant, and Huge state can change. Each team continues to hatch at most
  one replacement every four real seconds, and all four FIFOs operate in parallel.
- The observer publishes each slot's latest rolled species/variant/Huge result and labels Golden,
  Rainbow, and Huge pets directly on their cards. Team/world telemetry counts total, Golden,
  Rainbow, and Huge rolls, allowing a run's roster quality to be compared with its first-loss and
  terminal wave rather than treating all runs as equivalent.
- Enemies now emerge one at a time at 0.15-second intervals through a temporary purple portal at
  the rear spawn wall. `WaveDeploying` and a pending count remain visible until the complete wave
  has emerged; the portal then disappears and becomes non-queryable. It never replaces or disables
  the solid end wall, which remains available for tank/melee drive-back throughout combat.
- The first three waves are authored as fronts rather than inferred only from total head count.
  Wave 1 sends one three-Whelp trash group at the first online hatcher. Wave 2 keeps one front but
  introduces a lone Ember Brute. Wave 3 opens two fronts: a tank-led group of one Brute plus three
  Whelps and a separate group of four Whelps. Online
  hatchers receive groups first; any additional front is assigned to an empty position and remains
  undefended until that egg is installed. Eight-second intermissions after Waves 1 and 2, then six
  seconds after Wave 3, provide an explicit early egg-building cadence for the temporary buttons.
  The banner publishes front and online-hatcher counts so the test pressure is directly readable.
- The movement leash extends to one stud inside the authored rear wall so driven-back enemies can
  use nearly the full collision surface instead of snapping forward from the old three-stud inset.
- The repeatable opening contains 20 named, data-authored waves with totals
  `3/1/8/12/16/16/20/24/20/13/8/16/24/24/19/28/28/32/32/27`. Every top-level group is one
  independently assigned front and its `units` list names archetype plus count. Totals are derived,
  so inserting a wave or changing “one Brute plus three Whelps” does not require a second count edit.
  The service refuses any wave over the configured 32-enemy Studio ceiling. Difficulty above the
  ceiling comes from composition: Ember Moth lieutenants begin in Wave 6 and Magma Wyrm bosses anchor
  Waves 10, 15, and 20. Wave 10 remains the Home combat-layer checkpoint and Wave 11 begins Heaven 1
  pressure, but egg purchasing is never gated by that boundary.
  With random and upgradable egg teams, the useful measurement is the distribution of failure waves
  and the roster/variant/source-tier/queue conditions that produced them.
- Enemy identity now follows the installed egg on the hatcher receiving each front rather than the
  wave number. Home egg tiers draw a varied mix from the existing Earth/Lava enemies (Whelps,
  Rabid Dogs, Vicious Cats, Crows, Brutes, Bears, and their support counterparts). Bloom, Aurora,
  Solar, and Gilded defenders draw pet-model attackers from the corresponding Blight, Black Ice,
  Infernal, and Ash Hell eggs. A mixed-tier defense can therefore face multiple enemy families in
  one wave. Each authored position is an independent weighted hatch from that complete opposing
  egg: three minion positions plus a lieutenant can therefore roll any four species/roles the egg
  actually contains. The species and its inherent combat kit are selected first, then the abstract
  wave rank applies durability/reward/presentation. Lieutenant HP is currently 2× the rolled pet;
  Boss HP is 6× and uses Huge scale. Both are prototype multipliers rather than edits to canonical
  pet stats. Both also expose a damage multiplier initialized at 1×. Configured villain and
  archvillain overlays reserve 4×/6× Trials-style silhouettes. Heaven defenders map to their exact
  Hell counterpart and Hell defenders map back to Heaven through Layer 3.
- Pet-model attackers execute the rolled species rather than only borrowing its mesh: their native
  role and targeting geometry, elemental bolt/area presentation, control, damage-over-time, support
  aura, healing suppression, and configured active ability procs all cross the faction boundary.
  Rank never forces a rolled support, blaster, or controller into the tank role.
- The full source, draft, team, production, and pet-endurance presentation lives in the ground
  roster beside each deployed egg. The only camera-facing display above an installed objective is
  a compact, non-interactive health bar attached to that egg itself. Placement and merging stay on
  the physical board/deployment interactions rather than duplicating those actions in a billboard.
- Each wave stamps a unique `CombatMusicCue`. If combat music is being held across the short
  between-wave aggro gap, `AreaMusicController` immediately rerolls from the active realm pool and
  excludes the current track when another choice exists. If combat fully ended, the next ordinary
  combat entry still avoids the last track. This changes only music selection, not wave timing.
- Enemy defeats reuse the Hall's authored `hall_coins` pickup mesh/texture and saved Waycoin
  balance. Bosses now pay 2,400 base Waycoins (3× the earlier 800). Every defeat also rolls one
  persistent Gem at 2% for trash/tanks, 6% for lieutenants, and 20% for bosses. Both currencies use
  physical owner-only pickups; Gems use the existing textured amethyst-geode pickup rather than
  the emergency neon sphere. The prototype HUD therefore selects the Hall Gems + Waycoins stack
  instead of showing Crystal World's origin-crystal panes. The mode no longer owns or resets a
  pickup radius: every prototype currency record uses the player's game-wide Magnet calculation.
  The Auto Collector pass remains separate from that radius and its passive pet may retrieve these
  pickups like currency in any other world. Prototype Waycoin
  models render at 2× the ordinary Hall scale. Their burst endpoint is contained to the authored
  strip; a would-be outside endpoint visibly hits the nearest wall and tweens back to a reflected
  inside resting point. Ordinary drops retain their existing scale and unconstrained behavior.
- Entry is transactional around streaming: owned pets can be parked while the strip streams, but
  the session and `InMergeEggPrototype` presentation flag are committed only after the character
  visibly pivots. The strip is the configured `MergeEggPrototype` area in the ordinary
  `CurrentArea` location SSOT and renders as `Merge Egg` in the People list. Leaving through any
  normal travel path changes `CurrentArea`, which automatically closes and cleans the temporary
  session; gate admission also reconciles a stale record instead of trusting the private mode flag.

## Economy and progression experiments (2026-08-26)

- The literal merge timing probe sells only base Earth Eggs for 100 Waycoins. Two equal eggs always
  merge into one egg of the next configured tier, including at a hatcher: an empty position accepts
  any board egg unchanged, then the installed egg is one half of every later pair. Earth + Earth
  yields installed Ice, installed Ice + board Ice yields Lava, and so on. The total material cost of
  an installed Earth/Ice/Lava/Sand egg is therefore 100/200/400/800 rather than the obsolete 1,500-
  Waycoin sum of buying every result tier separately. Better eggs are core progression. Future permanent
  upgrades—hatch luck, team capacity, and similar board modifiers—must have a
  separate spend budget.
- A run snapshots the entering player's `EffectiveLevel` (falling back to earned `Level`) and uses
  it as the common base for all prototype enemies, NPC-team pets, the temporary player escort, and
  installed egg objectives. Tanks and trash remain even-level; EnemyService adds the normal rank
  offset only for configured lieutenants and bosses. The snapshot does not change during the run.
- The legacy captain button accepts a core-egg action only when the avatar is at least four studs
  behind the directional Bulwark plane and within 18 planar studs of that captain. Physical board
  drag placement instead validates the source board slot, visible purchased deployment pad, and
  management-board distance server-side; neither path can place remotely from the battlefield.
- A Studio-only upper-bound runner starts from 100 Waycoins, disables manual controls, and uses the
  ordinary character navigation path at the live `WalkSpeed` (26.4 in the measured runs). It walks
  to owner-only physical drops, reevaluates currency asynchronously with combat, buys Earth Eggs at
  the rear-wall station, walks to a separate side-wall station for every two-to-one merge, then
  returns beneath the selected captain to place the required crafted tier. The first escape latches
  telemetry but does not stop collection. Only all-tier completion, objective/encounter termination,
  reset/exit, or repeated navigation failure stops it. Reset discards test drops and restores the
  tester's exact pre-run Waycoin balance.
- The original 8/30 payout baseline failed in Wave 3 with one Earth team: the runner spent its
  starting 100, earned only 62 more, and lost the fifth objective egg before affording Position 2.
  The first corrected baseline is 40 per Whelp and 120 per Brute. Wave 1 therefore grosses 120,
  while the revised lone-Brute Wave 2 grosses another 120, leaving real movement time as part of
  the cadence.
- Three runtime-selectable progression modes leave canonical pet definitions unchanged:
  `positions` uses 3/4/5/6 slots by egg tier; `origin_10` and `origin_20` hold four slots and add
  10% or 20% contextual origin power per completed egg tier. The origin multiplier is a runtime pet
  attribute consumed as a `PetPower` context multiplier; it does not rewrite saved Power or pet
  config tables. These are experiment fixtures, not a chosen shipping rule.
- Single-run observations (useful, not statistically decisive):
  - 3/4/5/6 slots reached four Sand teams in Wave 9, spent 6,000, and had no escapes (320 seconds).
  - A discarded fixed-three +10% lower bound reached Sand in Wave 9 after one early escape
    (365 seconds). The escape happened while both compared models were still identical Earth teams:
    Whelps split away from the tank, so it is path/target variance rather than modifier evidence.
  - Fixed-four +10% reached Sand in Wave 9 with no escapes (257 seconds), then entered Wave 10 with
    all five objective eggs, 15 live pets, and one queued replacement.
  - Fixed-four +20% reached Sand in Wave 9 with no escapes (306 seconds), then entered Wave 10 with
    the same five objectives, 15 live pets, and one queued replacement. One trial cannot distinguish
    10% from 20%; repeat distributions are required.
- The shipping capacity track adds one pet at every aligned world level: `Home=3`, `Heaven 1=4`,
  `Hell 1=5`, `Heaven 2=6`, `Hell 2=7`, `Heaven 3=8`, and `Hell 3=9`. Each four-egg origin group
  inherits its world's capacity; the second/rebirth pass retains nine positions while continuing
  to improve draft quality. The earlier slot and flat-modifier modes remain selectable experiment
  fixtures.

### Candidate permanent knobs

- Keep egg creation/merging and better origins as core progression, not upgrades. The clean permanent
  upgrade axes are coin value, pet damage, attack cadence, installed-egg health, replacement hatch
  time, gem-drop chance, hatcher count, pets per hatcher, and draft quality/luck.
- Do not copy a separate unit `Spawn Level` upgrade into this mode. The prototype deliberately gives
  friendlies and enemies one shared player-level baseline; egg origin and draft quality provide the
  equivalent roster progression without reopening pet-level balance.
- Offline Waycoins are a promising checkpoint-recovery valve. Calculate them from already-banked
  progress (the last completed checkpoint plus the installed frontline), cap the away duration, and
  award only Waycoins when the player returns. Offline time must not simulate waves, damage eggs,
  grant gems, or advance checkpoints. Useful later knobs are offline efficiency and maximum banked
  hours; begin without a paid multiplier so the base recovery economy can be measured honestly.
- `Merge All`, passive pickup, temporary damage/fire-rate/coin potions, and rotating special-unit
  shops are recognizable secondary systems, but they add automation or monetization complexity.
  Keep them outside the first permanent-upgrade test until the basic checkpoint economy is proven.

## Phase 6 Home → Heaven 1 progression loop (2026-08-26)

- Home now holds every hatcher at three stable positions. Earth/Ice/Lava/Sand tiers offer two,
  three, four, then five ordinary hatch outcomes for each new pet. The weakest outcome becomes a
  session-only player-reserve cast-off; from the remaining outcomes, the hatcher draft first fills
  a missing tank, then a missing support/healer role, then takes the highest configured combat-power
  result. Canonical hatch odds, variants, Huge chances, pet definitions, and live combat math are
  unchanged.
- The runner no longer stops when all four Home hatchers reach Sand. Each captain immediately
  continues through Bloom/Aurora/Solar/Gilded when its next exponential cost is affordable; there
  is no wave, checkpoint, or combat-layer permission gate on an egg purchase. It sweeps remaining
  pickups only after the complete 20-wave encounter.
- The eight-tier price track is continuous per captain:
  `100/200/400/800/1,600/3,200/6,400/12,800`. Home tiers field three positions with 2/3/4/5 draft
  choices. Buying the first Heaven 1 egg expands that captain to four positions, and the Heaven
  tiers restart the 2/3/4/5 draft ladder. Future layer eggs can extend the same data-driven track
  without adding an artificial wave unlock.
- Wave 10 is only the combat checkpoint. Wave 11 changes the banner to Heaven Layer 1 and applies
  2.25× Home HP, 1.5× damage, and 5× Waycoin payout. Teams, egg tiers, balance, queues, and surviving
  pets continue in place. An isolated `{stage = "heaven_1"}` runner remains available for tuning
  that combat model without replaying the continuous path.
- The observer prefixes the wave banner with the current combat layer and distinguishes selected
  pets from total draft candidates. The ground roster identifies the installed source and its pick
  count; the egg billboard is health-only.
- The first complete Home run cleared Wave 20 with all five reserve eggs and swept to 57,260
  Waycoins after Home egg spending. Carrying that exact balance into Heaven 1 exposed the next
  economy problem: the runner spent 57,600 on Heaven eggs almost immediately and had nearly all
  sources advanced by Wave 2. The stage handoff works, but the current Home payout/Heaven pricing
  collapses the intended Heaven build tempo and needs a later tuning pass.

## Endless waves and the 56-tier catalog (2026-08-27)

- Waves 1–20 remain immutable authored fixtures for controlled experiments. Wave 21 begins a
  config-authored ten-wave cycle with three recovery waves and a checkpoint battle. The runtime
  generates later cycles up to a practical `999999` session guard, while the HUD presents the run
  as endless and fills its progress bar within the current ten-wave checkpoint.
- Generated difficulty never increases the body count. Every generated wave remains at or below
  the 32-model Studio ceiling; later cycles replace existing Whelps/Brutes with lieutenants/bosses
  and apply additive per-cycle HP, damage, and reward multipliers. Combat layers change at Waves
  10/20/30 from Home to Heaven 1/2/3; Heaven 3 remains the base layer after 30 while cycle scaling
  continues.
- The default egg track contains 28 current origins: four Home eggs, then the Heaven and Hell
  Earth/Ice/Fire/Desert eggs for Layers 1, 2, and 3. Tiers 29–56 repeat that same catalog as forced
  prototype-Huge NPC pets. The forced presentation is session-only: it is neither a genuine Huge
  roll nor an index/registry/inventory grant. Full-mode durable player hatches fold the tier back to
  its ordinary origin and use the canonical hatch unchanged.
- Capacity follows the world layer rather than growing forever: Home has three positions, Layer 1
  has four, Layer 2 has five, and Layer 3 plus prototype-Huge tiers have six. Ground roster panels
  reserve six logical card slots from the beginning, so capacity changes do not reflow neighboring
  stations.
- Early creation/upgrade costs retain their familiar doubling through tier 8, then use a slower
  config-owned growth rate so 56 tiers remain numerically representable. Wave 140 is the current
  first-run progression horizon to balance, not a hard ending.
- Cost presentation does not choose the eventual large-number economy. The Merge management board
  keeps exact comma-separated labels below one billion, then abbreviates billion/trillion/quadrillion
  as `B`, `T`, and `Q`. This is display-only; it does not halve costs, convert Waycoins into bars, or
  alter affordability checks.
- Merge-only rebirth is the combat and economy escape valve when enemies overtake the current
  defense ceiling. Every player starts at Rank 1 for free. Rank 2 costs 50,000 Waycoins and Rank 3
  costs 200,000; those two paid transitions produce 2x/3x pet power, cannon power, bulwark damage,
  defeated-enemy Waycoin amounts, and defeated-enemy Gem amounts. All factors live in
  `rebirth.per_rebirth_factors`; additive stacking means an authored factor of `2` resolves to
  1x/2x/3x at paid-rebirth counts 0/1/2. Cannon and bulwark radius factors are explicitly `1`, so
  neither defense widens as ranks grow. Cannon cadence plus bulwark cadence, duration, capacity, and
  control also begin at `1`; Gem drop chance remains `1` while Gem quantity grows. Gem management
  damage and Rebirth pet-power percentages share one additive pool: nine +5% purchases plus the
  first +100% rebirth produce `1 + 0.45 + 1.00 = 2.45x`, not `1.45 × 2`. The same combined pet value
  applies to hatcher NPC squads, Simple-mode reserve pets, and Full-mode durable player pets. There
  is intentionally no inferred third price. The Full-mode pet factor is read only while the player
  is inside Merge Defense and is never written into durable pet records, so it cannot affect combat
  elsewhere. The rank is durable; the
  active wave/checkpoint, board, deployed eggs, and Merge wallet reset, while player pets, level,
  prior world unlocks, and the durable Gem-upgrade table remain untouched. Each rank also owns one
  more personal hatch source in canonical egg order: Rank 1 starts with Grass, Rank 2 adds Ice, and
  Rank 3 adds Lava. No Rank 4 cost is inferred; adding a future authored price automatically extends
  the same one-egg-per-rank ladder. Management upgrade ranks and cumulative Gem spend now live in
  the Merge-defense profile record rather than only the session.
- A ninth management-board card shows the next exact price and total damage. Rebirth requires a
  second confirmation click because it clears the current run. Future anti-spam progression gates
  use `rebirth.requirements.minimum_deployed_egg_tier_by_rank`; the list is deliberately empty
  until the exact egg thresholds are selected through playtesting.

## Player combat modes and defense hatches (2026-08-27)

- Merge defense has two player-combat modes. `Full` is available after the player reaches earned
  Level 10 or completes the combat tutorial; otherwise an attempted Full preference resolves to
  `Simple`. The preference is persisted in ordinary Settings and may be changed live. Choosing
  Simple remains valid after Full is unlocked.
- Mode onboarding is persisted separately from the setting. An ineligible first entrant silently
  plays Simple and records that locked-Simple experience; no banner is shown to either a fresh or
  returning ineligible player. An eligible first-time entrant begins in Full and receives one
  click-through notice that Simple remains available in Settings. If a locked-Simple player later
  qualifies, the effective mode remains Simple until a blocking `Stay Simple` / `Switch to Full`
  choice is made. Interrupted notices repeat on the next entry, while acknowledged/resolved notices
  never repeat; changing the setting directly also resolves a pending unlock choice.
- Full uses the player's durable inventory and normal equipped-pet records. Defense hatches grant a
  real pet through `PetGrantService`, update the index and hatch counter, and fill only genuinely
  empty unlocked equip slots. They never replace a chosen pet or a downed pet, so normal combat,
  targeting, defeat, and revive management remain authoritative. Full mode does not create or park
  synthetic reserve ghosts.
- The personal defense-hatch source is derived from durable Merge rebirth count, then capped by the
  egg installed at the producing hatcher. Farm & Fight purchases no longer decide what Merge owns.
  Rank 1 owns Grass, Rank 2 Ice, Rank 3 Lava, and future authored ranks continue in the same canonical
  order. This is an independent canonical hatch, not the hatcher team's draft winner or cast-off.
- A personal hatch cannot enter inventory until `CombatTutorial.done == true`, even though the
  existing earned-Level-10 route may make Full combat mode available earlier. Rebirth ownership is
  retained while delivery is gated; completing Combat Training enables later hatches rather than
  fabricating missed pets.
- Every rebirth-owned egg also grants its mapped Farm & Fight area through `ZoneService`. The grant
  is reconciled on Merge entry and immediately after rebirth, so older rebirthed profiles and
  interrupted saves self-heal without another purchase. This is area ownership only: the independent
  `LayerService` earned-level requirements still gate realm travel (Layer 2 at Level 14, Layer 3 at
  Level 21).
- Both modes keep player combat pets at the breach-line escort anchor while the player manages the
  board behind it. Crossing forward restores the existing follow/heel behavior; entering combat
  still allows ordinary combat choreography to take control. The Auto Collector remains outside
  the combat squad and retains its separate currency-pursuit behavior.
- Full mode temporarily marks the real player's pet folder as open-targeting. Durable pets may
  therefore acquire any nearby prototype lane through the ordinary distance/threat tables before
  an enemy crosses the Bulwark, matching the Simple escort contract. NPC hatcher folders use their
  per-lane `CombatTargetGroup` for opening assignments, then only idle teams are opened by the
  reinforcement policy. The Bulwark remains the immediate all-teams emergency release: its
  sustained ordinary-threat seed addresses both every live hatcher folder and the player's current
  escort folder. Merely opening the target-group gate is insufficient because a breach-line-held
  squad may still sit outside ambient acquisition range. This remains an aggro seed, not a focus
  pin; tanks and the normal threat tables retain target authority. The player's pre-session folder
  value is restored on mode switch, cancelled entry, and exit.
- A newly discovered Full-mode pet uses the regular single-egg reveal and pet picture, but as a
  passive nonmodal presentation whose transparent layer does not consume board/HUD input. Duplicate
  index entries enter inventory silently. `Show New Defense Pets` in Egg Settings disables these
  reveals without disabling the grants.
- Full mode retains ordinary player powers. Offensive targeting and targeted AoEs enumerate
  EnemyService enemies, while friendly pet targeting enumerates real `Workspace.PlayerPets`
  folders. Hatcher-owned NPC pets live in their separate `Merge Hatcher Team X` folders, so they
  cannot become targets of a player's targeted AoE.
- Merge enemies retain their isolated physical Waycoin/Gem reward path. NPC hatcher kills,
  Simple-mode ghost kills, summons, and player-power finishes never increment the player's global
  `enemies_defeated` counter or publish the ordinary `enemy_defeated` event. A durable Full-mode pet
  may earn exactly one global kill only when it lands the final damaging hit; participation and
  nearby-team credit do not qualify. Direct, AoE, aura, burn, and contagion final hits preserve this
  real-pet attribution. After `CombatTutorial.done` publishes `CombatTutorialDone = true`, that
  qualifying final hit runs the complete per-player Farm & Fight defeat path: the canonical enemy
  currency/token table (or the normal level-scaled area-coin fallback), combat XP, enhancement and
  potion rolls, boss-exclusive egg roll, `enemy_defeated`, and `enemies_defeated`. Home onboarding or
  Ascension alone is intentionally insufficient because powers and targeting have not been taught.
  Before Combat Training completion, Merge grants none of those ordinary rewards; autonomous and
  Simple-mode combat never grants them. Merge's own physical Waycoin/Gem callback remains separate,
  so reusing the combat reward path neither duplicates it nor gives NPCs contributor credit.

## Simple-mode session reserve roster (2026-08-26)

- This is the Simple-mode fallback, not owned-pet crossover, and writes nothing to inventory. Entry parks the
  player's normal runtime pets; reset, exit, character removal, and checkpoint restore explicitly
  destroy the prototype escort before restoring or rebuilding session state.
- Each completed hatcher draft removes its weakest candidate first and adds that one cast-off to the
  player's prototype bench. The hatcher chooses its own winner from the remaining candidates, so one
  roll result is never fielded by both owners.
- The player automatically fields the strongest available tank, ranged/blaster, and melee cast-offs.
  `extra_equip_slots` adds a fourth support slot, matching the shipped 3→4 Game Pass benefit without
  inheriting progression bonuses or allowing more than four slots. The four role seats stay fixed:
  a missing core role can use another non-support combat cast-off, but support never enters a
  three-slot lineup or displaces a core seat; an unavailable support seat remains empty.
- These ghosts live in the real player's pet folder, so the existing follow, aggro, combat, and My
  Team UI paths drive them while the avatar gathers Waycoins. `CombatTargetOpen` lets them join any
  hatcher-owned fight despite the four hatcher target partitions.
- A defeated player-escort pet is destroyed and its slot waits 30 real seconds. The strongest bench
  pet with the same role fills it; if no role match exists, the strongest cast-off fills it. An empty
  bench leaves the slot pending until a later hatcher draft supplies another cast-off. Hatcher FIFOs
  remain independent at four seconds.
- Checkpoint 10 snapshots and restores the active escort definitions, reserve bench, entitlement
  capacity, and counters. This makes retry comparisons deterministic without persisting any pet.
- Live validation on the extra-slot-pass account produced six Grass candidates for the first
  three-pet hatcher: three hatcher selections, three player cast-offs, and zero discarded rolls.
  The fixed-seat correction kept an unavailable ranged seat empty while placing a rolled support in
  slot four. A forced melee loss was still pending after 21 seconds, filled after the 30-second
  boundary, and all four escort pets then held the same live enemy target during the coin route.

## Breach and installed-egg experiment (2026-08-26)

- The gold `BulwarkLine` remains the all-teams-engage boundary at Z=-175. A separate red
  `BreachLine` at Z=-205 sits 13 studs in front of the hatcher anchors and is labeled flat on the
  ground `BREACH • EGGS EXPOSED`. Existing Studio maps receive the same line from a narrow runtime
  fallback, while the repeatable authoring script creates it permanently.
- The same movement-leading-edge calculation classifies both lines. World telemetry now separates
  current/peak enemies past each line, cumulative crossings, first breach wave, and first overrun
  wave. `BreachOverrun` begins when enemies beyond the red line reach the greater of four or one per
  active defender. `BreachOverrun` is now diagnostic/banner telemetry only; it never manufactures
  damage. Egg HP changes only through ordinary landed enemy attacks or the finish-line fallback.
-   Crossing the red line stamps that enemy as eligible to attack `MergeEggObjective` models and
  retargets their march onto a living egg. They cannot resolve as escaped while any hatcher
  egg is still up; the finish line only opens after the last objective dies.
  When an installed egg dies, leftover marchers always rewrite onto a remaining
  egg from their live position (never a skipped "already close" march off the
  spawn pivot). The lost hatcher's pets open (`CombatTargetOpen`) and every
  surviving folder is re-alerted; at most one idle team stays in reserve. The
  existing bulwark re-alert then seeds normal threat across the open defense, including installed
  eggs. Eggs publish explicit target threat but are not implicit-taunt tanks; real pet tanks retain
  their ordinary taunt authority and can pull an attacker away.
- A Studio-only focused probe can inject any valid starting wave and route every attack group to one
  hatcher. This is a diagnostic seam for repeatable pressure tests, not a player wave selector or a
  production network contract.
- Live verification under the retired head-count ladder injected Home Wave 10 onto Team 1 after
  installing only its first egg. All 64 enemies crossed the yellow bulwark, 63 crossed the red breach
  line, `FirstBreachWave` and `FirstOverrunWave` both latched to 10, and the red-line peak reached 63
  against a threshold of 4.
  The first rear arrival destroyed Team 1's installed egg; subsequent arrivals exhausted the five
  reserve eggs and ended the run as `ObjectiveLost`. This confirms the prior Wave 18 crowd was a
  reporting bug, not a non-breach: the old UI exposed active enemies but no authoritative red-line
  state.
- The completed continuous Home → Heaven 1 baseline ran all 20 waves in about 23.1 minutes. It
  reached first pet loss at Wave 2, first breach at Wave 6, first overrun at Wave 16, 88 cumulative
  red-line crossings, a red-line peak of 15, and a peak of 32 active enemies. It nevertheless ended
  with all five reserves, zero installed eggs destroyed, and zero abstract pressure hits while all
  four sources reached Gilded. This conclusively rejected defender-count pressure as the damage
  model: crossings describe danger, but actual attacks on durable egg targets must decide loss.
- The former focused Wave 10 pressure proof remains useful only as evidence that the retired timer
  executed; it is no longer a balance result. The next live probe must measure time-to-first-egg-hit,
  damage by archetype, tank peel behavior, time-to-destroy, and rebuild opportunity against the new
  5,000-HP objectives.

## Literal merge-board timing probe (2026-08-26)

- The early board is now a literal 4×4 floor grid. A green rear-wall button creates one base Earth
  Egg for 100 Waycoins, and dragging one equal egg onto another produces the next configured tier.
  Dragging a board egg onto an empty deployment pad installs it unchanged; dragging onto an occupied
  pad requires the deployed tier and advances it once (for example, Ice onto Ice produces Lava).
  Empty cells remain neutral. Each occupied egg receives a smaller neon sign beneath it; matching
  tiers share a color, so matching colors identify a valid merge pair. The six-color sequence starts
  Earth green and Ice blue, then repeats every six tiers. Board placement derives from the authored
  `StartPlatform`: its player-side edge exactly meets the pedestal's rear edge rather than relying on
  a guessed offset.
- Crafted inventory is mirrored into the 16 cells using the real cached egg assets from
  `ReplicatedStorage.Assets.Models.Eggs`. Board eggs are anchored, non-colliding, queryable, and
  rotate locally so the avatar can run through the board while still grabbing them with the cursor.
  The player drags one egg onto a same-color/equal-tier companion and the server validates both slot
  identities before performing one merge. Nine thin deployment pads share the permanent station
  layout, but ownership controls visibility and deployment: a new run exposes slots 2/4/6/8, the
  first Active Slots purchase reveals and deploys center slot 5 immediately, and the remaining
  purchases fill 3/7/1/9.
  Unowned pads stay present but invisible and non-queryable. Empty owned pads use a neutral available
  color and occupied pads use the same six-color tier identity as matching board eggs. A full board
  rejects another base egg; merging or placing frees a cell.
- The former side-wall auto-combine sign now hosts one 3×3 single-click management board. Coin Value,
  Damage, Fire Rate, Active Slots, and Egg HP are session balance knobs paid in Gems. Spawn Level is
  the existing base-generator advance and Buy Egg creates the current base tier; those two remain
  Waycoin progression. Each percentage card advertises its fixed `+5%` purchase rather than a
  before/after total. These bonuses are additive by level (`1 + 0.05 × level`), never compounded.
  Damage's accumulated percentage also adds to Rebirth's percentage on that same base rather than
  multiplying the two upgrade systems.
  The eighth card preserves the prototype Auto-Combine/future Game Pass seam and the ninth is
  Merge-only Rebirth. Each card is a colored rounded frame around a dark inset panel. Its purchase
  price sits in a separate overlapping pill: purple with the authored amethyst icon for Gem costs,
  gold with the Waycoin icon for Waycoin costs, and a red action pill for Rebirth.
  Both this board and the floor Equip Best control attach their interactive SurfaceGuis through
  `PlayerGui` with world Adornees, so camera zoom does not silently stop pointer delivery. Every
  accepted or refused click receives a short on-screen result.
  The generator begins at Grass/Earth for 100 Waycoins.
  Grass→Ice costs 1,000, changes each newly created egg to Ice at 250, and later generator advances
  and creation prices each double independently. Generator advancement has no wave or hatcher-tier
  cap. Its tier is a global minimum: purchasing an advance promotes every unplaced board egg and
  every installed hatcher below the new tier one-for-one. Healthy deployed pets remain in place;
  newly granted positions are filled and future replacements use the promoted source.
- Auto-Combine immediately resolves every available pair and repeats that cascade after each new
  base egg. Desktop keeps direct drag-and-drop. Touch devices use a sequential two-tap contract:
  the first tap selects a board egg and highlights compatible board/deployment destinations; the
  second tap merges with an equal board egg, deploys into an empty hatcher, or advances an
  equal-tier deployed egg. A second tap on the same source, a tier mismatch, or any other invalid
  world target clears selection without sending a mutation. Camera pans and multi-touch gestures
  are rejected by configured movement/duration thresholds. The server remains authoritative for
  distance, inventory, and live destination tier. The tutorial and result cards use viewport-width
  sizing with desktop caps so those cues stay on-screen on phones and tablets.
- While the first-visit tutorial is still required, setup through Wave 10 suppresses the central
  power hotbar and blocks click, keyboard, controller, and auto-cast activation through the same
  local coverage attribute. Hands-on pauses show their exact instruction; combat intervals fill the
  same footprint with a config-authored preview of the next lesson, so a resumed session cannot
  expose a blank hole. The card copies the live hotbar `PillFrame`'s final absolute bounds after
  phone/tablet scaling instead of owning another pixel size. Completing or rebirth-skipping the
  tutorial restores the hotbar immediately; Wave 11 remains the final safety boundary. Pets/Menu
  and Powers/Board are separate flank controls and remain available while the center is covered.
- The session inventory is server-owned and publishes per-tier counts plus created/merged/placed
  totals as world attributes. Captain controls are inactive until the required tier is actually
  owned; placement itself never spends currency. All Waycoin spending occurs at base-egg creation,
  which preserves the previous exponential material curve exactly.
- Waycoins are the durable Merge wallet. A returning run with a real board or Wave-10 checkpoint
  keeps its saved balance. A fresh Wave-1 (no board, no usable checkpoint), an in-game pre-checkpoint
  reset, a rebirth, or Admin Reset to Beginning sets the wallet to
  `opening_economy.wallet_amount` (0) and lays five owner-only 120-Waycoin stacks beyond the
  Bulwark (600 total) plus one gem in front of the gold-line engineer (left of
  the field while facing the enemy gate). Chevrons walk the closest remaining
  stack, then the gem; leftover gems in the wallet do not skip that drop.
  `collect_setup` re-arms that lesson if the wallet is below 600 and this
  session has not spawned the stacks. A leftover `hall_coins` profile default of 100 is not a
  possession and must not skip the stacks. Checkpoint 10+ retries do not recreate the opening.
  Opening and combat Waycoin drops persist for ten minutes in this management mode; ordinary-game
  drops remain at 30 seconds.
  Entry now arms the encounter and creates the owned empty hatcher positions immediately; the old
  yellow pillar remains only as a Studio scripting seam and has no player prompt. With no installed
  egg, Wave 1 remains sealed exactly as before. A restored run with deployed eggs can therefore
  resume without a second arming interaction.
- The persisted first-visit tutorial uses a flowing trail of the shared world-chevron breadcrumb
  presentation. Wall steps resolve the exact lower-left Buy Egg card, pulse that real button, and
  attach the same large bobbing `CLICK HERE` pill used by the other tutorials rather than sending
  the trail to the wall origin. That explicit click cue teaches purchases one through three, then
  retires; the tutorial card continues counting the required five Earth Eggs down after every
  click, while the overlaid action toast confirms the actual egg created. The server then
  accepts player-directed ordering: completion requires five purchased eggs, at least one real
  equal-tier combination (board-to-board or board-to-deployed), and at least one deployed egg. It
  does not require all four hatchers or prescribe whether merging happens before deployment. Wave 1
  remains sealed until those facts are true. Auto Collector owners receive Coin Pup copy instead of
  walking breadcrumbs and advance when that pet has actually placed all 600 Waycoins in the wallet.
  Phase 1 completion is stored as `tutorial_setup_completed` and releases Waves 1–2.
  Locked first-visit drip (pauses are end-of-wave, then the next wave is held):
  - **Wave 0:** collect coins + gem, buy eggs, combine, deploy.
  - **End of Wave 2:** meet gold-line engineer, unlock Impaler for 1 Gem, install.
    Persists `tutorial_workshop_completed`.
  - **End of Wave 4:** if the Waycoin wallet is empty, chevron any existing
    pile (do not spawn one; credit 1 Waycoin if none are left so the beat
    cannot stick). Then a gem if the gem wallet is 0, meet right-pad
    artillery, unlock Heal for 1 Gem, install. The gem lands on the field
    past the stone wall, not on the cannon pad. Stamps
    `tutorial_cannon_completed` and snapshots egg merge/place/base-tier
    so Wave 6 can tell whether they already upgraded.
  - **End of Wave 6:** optional. If they merged, installed, or raised the
    base egg since Wave 4, skip. Otherwise pause, pick up field coins
    until the wallet is about 600 (enough for six Earth eggs), then one
    loose card: create a couple, then upgrade or place. Hands-off.
    `tutorial_upgrade_completed` stamps when that beat finishes. Skip
    leaves it false so Wave 10 can still land.
  - **End of Wave 10:** reveal the bay supply booth and post Macros as
    Quartermaster. His first interaction completes `tutorial_completed`, then opens the configured
    Merge pass catalog, Browse Potions for the player's own pets, and (until it is completed) the
    full persistent Combat Training mission. Macros and tent stay planted and hidden (Transparency
    1, no collide/query,
    prompt off) until this beat.
    His unfinished-training conversation makes the progression bargain explicit: Merge rebirths
    unlock personal eggs, while completing Combat Training lets pets from those eggs enter durable
    inventory. After completion, the same conversation acknowledges that those pets are now the
    player's to keep and the training service disappears as before.
  After Wave 2 clears, combat pauses (`TutorialIntermission`). Vendors are
  always in the bay but invisible (`Transparency = 1`, no collide/query,
  prompt off) until `_setVendorPosted`. The gold-line engineer is revealed
  with the card (`THE ENGINEER TOOK THE GOLD LINE`), then baby-steps Talk →
  UNLOCK (1 Gem for Impaler Palisade) → INSTALL. That beat stores
  `tutorial_workshop_completed` and releases Waves 3–4; the gold-line post
  stays visible. After Wave 4, combat pauses again. If the gem wallet is 0,
  a second gem is laid on the field in front of the right pad
  (`cannon_gem`) and chevrons walk it. Then Talk → UNLOCK (1 Gem for
  Heal) → INSTALL. That beat stores `tutorial_cannon_completed` and
  releases Waves 5–6; remaining vendors unhide. After Wave 6, if they
  have not merged, installed, or raised the base egg since that snapshot,
  combat pauses for an encouraging coin pickup (about 600 Waycoins) and
  one loose create-then-upgrade-or-place card. If they already did that
  work, Wave 6 does not pause. The Wave 6 preview is definite: the egg-upgrade lesson will begin
  after Wave 6 when the skip condition has not been met. Its Buy Egg result never reuses the
  opening lesson's lifetime five-purchase countdown. A successful merge, base-source upgrade, or
  deployed-egg upgrade during this beat shows the config-authored five-second encouragement; the
  ordinary short action feedback remains unchanged outside that lesson. The same scaled
  tutorial/hotbar footprint also carries sparse progression milestones: the first creation of each
  egg tier, each generator tier, first bulwark/cannon family unlocks, new pet-slot capacity, the
  first 1,000 Waycoins earned in a session, and the Quartermaster tutorial arrival. Routine
  creation, merging, deployment, installation, and management purchases do not toast, and Gem
  pickups never toast. Distinct milestones can queue without turning normal play into an activity
  feed. Auto-Combine returns every new egg-tier and pet-capacity discovery from its cascade through
  the same queue, so automatic merges cannot silently consume a first-time milestone. After Wave 10
  the supply booth and Macros
  unhide; the tent/sign uses the config-owned visible transparency instead of treating its authored
  hidden transparency as the reveal value. The legacy `Browse Potions` tent prompt stays suppressed;
  the Quartermaster's responsive Services menu is the only Merge interaction and reuses the ordinary
  potion catalog/transaction service. Its Game Passes choice reuses the ordinary Pet Shop's
  Marketplace price, ownership, and purchase pipeline with the config-authored Merge subset: VIP,
  Auto Collector, Speed Boost, Golden Touch, Rainbow Radiance, Huge Hunter, Extra Pet, and Second
  Wind. Kade's rocketboards remain exclusive to his vendor. Combat Training checkpoints and
  releases the Merge session before opening the existing mission, then reconstructs the saved
  playstate when the mission ends. Once Combat Training is complete, it is removed from the
  Quartermaster menu rather than offered as a replay; player-pet kill XP remains gated on that
  completion.
  The first Quartermaster interaction completes the first-visit drip. Full
  completion is stored in `GameData.MergeDefense.tutorial_completed` when
  that Talk finishes. A Wave 6 skip does not stamp it. Later entries
  keep the same 600-Waycoin opening but are not tutorial-blocked. A positive Merge rebirth count is also an
  independent hard tutorial gate, so legacy or incomplete onboarding state cannot restart it after
  rebirth. Admin **Reset to Beginning** (`🔄 Reset to Beginning (keeps ALL unique pets)`) is the
  deliberate clean-slate exception for Merge possessions **and** the Merge tutorial flags.
  It closes any live/pending Merge session before profile mutation; clears wallet, checkpoint,
  board and deployed eggs, hatcher/bulwark runtime models, rebirths, management upgrades, spent
  Gems, and `GameData.MergeDefense.tutorial_completed`; then re-enters on the next scheduler turn
  with no scheduled wave. Stage 1 (`collect_setup`) starts again so the opening piles get
  chevrons. The new session starts at Wave 0 with zero Waycoins and exactly five owner-only
  opening piles worth 120 each plus the opening gem; Wave 1 remains sealed until an egg is
  deployed. Unique/huge pets stay, while ordinary inventory follows the global Reset to
  Beginning contract. On the dedicated Merge place this never starts the Farm prologue or first-pet
  chooser. Wall cards show the reset values (Coin Value 100%, Rebirth R1) and next purchase
  (+5% → 105%, Next R2). `scripts/studio/test_merge_admin_reset_lifecycle.luau` exercises the real
  pickup, five-purchase, merge, Equip Best, combat, bulwark-install, and reset path; it asserts the
  same clean result during the live session, and the result was separately verified across
  Stop→Play.
- The perfect runner follows the same sequence at actual character walk speed while combat remains
  asynchronous: collect drops → create base egg → repeat/merge as necessary → walk to the selected
  hatcher → place. One merge press always chooses the lowest available equal pair, keeping this
  timing experiment deterministic without adding a selection UI.
- Outside an incomplete first-visit lesson, Wave 1 remains sealed until the first crafted egg is
  placed. During that lesson it waits for the five-purchase/one-combination/one-deployment contract.
  Checkpoint snapshots now include
  base-generator tier/spending, unplaced crafted inventory, and creation/merge/placement totals
  alongside balance, rosters, and objective state, so a failed stretch cannot duplicate or erase
  board materials. Floor roster panels derive their player-side offset from the deployment-pad
  geometry and begin beyond the egg square instead of overlapping it.

## Permanent ten-bay realm and durable checkpoints (2026-08-28)

- `Workspace.Maps.MergeEggRealm` is the permanent editable ten-bay map: five Heaven-styled lanes
  and five Hell-styled lanes sit on opposing raised terraces around a long sunken public mall. All
  ten bays live under its `Bays` folder; `CentralHall` owns the mall, bay approaches, retaining
  walls, circular end plazas, opposing flows, cancellation band, bridges, and civic details. Runtime binds this
  authored root and fails closed if it or any bay contract is absent. It does not generate map
  geometry.
- Each playable lane is 96×300 studs. The five bay centers use a 136-stud pitch, leaving the
  reference's 36-ish-stud themed berm between neighboring 100-ish-stud bay envelopes. The rows use
  a 180-stud center gap. Each bay receives its own 56-stud-wide, 10-step civic stair from the
  terrace at Y=2 down to the mall at Y=-8. The permanent blockout currently measures roughly
  1,003×784 studs and remains inside the 1,320×920 `MergeEggPrototype` CurrentArea envelope.
- The common space is a 680×180-stud mall with continuous retaining walls. Circular Hell and
  Heaven end caps feed lava and water into a straight 18-stud river; the flows meet in a 26-stud
  steam/pearl cancellation band. Four wood-and-metal bridges align between bay mouths. The
  player-end cap of every
  lane remains an open public entrance, while transparent side boundaries keep players from
  shortcutting between bays through the decoration seams.
- Existing flora and MissionProps are cloned outside the playable lanes and along the mall to
  establish Heaven/Hell identity without covering the board, pickups, or combat. Every bay also
  has an architectural outer spawn gate around its existing gameplay portal. Runtime asset
  clones are anchored, non-colliding, non-queryable, and stripped of scripts.
- The first custom Hell landmark candidate is the rebuilt Ember Citadel under
  `assets/exports/props/ember_citadel/`. Its `.blend` preserves the original Meshy GLB in a hidden
  reference collection and keeps a fully editable procedural rebuild separately. The Roblox GLB is
  consolidated to seven material-based meshes (15,978 triangles) and passes the strict topology
  check with zero boundary, wire, non-manifold, zero-length, or zero-area geometry.
  The same builder supports a middle-only height extension; the current 4-stud tall variant is under
  `assets/exports/props/ember_citadel_tall/` (24.62 studs high, 15,594 triangles), with the base and
  crown proportions preserved while the shaft, banners, and crown are shifted upward together.
  A near-double-height 40-stud variant is under `assets/exports/props/ember_citadel_tall_40/` for
  landmark-scale placement; it uses the same 9.8 × 9.8 footprint and clean seven-part export.
- The matching Emberfang Gate candidate is under `assets/exports/props/emberfang_gate/`. It is a
  separate clean rebuild from the supplied Meshi arch: two side towers, a connected pointed arch,
  banners, spires, and restrained ember liners. The export keeps a 21 × 6.8 footprint, is 18.95 studs
  high, and passes the strict topology gate with zero boundary or non-manifold edges.
  The richer architectural pass is preserved separately under
  `assets/exports/props/emberfang_gate_v2/`: 21.85 studs high and 14,346 triangles, with recessed
  tower façades, repeated ribs/parapets, layered lancets, structural arch piers, segmented arch ribs,
  flying buttresses, and an integrated central crown.
  The 32,605-triangle voxel/rebake experiment under `emberfang_gate_v11_refined/` is superseded:
  it softened the hard-surface design and exceeded Roblox's 20K MeshPart limit. The selected
  source-preserving candidate is now `assets/exports/props/emberfang_gate_crisp/`. It keeps the
  original UVs, texture, and silhouette at 13,329 triangles, welds exact duplicate geometry, uses
  flat shading, and selectively snaps 278 broad axis-aligned architectural patches to shared
  planes, and removes one inherited zero-area triangle. This is the candidate to compare in Studio
  before any manual recolor/retopology work.
  The matching Heaven-side candidate is `assets/exports/props/celestial_gate_crisp/`, derived from
  the supplied Celestial Gate of Lum GLB with the same source-preserving process. It remains below
  the Roblox MeshPart limit at 13,345 triangles, welds 10,400 exact duplicate vertices, and snaps
  231 broad architectural patches (1,578 vertices) to shared planes while retaining the original
  white/gold/cyan atlas and silhouette. It also retains the donor's intentionally disconnected/open
  component structure rather than voxel-remeshing it.
- Hall entry normally allocates one unclaimed bay at random and publishes its id, side, and column
  on the player. During first-bay environment authoring, `realm_layout.authoring_bay` pins Hall
  entry by `side` and `column`; it currently selects Heaven Bay 1, can switch to Hell Bay 1 by
  changing only `side`, and restores random allocation when `enabled` is false. Every bay has
  authored claim displays on the upper terrace and at the lower stair landing, clear of the
  playboard. Runtime binds every tagged display in place to the same bay claim; empty displays can
  request that specific bay and occupied displays all show the owner's name. Claims are released on cancelled entry, exit, character
  cleanup, and player leave. The client resolves all world-space Merge UI through the player's bay
  id plus the required `HatcherSpawn` gameplay hook instead of assuming the first Model stamped with
  that id; decorative spawn gates deliberately share the id and are not valid runtime roots.
- The complete ten-bay footprint is one `MergeEggPrototype` CurrentArea, so walking down the hall or
  visiting another bay does not accidentally end the mode. Enemy movement and physical drops still
  use the selected bay's authored `ArenaBounds`; no combat actor can leak into a neighboring lane.
- The dedicated `Halo and Horns: Merge` place is configured as place id `84544653387905` in the
  same universe as main. Session ownership is per player (`_activeByPlayer` plus per-entry records),
  and every record owns its claimed bay/world reference. Heartbeat stepping iterates those records;
  NPC principals and transient folders include the player identity. This replaces the former
  singleton `_active`/`_world` assumption and is the runtime seam for simultaneous occupied bays.
- While the place remains unreleased, the main/Farm and Fight door keeps its sealed `COMING SOON`
  presentation and exposes the Merge teleport prompt only to the canonical internal-account IDs
  plus Kade (`536245038`). The client hides the prompt for everyone else, the server validates every
  use, and an unauthorized direct join to the Merge PlaceId is returned to main (or kicked if that
  teleport fails). Studio uses the same ID policy and the same configured PlaceId route. Because
  Studio cannot complete a normal cross-place teleport, using the door in a local playtest fails
  visibly instead of silently entering the obsolete embedded prototype.
- `MergeEggPrototypeService` is a required `map_binding` runtime module in published servers as
  well as Studio. Only its balancing `AutomationService` dependency remains Studio-only. If the
  service is placed behind `RunService:IsStudio()`, Farm and Fight retains the sealed door but
  never creates `MergeEggPrototypeEnterPrompt`, and the dedicated place loses its gameplay/return
  bindings.
- The dedicated place's authored common-area `Workspace.HallOfWorldsPortal` is the reciprocal
  return door. Runtime styles and labels that existing hook, then exposes an unrestricted
  `Return / Farm & Fight` prompt to every player. Return does not require a claimed bay, active
  session, internal-account classification, or Kade's explicit preview grant.
- Dedicated-place character entry waits for ProfileStore data before creating the isolated wallet
  or arming a wave. This prevents a transient `currency_setup_failed` from leaving the player in
  the map with only fallback art and no working management grid. A veteran whose settings finish
  loading during entry is reconciled once more after the mode listener is connected, so Full mode
  restores the real equipped pet folder and cannot coexist with the temporary Simple reserve.
- Each bay still owns portable gameplay hooks, while the polished 4×4 board and hatcher stands are
  authored under `Workspace.GeneratedMap_MergeEggVoxel`. Runtime adopts the matching authored board
  as that bay's only `MergeBoard`, aligns the nine interaction pads and installed eggs to the visible
  stands, and places Equip Best at the authored floor height. The client and server consequently
  share one board reference for dragging, snapping, merging, tutorial focus, and inventory display.
  Adoption never changes the authored board's saved Studio transform. Reparenting is allowed, but
  runtime-derived offsets must not relocate map geometry; Equip Best follows the authored board.
- The central nine-card management grid is authoritative. The giant green Create Earth Egg and
  giant yellow Upgrade Base Egg panels are obsolete duplicates: in the dedicated map they are
  invisible, non-queryable compatibility anchors. Coin Value, Damage, Fire Rate, Active Slots, Egg
  HP, Spawn Level, Buy Egg, Auto-Combine, and Rebirth remain visible and interactive.
- Base egg creation prices are `100, 250, 500, 1,000, 2,000, ...`; generator advances begin at
  1,000 and also double. The former tier-8 switch to 1.25× growth was removed because it flattened
  late progression and made high eggs cheaper than the combat ladder required. The pricing helper
  enforces a minimum 2× multiplier across the full prototype-huge ladder.
- Runtime derives three tall invisible collision barriers from each selected bay's authored
  `ArenaBounds`: both long sides plus the enemy/portal end. The player entrance stays open for
  legitimate travel through the mall. These barriers prevent jumping over the intentionally low
  decorative sightline walls. Waycoin and Gem pops resolve the same occupied-bay bounds through
  the session record and use DropService's reflected landing animation, keeping wall-edge loot
  visible and collectible instead of letting it settle beyond the terrace.
- `GameData.MergeDefense.checkpoint` remains the compact ProfileStore-safe Wave-10 boundary used by
  deterministic tests and banked-wave recovery. `GameData.MergeDefense.playstate` separately stores
  exact current Merge possessions on normal exit: wallet, reserve-objective count, base generator
  tier, unplaced board inventory, and deployed egg tiers. Its wave alone is rounded down to the
  prior ten-wave boundary, and Wave 0 is a valid saved state. Re-entry therefore keeps every egg,
  placement, and collected Waycoin while rebuilding objectives at full health, rerolling temporary
  NPC squads, and scheduling only combat again. Tutorial completion writes this playstate
  immediately. DataService runs the synchronous snapshot hook from `ReleaseProfile`, covering both
  PlayerRemoving and server shutdown before ProfileStore's final release save. Rebirth and Admin
  Reset clear both durable records; ordinary exit/logout does not.

## Source and authoring

- Runtime/config: `configs/merge_egg_prototype.lua` and
  `src/Server/Services/MergeEggPrototypeService.lua`.
- Authored layout/allocation: `src/Shared/Game/MergeEggRealmLayout.lua` and
  `src/Server/Services/MergeEggRealmBuilder.lua`.
- Durable checkpoint/playstate normalization: `src/Shared/Game/MergeEggCheckpoint.lua` and
  `src/Shared/Game/MergeEggPlaystate.lua`.
- Combat telemetry and Studio-only core egg progression UI:
  `src/Client/Systems/MergeEggPrototypeObserver.lua`.
- Repeatable Edit-mode passes: `scripts/studio/build_merge_egg_prototype_world.luau` builds the
  temporary one-bay source, then `scripts/studio/bake_merge_egg_realm.luau` consumes it and replaces
  only `Workspace.Maps.MergeEggRealm`.
- The service is registered only when `RunService:IsStudio()` and map binding is enabled. A missing
  authored realm fails closed and logs the exact expected Workspace path; runtime never fabricates,
  transforms, or tiles the venue.

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

The first empty-hatcher pass deployed all four captains at tier 0 with zero pets and zero replacement
queues. Every local billboard was input-active in `PlayerGui` and read `UPGRADE → EARTH EGG`. A real
screen click on Captain 3—not an injected remote—changed only that folder to `grass_egg`, created
exactly five random pets, and engaged its assigned enemy. Captains 1, 2, and 4 remained `NO EGG`
with zero pets/queues. After the setup gate was added, a restart held at `AwaitingFirstEgg`, Wave 0,
with zero active/pending enemies and a sealed portal. The first real captain click started Wave 1
with one front and three trash enemies assigned to that online team. Wave 2 then published two
fronts: one Ember Brute remained assigned to the online captain while four Whelps targeted an empty
position. Bringing a second captain online during that fight raised the hatcher count to two before
Wave 3; its two-front Brute-led/trash configuration also deployed without runtime errors.

The first Waycoin pass showed the Hall pane and canonical coin icon while Gems remained visible and
all four origin-crystal panes stayed hidden. Wave 1 produced three owner-only textured Waycoin
pickups, each carrying 8 `hall_coins`, the Hall mesh `96505477571443`, and texture
`75902763288492`. That run originally tested a prototype-only ten-stud radius; the scoped override
was removed on 2026-08-27 when the design standardized Magnet game-wide. The runtime log remained
clean.

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
- Treat the early `8/8/6`-second intermissions and `1/1/2` attack-front progression as the first
  board-cadence probe, not shipping timings. The free buttons stand in for completed egg builds;
  compare whether a player can comfortably bring a second hatcher online before Wave 2 while still
  reading the fight.
- When the merge board supplies physical eggs, define one simple shortage rule before adding queue
  controls. The least complex candidate remains: each team reserves its oldest empty slot, and the
  next completed egg assigned to that captain satisfies it.
- Tank/melee drive-back that pushes the whole frontline away from the hatcher is desirable lane
  behavior. A legitimately advanced team travels back to its hatcher after combat rather than
  teleporting at the generic catch-up distance.
- The bulwark is a secondary engagement boundary, not a new focus system. Team ownership establishes
  the opening fronts; after the configured grace, targetless teams may reinforce the hardest live
  target while at most one stays in reserve. The Bulwark immediately releases that reserve, and
  ordinary aggro tables still choose whether already-engaged pets peel.
- The player remains free to move between hatchers, merge eggs, and manage the board while these NPC
  teams fight asynchronously. Player position must not be a combat leash or scheduling input.
- Waycoin pickups are the first reason for the player to leave the board during combat. Player
  Magnet reach is game-wide and must not be reset on mode entry. Auto Collector is a separate
  passive pet: while idle in this mode it obeys the same behind-breach heel anchor as the reserve
  squad, but it may run out to collect physical currency.
- The physical contract always contains nine hatcher coordinates at eight-stud spacing. Captain
  roots, visible pads, and floor `SurfaceGui` anchors derive from the owned-slot order, so only four
  stations deploy initially and slot 5 appears as the first purchased expansion without shifting
  any existing station.
- Board eggs remain directly draggable either onto an equal-tier board companion or onto an owned
  frontline deployment pad. Pickup moves the gold tutorial chevron to a recommended destination;
  all compatible destinations light gold, then the destination inside the horizontal snap radius
  turns green and accepts release. Board-to-board merging now uses the same proximity snap as
  deployment, so camera angle and egg height cannot make a visually correct drop miss. Mismatched
  eggs and unpurchased pads never advertise as valid. The floor `Equip Best` control between board
  and hatchers performs one fair pass only:
  strongest eggs fill empty hatchers, then matching eggs advance the weakest occupied hatchers at
  most once each. It does not merge board inventory or repeatedly advance one station.
  Its green/gray state is server-authored from that exact assignment plan, not merely from board
  inventory count; an unusable low-tier egg therefore leaves the control gray rather than promising
  an equip action that the server will refuse.
- Each floor roster owns a permanent 7.5-stud cross-lane footprint: one eight-stud station cell minus
  a 0.5-stud gap. A fixed six-slot logical canvas and 6.25-stud minimum rearward footprint keep the
  Layer-3 maximum readable when neighboring slots activate. Each local anchor raycasts to the actual
  collidable play-field surface and uses zero `SurfaceGui.ZOffset`; it never inherits the height of
  a legacy `StartPlatform`. Pet fills remain `current endurance / maximum endurance`. The all-nine
  density fixture remains a presentation proof, not default ownership.
- The combat enemy rail uses two columns before density scaling. Gems and Waycoins remain permanently
  visible during a fight because they drive the background management loop; only non-economic menu
  controls may yield screen space to an extreme pull.
- Damage to an installed egg refreshes a five-second production lock for that captain. Replacement
  slots remain queued but cannot hatch until the egg has gone five uninterrupted seconds without a
  hit; a missing or destroyed egg cannot produce at all. The existing team window labels this state
  `PRODUCTION JAMMED`, while world/team attributes count damage hits, distinct lockouts, and currently
  locked eggs. Checkpoint restore installs full-health eggs with no carried lock timer.
- Instant healing pulses are rendered by each client from the healed model's locally smoothed pivot.
  The server remains authoritative for the heal and publishes the ordinary combat result, but never
  anchors VFX to its stale pet-follow spawn position.
- Every installed egg owns a 12-stud heal-denial field using the shared combat
  `HealingSuppression` status and PowerService ground-rune visualization. The first crossing of the
  red breach line activates every installed field that is ready; real damage activates only the
  struck egg. A field remains active for 30 seconds, then recharges for 30 seconds. Hits and breaches
  during either window do not refresh it, and each hatcher keeps an independent timer. Wave 14's
  healer composition remains unchanged until this defense is measured. These fields pass the
  selected bay's authored `LandStrip` top to the shared rune primitive; an unrestricted downward
  ray can otherwise land on the stationary Hatcher Captain and suspend the ring several studs above
  the floor.
- The temporary player escort uses the red breach plane as a conditional idle anchor. While the
  player works behind the line, untargeted escort pets heel near the eggs instead of obstructing the
  merge board. Crossing to the enemy side restores the player's live character as their formation
  anchor, so they follow forward normally; returning behind the line returns them to defense.
- Every tenth wave is a progression checkpoint. The checkpoint is banked after its extended
  intermission. In gameplay it contributes only the rewind wave number: defeat retains the live
  Waycoin wallet, uncollected drops, merge-board eggs, base-egg progression, deployed egg
  tiers/positions, current rosters, and every purchased Gem upgrade. Destroyed deployed eggs retain
  their placement identity while inactive, then every retained egg/objective and combat roster
  returns at full health before the wave after the checkpoint rolls again.   Gameplay recovery is
  automatic after the defeat delay; the rear reset control can trigger it immediately.
  Before the first Wave-10 bank, Wave 0 is that boundary: overrun or egg-loss rewinds
  to Wave 1 and keeps the live egg/board/wallet. A missing snapshot used to leave
  DefenseOverrun parked with no restart.
- Normal exit/logout saves possessions independently from the last banked boundary. Re-entry keeps
  the live wallet, board inventory, base tier, deployed egg tiers, and purchased systems exactly as
  they were, restores objectives at full health, and rerolls only session-only squads. The wave is
  the sole rollback: Wave 1 returns to Wave 0/next Wave 1, Wave 14 returns to Wave 10, and so on.
- Deterministic balance automation deliberately retains the former exact-snapshot restore. The coin
  runner and the explicit test restore seam can replay the precise economy/board/roster state banked
  at Wave 10/20, while ordinary play never uses that rollback policy.
- Failure at the next ten-wave boundary is an intentional progression wall, not evidence that the
  recovery stretch must be weakened. The current no-upgrade runner repeatedly reaching but failing
  Wave 20 is the desired baseline: a player should need the separate upgrade system to clear 20,
  then need further upgrades at 30, 40, and later boundaries. Exact restore is a test-only tool;
  gameplay retries accumulate defenses and currency so a stuck player can build momentum.
- Author waves `N+1` through `N+3` after each checkpoint as a recovery ramp with enough payout and
  collection time to rebuild. The current Wave 11/12/13 ramp uses one/two/three eight-Whelp fronts
  and `8/8/6`-second gaps; the 5× Heaven reward makes them worth 1,600/3,200/4,800 Waycoins. Wave 14
  resumes the real climb.

## Human-play transition notes

- The current opening is technically survivable, but the margin is slim: a human player only just
  completes the first egg at the second hatcher position before the Whelps overrun the defense.
  The actual-walk-speed automation remains an upper bound because it reacts immediately, chooses
  routes perfectly, and loses no time interpreting the fight or selecting a captain.
- Do not treat “the runner can do it” as sufficient opening balance. Before human combat becomes the
  primary test, preserve a readable buffer for reaction, camera movement, coin-path variance, and
  imperfect routing. Candidate knobs are the first two wave gaps, opening drops, Wave 2 deployment
  delay, and early Whelp pressure; no particular correction is chosen yet.
- The next human-play pass should record when 100 Waycoins for Position 2 are reached, when the
  second egg is installed, and when the first red-line breach occurs. The time between installation
  and breach is the useful safety-margin measurement.
- The first measured pass under the old two-front Wave 2 crossed four Whelps over the red line even
  though the perfect runner brought Position 2 online and eventually recovered them. Wave 2 was
  therefore reduced to one lone-Brute front; Wave 3 now owns the first two-front test.
- The first single-Brute rerun remained breach-free through Wave 10 with all five reserve eggs and
  all four Home hatchers at Sand. Wave 11 immediately rose to 46 active enemies; the run was stopped
  to replace the old hard stage handoff. Wave 11 now begins the Heaven 1 combat layer, while the
  runner is free to buy Heaven 1 eggs before or after that checkpoint whenever it has the coins.
- The first stationary-objective run failed at Wave 14 with no Waycoins left to rebuild. That is an
  acceptable difficulty wall only because Wave 10 is now a real restart checkpoint; the recovery
  ramp must still prove that a player can earn useful money before Wave 14 rather than repeatedly
  re-entering an unwinnable state.
- The later reserve-roster run reached and failed Wave 20 twice, restored to Checkpoint 10, and
  reached Wave 14 again with a full four-pet player escort and a deep reserve bench. That is now the
  accepted no-upgrade result. Do not tune Wave 20 down merely to let the automation clear it; use
  this run to measure the amount and price of player upgrades required for the first gate.
- A possible later crossover escape valve is deliberately narrow: the player may carry only their
  currently equipped three or four pet slots into the lane. Do not wire owned inventory into this
  prototype yet. This mode has no leveling and therefore no ordinary power acquisition; Heal may be
  the only taught player action, while Resonance has no useful progression role here. Manual focus
  fire on enemy healers was useful in testing and may become one simple targeting lesson later.
  A candidate cross-mode **Assassin** convenience game pass gives the player's personal squad healer
  priority during ordinary auto-target selection. It must not add combat stats, defeat tank taunts
  or explicit focus, or grant the behavior to all four NPC hatcher teams; that would erase the healer
  composition test rather than reduce player targeting friction.
  Keep any opt-in separate from the NPC-only balance baseline so inherited account strength does not
  hide a broken checkpoint economy.

## Explicitly deferred

- Tile generation or tile streaming.
- Merge/placement animations, selectable recipes, persistent egg inventory/compatibility, or
  monetization. The 4×4 board now supports server-validated drag-to-equal and drag-to-deployment
  interactions, but its deterministic two-to-one recipe still exists only to measure cadence. Installed
  source eggs use the same real egg assets and prototype combat health; final damage feedback and
  repair rules remain deferred.
- Wave selection UI, production difficulty curves, matchmaking, or more than one active player.
- Player-facing queue reordering, congestion policy, and production team-state controls.
- Production board recipes, timings, persistence, and unlock requirements. The current generator
  cost schedules and two-to-one recipe are balance fixtures, not a shipping economy decision.
- Owned-pet crossover and a final combined NPC/player roster presentation. The current player escort
  is only a session cast-off experiment. If crossover is retained later, it is limited to the
  player's currently equipped three or four slots rather than their full owned collection.
- Reopening Hall of Worlds in production.

## Edge tower art set

- The visual family comprises Heal, Rage, Debuff, Gravity, Repulsor, and Nullifier cannons. The
  first three use the supplied concept art directly; the latter three were generated in the same
  low-poly wheeled-siege silhouette. All six were rebuilt through the Meshy smart-topology pipeline
  and retextured from their corresponding concept art.
- Every tier is a single watertight mesh below 9,500 triangles. All 24 group-owned Model, Mesh,
  and Texture ID triples, checksums, Meshy task IDs, integrity reports, and runtime paths live in
  `scripts/merge_cannon_model_ids.json`; `scripts/merge_cannon_pipeline.js audit` verifies the
  complete local chain. The concept briefs live beside the art in
  `assets/concepts/merge_cannons/prompts.json`.
- Runtime identity is config-owned: `scripts/sync_merge_tier_art.js` deterministically generates
  `configs/merge_tier_art.lua` and `scripts/merge_tier_runtime_manifest.json` from the cannon,
  cannon-preview, bulwark-model, and bulwark-preview manifests. Workshop cards and world spawns
  consume that same table. The 24 cannon preview PNGs under `assets/ui/merge_cannons/` are normalized
  to 256×256 RGBA with a 78% maximum silhouette footprint; group-owned Decal/Image pairs live in
  `scripts/merge_cannon_preview_ids.json`. Cannon cards use the verified Decal IDs through `rbxthumb`
  and do not create ViewportFrames. A cached world instance is replaced when its Model/Mesh/Texture identity or cannon
  scale differs from the selected family/tier, even if its tier attributes look current.
- Cannon visuals are repo-owned spawnable assets under
  `ReplicatedStorage.Assets.Models.MergeCannons/<Role>/Tier1|Tier2|Tier3|Tier4`, prebaked into
  `assets/place/Models.rbxm` by `scripts/prebake/add_merge_cannon_assets.luau`. The loose
  Workspace review lineup is removed; maps own mounts, not cannon visuals. Every tier is normalized
  to the corrected 7.953594-stud reference width at template scale 1. Presentation
  size is per-tier `worldScale` on `configs/merge_tier_art.lua` (every
  Tier 1 is 0.375; Tiers 2–4 stay 0.5). Every chassis sets
  `seatOffsetY` so wheels sit on the pad. Rage T1 also sets
  `barrelYawDegrees = 270`.
  `src/Shared/Game/MergeTowerModels.lua` clones the requested gameplay role/tier,
  applies that entry's `worldScale`, and grounds it on a pad's `TowerAnchor`;
  no current-art substitution or shared edge-tower scale remains.
- Each authored bay has two distinct armored tower pads: one immediately outside egg position 1
  and one immediately outside position 9, pulled one 8.4-stud pad-width back
  from the egg-stand depth so they are not on top of the red-line engineer.
  The pads live under
  `Workspace.GeneratedMap_MergeEggVoxel.TowerStations`, expose `MergeTowerPadSlot`,
  `MergeTowerPadRole`, and bay identity attributes on both the model and invisible `TowerAnchor`,
  and use cyan Heaven accents or ember Hell accents rather than the egg stands' circular language.
  The 8.4-stud footprint is sized from the corrected roughly 8×7.4-stud Repulsor cannon. Pads
  start empty. Runtime clones the installed role's distinct gameplay-tier
  template, applies that tier's `worldScale`, seats the chassis on the pad, and
  lofts a fireball along a parabolic arc. Power-laying roles (Heal, Rage,
  and any `cast` landing) aim the floor under the target — the same
  LandStrip plane the ring uses — and the ball blooms out instead of
  lingering. Other roles still use the gate-side lane target. Aim uses `EnemyService:GetLivePosition` / `MoveTarget`, never
  the model pivot (that CFrame stays at the portal spawn). Each shot
  freezes aim for a short config recoil (lurch up, settle) that never
  owns the fire interval, then tracking resumes. Range reaches
  `OuterSpawnGate` on the dedicated Merge place (the old `EnemyPortalVisual`
  hook is absent there), so they track from the gate rather than only the last
  90 studs. The chassis stays flat and only yaws; loft is in the projectile.
  Auto-fire requires a live incoming enemy. Each shot plays the group-owned
  `cannon_fire` clip from the cannon and `cannon_impact` at the landing
  (`configs/sounds.lua`), same pair for every role. The test E Fire prompt
  is gone. Talk the Artillery Commander behind that pad instead: the
  workshop is the same pick-then-act panel as the bulwark menu, but the
  list is the six cannon roles and that commander only writes his pad.
  Unlock is one-time and global (access to Tier 1). Playtest
  unlock, place, and upgrade stay one Waycoin; final unlocks will
  almost certainly be gems or a Robux game pass. The workshop
  shows LOCKED until that flag is set. Currently Owned and Next
  Upgrade each render the family/tier's config-owned transparent PNG
  from the generated preview manifest. The menu owns no live model,
  WorldModel, ViewportFrame, or model-thumbnail fallback. Install pays to place
  Tier 1 on that pad. Upgrade pays to advance only that pad. Persist is `MergeCannonPersist`: owned + per-pad
  slots only. Purchase does not compare the bay record to a rebuilt
  MergeDefense table and does not read the live wave. Board-action toasts use DisplayOrder 130 so they
  sit in front of the workshop (120), not behind it. Heal aims injured pets (`CombatDamageTaken`) and
  places the existing Healing Field at impact; Rage fires at one
  ally already in combat (`TargetType` Enemy / `AggroTargetRef`)
  and stamps Berserk on that pet plus any other ally inside the
  landing circle (`SipBrewOn` on each model, existing brew stack
  math, no ticks). No idle-pet or empty-lane shot. Owner sip is
  forbidden: that broadcast made the circle a visual only. Floor
  cards read the pet stamp; CombatAura watches the pet Until. Flask
  drink still writes the player.
  Hard rule: no shot at a target on the egg side of BreachLine. Heal
  and Rage use that same floor (`heal_fire_line` / `rage_fire_line`,
  also `bulwark` or `mid`).
  Debuff sips Weakening Vial on enemies. Gravity pulls into a
  black-hole rune. Repulsor is a concussion blast that flings
  outward from impact (per-enemy hit roll; T4 40%). Dest is
  leashed before Y-snap so they cannot clear the back wall.
  Nullifier rolls Frost Bind per enemy. No rebuilt powers.
  Playtest unlock is Wave 1 / one Waycoin;
  production stays the Wave-10 intermission. Hits do not deal damage yet.

## Bulwark defense art set

- The walk-up workshop is a pick-then-act panel: Currently Owned and Next
  Upgrade previews on the left, the six families as a list on the right.
  Buy unlocks the family globally. Upgrade lives in the next-upgrade
  card and only advances this slot. Install pays to place Tier 1 on
  this slot. Persist is `MergeBulwarkPersist` (owned + per-slot
  installs only). Purchase does not compare the bay record to MergeDefense
  and does not read the live wave. Per-tier `upgradeNotes` and draft roles (stop, bleed,
  hunt, shred, hold, ward) live on `MergeBulwarkProgression`. Impaler Palisade
  is the first live effect: a no-damage stop shove toward the gate (same
  displacement as tank Seismic) plus a short root. Charges are per marcher,
  1–4 by tier; after the last bounce they walk through and the gold line
  opens combat. Concertina Line is the bleed family: a lane DoT plus a graded
  slow (T1 on-strip only, T2/T3 linger, T4 stacks and stays). Land Shark is
  hunt/drag. Saw Blade is the shred line: rapid high damage on the deck plus
  client-only cube chips. Grasping Hedge is a temporary front-wave root plus
  pile slow. After the root expires they walk; walking back in roots them
  again. Wardstone Barrier is still visual-only and egg-only. The five lane
  families may sit on the gold line, the red line, or both. Mid/front slots are
  cataloged but not authored yet. Crossing `BulwarkLine` still opens pet combat;
  crossing `BreachLine` still opens egg attacks.
- The first bulwark catalog has six four-tier visual families: Impaler Palisade, Concertina Line,
  Land Shark, Saw Blade, Grasping Hedge, and Wardstone Barrier. Every tier is distinct art rather
  than a resized copy. Their shared material progression is primitive, reinforced, elemental, and
  soul/void so an upgrade remains readable during combat.
- All 24 concepts and reproducible prompts live under `assets/concepts/merge_bulwarks/`. Each model
  was rebuilt geometry-first through Meshy Smart Topology, repaired when necessary, retextured only
  after approval, and rechecked at 3,984–5,968 watertight triangles. Group-owned Model, Mesh, and
  Texture IDs plus Meshy task provenance live in `scripts/merge_bulwark_model_ids.json`.
- Runtime-ready templates are prebaked under
  `ReplicatedStorage.Assets.Models.MergeBulwarks/<Family>/Tier1|Tier2|Tier3|Tier4` by
  `scripts/prebake/add_merge_bulwark_assets.luau`; maps should own only placement anchors.
  `src/Shared/Game/MergeBulwarkModels.lua` supplies clone/spawn access and grounds a template at a
  supplied CFrame or `BulwarkAnchor`.
- `MergeBulwarkProgression.combatEffect` no longer owns a duplicate balance table. Every tiered
  charge, damage, cadence, radius, control, and movement value is read from
  `configs/merge_egg_prototype.lua`; missing entries fail loudly instead of selecting hidden code
  defaults.
- The lossless Roblox-upload snapshots under
  `assets/source/props/merge_bulwarks/roblox_originals/` are the authoritative source for all 24
  runtime templates. Do not reconstruct them from only MeshId, TextureId, or a canonical Size:
  doing so discards the imported hierarchy and previously produced flattened proportions.
  Runtime uses uniform `Model:ScaleTo`, clears only the package's 90-degree PrimaryPart import-pivot
  rotation, and then applies the authored anchor yaw; it must never scale individual axes.
- `scripts/studio/author_merge_bulwark_anchors.luau` authors placement hooks from
  `MergeBulwarkSlots` without mutating `BulwarkLine` or `BreachLine`. Those two
  parts stay the combat planes (pets open / eggs become attackable). Lane
  anchors sit on the gold line; egg anchors sit on the red line. Mid and front
  stay dark until helper lines exist. A 96-stud line uses a 94-stud defense
  strip (ten 9.4-stud tiles) with one-stud wall clearance. Anchors ground to
  `LandStrip`. Talkable Bulwark Engineer vendors (`user_id` 3200870803)
  stand on the red-line left and the gold-line right so the egg row and
  later cannons keep the middle. Each Talk opens the same unchanged
  workshop for that slot. Wardstone is egg-only.
  Select writes that slot at Tier 1. Upgrade advances only that
  slot. Playtest unlock remains Wave 1 / one Waycoin; production
  stays the Wave-20 intermission.
- Every one of the 24 family/tier variants is presentation-audited against all ten Heaven/Hell bays.
  The five static families use uniform `0.94` scaling on ten 9.4-stud anchors; each line spans 94
  studs and retains the authored one-stud wall clearance. Land Sharks are audited separately as
  three submerged hazards per bay. Saw Blade also has explicit six-stud depth and height ceilings so
  a deck-sized import cannot pass. The repeatable server audit is
  `scripts/studio/test_merge_bulwark_fit.luau` (2,120 placements under the current presentation rules).
- Saw Blade has four approved independently pivoted Roblox rigs. The accepted runtime snapshots live
  under `assets/source/props/merge_bulwarks/roblox_approved/saw_blade/` and are reproducibly rebuilt
  by `scripts/prebake/build_approved_merge_saw_blades.luau`; the Blender working sources remain under
  `assets/source/props/merge_bulwarks/saw_blade/`. Tier 1 uses the repaired brown rotor and wood hub,
  Tier 3 uses three repaired dark-metal rotors with the center rotor counter-rotating, and the
  accepted Tier 2 / Tier 4 mechanisms run at twice the Tier 1 / Tier 3 speed. Live spin is 2×
  those authored degrees, and each tile starts at a random phase so the line does not lockstep.
  All scaling remains
  uniform. The split/repaired MeshIds are 200-stud Roblox assets; Studio QA previews shrink them
  with Model.Scale `0.04` / `0.05`. The lune-assembled templates copy the 8–10 stud Size boxes
  without MeshSize, so spawn recreates each MeshPart through `CreateMeshPartAsync` and keeps the
  authored tile Size. `Models.rbxm` is the runtime authority and contains only these four approved
  variants.
- Saw rotors animate locally in `MergeEggPrototypeObserver`, scoped to the current bay's
  `MergeEggBulwarks` folder; the server never streams per-frame rotor CFrames. An installed line has
  one spatial idle-whirl loop centered on the line. The circular-saw contact asset plays at the
  struck combatant on a real shred tick, throttled so the long clip does not stack. Each tick
  also pulses `MergeSawShredPulse` so the local observer sprays tiny colored cubes.
- Land Sharks deploy as a tiered patrol (4/5/6/7) rather than a ten-model wall.
  Idle motion is a shared-strip wander (full bay width, only a few studs of depth) with an occasional
  porpoise. When a marcher enters the hunt strip, one shark leaves the wander, chases, grabs, and
  drags it under while biting on a pet-like cadence. The kill uses the `sink` death and extra
  `DeathSinkStuds` so the body disappears into the water. Combat is `hunt_drag` from
  `MergeBulwarkProgression.combatEffect`; shark kills do not stamp pet-kill credit.
  T3 adds a proximity venom cloud; T4 prefers an unclaimed boss and will not drop a drag.
- Bulwark menu art is flat, authored transparent art, not a live model viewport. Impaler Palisade,
  Concertina Line, Saw Blade, Grasping Hedge, and Wardstone Barrier all use the same long
  side-to-side presentation; Land Shark is the sole special case. The 24 source PNGs live under
  `assets/ui/merge_bulwarks/`, task provenance is recorded in
  `scripts/merge_bulwark_preview_sources.json`, and the group-owned Roblox Decal/Image IDs are
  recorded in `scripts/merge_bulwark_preview_ids.json`. The runtime card uses the Decal asset through
  `rbxthumb` because it preserves the authored alpha and resolves reliably without creating a
  `ViewportFrame`. Deployment remains separate: all five static families share the generalized
  anchor orientation, while only Land Shark is exempted in `MergeBulwarkModels.LONG_AXIS`.
