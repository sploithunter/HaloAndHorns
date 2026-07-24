# Summon the Creator — an allied NPC principal (design spec, DRAFT)

**Status:** proposed, not built. Jason 2026-07-24.

> "It summons essentially an NPC version of me with all of my best pets. All of my powers.
> Let's give it a 1,000-second recharge."

## What this is — and what it isn't

**Not the Colorado pet.** Not a guardian either. This summons an **NPC player**: a character
with a full squad of pets and a power kit, fighting beside you for the duration.

That distinction drives everything below, because guardians (`colossus`, `djinn`) are single
models expressing themselves through squad buff auras. This is a second *principal* on the
field — an entity that owns pets, casts powers, and holds aggro the way a teammate does.

## Why it's worth the bigger build

It isn't one feature, it's a **primitive**: "an allied NPC with a squad." Consumers already
visible:

1. **The Creator summon** — this power
2. **The prologue ally** ([[PROLOGUE.md]]) — the veteran fighting beside a brand-new player,
   with the TEMPORARY ALLIANCE banner up. One definition, two invocation sites: a power cast
   in the live game, a script call in the prologue
3. **Anything later** — mentors, escort targets, faction allies, boss adds

Jason's framing was that the summon "would solve the code path we're planning on using here
anyway." Correct, with the direction reversed: **this is the investment, and the prologue is
its second consumer.** That's the right order — the prologue stops being scaffolding and the
primitive earns its keep twice on day one.

## The Creator anchors a real alliance (Jason) — and this deletes the prologue special case

> "If we did it this way, then my level 50 Colorado would sidekick somebody to level 49 in
> whatever situation they're in. All of my pets could be there. We could basically immediately
> fire like Simoom or something that would armor and health them. We essentially become a team."

This is the keystone. If the Creator is a genuine **level-50 principal**, he can be the
**alliance anchor** — and the lift happens through the shipping `AllianceRules` path, not a
bespoke one.

`PROLOGUE.md` originally proposed a third `GetEffectiveLevel` branch (a `PrologueLevel`
attribute) precisely *because* NPCs can't anchor today: both existing branches resolve their
anchor with `Players:FindFirstChild(name)`. **Generalizing the anchor to a principal deletes
that special case** — one mechanism instead of two, and the prologue inherits the real thing
rather than a lookalike.

What falls out for free, in the live game as much as the prologue:

- Summon the Creator next to an underleveled friend → **they sidekick to 49** for the window
- His squad is on the field, so the fight is genuinely two-sided
- He opens with support — Simoom armoring and healing the player — which flows through the
  **existing** alliance support paths (`_withTeamPets` reciprocity, `CombatAllies`, summons
  covering allies). No new support plumbing.
- The TEMPORARY ALLIANCE banner comes up, because it *is* one

"We essentially become a team" is not a metaphor here — it's the same code path a real duo
runs.

### What the generalization actually costs

The `principal` abstraction now spans three places, not one:

| Seam | Today | Needs |
|---|---|---|
| Pet ownership | `_tick` over `Players:GetPlayers()`, folder keyed by player name | iterate registered principals |
| **Alliance anchor** | `Players:FindFirstChild(anchorName)` in both `GetEffectiveLevel` branches | resolve to a principal |
| Level lookup | `GetEarnedLevel(player)` — a profile read | `levelOf(principal)`: profile level *or* config level for NPCs |

Plus a sweep of everywhere an ally/anchor **name** is resolved back to a `Player` (the
`CombatAllies` consumers, `AllianceWith` publication, the enemy-rail team map). Bounded, but
real — and it is a refactor of live, recently-hardened teaming code.

## The firewall solves itself

§16.5 says player powers never deal direct damage — pets do. Guardians had to work *around*
this (buff-only identities: Colossus is a wall-plus-fist, Djinn is a fount).

An NPC Creator is firewall-compliant **by construction**: his damage comes from *his pets*,
exactly like a real player's. No special case, no carve-out. That's a strong signal the
abstraction is the natural one.

## Architecture: generalize "pet owner" from Player to principal

**The finding that sets the cost.** `PetFollowService:_tick` is:

```lua
for _, player in ipairs(Players:GetPlayers()) do
    self:_tickPlayer(player)
end
```

Player-keyed, and `workspace.PlayerPets/<name>` is keyed by player name. **An NPC's pet
folder would never be ticked** — no movement, no mining, no combat. There is currently no
NPC-with-squad precedent anywhere in the codebase, and no `HumanoidDescription` usage.

So the core work is generalizing the owner concept: `_tick` iterates **registered principals**
(players + live NPCs) rather than `Players:GetPlayers()`. Everything downstream already reads
the world folder directly (see the ghost-pet finding in [[PROLOGUE.md]]), so the pets
themselves need no change — only the driver's notion of who owns a folder.

Three seams, in rising order of unknown:

| Seam | Work |
|---|---|
| The character | Humanoid + avatar. Greenfield but standard Roblox. |
| The squad | **The real work** — owner generalization above. |
| The powers | `PowerService` casts are player-keyed. Either a principal context or a scripted rotation. |

The power seam is where I'd expect surprises; worth a spike before committing to "all of my
powers" literally.

## The loadout is authored, not live

"All of my best pets" should be a **static config snapshot**, not a read of Jason's actual
profile. Live-reading means depending on his data on a server he isn't playing on, it drifts
whenever he re-equips, it can't be balanced, and it leaks account state into other players'
sessions. Author "the Creator's loadout" in config and tune it deliberately.

## Balance

**1000s recharge** (~16.7 min) for a ~20s window. That is effectively *doubling the player*
for the duration — enormous burst — and the long clock is what makes it fair. It also lands
naturally in the established recharge-chase language: Hasten sits at 700s with perma as the
endgame goal, so 1000s makes recharge slotting a real, legible chase target here too.

## Sequencing — the decision that actually matters

This started as an 8-second cold open. It is now "generalize the principal abstraction across
pet ownership, alliance anchoring, and level lookup." That is a *better* system and the right
long-run architecture — but it is a much larger build, and it refactors teaming code that was
hardened and live-fixed only days ago, with an ad run imminent.

Two honest paths:

**A — Prologue first, principal later.** Ship the prologue on the cheap `PrologueLevel`
branch (~10 lines, no refactor), get it in front of ad traffic, let D1 decide whether the cold
open earns its seconds. Build the Creator principal properly afterward and retire the special
case then. Risk: one throwaway branch, and the prologue ally is a simpler NPC than the vision.

**B — Principal first, prologue after.** Build the abstraction, then the Creator summon, then
the prologue as its second consumer. Nothing is throwaway and the prologue is the real thing
on day one. Risk: the ad run either waits or goes out without the cold open, and a teaming
refactor lands right before/during the traffic spike.

**DECIDED: B (Jason, 2026-07-24).** The recommendation above was A; Jason overruled it and
was right. Recorded here with the reasoning, because the error is instructive:

> "We're just getting above 75% is a Band-Aid on a broken problem. We need to fix the
> problem. This is the fix. Implement it fully. Your own logic is contradictory."

It was. Three specific faults in the case for A:

1. **Same species of band-aid.** The argument against friend-voting the rating was "treat the
   cause, not the symptom." Shipping a degraded prologue to hit a date is the same move.
2. **It protected a schedule that isn't real.** The stated risk was "refactoring live teaming
   during a traffic spike" — but the ad run is returning ~4 plays per 16 credits. There is no
   spike. And the same analysis recommended *throttling* the spend, which frees exactly the
   time A was trying to save. Optimizing for a deadline while arguing to remove the deadline
   is incoherent.
3. **A isn't just internal debt.** Without the principal, the prologue ally has no squad, no
   powers, and can't anchor a real alliance — so no Simoom moment and no team feeling. That
   *is* the hook. A degrades the product, not only the code.

Build order is therefore: principal → Creator summon → prologue, with the ad spend throttled
until the cold open is in and the A/B can buy comparisons instead of anecdotes.

## Open questions

1. **Where the power lives.** Jason said natural origin, but geomancer's summon capstone is
   already `gaia_colossus` (guardian `colossus`, duration 20 — the same 20s). Options: a
   second natural pick, a high-level upgrade of the colossus slot, or — recommended — an
   **earned/special unlock** outside the origin pools, matching the established Creator-class
   fiction (dev-only, untradeable apex). A dev cameo is a story players tell each other when
   it's rare, and wallpaper when everyone runs it.
2. **Element identity.** `colorado` / `colorado_creator` are pinned to **lava** in
   `combat_fx` ("the Creator apex is a FIRE blaster"), but Colorado-the-state reads earth.
   The pet and the summon shouldn't drift — pick one.
3. **The model.** Recommend building from Jason's **real Roblox avatar** via
   `HumanoidDescription` off his userId rather than authoring a lookalike: zero asset work,
   always current, and "that's literally him" lands harder than a resemblance. It shifts when
   he changes his avatar — arguably a feature. (No `HumanoidDescription` usage exists in the
   codebase yet.)
4. **Powers: real or scripted?** Literally running his kit through `PowerService` vs. a
   scripted rotation. Depends on the spike above.
5. **Squad HUD.** Does the Creator's squad show on the rail, or only his own card? Related to
   the spawned guardian-HUD task — summoned allies currently render no cards at all.
