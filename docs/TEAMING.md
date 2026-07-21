# Teaming — fight together, heal each other's pets

**Goal (Jason, 2026-07-06):** 2 players team up, fight together, and support each other's pets;
build for 2, plan for 4. With 20–40 pets on screen, nobody can micro-target a teammate's pets —
so support casts route **through the player**: each teammate is ONE card with an aggregate
endurance bar, and a heal cast AT the card is redirected server-side to their most appropriate
pet. Enemy spawns must scale into **packs** sized by the fighting team — configurable, because
today's static spawns are tuned for one level-50 player with 10 pets.

## Pillars

1. **Team = the existing Party** (`PartyService`, max 4, session-scoped). Missing piece is the
   invite/accept handshake (remotes) + membership replication (player attributes `TeamId`,
   `TeamLead`) so every client can render the roster.
2. **Cast-through-player**: the client casts a support power with an optional `targetPlayer`.
   Server verifies same team, then resolves the actual pet(s) via the pure `TeamCast` core:
   - heal / heal_over_time → lowest endurance FRACTION, skipping downed
   - revive → downed pets
   - shield/absorb → the pet holding enemy aggro (tank first)
   - defense/offense buffs → whole teammate squad (same as self-cast squad scope)
   Aggregate bar (client-side): teammate endurance = Σ(max−taken)/Σmax over their
   `Workspace.PlayerPets[name]` — all attributes already replicate globally.
3. **Team HUD** (per the recorded layout decision): teammates on the RIGHT rail under your own
   squad — one strip-header player-icon card each (the `TEAM_SEL=-1` header pattern in SquadHud
   is the seed), aggregate endurance bar + downed count. DensityScale shrinks rails as the team
   grows. Clicking a teammate card sets `CombatBuffTargetPlayer` (a local attribute the hotbar
   Cast forwards); clicking your own header clears it.
4. **Pack scaling** (`configs/teaming.lua` + pure `PackScale`): when a spawner/patrol triggers,
   count = wave count × pack multiplier(f(team members engaged)), enemy HP × the existing
   `PartyMath.scaledHp` (`combat.group_scaling.per_extra_player`). All knobs in config; caps per
   tier so bosses don't multiply.
5. **Shared credit**: enemy `contrib` ledger already records per-pet damage; route kill
   XP/coins through `PartyMath.attribution`/`splitLoot` for teamed contributors.
6. **Battlefield principle** (Jason, 2026-07-07, CoH-style): a PLACED area effect is a
   battlefield entity, not a roster query on the caster. Anything friendly standing in it is
   affected — teammates AND strangers (friendly = any player's pets; player pets never fight
   each other). You can run around buffing/healing other people's squads without teaming.
   First application: the ground heal field (`_healZone` sweeps ALL of `Workspace.PlayerPets`
   radius-gated, not `_targetPets`). Every future positioned/radius support power (fields,
   auras, ground runes) must follow this; list-scoped squad buffs with no position
   (bastion-style) stay team-gated via `support_families`.

## Known blockers (scouted 2026-07-06, file:line in the scout report)

- `PowerService:_targetPets` (≈:610) resolves ONLY `Workspace.PlayerPets[player.Name]` —
  needs a `targetPlayer` parameter (team-verified) + TeamCast resolution.
- `EnemyService.SpawnEnemy` (≈:4842) never calls PartyMath.scaledHp; spawner waves
  (`configs/enemies.lua spawners`) have no size scaling.
- PartyService has no invite/accept remotes (comment marks them `[studio]`).
- `PlayerProgressionService:GetEffectiveLevel` (≈:157) has the sidekick/exemplar seam
  (sync to team lead) — DEFERRED, power axis only (task #150), not needed for v1.
- Loot credit stub: only the initial AggroOwner's player is paid today.

## Slices

- **TM1** pure cores + specs: `TeamCast.lua` (family → pet pick from replicated state),
  `PackScale.lua` (count/hp scaling from team size), `configs/teaming.lua` (+ ConfigLoader
  validator, same-commit rule).
- **TM2** server: Party invite/accept/leave remotes + `TeamId`/`TeamLead` attributes;
  `PowerService` support-cast redirect (`targetPlayer` in the Cast payload, team-verified);
  taunt/tank resolution stays owner-side.
- **TM3** spawns: spawner/patrol pack sizing + HP scaling via PackScale + PartyMath (engaged
  team members = party members inside the spawner radius), config-driven, admin
  `combat.spawnEnemy` gains a `packFor` arg for testing.
- **TM4** HUD: teammate strip cards (aggregate bar, downed count, click-to-target), team
  invite UI (nearby-player list on the team header), DensityScale shrink.
- **TM5** credit: attribution split for XP/coins on teamed kills.
- **TM6** live verify: Studio "Start Server + 2 Players" (the trade-escrow test rig):
  team up, cross-heal (watch the teammate's lowest pet's `CombatDamageTaken` drop), pack
  spawn doubling, both squads fighting one pack. Then commit each slice.

Screen density at 3–4 players: aggregate bars carry the info load; if pet clutter hurts,
follow-ups are FX distance-culling and nameplate thinning — NOT fewer pets.

## Status (2026-07-07): SHIPPED — live-verified two-account in the published game

All slices landed plus everything the verify shook out:

- Invite UI: TeamPanel (TradePanel framework) + ➕ on the squad-rail MY TEAM header; live
  TeamInviteFrom popup armed from boot. Duo = BOTH full squads on the rail (teammate pets as
  HudCard cards under their owner's header); 3–4 players collapse to aggregate cards that
  expand while selected.
- Mobile invite layout: TeamPanel is bounded to the live camera viewport and recomputes on
  rotation. Its header, hint, invite list, and teamed footer share one responsive layout contract,
  so fixed pixel bands cannot collapse the player list on a short landscape phone/tablet.
- Sidekick/exemplar: `GetEffectiveLevel` anchors members to lead + `sidekick.level_offset`
  (-1); PlayerBar disc shows the synced combat level (green up / orange down). EVERY
  EffectiveLevel consumer verified: accuracy/damage curves, layer access (= the guest pass),
  enemy SPAWN level, and both con-colour readers (rail cards + nameplates).
- Selection contract ("if you can select it you should be able to affect it"): world-click or
  card-click ANY player's pet → support casts land on it, teamed or not. support_families
  keys = REAL effect_kinds ids ("buff", not "damage_buff") + every lands-on-pets family
  (taunt/fortify/root_guard/evade/heal_blind). Taunt/rage resolve holders via _tauntHolders —
  redirected separately (bespoke-resolver gotcha). Slot-collision guard: a mate selection
  never slot-matches the caster's own squad.
- Battlefield principle: placed fields (heal zone) tick EVERY player's pets in radius; squad
  buffs (bastion) cover the whole TEAM via _withTeamPets; combat auras render on all clients
  for all owners (CombatAuraController watches every PlayerPets folder).
- TEAM BATTLE aggro: the engaged tick's leash/threat/valid scans iterate _teamSquads; neutral
  pets join teammates' fights; assist pick + _enemiesInRange cover team-engaged enemies.
- Shared kill credit: contributors ∪ teammates within kill_credit.radius of the down site.
- Known follow-ups: #244 (one badge reader + one target resolver everywhere), per-player
  EnemyLevelOffset on teamed spawns (currently the trigger player's setting), hasAggro
  introspection in TeamCast states.
- IDEA (Jason, 2026-07-07): **Teleport-to-teammate as a POWER** ("Recall Friend"-style), not a
  free HUD button — fits the perma-build power chase; gate travel convenience behind a pick.
  Complement: a find-teammate waypoint beacon (screen-edge arrow + beam, client-only) as the
  free tier. Teammate location line on the rail card shipped (CurrentArea).
- POSTPONED (Jason, 2026-07-07): **teams are capped at TWO for now** (configs/party.lua
  max_size=2) — the TeamPanel has no invite-while-teamed flow, so a third member was never
  reachable anyway; the config now matches the truth. The 4-player design when we pick it up:
  (a) invite from the teamed roster (not just the solo picker), (b) rail scaling — click a
  teammate's card to EXPAND their pet list while the other members' groups collapse to
  aggregate headers (SquadHud already collapses >2-member rosters and expands the selected
  mate, so most of the rail work exists; the missing piece is the invite flow + polish).
- TEAM FOLLOW shipped (Jason, 2026-07-07): any member auto-follows any teammate (not just the
  lead). Client `TeamFollowController` walk-follows via Humanoid:MoveTo; ANY manual movement
  input (WASD or mobile joystick, via the PlayerModule move vector) breaks it. Toggle = follow
  chip on the SquadHud mate card (mobile-first, lights green while active) or F with the
  teammate selected. REALM PORTALS: on a CurrentLayer mismatch the client requests
  `team.follow_warp` — PartyService:FollowWarp re-runs the portal's own gates (geometry +
  requires_level vs EffectiveLevel) then LayerService:UseLayer, landing at the realm entry as
  if the follower touched the portal. Never a same-layer teleport, so the teleport POWER idea
  above keeps its value; knobs in configs/teaming.lua `follow{}`.

## The Farming Pass (2026-07-09)

Jason: "the game was meant to have two paths of success" — combat teaming multiplied
rewards (kill credit) while mining SPLIT them. Closed:

- **Team mining bonus** (`teaming.mining.team_payout_mult`, 1.2): the proportional
  contribution split stays; a contributor whose TEAMMATE also contributed to the same
  node gets their share multiplied. Duo even-split = 60% each; with two squads clearing
  ~2x faster that's ~120% coins/min per player vs solo. Zero-contribution bystanders
  earn nothing — farming has no combat danger to gate leeching, so contribution IS the
  anti-leech.
- **Shared economy auras** (`teaming.mining.economy_auras_shared`): a teammate's yield
  (CoinYieldBuff) and hatch-luck (HatchLuckBuff) buffers benefit the whole team, folded
  CONSUMER-side (BreakableSpawner / EggService) as extra BuffStack/luck sources — two
  owners' auras never clobber one attribute, same axis caps apply.
- Sidekick guest pass: realm portals now gate on EffectiveLevel (same as follow_warp and
  LayerService) — a boosted teammate travels at their sidekicked level.
- Hybrid follow: straight-line MoveTo + no-progress watchdog -> client pathfinding with
  jump labels; drops back to direct on line-of-sight (TeamFollowController).
- Parked: team nodes ("boss crystals" — farming's raid moment, waiting on the map pass);
  mining payout level-scale reads EffectiveLevel when that seam activates.
