# Combat Tutorial

Last checked: 2026-08-25

Live Homeworld combat beat (`configs/tutorial.lua` v6). After Resonance is
bound, cast, and enhanced, `first_fight` sends the player into the Earth cave.
That cave no longer fields ambient waves (`enemies.spawners.bindings.Earth.disabled`).
The combat-training loop (lobby → ENTER → fight → pillar) runs in a
mission-slot instance. The last pillar warps them back to the cave mouth, grants earned
Level 2, then Homeworld continues with Rally. Progress is
`profile.CombatTutorial` — never a ProfileStore template field.

## Live-save grandfather

Cave enter did not exist in tutorial v1–v5. The old combat start was
`first_fight` (defeat an enemy): v1/v2/v4 step 5, v3/v5 step 8.

- Not there yet (hatch through Resonance, or `first_fight` with no kill):
  they stay on Homeworld. Cave E is always available; this path walks
  straight in.
- Already scored that beat (old first_fight count, brew, Rally, or a
  `tutorial_first_fight` milestone): Homeworld is marked done. Heal and
  Rally are bound so they cannot stick waiting for `combat_tutorial_complete`.
  Live `enemies_defeated` does not count — stray Homeworld kills were
  completing a fresh first_fight and hiding the cave E.
- Already complete (including veteran skip): Heal is unlocked and bound.
- A live `CombatTutorial` save is the new track and is left alone.

## Entry

The Earth cave mouth (`Maps.Home.EarthLair`) always shows **Press E to
Enter** (gamepad X). Homeworld `first_fight` points the FIGHT beacon
there. Walk straight in unless `CombatTutorial.done` — only a finished
cave asks **Redo / Not now**. Homeworld `Tutorial.done` is not enough
(admin reset and grandfather leftovers were showing Redo on a new run). E opens a `combat_tutorial` mission
slot on the far-X band (`missions.slots`: 10 concurrent, 3072 studs
apart at x=24000) — the same pool as Range / Training Ground. Realm
layers already own vertical stacking, so instances go sideways, not up.
The frost door (or the lobby pad if the seal is down) has **Continue
later** (E / gamepad X) after a short landing grace so cave-enter E
cannot bounce them out. Confirm: **Your progress is saved. Come back
anytime.** Arena fights and the pillar do not show it. The door plate
stays the lesson (SET HEAL FIRST / ENTER) — click continues or nudges;
E leaves. Progress is kept (`leave_resume` on
mid-fight disconnect still applies). The Hall arch is **not** an entry.
`restart_on_enter` is off so an unfinished cave visit keeps progress.

## Mission

- Training Ground Room 1 maps: `ChallengeRun.layoutContext(1, "combat_tutorial")` → `train#1`
- Same gray-box kit as Heaven/Hell trials. Open stamps `theme = grass`
  (Earth-cave palette — `earth` has none). Lobby beats repaint the kit
  through the trial skins: grass → lava → heaven → hell → desert → ice
  → heaven → grass. Decor matches trial density (wall hangings, props,
  showpieces); crates are not farmable.
- `seed_policy = "gauntlet_room"`, one room, `skip_engage_gate`, `persist_runs = false`
- No auto-population, no clear-then-beacon monitor, no ChallengeRuns persist
- Rhythm is **lobby → ENTER door → fight → pillar back to lobby**. The frost
  ENTER plate only opens when the current step is a ready/enter beat **and**
  every row in the door `unlock_when` checklist is true. Ready beats alternate
  READY / ENTER; blocked lobby beats stamp the first missing action (DRINK FIRST,
  SET HEAL FIRST, PRESS DONE, EQUIP PETS) and a click fires
  `combat_tutorial_door_blocked` (banner nudge). The pillar
  (`return_to_lobby`) warps to the lobby `SpawnPad` / PlayerSpawn hook and
  reseals the door. Same map — no gauntlet restamp. Lobby return
  (`refresh_on_lobby`) clears Heal/Revive cooldowns, pet recovery clocks,
  res-sickness, lockouts, sip locks, and refills Focus so the next room
  starts fresh.
- `restart_on_enter = false`: cave visits keep `profile.CombatTutorial` so the
  live funnel can continue.
- Arena packs spawn on the objective-room `MissionSpawn` part (found by name +
  `ObjectiveRoom`). The stamper hook table does not include that part.
- `pack_cap` is hard: one healer and at most three other pets, pinned at
  `enemy_level = 1`. Player level and leftover rooms cannot field a second
  healer. Each spawn despawns this player's tagged leftovers through
  `EnemyService` (not `model:Destroy()`), sweeps the mission AABB, then
  culls any live extras. Admin reset-to-beginning wipes
  `profile.CombatTutorial` and leaves the instance so testers do not stay
  on 26/32 with a stacked pack.
- Mid-fight leave (`leave_resume`) rewinds only to that loop's lobby so
  brew / Heal / tank / vials can be prepped again. It does not restart
  the track. Pillar steps keep progress. Each completed combat beat fires
  `tutorial_step_completed` as `combat_<id>` into the onboarding funnel.

## Combat ranks

Eight Halo-flavored titles, one per finished fight loop, granted on the
pillar (`advance_*`) — never on a lobby sip. Current rank only. Not a
public leaderboard and not stacked `GrantTitle` strings.

| Pillar | Rank |
|---|---|
| `advance_stage` | Spark |
| `advance_brew` | Kindled |
| `advance_heal` | Warden |
| `advance_weaken` | Hexed |
| `advance_stack` | Surge |
| `advance_tank` | Bulwark |
| `advance_healer` | Hunter |
| `advance_together` | Skilled |

Persist `GameData.CombatRank = { current, earned }` plus attributes
`CombatRank` / `CombatRankLabel`. First earn plays the crest (keyed PNG
→ fly to a chip left of the People list + nametag). The lobby warp waits
for that fly so the frost **ENTER** door is the continue path. Lobby
**Leave** exits with progress kept; cave E resumes the same step. Redo is
silent. `CombatTutorial.done` backfills **Skilled** with no ceremony.
Admin reset-to-beginning clears the rank. Config: `configs/combat_ranks.lua`.
Later tutorials can replace the current title.

## First slice

Each taught tool is its own lobby → ENTER → fight → pillar loop.

1. `ready` — lobby; frost door sealed; ENTER
2. `first_fight` — one weak Training Dog in the arena
3. `advance_stage` — pillar; warp to lobby and reseal
4. `battle_brew` — lobby; drink Berserk Brew (door stays sealed). The
   first sip glows the badge and puts a fire aura on the player and pets.
5. `ready_brew` — ENTER
6. `brew_fight` — one weak dog
7. `advance_brew` — pillar; warp to lobby and reseal
8. `bind_heal` — lobby; bind innate Heal. Heal is withheld on Homeworld
   (`hidden_while.until_combat_tutorial`) so the early Resonance bind has
   one power and Heal cannot auto-land on the bar. The first combat-training
   enter unlocks it for good (`CombatTutorialHealUnlocked`, not wiped by
   `restart_on_enter`). Resonance is withheld for the whole combat-training
   mission (`hidden_while.in_combat_tutorial`) so the picker only offers Heal
   and the bind arrow points at Heal. Completes only when the step
   `unlock_when` list is all true: at least one pet equipped, Heal on the
   saved bar, and the hotbar **not** in edit mode (Done). Named checks live
   in `src/Shared/Game/TutorialUnlock.lua`.
9. `ready_heal` — ENTER (same shared door checklist: pets equipped, not editing)
10. `select_pet` — two shielded dogs; one live pet is wounded to the yellow
    bar (`wound.remaining_fraction`); click that injured card. `CLICK HERE`
    sits to the left of that card's health bar.
11. `cast_heal` — press Heal; **drop shields** so the dogs become killable
12. `heal_fight` — defeat both training dogs (`combat_tutorial_room_cleared`).
    The pillar stays dark; the inner door reseals so they cannot leave yet.
13. `advance_heal` — pillar after the room is clear
14. `ready_weaken` — lobby; grant two Weakening Vials; ENTER
15. `select_enemy` — two shielded dogs; click the marked enemy card
16. `throw_weaken` — throw Weakening Vial; **drop shields**
17. `weaken_fight` — defeat both training dogs (`combat_tutorial_room_cleared`).
    Same as heal: the pillar stays dark until the room is clear.
18. `advance_weaken` — pillar after the room is clear
19. `stack_brew` — grant ten Berserk Brews; drink at least five (capsule `n / 5`).
    Sips fill the damage meter; `drain_seconds` stays 60. The frost-door plate
    counts down: DRINK FIVE MORE → FOUR → THREE → TWO → ONE. Extra sips
    shake the badge and leak a barely-contained halo (`BrewJuice`).
20. `ready_stack` — ENTER. `ensure_meter` refreshes the Berserk pie so lobby
    sipping is not wasted by the walk in.
21. `stack_fight` — 400 HP dog (was 900). Five sips are ~2.4× damage, so this
    should die faster than the 275 HP dogs, not slower. Three doggies, not a tank.
22. `advance_stack` — pillar
23. `ready_tank` — reset to three doggies, then walk inventory: open Pets, take
    off the last/weakest doggy, click the strongest tank (or Best Pets → Tank,
    which may replace the weakest on a full squad), Activate (Pets closes), ENTER.
    Inventory card cues use `TutorialCueOverlay` (DisplayOrder 130, same inset
    as MenuOverlay) so the same on-top sign is not clipped by `ItemsScroll`
    and does not float a topbar-height above the card.
    Door stays sealed until `squad_has_role` tank. Other pets stay legal.
24. `tank_fight` — soak-and-finish
25. `advance_tank` — pillar
26. `ready_healer` — ENTER
27. `healer_hunt` — Training Healer (`rabid_bunny` + `auto_heal`) plus two dogs.
    The healer card wears the game-wide green heal mark at the end of its bar.
    Completes only when that healer dies. `KILL THIS` hides after the first
    click **or** when pets already have that healer (`TargetID`). A click
    pins the squad on that healer (assist + wipe other pet threat) so dogs
    cannot peel them off. It returns only when live pets leave a still-alive
    healer, not when the healer dies (the card is gone — do not ask for
    another click). HUD assist expiry is not a miss.
28. `healer_fight` — finish the remaining dogs (`combat_tutorial_room_cleared`).
    The pillar stays dark; the inner door stays sealed. A stuck-disengage
    despawn that never fires `enemy_defeated` still clears the room once no
    tutorial enemies are left.
29. `advance_healer` — pillar after the room is clear
30. `ready_together` — grant extra vials/brews; ENTER
31. `together_fight` — two unshielded dogs + a healer, **no click arrows**.
    An easy clear (`combat_tutorial_room_cleared`).
32. `advance_together` — pillar; this last advance marks the track **done**,
    warps them back outside (`return_to_exit`), grants earned Level 2, and
    fires `combat_tutorial_complete` so Homeworld can teach Rally.

## Unlock checklist

Door and lobby-lesson unlocks are an AND-list of named checks in
`src/Shared/Game/TutorialUnlock.lua`. Config rows point at those functions:

- `pets_equipped` — at least `count` live equipped pets (default 1)
- `squad_full` — every slot in `1..maxSlots` is filled
- `squad_has_role` — at least one equipped pet has that `pet_roles` role
  (for later tank / healer lessons)
- `hotbar_bound` — saved bar has `{ type, target }`
- `hotbar_not_editing` — `player.HotbarEditing` is not true (client reports
  via `Hotbar_EditMode`; you cannot click a power while editing)

The first failed row stamps `fail_plate` on the door and uses `fail_nudge`
as the blocked-click banner. Later lessons add rows; they do not invent a
new door path.

## Battle music

`AreaMusicController` swaps to `combat_music` while `player:GetAttribute("InCombat")`
is true — the same engaged flag overworld fights use. That flag is derived from
pet-side threat (`engage_floor`), not from `InCombatTutorial`. The Training Dog
only deals 1 damage, which cannot hold the floor against decay, so a connected
pet swing (including an absorb on a shielded dog) is what starts the track.

## Shields

Heal-room shields exist only so the player must Heal first. After the correct
pet is healed, those shields drop and they have to defeat the training dogs
before the pillar lights. Debuff-room shields stay until Weakening Vial; after
the throw they still have to finish the dogs before the lobby breadcrumb.
Room-clear does not fire on an empty scan — the service counts the spawned
pack and waits until those enemies are defeated.
`CombatApplication.ApplyDamage` soaks `dune_shield` / `CombatShield`. Spawn
stamps `CombatTutorialShielded` only on teaching dogs; the mark loop
re-applies that lock. Finale dogs use `absorb` → `combat_shield` (400 / 12s,
same as a pet Dune Shield) once. Do not invent a protected / min-HP flag.

## Loaned starter pets

On enter, `CombatTutorialService` snapshots `Equipped.pets` into
`profile.CombatTutorialLoadout` (not a ProfileStore template field) and
temp-grants **three** of each starter common: bunny, doggy, bear, kitty.
Those are real inventory stacks, so Inventory can mix a 3-slot squad
(three bunnies, three kitties, or any mix). `loaned_squad.equip` starts
them on **three doggies** so early fights show melee damage (a pre-equipped
bear made stacked Berserk look weak). The tank lesson runs `reset_squad`
back to those three doggies, then asks for a bear. This is not the Range
GhostPet catalog.
While `InCombatTutorial`, Inventory shows every bunny / doggy / bear / kitty
(any variant) and hides other species. The squad strip still shows the live
equipped list; the filter does not rewrite it. No server deny list.

On leave, disconnect, or a later join that still has the loadout, the
grant quantities come off, the saved equipped list is restored, down
slots clear, and the original squad respawns / recovers. XP and items
earned inside stay. `restart_on_enter` does not wipe `CombatTutorialLoadout`.

## Ownership

`CombatTutorialService` owns `Signals.TutorialState` only while
`player:GetAttribute("InCombatTutorial") == true`. `TutorialService` skips push/advance in
that window and restores the Homeworld capsule on leave.
