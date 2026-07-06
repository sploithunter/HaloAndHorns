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
