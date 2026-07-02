# Emergent Behaviors

Mechanics that fell out of systems interacting rather than being designed — kept
deliberately (or at least knowingly). Each entry records the behavior, the systems
that produce it, and the verdict, so a future refactor doesn't "fix" something
players actually experience as a feature.

## Dormant zones (2026-06-11)

**Behavior:** A zone the local player hasn't unlocked appears *asleep*: any ore lit
by a previous key-holder gets mined out or swept by the inactive-world despawn, and
nothing repopulates until a player with the unlock is present. New players walking
into a locked biome see a depleted, still landscape that visibly "wakes up" —
crystals blooming — when someone who's earned it arrives.

**Produced by:** BreakableSpawner's active-world rule (a biome only spawns ore
while at least one *currently present* player has it unlocked) + the per-miner
zone gate (PetFollowService:_mine / AutoTargetService refuse locked-zone nodes)
+ open world geometry (walking in is never blocked).

**Verdict:** Keeper. It conveys "this place has nothing for you *yet*" with zero
UI, and the effect concentrates in small/early servers — exactly where new players
live. Optional lean-in someday: faint mist / "dormant" ambience on un-lit zones via
the area theme config. (Jason: "that's actually could be an interesting game
mechanic... probably not super useful but still.")

## Window-shopping locked zones (2026-06-11)

**Behavior:** Locked zones are physically enterable — players can walk through
Ice/Lava/Desert before unlocking, see the terrain and (if another player has it
lit) the ore they can't mine. The unlock buys *profit*, not *passage*.

**Produced by:** Open world geometry (no barriers) + server-side enforcement
living at the payout (the mine gate), not the border.

**Verdict:** Keeper. Previewing the next biome is better marketing than a wall;
enforcement at the economic layer is also simpler and cheat-resistant. Watch-item:
whether silent mining refusal needs a "🔒 Unlock Ice Fields first" nudge.

## Pets herd the fight — push-away vs draw-toward, and the multi-tank spread (2026-06-14)

**Behavior:** Where pets STAND relative to their target (the attack ring's angle-0,
`configs/pet_follow.lua attack.combat_ring_zero`) silently decides whether the squad
*shoves enemies away from the player* or *pulls them toward the player* — and that
turns the player's own position into a tactical lever (walk an enemy into a corner,
funnel a pack through a choke). The current default (`toward_player`) makes a pet body
up between you and its target; the enemy backs to the far side to keep range, so the
squad **peels/shoves enemies away** — a bodyguard pushing the threat off you. The
unexpected twist: with **multiple tanks**, each shoves toward *its own* "away from
you" direction (every tank sits at a different angle), so the divergent pushes make
the fight **spread out and de-centre** instead of concentrating.

**Produced by:** anchored, non-colliding pets positioned every frame around their
target (`PetFollowController` + `PetFormation.attackOffset`), the ring oriented to the
player, AND enemies independently holding their own attack range around the pet
(`EnemyService` chase + `RingSeparate`). Neither side "pushes" the other — the herd
falls out of two range-keeping loops fighting over the same axis.

**Slot-0 is the tank's (2026-06-14).** The peel only works if the enemy's aggro-holder
— the TANK — owns the ring's slot-0 (the player-facing anchor); the enemy keeps range
from *its target*, so whoever the enemy chases decides which way it gets pushed. The
combat ring was originally size-sorted (smallest → slot-0, so huge pets take outer
slots — a *mining* aesthetic), which silently put a big tank like the Polar Bear in a
*far* slot and **inverted the peel into a draw-toward** ("the polar bear is driving it
at me"). It only ever looked right with a single pet (that pet *is* slot-0). Fix:
combat (enemy) rings now sort by ROLE first (`COMBAT_SLOT_PRIORITY`: tank→melee→control
→ranged→support) so the tank anchors slot-0 regardless of size; ranged/support fall to
the far slots they want anyway. Multiple tanks tie-break to the stable size/equip order
(no frame-to-frame swap). Mining rings keep the size-sort.

**Verdict:** Keeper, *and* the spread is treated as intentional friction. A full tank
team being too chaotic/uncentred to control is a FEATURE — it makes team composition a
real choice (don't free-stack tanks; mix roles). The opposite pole
(`away_from_player`) is exposed as a config flip — pets take the far side and DRAW
enemies toward you, so many pets all pull to one point (you) and the fight
**concentrates**. Left on `toward_player` for now (Jason); the flip is one config
value when we want the concentrating variant, and the two poles could later split by
role (tanks peel-away, dps draw-toward). The flip-side risk to watch: pets can pin an
enemy against a wall/tree and trap it (the map-clamp corner-pin) — fine as a tactic,
watch for unwinnable stalls.
