# Combat Tutorial

Last checked: 2026-09-05

2026-09-06 Merge progression revision: Basic is now optional for Merge progression. Wave 6 grants
an earned Level-2 floor and unlocks manual Powers-menu claims; Full pets are eligible at Level 2,
and personal hatch inventory no longer requires a course. Wave 10 teaches two slots, Wave 12 an
enhancement, and Wave 14 introduces the Quartermaster without a required interaction. The old
persistent Basic reminder is disabled in Merge. All three optional courses retain their existing
once-only capped level/token rewards. The wave lessons use separate `GameData.MergePowerLessons`
receipts and never set `CombatTutorial.done`. See [Merge onboarding](MERGE_EGG_PROTOTYPE.md#wave-paced-power-onboarding-2026-09-06).

## Current: three independent courses

`configs/combat_courses.lua` projects the canonical lesson catalog below into:

- **Basic Combat Training**: `ready` through `advance_heal` (14 steps). The Heal pillar exits
  immediately and permanently unlocks pets/powers through `CombatTutorial.done` and
  `CombatTutorialDone`. Each newly completed course grants one **earned** level, capped at 50;
  Ascension/power choices remain manual. Basic keeps the existing coin/potion bundle.
- **Advanced 1**: Weakening and brew stacking (9 steps), one Double XP consumable token.
- **Advanced 2**: tanks, enemy healers, and the combined finale (10 steps), one Double Coins
  consumable token. These are existing `configs/items.lua` tokens, not automatically activated.

Advanced courses are optional and sequential. Cave/Quartermaster interaction opens the explicit
course selector after Basic; neither course is automatically launched or covers the normal pet UI.
The Merge instruction bar persists beyond Wave 10 while Basic is required, then disappears when
Basic is complete or existing full-pet eligibility already applies. It never advertises Advanced
1/2 over unlocked controls.

The custom Players list collapses once when `InCombatTutorial` becomes true (all three courses),
clearing the pet HUD. Players may expand it manually during training. Exit restores the previous
outside-training expanded/collapsed state; entering while the controller starts is also handled.

Persist `CombatTutorialAdvanced1`, `CombatTutorialAdvanced2`, `CombatCoursesVersion`, and a
`<progressKey>RewardGranted` receipt per course. `CombatTutorial` remains Basic's compatibility
receipt. A fixed `completionLevelTarget` and independent level receipt prevent repeated +1 awards
on retries. Token delivery requires an inventory UID before its receipt; missing service/failed
delivery retries on subsequent progress reads. `RewardService` is now an explicit boot dependency.
Replays use `CombatTutorialReplay`, never reset Basic or advance course rewards. Selection is
per-player; immutable projected configs are not swapped globally. Entry is guarded against repeated
requests. Existing v11 progress is split at its real lesson boundary. Historical graduates keep
credit but do not mint new advanced rewards; old Basic level-2 top-ups still retry.

Swift Tonic now closes 85% of its meter per sip, with +100% movement at full charge and a
60-second full-charge drain. First sip gives +85% movement to both player and pets, subject to
the existing shared +100% movement cap and other buffs. `Eff_Speed` drives character WalkSpeed;
pet movement consumes the same potion source. No extra speed lesson was added.

Tests: `combat_courses.spec.luau`, `scripts/studio/test_combat_courses.luau`, and the handoff
smoke execute boundary, migration, capped rewards, retry/reentrancy, replay, and concurrent-profile
cases. Studio client checks cover menu rendering and the persistent Basic reminder/unlocked state.

**Historical context below:** references to a single 33-step course, final-pillar Level-2 floor,
Skilled backfill on Basic completion, or Redo-only entry describe the pre-split implementation.
Lesson content/mission/squad contracts still apply; the course rules above supersede those claims.

2026-09-05 grant correction: the boot registration now includes the feature-gated
`PlayerProgressionService` dependency. ModuleLoader injects only declared dependencies; having
progression loaded elsewhere did not populate Combat Training's `_modules`, so its Level-2 grant
was perpetually deferred. Existing completed saves with no grant receipt retry via `_ensureProgress`
on join/state refresh. This tops up earned XP, not the manually claimed Ascension/power choice.

2026-09-04 handoff correction: `InCombatTutorial` stays true until the loaned squad is removed,
the original squad is restored/recovered, and tutorial loops are stopped. Leave is reentrant-safe.
Merge listens for both mission-close and tutorial-restored readiness; it no longer resumes after
an arbitrary timeout while restoration is unfinished. The live `CombatTutorialDone` receipt also
releases the peaceful level-5 combat onramp (config-owned), including graduates still at Level 2.
Base pickup reach is 20 studs in `configs/drops.lua`, available before completing any tutorial.
Regression: `scripts/studio/test_combat_tutorial_handoff.luau` executes the production methods with
isolated doubles in Edit; it never changes player saves or the authored map.

2026-09-05 return-order correction: mission close keeps `InMission` until the streaming-safe
return warp finishes, or cancels the pending warp at the existing close deadline before clearing
that attribute. Previously Merge could rebuild the player's bay first, then a late mission warp
would move them to their old entry position (potentially another player's newly claimed bay).
Merge still prefers the original bay and falls back to an available bay if occupied. The final
Merge placement now happens after the old warp, not in a race with it. Regression:
`scripts/studio/test_combat_training_return_order.luau` runs the production close/resume methods
with delayed, timed-out, errored, and character-less returns, with both bay-availability cases.

Live Homeworld combat beat (`configs/tutorial.lua` v6). After Resonance is
bound, cast, and enhanced, `first_fight` points the FIGHT trail at the
Earth cave. **Later** on that card opens the Okay banner and parks Combat
Training in Quest. Finishing the cave still advances to Rally.
That cave no longer fields ambient waves (`enemies.spawners.bindings.Earth.disabled`).
The combat-training loop (lobby → ENTER → fight → pillar) runs in a
mission-slot instance. The last pillar warps them back to the cave mouth and guarantees a floor of
earned Level 2: a player below Level 2 receives only the exact missing XP, while a player already at
Level 2 or higher is unchanged. This grant has its own persisted receipt and retries independently
of the one-time currency/potion reward. Homeworld then continues with Rally. Progress is
`profile.CombatTutorial` — never a ProfileStore template field.
Completing this track independently unlocks Ascension even when the crystal/Homeworld tutorial is
unfinished; completing either tutorial is sufficient. Combat Training completion is also the
universe-wide competency receipt for onboarding: a player who finishes it in Merge Defense is
marked complete for the Farm & Fight introduction on arrival, and a stale Combat Training quest
focus yields to First Steps instead of assigning the cave again. The cave remains available only as
an explicit optional Redo.

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
there. **Later** parks that pointer on the Combat Training quest after
Okay. Walk straight in unless `CombatTutorial.done` — only a finished
cave asks **Redo / Not now**. Homeworld `Tutorial.done` is not enough
(admin reset and grandfather leftovers were showing Redo on a new run). E opens a `combat_tutorial` mission
slot on the far-X band (`missions.slots`: 10 concurrent, 3072 studs
apart at x=24000) — the same pool as Range / Training Ground. Realm
layers already own vertical stacking, so instances go sideways, not up.
The frost door has two **SurfaceGuis** (front and back of the seal): the
lesson plate (SET HEAL FIRST / ENTER) and **Continue later**. No camera
Billboard and no door E prompt. Continue later confirms: **Your progress
is saved. Come back anytime.** Arena fights and the pillar hide leave.
Click the lesson plate to continue or nudge. Progress is kept
(`leave_resume` on mid-fight disconnect still applies). The Hall arch is
**not** an entry.
`restart_on_enter` is off so an unfinished cave visit keeps progress.

Merge Defense exposes the same entry boundary from its Quartermaster after the Wave-10 introduction.
This is not a shortened Merge lesson: `CombatTutorialService:OpenForPlayer` opens the same
`combat_tutorial` mission id, progress record, redo confirmation, loaned squad, rewards, and exit
flow described here. Merge checkpoints and releases the active bay before the mission opens so its
owned pets cannot overlap the loaned squad; when the mission completes or is left, Merge claims an
available bay and reconstructs the saved playstate. The Quartermaster menu labels unfinished saved
progress as Resume and completed progress as Redo.
The Merge shell suppresses only the Homeworld tutorial card so it cannot overlap the wave meter.
While `InCombatTutorial == true`, the Combat Training state owns that card and its world/UI cues;
the place-level Merge suppression must yield to the mission directions.

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
  starts fresh. The pillar E is one reused `CombatTutorialAdvancePrompt`
  (same idea as Range / Training Ground's one `MissionCompletePrompt`).
  Tutorial missions do not also get Next Room. Clicking a People-list
  row opens the slide-out; that card explains which Combat Training
  pillar granted the title.
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
  on 27/33 with a stacked pack.
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
`CombatRank` / `CombatRankLabel` / `CombatRankEarned`. Admin reset
clears those and the worn `StatusBadge` pick so the chip chooser is
empty Training again. First earn plays the crest (keyed PNG
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
On first entry, the tutorial grants one low-level natural Healing enhancement. The `entry` receipt
in the normal tutorial grant ledger makes this idempotent across reconnects and repeat visits.

9. `enhance_heal` — lobby; reuse the five-click Farm & Fight enhancement flow:
   Powers → Heal → empty slot → Healing → Apply. The step ensures an inherent Heal slot for the
   compatible level-3 Healing enhancement received on entry, and advances only for an
   `enhancement_slotted` event whose configured context is `powerId = "heal"`.
   Existing v10 test saves keep their later position; reset-to-beginning exercises
   the new lesson from a clean track.
10. `ready_heal` — ENTER (same shared door checklist: pets equipped, not editing)
11. `select_pet` — two shielded dogs; one live pet is wounded to the yellow
    bar (`wound.remaining_fraction`); click that injured card. `CLICK HERE`
    sits to the left of that card's health bar.
12. `cast_heal` — press Heal; **drop shields** so the dogs become killable
13. `heal_fight` — defeat both training dogs (`combat_tutorial_room_cleared`).
    The pillar stays dark; the inner door reseals so they cannot leave yet.
14. `advance_heal` — pillar after the room is clear
15. `ready_weaken` — lobby; grant two Weakening Vials; ENTER
16. `select_enemy` — two shielded dogs; click the marked enemy card. Enemy-card
    cues are forced into `TutorialCueOverlay` so MissionMap cannot cover them.
17. `throw_weaken` — throw Weakening Vial; **drop shields**
18. `weaken_fight` — defeat both training dogs (`combat_tutorial_room_cleared`).
    Same as heal: the pillar stays dark until the room is clear.
19. `advance_weaken` — pillar after the room is clear
20. `stack_brew` — grant ten Berserk Brews; drink at least five (capsule `n / 5`).
    Sips fill the damage meter; `drain_seconds` stays 60. The frost-door plate
    counts down: DRINK FIVE MORE → FOUR → THREE → TWO → ONE. Extra sips
    shake the badge and leak a barely-contained halo (`BrewJuice`).
21. `ready_stack` — ENTER. `ensure_meter` refreshes the Berserk pie so lobby
    sipping is not wasted by the walk in.
22. `stack_fight` — 400 HP dog (was 900). Five sips are ~2.4× damage, so this
    should die faster than the 275 HP dogs, not slower. Three doggies, not a tank.
23. `advance_stack` — pillar
24. `ready_tank` — reset to three doggies, then walk inventory: open Pets, take
    off the last/weakest doggy, click the strongest tank (or Best Pets → Tank,
    which may replace the weakest on a full squad), Activate (Pets closes), ENTER.
    Inventory card cues use `TutorialCueOverlay` (DisplayOrder 130, same inset
    as MenuOverlay) so the same on-top sign is not clipped by `ItemsScroll`
    and does not float a topbar-height above the card.
    Door stays sealed until `squad_has_role` tank. Other pets stay legal.
25. `tank_fight` — soak-and-finish
26. `advance_tank` — pillar
27. `ready_healer` — ENTER
28. `healer_hunt` — Training Healer (`rabid_bunny` + `auto_heal`) plus two dogs.
    The healer card wears the game-wide green heal mark at the end of its bar.
    Completes only when that healer dies. `KILL THIS` hides after the first
    click **or** when pets already have that healer (`TargetID`). A click
    pins the squad on that healer (assist + wipe other pet threat) so dogs
    cannot peel them off. It returns only when live pets leave a still-alive
    healer, not when the healer dies (the card is gone — do not ask for
    another click). HUD assist expiry is not a miss.
    `KILL THIS` uses the same forced overlay as the earlier enemy-card cue.
29. `healer_fight` — finish the remaining dogs (`combat_tutorial_room_cleared`).
    The pillar stays dark; the inner door stays sealed. A stuck-disengage
    despawn that never fires `enemy_defeated` still clears the room once no
    tutorial enemies are left.
30. `advance_healer` — pillar after the room is clear
31. `ready_together` — grant extra vials/brews; ENTER
32. `together_fight` — two unshielded dogs + a healer, **no click arrows**.
    An easy clear (`combat_tutorial_room_cleared`).
33. `advance_together` — pillar; this last advance marks the track **done**,
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
that window and restores the Homeworld capsule on leave. On the client, the same attribute overrides
the dedicated Merge-place visibility gate so the mission cannot load without its direction card.

## Power catalog handoff

Heal and Resonance both belong to the shared NATURAL catalog as innate, slottable powers. The Power
Choice menu applies `PowerAvailability` before rendering that catalog: Heal is hidden until Combat
Training begins, Resonance is hidden during Combat Training, and unlocked Heal remains available in
both Merge Defense and Farm & Fight afterward. Innates are server-rejected as level-up selections,
so neither power consumes a pick. `PowerService:IsPowerOwned` is the authoritative ownership query
for picker state, casts, level-grant slot commits, and augmentation placement; do not reconstruct
ownership from `profile.Powers`, because innates deliberately do not live in that selected-power list.
