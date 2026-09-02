# Current Status

Status: current (repo = `sploithunter/HaloAndHorns`, fresh single-commit start 2026-07-02; history + alpha issues live on the predecessor `sploithunter/RBX-Template`)

## Merge tier art is config-owned and runtime-verified (2026-09-01)

`configs/merge_tier_art.lua` is generated from the committed cannon-model, cannon-preview,
bulwark-model, and bulwark-preview manifests. It is the single runtime authority for both workshop
previews and spawned model identity. Cannon cards use 24 group-owned 256×256 transparent Image
assets normalized to a 78% silhouette footprint rather than model thumbnails or live
ViewportFrames. `scripts/merge_tier_runtime_manifest.json` proves 24 cannon mappings, 24 cannon
preview mappings, 24 bulwark mappings, 24 bulwark preview mappings, and 48 distinct model assets.
The cannon pipeline generator also owns and round-trips each tier's world scale, wheel seating, and
the Rage Tier-1 barrel yaw, so its deep local-source audit cannot erase or falsely reject runtime
presentation tuning.
Fresh Studio Edit and Play audits passed
all 48 templates, all 48 transient runtime clones/spawns, and fail-closed rejection of a deliberately
stale model ID. Existing world instances are replaced when their manifest identity or cannon scale
does not match, rather than trusting tier attributes alone.

## Artillery Commander workshop (2026-09-01)

SploitHunter stands behind each pad. Talk opens an artillery workshop
that matches the bulwark panel (six roles, unlock / upgrade / install).
Unlock is global and one-time; each commander places and upgrades
only that pad. Pads start empty and keep their own tier. The
workshop shows LOCKED until that family is unlocked — the catalog
is not granted for free. Currently Owned and Next Upgrade use that
family/tier's config-owned transparent preview image. The 24 previews
are normalized flat PNGs; the menu does not clone live models, create
ViewportFrames, or depend on Roblox's arbitrary model-thumbnail camera.
Playtest unlock/place/upgrade are one
Waycoin each. All six families use distinct Tier 1–4 models. Each of the 24
cannon entries has its own `worldScale` (0.375 on every Tier 1,
0.5 on Tiers 2–4). Every chassis uses `seatOffsetY` so wheels sit
on the pad (0.55 at T1, 0.733 at T2–4). Rage T1 has
`barrelYawDegrees = 270`; Debuff T3/T4 use 90 so their local +Z barrels align
with the common local +X ballistic basis. Gameplay
tier selects the matching
prebaked template, then spawn applies that entry's presentation.
Board-action toasts sit above the workshop
(DisplayOrder 130). Install writes `MergeCannonPersist` only — no
wave/MergeDefense signature compare. The `CANNON STATE CHANGED`
toast was that compare; it is no longer returned. Bulwark install
is the same cut (`MergeBulwarkPersist`). Egg create/merge already
mutated the board without that compare. Waves stay start → result
→ optional pause → start. Headless covers both persist modules.
The tier-art menu/template/clone path is Play-confirmed; cannon combat behavior below is not.
Heal aims injured pets (`CombatDamageTaken` or `HP`/`MaxHP`,
including the player's real pets) and places the existing Healing
Field at impact (same rune and ticks; no rebuilt visual). Heal tiers
only change magnitude and fire interval; `hot_tick` stays 2s. Rage
fires at one ally already in combat (`TargetType` Enemy or
`AggroTargetRef`) and drops a one-time ruddy MagicCircle; that pet
and any other ally inside the radius each get their own Berserk
stamp (`SipBrewOn` on the model, existing stack math, no ticks). No
idle-pet or empty-lane shot. Pets outside the circle are not buffed. Flask
drink still broadcasts from the player. Floor cards read the pet
stamp (`damage_potion_pet`); CombatAura watches the pet Until. Not
Play-confirmed. Rage tiers only change fire interval and circle
size. Rage T1 circle is 7 studs (T2–T4 stay 28); the rune and
the sip share that radius. Cannons never fire at a target on the egg side
of BreachLine. Heal and Rage use that same floor for now; bulwark/mid stay
tunable. Debuff sips Weakening Vial on enemies (Rage's sibling).
Gravity pulls into a black-hole rune. Repulsor is a concussion
blast (CombatFX lava detonation, no magic ring). Fling is radial
from impact so the pack spreads; each enemy rolls hit_chance
(T4 40%) so a 2.4s T4 shot cannot freeze the lane. Live play:
still overpowered, not broken. Dest is still
leashed before Y-snap. Nullifier rolls Frost
Bind per enemy (T1 40% hit) so a 2.4s circle cannot hard-lock the
lane. Not Play-confirmed yet.

## Dead hatcher egg retargets leftover marchers (2026-09-01)

Wave 14 traces showed leftovers loitering at the gate (~170 studs,
pets `current=0` after a brief lock). Egg death now always marches
them to a living egg from live position, re-alerts every hatcher
folder including the lost team, and keeps one idle reserve. Finish
is last. Not Play-confirmed yet.

## Merge bulwark slots are independent of combat planes (2026-09-01)

`BulwarkLine` still opens pet combat. `BreachLine` still opens egg
attacks. Those two named parts keep those meanings. Physical installs
are a separate catalog (`MergeBulwarkSlots`): lane sits on the gold
plane, egg sits on the red plane, mid/front are reserved for halfway
and the same spacing out past the gold line. Wardstone stays
`wardstone_barrier` and egg-only. Lane-family combat on the egg slot
uses the red strip plane. Talkable Bulwark Engineers stand on the
red-line left and the gold-line right; each Talk opens the same
unchanged workshop for that slot. Alts vs a line-picker is still
open. No Wardstone combat this pass. Not Play-confirmed yet.

## Grasping Hedge is a temporary front-wave root (2026-09-01)

Fifth live bulwark combat. `combatEffect("grasping_hedge")` is `grab_root`:
root the front of the wave (`RootedUntil`, hands free) and slow the pile.
The root is timed and not refreshed, so they can walk off. Leaving the hedge
and walking back in is a new grab — not a lifetime counter. They must clear
the strip plus a 6-stud march-axis buffer before that re-entry counts.
Never `HeldUntil` (sharks already own the true hold). T3/T4 add a timed
venom. Combat still opens on the gold line. Not Play-confirmed yet.

## Saw Blade is rapid shred plus chips (2026-09-01)

Fourth live bulwark combat. `combatEffect("saw_blade")` is `shred_line`: high
raw damage on the six-stud deck, no slow/linger/stop. Ticks are 0.16 / 0.13 /
0.10 / 0.08s. Each tick pulses local tiny cubes colored from the chewed
model plus a couple flesh chips. Contact audio plays at the struck combatant,
throttled. Live spin is 2× the authored deck speeds, and each tile starts
at a random rotor angle. Combat still opens on the gold line. Not
Play-confirmed yet.

## Concertina Line is bleed plus slow (2026-09-01)

Third live bulwark combat. `combatEffect("concertina_line")` is `bleed_slow`:
lane DoT while they walk the wire, plus a graded `SlowFactor` that now also
applies on the authored march path. T1 is on-strip only. T2/T3 linger after
they leave. T4 stacks (cap 4) and stays for the rest of the wave. Combat still
opens on the gold line — this is not a stop wall. Not Play-confirmed yet.

## Land Sharks hunt, grab, and sink (2026-09-01)

Second live bulwark combat after Impaler Palisade. Play-confirmed: the hold
pulls the marcher under and the sink death reads. `combatEffect("land_shark")`
is `hunt_drag` — leave the wander, bite on a pet-like cadence, hold, drag under.
One shark, one target. Count is 4/5/6/7 by tier. T3 adds proximity venom; T4
prefers an unclaimed boss. No pet-kill credit.

## Pre-checkpoint overrun returns to Wave 1 (2026-08-31)

A loss before Wave 10 had no checkpoint snapshot, so auto-restart never
fired. Wave 0 is now the opening boundary: keep the egg/board and roll
Wave 1 again.

## Impaler Palisade is a no-damage stop wall (2026-08-31)

First live bulwark combat: tank-style shove toward the gate plus a short
root. The shove itself deals no damage. Each marcher gets T1=1 / T2=2 /
T3=3 / T4=4 bounces. T3 adds a permanent venom DoT; T4 adds a permanent
contagion plague.
then walks through and combat opens. Five per enemy on T1 would farm-lock
the wave.

## Merge first-visit collect re-lays 600 Waycoins (2026-08-31)

Durable-wallet entry kept the `hall_coins` profile default of 100 and skipped
the five stacks. Fresh Wave-1 / admin reset / incomplete-tutorial empty board
now zero the Merge wallet and spawn the 600-Waycoin lesson again.

## Merge bulwark previews use authored flat art (2026-08-31)

All five static families use the same long side-to-side presentation. Land
Shark is the sole special case. The workshop uses the exact transparent
family/tier thumbnails under `assets/ui/merge_bulwarks/`; it does not rebuild
cards from live models or per-family cameras. This is independent of runtime
deployment orientation, which remains one generalized anchor rule with only
Land Shark exempted in `MergeBulwarkModels`.

## Merge bulwark workshop shows owned vs next (2026-08-31)

The workshop is two stacked previews on the left and the family list on
the right. Currently Owned shows the owned mesh; Next Upgrade shows the
next rank plus three role-true bullets from `upgradeNotes`. Buy/Upgrade
lives in that next card. Install only deploys an owned family onto the
strip. List rows report NOT OWNED / OWNED • TIER N / MAX.

## Merge pads and walls upgrade independently (2026-09-01)

Unlock is one-time and global. The workshop shows LOCKED / UNLOCK
until that family is bought. Playtest unlock, place, and upgrade
stay one Waycoin. Final unlocks will almost certainly be gems or
a Robux game pass and survive rebirth; placements do not.
Installing on a second pad or on the egg wall starts at Tier 1.
Upgrade only advances the slot you are standing at. Workshop
layout is unchanged. Not Play-confirmed.

## Merge bulwarks are owned per family (2026-08-31)

The right-hand list is the selector. First purchase unlocks Tier 1
globally. Later visits still pay to place that family on a slot.
Upgrade advances only the slot you talked to.

## Merge bulwark menu is pick-then-act (2026-08-31)

Draft roles (stop/bleed/hunt/shred/hold/ward) live on
`MergeBulwarkProgression`. Live combat so far: Impaler Palisade `stop_shove`,
Concertina Line `bleed_slow`, Land Shark `hunt_drag`, Saw Blade `shred_line`,
and Grasping Hedge `grab_root`. Wardstone Barrier is still visual-only.

## Ability cannon shots land on the floor (2026-09-01)

Heal, Rage, and other power-laying shots aim the floor under the
target — the same LandStrip plane the ring uses — then the ball
blooms out in 0.16s instead of lingering. Not dramatic. Config:
`land_at`, `ability_impact`, `bloom_seconds`, `bloom_scale`. Not
Play-confirmed.

## Merge cannon shots boom on landing (2026-08-31)

Fireballs play group-owned `cannon_impact` (`rbxassetid://105126690616608`,
ElevenLabs muffled bomb, 1.28s) at the landing point so the fireball can
despawn without cutting the clip.

## Merge cannons play the siege fire clip (2026-08-31)

Group-uploaded `cannon_fire` (`rbxassetid://77523296675224`, ElevenLabs
WEAPSiege pirate siege, 2s) lives on every pad cannon and plays
positionally on each shot. Same clip for every role.

## Merge cannons track from the outer gate (2026-08-31)

Live Merge has `OuterSpawnGate` (X≈370), not `EnemyPortalVisual`. Range
was stuck at 90, so cannons only woke when pets entered the last third
of the lane. Aim and range now use the gate (or the old portal visual
when that world is present), plus live `MoveTarget` / `GetLivePosition`.
Still no shot damage.

## Merge cannons kick on fire (2026-09-01)

On each shot the chassis stops aiming for 0.18s, lurches up 0.2 studs
with a light shake, then settles and resumes tracking. Config lives on
`team.edge_towers.shot.recoil`. It does not change the fire interval.
Not Play-confirmed.

## Merge cannons aim the barrel and spit fireballs (2026-08-31)

Pad cannons sit on the authored pad deck (highest opaque plate), not a floor
raycast. They stay flat and only yaw toward gate-side enemies, then auto-fire
a neon fireball. The test E Fire prompt is gone. No damage yet.

## Merge admin reset stays on the pad (2026-08-31)

Reset to Beginning on the dedicated Merge place skips the Farm prologue,
tears down the live wave/eggs (not just the wallet), wipes the Merge
checkpoint, and re-enters Wave 1 on the hatcher pad with the first-visit
tutorial. The Farm "Hatch your first egg" card stays hidden so it cannot
cover the wave meter.

## Flora rustle (2026-08-31)

Nearby plants, trees, cacti, and banners tilt a few degrees on the client.
Rocks stay still. Anything farther than 80 studs from the camera sleeps.
Settings → Prop Effects turns it off; it defaults on.

## Merge tower E fires a cannonball (2026-08-30)

Walk-up E on a pad cannon lofts the same arcing sphere. No combat session required.
Size cycling is off; the installed gameplay tier selects its matching cannon model.

## Merge cannon four-tier art complete (2026-09-01)

All six families now have distinct Tier 1–4 concepts, Meshy geometry, manifold repairs,
2K retextures, embedded-texture FBXs, group-owned Roblox Model/Mesh/Image assets, and
prebaked runtime templates. The 24-way manifest and audit live in
`scripts/merge_cannon_model_ids.json` and `scripts/merge_cannon_pipeline.js`; Roblox
ownership verification covers all 72 component assets. Runtime selects the gameplay tier
directly from `configs/merge_tier_art.lua` at uniform template scale. The old scaled-copy fallback
is removed; `scripts/merge_tier_runtime_manifest.json` is the menu/world wiring proof.

## Merge edge towers fire a sphere and aim (2026-08-30)

Installed cannons spawn their own tier-specific model. Each shot is a metal sphere on the same
parabola. The cannon yaws and pitches along the launch tangent before it fires.

## Merge edge towers loft a spear (2026-08-30)

Installing a chassis clones that role's selected tier onto its authored tower pad. Each cannon
lofts a labeled spear on a 14-stud parabola every 2.4s toward the nearest in-lane enemy, or
a gate-side landing point if the lane is empty. The spear plants for 1.2s. Upgrades and
cannonball art are still later.

## Merge Defense permanent ten-bay realm (2026-08-28)

`Workspace.Maps.MergeEggRealm` is now a permanent Studio-authored ten-bay architectural blockout:
five raised Heaven bays and five raised Hell bays flank a formal 180-stud-wide civic mall ten studs
below the play fields. A 36-stud landscaped berm separates neighboring bay mouths. Ten 56-stud
balustraded stairs connect the terraces to the mall, while a straight 18-stud center river uses four
bridges and a steam/pearl cancellation band. Circular water and lava end caps, outer spawn gates,
continuous retaining walls, lamps, railings, and ice/basalt cliff masses establish the final
composition. Runtime validates/binds those ten authored bays and owns only transient claims; it
does not create, transform, or theme map geometry. Hall entry randomly claims an empty bay, and
bay-relative UI is ready for the future dedicated place. The current combat runner remains
single-owner until that place receives per-bay concurrent session state.

Wave-10 boundaries are now profile-backed. The checkpoint wallet, board inventory, base tier, and
deployed egg tiers survive logout/restart and rebuild as full-health objectives; Gems and Rebirths
remain durable, while Rebirth/Admin Reset deliberately clear the saved boundary. Logout after a
failed attempt persists each destroyed hatcher's last-good deployment identity rather than the
temporary empty live slot; same-wave legacy saves recover missing deployments from the checkpoint.
Newly spawned combatants resolve the player's current effective level, so leveling during a run no
longer requires rejoining before later spawns adopt the new level.

Merge-only player-pet recovery is automatic and place-configured: ordinary equipped pets return
after the 10-second slot delay and Huge identities return after 60 seconds. Farm & Fight retains
its existing manual Summon behavior and longer canonical timers; gauntlet no-revive rules override
automatic recovery everywhere.

## Adventure status crests uploaded (2026-08-25)

Noob through Legend plus Huge Hatcher are group-owned Image ids on the
Status chip, picker, and People-list inspect card. Leaderboard titles
still have no crest.

## Combat Training Later → Quest (2026-08-25)

After Resonance, TUTORIAL 8/9 still points at the Earth cave. **Later**
on that card opens the Okay banner and moves Combat Training into Quest.
Finishing the cave still continues to Rally. The People list stays
visible during the tutorial (docked under the capsule).

## Auto-cast glow ring (2026-08-25)

Right-click / long-press lock is a pulsing green ring around the power
disc. The old corner ⟳ did not read on purple badges.

## Board speed slider (2026-08-25)

Right-click or long-press Board for a 20–100% cruise slider. Rocket 128
at 25% is 32. Persists on the hoverboard save.

## Brew overcharge juice (2026-08-24)

First Berserk sip glows the badge and puts fire on the player + pets.
A second sip shakes the disc and leaks a barely-contained halo. Intensity
follows `Brew_damage` via `BrewJuice` (`configs/potions.lua` overcharge).

## Dramatic enemy deaths (2026-08-24)

Enemy defeats play a short corpse pose plus a positional sting. Seven
styles (flop / pop / shatter / whirl / sink / launch / robux). The
robux style bursts gold cubes one-by-one onto the ground for ~2s.

## Combat-training lobby Leave (2026-08-24)

Lobby pad E asks to leave without completing. Arena and pillar do not.

## Cave E is always on (2026-08-24)

Earth-cave Enter is not gated on `first_fight` or stray Homeworld
kills. Walk in unless they already finished the cave — then Redo.

## Cave E uses EarthLair (2026-08-24)

Stray Homeworld kills no longer complete a fresh first_fight. The Enter
prompt is on EarthLair (40 studs), not the interior spawn part.

## Cave-training grandfather (2026-08-24)

Old first-enemy (v1–v5 `first_fight`) counts as the combat start. Those
players get Heal and are marked done. Players who have not fought yet
can enter the new cave.

## Power pick percentages (2026-08-24)

Committed picks now have a share readout: dashboard `powerPicks`, Creator Hub
`PowerPicked`, and export `power_picks.csv` from the existing raw event stream.

## Combat traces quiet (2026-08-24)

`combat.combat_trace` is false. Flip it on only for a balance pass.

## Layer 3 Roblox asset publishing (2026-08-25)

The group-owned upload pass is complete for all Layer 3 assets: 80 pet model/texture variants,
80 pet cards, eight eggs, two realm egg stands, and 38 environment props (29 flora, four ambient
fauna, and five landmarks). Every published asset has a resolved raw MeshId/ImageId in the tracked
registries; no entry or approved environment concept is pending. Dreadguard Bear Golden uses a
dedicated mesh because its topology differs from Basic.

Layer 3's eight authored egg fixtures now use the realm-specific stand meshes. Its 141 flora
anchors are source-of-truth: 46 stale copied visuals were removed, and runtime config supplies the
complete Heaven 3/Hell 3 plant, tree, rock, and cactus palettes from the prebaked Models bundle.
Four realm landmarks are placed in Studio, and twelve tagged ambient-fauna anchors spawn six
non-combat moving props per realm. Heaven 3 and Hell 3 physical portals
use the same per-player lock as the other built gates: 🔒 until earned
Level 21, then the destination label.

The Layer 3 runtime configuration is now live for walkthrough testing: eight realm-specific eggs
resolve on the authored stands, all 40 published pets are hatchable, and each Heaven 3/Hell 3
origin has a 1.5M coin unlock plus a presence-gated crystal world. Heaven 3's omitted terrain edge
was restored from the corresponding Heaven 2 voxel region, and Pearlback Snails use an anchor-level
180-degree visual correction so their authored faces point along travel.

## Healer hunt pins pets; leftover despawn cannot lock the room (2026-08-24)

Clicking the training healer pins the squad on it. If a leftover dog
vanishes without `enemy_defeated`, the room still clears so the pillar
can light.

## Build your squad walks a real swap (2026-08-24)

The early inventory lesson grants a Rainbow Kitty and points CLICK HERE
through unequip, the strongest inventory pet, and Activate. Equipped pets
are the top row; extras wait in Inventory. Closing without a swap does
not complete the step.

## Onboarding vs Activation funnels (2026-08-24)

Creator Hub 7/28/1-day funnels from 2:00 PM MDT are archived. Onboarding
ends at Rally (including the 32 combat beats after publish). Optional
first quest / First Steps / first area are a separate Activation funnel.

## Combat training lobby refresh (2026-08-24)

Returning to the training lobby clears Heal/Revive clocks, pet recovery,
and Focus so the next room is a fresh start.

## Mythical+ gift chat (2026-08-24)

Finalized Mythical and higher gifts announce in the server chat without
naming the pet (`Colorado sent Splite a mythical gift!`).

## Admin reset restarts combat training (2026-08-24)

Reset-to-beginning now clears combat-training progress and kicks the
tester out of the cave. Teaching packs despawn through EnemyService and
cull extras so a leftover healer cannot stack on the next ENTER.

## Hold level claim until Rally (2026-08-24)

Players can earn XP during the tutorial but cannot claim a level (Powers
COMMIT, altar, or field filler) until Homeworld tutorial is done. POWERS
stays on enhance so the Resonance lesson is clickable.

## Combat training funnel + leave-resume (2026-08-24)

Onboarding now records each combat-training beat. Leaving mid-fight rewinds
only to that loop's lobby, not the start of the cave.

## Homeworld Resonance slot cues (2026-08-24)

Power up Resonance keeps the POWERS button cue, then walks CLICK HERE onto
Resonance, the empty enhance slot, Potency, and Apply.

## Combat tutorial (live in the Earth cave 2026-08-24)

An isolated combat-training track lives beside Homeworld tutorial v5. The disabled Home Hall
arch is a Combat Training mission door into Training Ground Room 1. Heal-room enemies use a
huge existing absorb shield; that shield drops after the player heals a damaged pet. The track
holds on "more coming" and is not marked complete. ENTER on the frost door is the ready
step; the first weak melee (Training Dog) spawns in the opened room after that click.
Each hall entry restarts the track (`restart_on_enter`) until save paths are wired.
The track loops lobby → ENTER door → fight → pillar back to the lobby. Lobby
lessons stay behind the sealed door so they finish before the next fight. The
door plate alternates READY/ENTER when you can go, and names the first
missing checklist item if you click early (pets equipped, Heal bound,
hotbar not in edit mode). Resonance is withheld for the combat-training
mission so the first bind lesson points at Heal.
See [Combat Tutorial](COMBAT_TUTORIAL.md).
Combat ranks (2026-08-25): eight Halo-flavored titles grant on pillar
steps (Spark → Skilled). A crest flies to a chip at the 14px top,
left of the quest bar. Click the chip to wear any earned Training,
Adventure, or Leaderboard title. A newly earned title replaces the
worn pick so the chip and nametag update without reopening the
chooser. Status shows that worn badge.
VIP/staff sit as one name badge. Persist `GameData.CombatRank`.
People list (2026-08-25): custom smoked list replaces CoreGui. Tab or
the header collapses it. One name badge (owner Colorado C+blaster,
then developer / content creator / official tester / founder ⭐ / VIP).
Its dock width, top/right position, header/row/body heights, columns, and
profile-card footprint are viewport ratios selected by DisplayClass
(phone/tablet/desktop/ten-foot); no fixed 397px screen-width contract remains.
Viewport and orientation changes relayout the live list.
Rank is the claimed/Ascended level, not the potentially-ahead earned level. The Rank cell and
Ascension nudge stay hidden until either the crystal/Homeworld introduction or the independent
Combat Training tutorial is complete; older players who already claimed a level remain unlocked.
Tester is `roles.tester_user_ids`, not an open-beta campaign pet. A row
opens a slide-out (headshot, every role they hold, how the Status
title is earned, Examine Avatar = live character). The list row still
shows one name mark. Leaderboard Status is `Farm #N` (or Slayer /
Dragonlord / etc.); hover and the card use `Farm #N (#N Crystal LB)`
instead of a combat crest. Hover shows Name, Role, Status (source).
Friend/Block stay on that card. Report stays on Esc.
Lobby leave (2026-08-25): frost door has two SurfaceGuis — the lesson
plate and Continue later (confirm, then exit). No camera Billboard.
Combat training now temp-grants three bunny, doggy, bear, and kitty commons
and restores the saved equipped list on exit. The heal-target lesson wounds
one live pet to a yellow bar and points `CLICK HERE` at the left of that card.
After Heal the training shields drop and they must finish the dogs before
the pillar lights. Separate loops teach Weakening Vial, sipping
five of ten Berserk Brews, equipping a tank, killing a healer first, then an
unguided room that puts those tools together. Battle music follows the
normal `InCombat` attribute; pet swings now credit pet-side threat so the
1-damage Training Dog still counts as a fight. Heal is withheld until the
first combat-training enter so Homeworld Resonance bind is a single-power
lesson.
Teaching packs stay capped at one healer and three other pets at any
player level; leftovers despawn before the next authored pack.
The lobby breadcrumb now waits until the spawned training pack is actually
down. Weakening Vial has the same finish-the-dogs beat as Heal (`weaken_fight`).
Combat training starts on three doggies. The stacked-Berserk dog is 400 HP
and the brew meter is refreshed on enter so five sips read as faster kills.
The tank lesson resets to those doggies and then requires a bear.
The tank lesson now walks inventory click-by-click (take off the last doggy,
strongest tank or Best Pets → Tank, Activate, ENTER).
The stacked-brew door plate counts down remaining sips (DRINK FIVE MORE → ONE).
Inventory tank cues use a DisplayOrder overlay so TAKE OFF stays the same on-top sign.
The healer-hunt `KILL THIS` cue hides after click or when pets already have
that healer. It never asks for another click after the healer dies. A banner
asks them to click again only if live pets leave a still-alive healer.
Successful Pets Activate closes the inventory panel.
The healer room now waits for the leftover dogs after the healer dies
(`healer_fight`) before the pillar lights.
The unguided finale is two dogs and a healer. Clearing it and taking the
pillar completes combat training and grants a once-only thank-you (coins +
potions). The Level 2 top-up is authored for when this track is the live tutorial.
Tank-lesson overlay signs now share MenuOverlay's inset space so TAKE OFF /
CLICK HERE sit on the card instead of a topbar above it.

## Pet function marks (2026-08-24)

Healers, armor buffers, and debuffers now carry a job chip at the right end of
the squad/enemy health bar — green heal, blue armor, red debuff — so they are
not just another Support icon. The same colours tint those pets' inventory
support badges. See `power_icons.function_mark` and `PetFunctionMark`.

## Homeworld routing rollback (release candidate 2026-08-22)

Hall of Worlds remains authored but entry is disabled while its map is repaired. All joins and
character respawns resolve to Homeworld Spawn, including profiles whose saved `LastArea` was a Hall
tile. Schema v18 strips only the four Hall route ids from `UnlockedAreas`, preserves all other world
unlocks and player-owned data, and leaves the Hall progress ledger dormant. The Home Hall arch is
sealed as a frosted **Hall of Worlds — Coming Soon** barrier.

Tutorial v5 restores the v3 Resonance-before-combat Homeworld path (the v4 Hall rollback had
re-imported the older fight-then-Resonance order). The complete
authored Range fixture was moved to Lava and the complete Training Ground fixture to Desert under
`Workspace.Maps.Home.ChallengeBindings`; their MissionDoor pads, lightning marker groups, titles,
guides, and public leaderboards remain attached to the original Studio Instances.

## Production streaming visibility (landed 2026-08-22)

The authored world uses a 1024-stud protected streaming radius and a 1536-stud target radius.
One Crystal World level is roughly 744 × 947 studs, so its enclosure remains inside the protected
radius; the 2000-stud vertical separation still keeps adjacent stacked levels out of the target.
The larger Hall is covered by the target plus the player's moving focus. `ModelStreamingBehavior`
is Improved and `PauseOutsideLoadedArea` remains the integrity gate. These non-scriptable Workspace
properties are source-controlled in `default.project.json` and must publish with the place.

`RealmAtmosphere` also establishes a minimum Atmosphere envelope before interpolating base → each
Heaven/Hell depth. It uses Density/Haze/Offset rather than legacy `Lighting.FogStart/FogEnd`, which
Roblox hides while an Atmosphere exists. The envelope obscures unloaded distance while every level
retains its own sky, color, ambient light, clock, and increasing depth intensity.

## Range / Training Ground (landed 2026-08-20)

Homeworld Lava hosts The Range entry and Homeworld Desert hosts Training Ground; their missions
continue to use the shared Challenge Field gauntlet implementation. Room 1–99 is a
difficulty index (`ChallengeRun.packForRoom`) on a **fixed layout sequence**: Range
`room#N`, Training Ground `train#N`. Early rooms are one chamber and two imps;
later rooms add trash, lieutenants, then bosses. Settings Enemy Level and Trial
Enemy Group Size do not apply. Advancing
restamps that room. Range is **solo-only** and uses a catalog GhostPet loadout picked
across Inventory + PowerChoice (origin + up to 6 loaned powers). Closing
that picker clears the menu flag and re-arms the pad E. Everyone
fights at level 50 for the run (`ChallengeLevel` on the sidekick
`EffectiveLevel` pipe; earned/claimed stay put and restore on exit). Kill
XP pays from earned Level, not the pin. Those picks persist as
four per-origin Range defaults (`GameData.RangeDefaults`) plus the last catalog squad,
and they are the only legal powers for the run (auto-slotted: Hasten 6 recharge; others
3/3). The hotbar blanks to that kit and restores the saved bar on exit
(publish-only; `profile.Hotbar` is not written).
Hotbar auto-cast locks clear on Range enter and exit so a slot lock cannot
follow a loaned power home. Range and Training Ground now use the ordinary Homeworld HUD
(`hall_currency_hud = false`); exit drops `mission_*` as before. Training Ground uses your own pets on an easier curve
and still allows a team. The overworld level-5 combat onramp does not apply.
A downed slot stays down for the run (no Ready/Summon
timer) and cannot be refilled. Entry-tile kit-up is white slots only. Overworld
red slots stay reserved for 60s. Neither field spawns farmable crate or
crystal-node debris (the MissionCrate placeholder was a sideways crystal).
Best room persists under `GameData.ChallengeRuns`, plus a compact `recent`
attempt list. The public Range / Training Ground boards use fixed, clock-aligned
award rounds rather than sliding score expiry: entrants remain visible for the
complete round even while offline, then both the visible cache and logical
OrderedDataStore rotate atomically at the boundary. The board header counts down
to that same boundary. Release cadence is one America/Denver calendar day, midnight
to midnight; exact UTC boundaries account for 23-hour and 25-hour DST days. Each public
top-10 entrant retains their lowest numeric rank for that
whole round. The exact configured Top 10 bundle is delivered durably online or on
the next return, and a queued click-through receipt explicitly shows the held
Gauntlet Champion Egg before play continues. Unclaimed durable awards expire 30
days after they were earned; returning after that deadline discards the pending
message without a grant. Neither `ChallengeRuns` nor award
delivery state belongs on the ProfileStore template. Internal IDs still write to keep the
publisher deterministic, but `hide_internal_accounts` is enabled for release: the canonical
developer/test IDs in `configs/internal_accounts.lua` are omitted from public ranks and awards.
See [Hall of Worlds](HALL_OF_WORLDS.md). Hall arch lightning lives in an
`ArchLightning` group inside each Hall gate visual (plus the Home Hall
arch and `HellFaceGateTest`). The last Plaza endcap is closed by a Coming
Soon wall at the SeamTowers. Save the place after the stamp.

## Console Support (landed 2026-08-13)

Runtime status: **disabled by feature flag as of 2026-08-15** following a published-build rollback.
The controller implementation remains in source for diagnosis and later re-enable; touch and
keyboard/mouse paths remain active.

- Controller gameplay has one semantic action layer: `X` world interaction, `LB`/`RB` hotbar
  selection, `RT` cast/use, `LT` autocast, `Y` Farm mode, and D-pad shortcuts to Pets, Powers,
  Quest, and Settings. `A` activates the selected control and `B` closes the top custom menu.
- Custom menus now use contained geometric focus navigation, automatic scrolling, a strong selection
  treatment, dynamic-control discovery, and opener-focus restoration. Core click handlers use
  `Activated`, preserving one behavior path across mouse, touch, and gamepad.
- Input mode and display class are independent. Ten-foot displays receive safe-edge positioning,
  larger scaling, controller legends/tutorial text, and floating-banner mirrors for game
  announcements without suppressing ordinary Roblox chat.
- Pure headless specs cover input/display classification, glyph selection, and hotbar wrap/recovery.
  See [Console Support](CONSOLE_SUPPORT.md) for the controller contract and physical-device QA matrix.

## Trials Endgame (landed 2026-07-08/09; rewards revised 2026-08-07)

CoH-style DOOR MISSIONS ("Trials") are the shipped endgame: deterministic procgen interiors,
a 2-realm × 4-element trial matrix, quest-chain gate steering, and evolving-egg century chases.
SSOT = `docs/MISSION_WORLDGEN.md` (§13 = the shipped contract).

- **Worldgen**: authored `MissionDoor` → instance slot → seeded tile-kit map (pure LayoutSolver,
  CI seed sweeps, `worldgen_version` fold). Clear-gate objective, hold-E beacon completion with
  fanfares, fog-of-war draggable minimap, room-clear-locked treasure, farmable mission crates,
  per-theme dressing/atmosphere (hell/heaven/lava/ice/grass/desert palettes).
- **Shared sequences**: everyone's trial #N is the SAME map (`shared_sequence` seeds); finish-or-
  skip advancement (abandon re-deals the same number; skip = consumed without credit);
  `mission.replay` by already-reached number. Map title: "MAP — <name> #N".
- **The matrix**: 8 trials = hell/heaven × lava/ice/grass/desert, each composing three independent
  fields (theme = dressing, area = element branding/RPS/drop origins, realm = resonance override).
  Pet-model enemies via `SynthesizePetEnemy` + the `pet_ranks` ladder — minion volume, lieutenant
  splash + warcry, boss = the middle, TITAN = archvillain apex ("Titan " prefix). Balance stack:
  tier-aware `enemy_damage_growth`, crit ladder with shield penetration, drop level/quality
  scaling (enemy-level rolls, cap 52, rank quality odds).
- **Selection = quest activation**: realm gates are `MissionId="auto"` — the active quest track's
  mission binding deals the trial; nothing active = random from the FOUR base trials only (matrix
  counters move exclusively via activation). QuestPanel: "▶ Activate — realm gates will deal this
  trial"; the green banner taps to DEACTIVATE. Chains = 5 layers per combo (10/25/50/90/100). One
  held Celestial/Obsidian egg per track evolves Basic → Golden → Rainbow → 10%-Huge Rainbow →
  guaranteed Huge Egg; the Century retains its level-50 claim gate. Hatching is final, and trading
  freezes evolution unless the same canonical egg returns to its award recipient.
- **Gate UX**: Trials tracks unlock at level 14 with the first reachable mission doors in Heaven 2 /
  Hell 2. Per-player `NextTrialLabel` is stamped locally onto the door E-prompt ("Hell Lava
  Trial #4" / "Random Trial"); back-to-back heaven/hell portals side-gated client-side
  (`RealmPortalSideGate`); huge pets read ALL CAPS on the team rail.
- **Ops**: `admin.setCounter` = the sanctioned counter override (`test.*` is unreachable from
  network origin by design, even in Studio); `MissionSchema`/`ZoneSchema` pure validators run at
  config load AND in CI (`config_validation.spec`) — loud failures, orange-Warn fall-throughs.
- **Owed**: skip/replay UI buttons (map panel), lieutenant warcry live verdict, evolving-egg Studio
  and trade-return verification, duo pass, MissionProps.rbxm export.

## Combat Endgame (landed 2026-07-02, all live-verified)

The CoH-style combat game is now END-TO-END: one symmetric threat-table aggro model driving both
sides, a capital-baddie encounter ladder, and the powers roster fully implemented and honest.

- **Aggro v2 Phase 2 complete** (`docs/AGGRO_MODEL.md`, `configs/aggro.lua`): taunt (pet-centered
  AoE pull, live-position radius math), **fear = negative aggro** (flee the most-feared pet at a
  1.5× panicked sprint, passive build suspended, `pet_refocus_mult` knob), and the **rage tipping
  point** (`AggroTable.heat` + `AggroModel.rageLatch`, PER-SIDE tips — pet 200/80, enemy
  25000/10000 — berserk = ×`rage.amp` outgoing damage; the `Enraged` attribute is the public seam).
  Emergent keepers: a boss's pulse aura tips the WHOLE squad into rage together; taunt provokes
  enemy rage. GOTCHA: the enemy tick's local `aggroCfg` is the legacy combat.lua block — rage/fear
  knobs must read `self._aggroConfig`. Double-taunt reinforce now anchors to the top NON-taunt
  attacker (two taunt tanks used to leapfrog threat exponentially — observed 1.6M heat).
- **Capital baddies**: `archvillain` tier above boss (rank_offset 3, ×6 XP/coins;
  `infernal_archvillain` = the kit that wiped a 10-pet squad, on 150k HP / armor 300 / scale 22).
  Config-only abilities ANY enemy can wear: `attack.splash` cleave, `abilities.slam` (telegraphed
  red-rune targeted AoE via `PowerService:SpawnGroundRune`), `abilities.pulse` (radiating aura —
  "everybody gets somewhat damaged"). Boss ladder calibrated empirically: boss = hard/downs-pets/
  beatable, AV = the wipe kit × 3 duration. Admin bar spawn buttons: ☠ BOSS / 𖤐 PACK / 👑 AV /
  💀 WAR (full composition: boss + 2 LTs + healer-behind-boss + whelp screen) riding
  `combat.spawnEnemy` (Studio-or-IsAdmin).
- **Powers audit closed**: `target="single"` is REAL (resolves the squad's engaged target — it used
  to hit the whole combat set at the widest default radius); `_applyEffect` warns on unknown
  families (how fear + Armor Field once shipped dead); Armor Field re-kinded to defense_buff;
  Fire Nova really burns; Simoom really blinds; every hostile family rolls accuracy (blind /
  heal_blind / root_guard included). Cast preflight covers enemy-targeted blind, downed-pet Revive,
  pet-dependent support, Simoom's heal-or-blind hybrid, and Resonance crystals before Focus/cooldown
  commitment. Shield = absorb pool / armor = +Defense curve / evade = miss roll — three defensive
  pillars, deliberately no fourth.
- **Veteran levels** (`docs/VETERAN_LEVELS.md`): 50 stays the build cap; overflow XP = flat
  2000-XP vet levels paying enhancement ROLLS (not currency), `data.VeteranPaid` once-only ledger,
  PlayerBar shows `VET N · x/y XP` at cap. The "keep going" branch vs Rebirth/dragons.
- **Genie of the Dunes v2**: the RESURRECTION capstone — follows the FIGHT centroid, revive-on-down
  all window (35s, 300s cd), +5 focus/s wish aura (`FocusRegenBonus` seam in FocusService), 700
  arrival burst. **Res sickness**: every partial revive stamps a heal FLOOR for
  `squad.revive.sickness_seconds` (8s) — `ResSickness.clampTaken` applied at EVERY heal write.
  **Powered revives must call `EnemyService:ResurrectPet`** (releases the #179 `PetLockout` ledger
  first — plain PetRevive gets held right back down by the lockout enforcement).
- **Ops notes**: `combat.combat_trace` gates ALL balance traces (currently FALSE = player-quiet);
  `aggro_trace`/`glass_trace` are per-second-flood sub-flags. The loader only injects DECLARED
  deps into `self._modules` — resolve cross-service at runtime via `_G.RBXTemplateServices`.
  Focus is the raid's true health bar (boss `sundering` attacks it; "focus capped" is the loss
  condition).

## Summary

This is a Rojo Roblox project: a config-as-code template that **is becoming the game "Pet Realm" (Halo & Horns)** — a heaven/hell directional pet game. Template Phases 0–11 are complete (data spine, map integration, economy depth, stats/achievements/leaderboards, progression, the full Halo & Horns feature build P0–P10: data spine, pets & power, layer slice, party core, combat & focus, archetypes/powers/augment/hotbar/rosters, social/trade/fusion/rifts, reward spine, quest/daily/shop UI, escrow trade — plus P11 the SSOT pet-inventory model). On top of that baseline the **Pet Realm game layer** is the active lane: per-biome zone economy, mining/combat balance, the PetPower mining/combat split, an XP-everywhere level-50 system with a claimed-vs-earned split + Ascension Altar, a level-diff accuracy curve, and a bounded "pets-are-stars" power model with a Creator ceiling — all bound to the pinned progression/power/teaming design spec. See the **"Pet Realm" section below** for the current game state; the older phase sections remain as template-baseline history. The playable loop: mine biome ore → earn biome coins → hatch eggs → grow/equip a pet squad → claim levels (powers/slots/egg-hatch) → unlock zones toward the (planned) heaven/hell realm axis.

## Working Systems

- Rojo project builds and lints.
- Roblox Studio sync workflow is active.
- Data saving works after enabling Studio API access and saving the experience to Roblox.
- Breakable crystal spawners are present and visually tuned on the baseplate.
- Coin generator exists so testing can fund egg hatching.
- Eggs can hatch pets from configured asset ids.
- Fusion mints unique Chaotic pets through `PetGrantService` and rolls failed consumption back to exact inventory records. Packaged-model pets and Meshy mesh+texture pets retain their separate asset-loading paths.
- The Home/grass bunny, doggy, kitty, bear, and dragon use a consistent Meshy batch for basic +
  golden variants (ten group-owned mesh/image pairs, 2026-07-21); rainbow reuses each pet's basic
  geometry/texture and applies the runtime rainbow treatment. Mesh-combine prebakes validate their baked MeshPart source ids
  against config before the fast path, so changing art cannot silently retain a stale model cache.
- Rainbow pet visual effect exists and applies to models such as Rainbow Bear.
- Admin control panel opens and includes event/effects testing commands.
- Global event support has started, including scheduled event concepts and a UTC event clock.
- The launch **Founder's Choice** promotion reserves an exact, retry-safe first-10,000-player cohort
  after tutorial completion. Eligible players choose one of seven permanent single-purpose pass
  benefits in a confirmation modal; the Robux shop blocks the identical purchase, labels the source
  honestly, and returns the choice if Marketplace ownership later supersedes it. A Founder who already
  Marketplace-owns the complete choice catalog receives the hidden, permanent **Founder’s Legacy**
  instead: their presence supplies a non-stacking 1.5x whole-hatch retry aura to the server, announced
  through gold chat/banner treatment and a truthful source-specific HUD badge.
- `ConfigLoader` validates every loaded config at startup. Complex gameplay configs retain focused cross-reference validators; the remaining configs use the revisioned `ConfigSchemas` registry for required top-level key types. Unknown configs fail closed, and the architecture guard rejects configs without an explicit schema.
- The compact quest/mission tracker doubles as a rotating learning surface: once per minute it
  overlays one config-owned gameplay tip for 10 seconds, including potion, enhancement, pet-role,
  mining, hatching, power, teaming, and travel mechanics. The live objective continues updating
  underneath and is restored exactly afterward. Each session shuffles a no-repeat deck so players
  do not always see the same early tips. `Settings → Display Tips` persists the player's opt-out
  under `Settings.ClientPrefs.displayTips`; new players default to tips on. A claimable quest always
  preempts an active tip and pauses the rotation until the reward is claimed, so the 10-second tip
  lease can never hide or intercept the Claim action.
- Rarity hatch, genuine claimed-level congratulations, and team-sidekick announcements use the
  standard Roblox chat window and default on. Level messages randomize among **Grats**,
  **Congratulations**, and **GG**, use the player's display name, and never fire for respec replays.
  `Settings → Chat Announcements` immediately suppresses only these game-authored notices and
  persists the opt-out under `Settings.ClientPrefs.displayChatAnnouncements`; ordinary player and
  Roblox system chat remain unchanged. Presentation probes the live `RBXGeneral`/`RBXSystem`
  TextChannel rather than trusting `ChatVersion`, because Roblox can report `LegacyChatService`
  while rendering the modern channel; legacy `SetCore` remains the fallback.
- Phase 0 foundation services are in place for profile schema versioning, stat counters, modifier resolution, currency ledger aggregation, deterministic UTC day/seed behavior, and feature flags.
- Reward bundle currencies now flow through `EconomyService` rather than writing profile balances directly.
- Realm token earnings and paid layer traversal also flow through `EconomyService`; failed debits no longer move the player.
- Pet-index and achievement currency rewards no longer retain direct profile-mutation fallbacks.
- Shop purchases spend and refund through `EconomyService`, with tested multi-currency rollback before purchase counts advance.
- Paid zone unlocks debit through `EconomyService` and remain locked when the debit fails.
- Enchant rerolls debit through `EconomyService` and retain the existing enchant when payment fails.
- Egg hatch charges and partial/full refunds now flow through `EconomyService` with their existing source tags.
- Combat loot currencies, including def-less realm-enemy coin fallbacks, now flow through `EconomyService`.
- Enhancement buys and sells use `EconomyService`; rejected sale credits restore exact enhancement stacks before commit.
- Trade gem escrow, adjustment refunds, and recipient credits now use checked `EconomyService` calls.
- Trade pet/enhancement delivery now preserves full source records and special-pet UIDs through
  `PetTransferService`. Both trade legs roll back in reverse on failure, cancel only closes after an
  atomic two-owner refund, and graceful disconnect refunds before ProfileStore releases the profile.
  Durable hard-crash escrow recovery remains separately planned.
- `EconomyService` is now the only server service allowed to call currency persistence primitives.
  Admin, automation, Game API, Studio smoke setup, and Upgrade purchases use its set/add/transaction
  APIs; Upgrade purchase commits are rollback-safe and the loader dependency cycle is removed.
- Studio Play boots successfully through the validated config loader; current remaining Output noise is warning-level placeholder/test data such as monetization ids and unknown legacy saved effects.
- **Boot is event-driven and gated** (`docs/BOOT_ORCHESTRATION.md`): `BootReadiness` milestone latches + a `configs/boot.lua` dependency graph + a `BootOrchestrator` that validates the graph, logs `[BOOT] milestone ready`, and mirrors readiness to `ReplicatedStorage.BootStatus`. Producers signal (`world_structure`/`models_ready`/`crystals_ready`/`eggs_placed`/`icons_ready`); consumers (pets, crystals, eggs) `await` instead of polling/aborting/fire-once-waiting — the class of fast-boot races (pets not deploying, crystals only filling on the 30s safety-net) is closed. The loading screen renders those real milestones as informative phases.
- Roblox Studio MCP is enabled and connected to Codex. Agents can now read Output, capture Studio screenshots, start/stop play, inspect the game tree, execute Luau, and read/edit Studio scripts through the official Studio MCP bridge.
- Phase 1 now has `configs/areas.lua`, `configs/markers.lua`, `WorldBindingService`, `ZoneService`, synthetic multi-area baseplate hooks, server-authoritative `TeleportPad`/`Portal` travel, and `BreakableSpawner` binding through `SpawnZone` when available.
- Synthetic `Spawn` and `Meadow` areas are configured. Spawn stays live for the starter loop; Meadow breakable spawning stays dormant until a player travels/enters it.
- Authored reference-map readiness exists: `scripts/studio/create_reference_map.luau` creates a tiny Studio-owned `Spawn`/`Meadow` marker map, and `tests/studio/MapContractSmoke.lua` verifies the live marker contract.
- `default.project.json` now keeps unknown Workspace instances, so Rojo sync does not delete designer-authored map geometry.
- Studio-only automated smoke testing has started with `StudioSmokeTestService` and `tests/studio/EggProximitySmoke.lua`.
- Spawn placement is now map-derived: `ZoneService` places characters at the active area's authored floor/`SpawnZone` through `WorldBindingService`, so the player does not fall when the Studio-owned map is offset from config defaults.
- `configs/upgrades.lua` and `UpgradeService` now provide permanent upgrades for pet equip slots, pet storage, and crystal reward value. Upgrade levels persist under `DataService.Upgrades`; inventory slot limits read the upgrade effects server-side.
- `Meadow` now has a paid unlock cost of `100 crystals`, and its breakable table includes stronger medium/big crystals. This is the first area-gated Phase 2 progression step.
- Phase 2 network bridges exist for UI/admin work: `PurchaseUpgrade`/`UpgradeResult`, `UnlockZoneRequest`/`ZoneUnlockResult`, and `ZoneTravelResult`. Locked-zone results include the configured unlock requirement payload.
- All runtime remotes now come from the validated network manifest and generated registry; manual remote-construction debt is zero.
- Gameplay events publish exclusively through `FireGameEvent`. Its terminal send is the sanctioned publisher boundary rather than migration debt.
- Runtime readiness uses milestones, attributes, completion callbacks, and replicated instance events. The remaining clocks are reviewed in `scripts/runtime_wait_classifications.json` as animation, cooldown, deadline, debounce, frame-budget, periodic, retry, simulation, test, or watchdog timing; readiness is intentionally not an approved purpose.
- Pet ownership writes are restricted to `PetGrantService` and transfer transaction boundaries. Studio smoke fixtures explicitly exercise both the original-pet compatibility path and the modern stack/special paths without making those fixtures production mutation APIs.
- Pet inventory storage is already mixed: normal pets stack under `Inventory.pets.items["petId:variant"]` with a quantity, while special pets are individual records. Equipping a stacked pet creates an ephemeral equipped id and temporarily decrements the stack quantity.
- Clicking an inventory stack card now equips another copy from that stack when quantity remains. Clicking the equipped ghost card unequips that specific equipped instance.
- Phase 3 configs are live: `configs/pet_index.lua`, `configs/achievements.lua`, and `configs/leaderboards.lua`.
- `PetIndexService` records first-time pet/variant acquisition under `DataService.PetIndex`, increments/syncs `distinct_pets`, and grants index milestones once.
- `AchievementsService` listens to `StatsService.CounterChanged`, evaluates config tiers over K1 counters, stores completed tiers under `DataService.Achievements.Completed`, and grants rewards once.
- Four global origin boards are configured: Grass `Most Dragons`, Desert `Crystal Crusher`, Lava
  `Enemies Defeated`, and Ice `Team Power`. `LeaderboardService` publishes only loaded players on
  join/relevant changes/leave, reads a top-100 cache, and exposes the first 10 to reusable tagged
  physical boards; it never walks the profile DataStore. Internal tester
  identities live in `configs/internal_accounts.lua` (IDs, not `Colorado*`
  names) and still write; release `hide_internal_accounts` omits them from the
  visible page and placement awards.
- Top-100 placement also feeds the native People-list `Status`: `Dragonlord`, `Farmer`, `Slayer`,
  `Commander`, or `Hatcher`. The lowest rank wins for multi-board qualifiers. Eggs Hatched uses the
  same bounded cache as a status-only ranking; the authored world still has exactly four boards.
- Inventory now allows adding to an existing pet stack even when storage slots are full, because existing stacks do not consume new slots.
- Admin tools now include zone lock testing controls. Developers can toggle, lock, paid-unlock, or bypass-unlock `Meadow` from the admin panel, and custom zone lock input supports future `zoneId:toggle|lock|unlock|bypass` testing.
- Locked portal/pad travel now shows a player-facing notice with the target area's unlock cost instead of only logging `ZoneTravelResult`. Travel hooks also have `ZoneTravelPrompt` proximity prompts for paid locked gates, and the client hides those prompts once the local player owns the destination so unlocked travel stays touch-only.
- Pet config now supports imported asset transform metadata. `asset_transform.scale` normalizes a model's default size, `asset_transform.orientation` fixes imported facing in degrees, and `asset_transform.huge_scale` controls the runtime size multiplier for pets stored with the `huge` trait.
- The Colorado Plays creator pet is configured from two Roblox model assets: normal/rainbow use `100466492312776`, golden uses `121192248833075`. Admin tools can grant basic, golden, rainbow, or huge Colorado for scale/orientation testing.
- The Kade developer pet follows the regular Colorado reward contract and uses packaged Roblox model assets: normal/rainbow use `107161152905013`, golden uses `139643909402590`. Its authored forward axis is corrected by a declarative -90° Y transform that the final local/remote pet render pivot preserves. Admin tools can grant all four visual test forms. Meeting Kade (`536245038`) now grants the once-ever, inventory-only `kade_egg`; it mirrors Colorado's fixed odds (5% Golden, 0.5% Rainbow, 1% Huge) and uses group-owned icon `75293308801530` plus runtime-assembled mesh/texture `103492246635387` / `137761201042755`.
- `PetGrantService` now centralizes pet grants for hatching, admin tools, and Studio scripts. `PetSerialService` allocates global huge serial numbers before the pet is inserted into inventory, so future trading can preserve the entire unique pet record.
- Colorado Plays is currently an eternal pet family. Equip rebuilds cache team-relative `EffectivePower` from the configured eternal percent and top-team-average baseline, while preserving the pet's configured power as the minimum. Huge pets clamp to at least `100%` of that baseline. Inventory pet hover details now show power, base power when different, eternal percent, baseline, huge serials, enchant capacity, and stack count.
- Enchant capacity is now controlled by pet rarity config: Mythic pets get `1` slot, Secret/Exclusive pets get `2`, and Huge pets get `3`. Rarities with enchant slots are granted as unique pet records going forward; normal stacked pets stay stack-only and are not planned for generic stack-to-unique promotion.
- Phase 4 pet progression has a first foundation slice: `configs/pet_progression.lua` and `PetProgressionService` define unique-pet XP curves, max levels by rarity, capped power growth, and enchant slot unlock milestones. New unique pets keep their full potential `max_enchantments` but start with configured `unlocked_enchant_slots` (currently one slot) and gain the rest through levels.
- `configs/enchants.lua` is the single source of truth for enchant chance and behavior. It defines rarity roll profiles, roll counts, weighted chance entries, strength low/high/scale ranges, duplicate policy, reroll cost, and modifier mappings. The initial template ports the useful ColorfulClickers concepts (`HomeWorld`, `Luck`, `SecretLuck`, `Tactics`, `Leadership`, `Efficiency`) into config-first effects and adds this-game examples for crystal rewards, coin rewards, and pet XP.
- `EnchantService` rolls hatch-time enchants for eligible unique pets through `PetGrantService`, exposes server-authoritative manual rerolls through `EnchantPetRequest`/`EnchantPetResult`, and registers equipped unique pet enchants as `enchants` modifier providers. Live enchant consumers now include `breakable_reward`, `collect_radius`, `pet_zone_resonance`, `pet_xp`, `hatch_luck`, `secret_hatch_luck`, `pet_damage`, `team_power`, and `pet_efficiency`.
- Enchant magnitude is resolved through shared `EnchantRuntime` logic for gameplay and UI, including rarity/Huge type scaling. Every configured equipped enchant publishes its own player-bar badge; Active Buffs composes the live modifier pipeline into Attack (Tactics), Pet Speed (Efficiency), Coin rewards, Luck, and the physical Magnet collection radius instead of displaying partial or generic aggregates.
- The saved `crystal_finder` enchant id is retained for profile compatibility but is player-facing **Magnet**. It multiplies the complete server-owned player pickup radius after base reach, the Magnet power, and any larger pet-ability minimum. The exact result is published as `CollectRadius`, which the HUD displays verbatim; an Onyx Exclusive (+30%) raises the common 41-stud base+power setup to 53.3 studs. Auto Collector no longer changes this value: its pass manifests an inventory-free Trail Pup outside `PlayerPets`, chases physical currency with a fixed 11-stud reach, scales travel from `Eff_Speed`, and can neither fight nor draw aggro.
- `Home World` is a per-pet Home-biome resonance floor, not a squad-wide reward modifier. In Grass, Desert, Ice, and Lava, the pet uses `max(normal biome RPS, 1 + rolled/type-scaled Home World magnitude)`; Heaven, Hell, and special zones are unchanged. For an Exclusive pet the five metal tiers provide +5/+10/+15/+20/+25% floors, while a naturally stronger +25% matchup is never reduced.
- Map-authored enchanter stations now bind through `EnchanterStation` hooks. The current Studio `Workspace.Enchanter` model is tagged as `basic_enchanter`, uses its `EnchantTouchPart` child as the touch/prompt volume, keeps its floating cosmetic scripts, and opens a dedicated pet enchant panel for server-authoritative rerolls.
- Equipped unique pets now receive configurable breakable-destroy XP through `PetProgressionService:AwardBreakableDestroyed`. `BreakableSpawner` calls this after contribution rewards, and pet XP can itself be modified by enchant effects such as `scholar`.
- `configs/player_progression.lua` and `PlayerProgressionService` now make player level affect team power through the modifier pipeline and grant extra equipped pet slots at configured level milestones. The initial default is +1% team power per level after level 1, capped at +100%, and +1 equipped pet slot every 10 levels capped at +3 bonus slots.
- `scripts/balance_team_power.py` is available for offline balance passes. It reads current pet/progression/player-progression configs and estimates team power across team size, pet level, eternal/huge rules, and the configured player-level power curve.
- Pet mining still uses a stabilized legacy `Follow` script cloned onto pet models. Phase 4 routes pet damage and efficiency modifiers through it, but a future service-owned PetWork/Combat loop should replace this bridge for cleaner tests and configuration. **Tracked: template issue #4** (do during Phase 4 Combat).
- Huge-and-above provenance is now captured as separate hatcher metadata. Future grants stamp `hatcher_name`/`hatcher_user_id` for pets meeting the configured provenance threshold; `grant_source` remains non-displayed audit data. `tests/studio/BackfillPetHatcherProvenance.lua` can backfill existing qualifying pets for the current Studio player.
- Pet tooltip metadata visibility is driven by `configs/inventory.lua` `tooltip_fields`, so fields can be hidden, labeled, or ordered without editing `InventoryPanel`.
- `MenuManager` temporarily disables Roblox's `PlayerList` CoreGui whenever any full game menu is present in `MenuOverlay`, so the native People list cannot cover Shop, Inventory, or other menu controls. Managed closes, direct panel X closes, panel switches, and manager destruction restore the exact enabled state captured before the first menu opened; individual panels must not own competing CoreGui guards.
- The active tutorial objective owns a responsive upper-right dock rather than the top-center player-bar stack, leaving the main playfield clear. Its dock is scale-only at `{1,0},{0,0}`; arbitrary pixel offsets must not be added because they break placement across screens. While visible it suppresses Roblox's People list; tapping the objective swaps in the People list for ten seconds and then restores the mandatory tutorial automatically. `MenuManager` publishes the `LargeMenuOpen` local-player attribute from actual overlay panel presence; the tutorial yields while any full-size menu is present and restores after every managed or self-close path. After the tutorial, the quest tracker uses that upper-right anchor plus the measured CoreGui PlayerList geometry: a justified 14px rounded-screen top inset, 4px right inset, and 397px width; a shared `TutorialCornerOwned` attribute prevents overlap during the completion handoff. Its Claim action is contained at the lower-left and the standard red close X occupies the upper-right. Project-wide placement follows [UI_LAYOUT_POLICY.md](UI_LAYOUT_POLICY.md): pixel offsets may only be small, locally justified alignment corrections after the responsive layout is established.
- Pet inventory cards now distinguish rarity/specialness and variant separately. Rarity rings are config-driven and can animate around the card using a `UIGradient`; the default rarity ladder currently includes Common, Uncommon, Rare, Epic, Legendary, Mythical, Secret, Exclusive, and Huge. Variant backgrounds are also config-driven, including darker gold and rainbow fills. Inventory display reads rarity names/colors from `configs/pets.lua`.
- Pet-card thumbnails use uploaded, group-owned flat images for the cheap steady state and
  lazily constructed 3D views as the delivery fallback. The client does not catalog-prewarm pet
  textures; only cards a player actually owns request their flat art.
  `AssetPreloadService` does not generate cached ViewportFrames for registered flat pet/egg art;
  those caches exist only for variants with no uploaded thumbnail. Inventory cards use a cheap glyph
  during `None`/`Loading`, stay flat-only after `AssetFetchStatus.Success`, and queue an on-demand
  viewport after `Failure`/`TimedOut`. That viewport is built from the already-loaded model only when
  the failed card enters the visible scroll window, so even a broad CDN outage cannot allocate
  hidden viewports across a large collection. Egg-stand previews and TradePanel pet cards also read
  the flat registry through the shared `PetThumbnailResolver`; secondary card surfaces must not infer
  flat-art availability from the generated ViewportFrame cache.
- Pet power is now config-only durable data. `configs/pets.lua` defines family base power plus global Basic/Golden/Rainbow multipliers, while grant/progression/inventory save paths avoid writing per-copy power or stats power. `tests/studio/BackfillPetPowerSourceOfTruth.lua` can strip legacy saved power fields for the current Studio player.
- `configs/auto_systems.lua` and `AutoTargetService` now provide the first Phase 5 auto-system slice. New profiles start with **Farm Near enabled**; explicit later player choices persist under `Settings.AutoSystems.auto_target`. Clients request initial status without toggling the saved setting, then request auto-target work while the server selects the breakable. The configured modes are nearest, highest value, weakest, strongest, and selected currency.
- Hatch auto-delete filters persist under `Settings.AutoSystems.auto_delete` and are enforced in `EggService` before `PetGrantService` writes inventory. Filters can match rarity, pet family, or variant, and Secret/Exclusive/Huge are protected by default.
- Hatch auto-delete filter state now replicates through `Player.Settings.AutoSystems.AutoDelete`, including `Enabled`, `Rarities`, `PetTypes`, and `Variants` folders. `EggInteractionService` reads and live-binds those folders so the hatch drawer reflects saved filters even if the earlier `AutoTarget_Status` packet was missed during startup.
- The hatch drawer now summarizes saved auto-delete filter count in its header, using config-owned summary strings such as `summary_empty`, `summary_enabled_format`, and `summary_disabled_format`. The summary exposes count attributes for smoke tests and helps players understand when filters are saved but auto-delete is off.
- Egg hatching is treated as two-stage: first roll chooses the pet species, second hidden roll chooses basic/golden/rainbow. Egg previews stay species-only and show basic-form pets, while `egg_sources.<id>.variant_rolls` controls allowed variants and optional cost multipliers such as the starter `20x` no-basic/golden mode.
- Egg preview percentages now use the same relative `pet_weights` denominator as the server hatch roll. Large weights are no longer treated as an implicit out-of-100000 table, so preview odds sum to the real hatch distribution.
- Egg preview cards reuse the inventory's universal identity badges: every species shows its
  archetype and support/control pets also show their configured ability. Hovering a badge explains
  it; touch players can tap the badge to toggle the same tooltip.
- Near-egg hatch controls are now settings-driven instead of always-visible. `Settings.AutoSystems.hatch.action_mode` persists what the E key does (`single`, `max`, or `auto`), the Settings menu exposes this choice plus Show Hatch/Silent Hatch toggles, and the original `EggCurrentTarget` proximity UI is the single egg-side surface. It shows the selected action prompt plus total cost, per-egg cost, max entitlement, and affordability; the separate lower `EggHatchPanel` surface was removed.
- Egg prompt discoverability is developer-configured through `egg_system.ui.interaction_prompt.mode`. The default `clean` mode follows the configured E-key action, while `advertised_hotkeys` can show the legacy `E Hatch | R Max | T Auto` prompt for games that want that onboarding surface.
- Hatch filter UX direction: avoid permanent on-screen filter panels near eggs. Auto-delete filters still exist in the engine and drawer for testing, but the preferred player-facing path is contextual selection through settings, egg preview interactions, or inventory actions such as “do not hatch this pet anymore.”
- Special hatch reveal metadata is driven by `egg_system.hatching.animation`: configured rarities mark per-result special outcomes, aggregate reveal metadata is returned to the client, and Skip Hatch remains a hard animation-suppression preference instead of being overridden by rare outcomes.
- Hatch mode stubs now include Golden and Charged. Golden removes basic variants and uses its configured multiplier; Charged uses its configured multiplier plus hatch-luck and secret-luck bonuses. Both are server-entitlement checked and surfaced through the hatch settings drawer.
- Normal players default to `3` max hatch count. The engine still supports dynamic `1..99` hatching, but higher counts are granted through the `MaxEggHatchCount` entitlement/admin stub rather than given to everyone by config.
- Admin hatch entitlement tools now expose the egg shop stubs before the shop UI exists. Developers can view, lock, unlock, reset, or directly set Auto, Golden, Charged, Fast, Skip, and max hatch count attributes from the admin panel; snapshots include effective hatch entitlement status.
- `HatchEntitlementService` now centralizes server-side hatch shop/unlock stubs. `EggService` and `AdminToolsService` read the same effective entitlements for Auto, Golden, Charged, Fast, Skip, max hatch count, hatch-luck bonus, and secret-luck bonus, so future shop code has one resolver to call.
- Hatch settings education is now config-driven. `configs/egg_system.lua` owns help copy for core hatch controls, mode toggles, and auto-delete filters; the hatch drawer renders a `HelpText` line and the interactive controls carry `HelpText` attributes for hover/focus updates.
- Hatch auto-delete protection is visible in the hatch settings drawer. The client reads `configs/auto_systems.lua` through `Locations.getConfig("auto_systems")`, renders the protected rarity list from `auto_delete.protected_rarities`, and exposes the list as `ProtectedRarities` UI metadata for Studio smokes.
- Auto-hatch failure feedback now explicitly stops with a reason for no-currency and no-storage sessions, and the client loop also reports when the player moves too far away, e.g. `Auto hatch stopped: out of currency`, `Auto hatch stopped: storage full`, or `Auto hatch stopped: too far away`.
- Rapid manual re-entry still shows the red **Please wait before hatching again** card, now paired
  with a responsive adjacent blue teaching card: **Hatch Fast with Auto Hatch in the Pets Menu**.
  Other egg errors remain single-card notices, and repeated input replaces rather than stacks the UI.
- Hatch reveal markers are now config-driven. `egg_system.hatching.animation.reveal_badges` controls rarity, variant, special, and auto-delete badges, and `EggHatchingService:GetActiveAnimationDebugState()` lets Studio smokes inspect the live client animation contract without relying on screenshots.
- Hatch mode education now reads player entitlement state. The settings drawer grays locked modes, stores `ModeState`/`ModeOwned` attributes on each mode toggle, shows a `ModeStatus` summary, and uses config-driven locked/available/active help text.
- Server hatch debugging now has a bounded recent-history path. `EggService` records successful and rejected hatches with request count, actual count, cost, stop reason, options, entitlements, sampled results, auto-delete counts, special counts, and authored animation metadata. Admin tools expose this through `Admin_RequestHatchHistory`, and the admin panel has a Recent Hatch History action.
- Egg source unlock requirements are now server-authoritative for both real hatches and no-mutation hatch simulations. `egg_sources.<id>.unlock_requirement` can point at a stat/counter threshold, rejected hatches return `egg_locked` with current/required progress, and auto-hatch feedback maps that code to `locked egg`.
- Studio hatch forcing now uses player `ForcePet`/`ForceVariant` attributes directly before the roll, avoiding the earlier copied-config gotcha where mutating `Locations.getConfig("pets")` did not reliably affect `simulateHatch`.
- `ConfigLoader` now validates the expanded egg-system hatch contract, including hatch count relationships, debug/history limits, animation capacity, reveal badge field types, shop max-count defaults, and hatch-panel button labels.
- Egg hatching has a no-mutation simulation path for admin/testing. `EggService:SimulateHatchBatch` rolls the same server pet/variant/luck pipeline and reports costs, counts, auto-delete matches, special reveal counts, and animation metadata without spending currency, granting pets, incrementing stats, or playing client animation. Admin tools expose this through `Admin_RequestHatchSimulation`.
- The near-egg hatch panel now reads the same effective Max Hatch and Auto Hatch entitlement state that the server uses. Selected hatch count clamps to player/config max entitlement, controls expose `MaxEntitledHatchCount`, and locked Auto is grayed/blocked client-side before the server-authoritative rejection path.
- Hatch animation presentation has another config-first slice. `egg_system.hatching.animation.layout` controls grid padding and min/max egg sizes, `special_glow` controls the special hatch rarity stroke/pulse, and the client animation debug state exposes layout/glow metadata for Studio smokes.
- Fast Hatch presentation speed is no longer hardcoded in `EggHatchingService`. `egg_system.hatching.animation.fast_hatch_speed_scale` owns the duration multiplier, `ConfigLoader` validates it, and the animation debug state exposes resolved Fast/Silent timing metadata.
- Hatch selected count is now a persisted player setting. The near-egg panel writes changes through `HatchSettings_SetCount`, `SettingsService` stores them under `Settings.AutoSystems.hatch.selected_count`, and clients restore the replicated `Player.Settings.AutoSystems.Hatch.SelectedCount` value when the hatch panel is rebuilt.
- Hatch mode toggles are now persisted player preferences too. `SettingsService` sanitizes the configured hatch mode keys, stores them under `Settings.AutoSystems.hatch.modes`, replicates `Player.Settings.AutoSystems.Hatch.Modes`, and `EggInteractionService` restores/persists Show, Golden, Charged, Fast, Skip, and Silent toggles while the server still enforces entitlement on hatch requests.
- The near-egg hatch panel now listens to replicated hatch setting changes after startup. Live `SelectedCount`/mode value changes update the visible panel, and the panel exposes cost metadata (`BaseCostEach`, `CostMultiplier`, `EstimatedCostEach`, `EstimatedTotalCost`, `EstimatedAffordableCount`) plus a compact per-egg affordability detail line.
- The selected hatch count control is now editable in addition to +/-/Max buttons. Players can type a numeric count directly into the near-egg panel, and the client clamps/persists it through the same server-backed selected-count setting.
- The near-egg hatch panel now has config-driven responsive scaling. `configs/egg_system.lua` owns `ui.hatch_panel.responsive`, `ConfigLoader` validates its scale bounds, `EggInteractionService` applies a `UIScale` against the current viewport, and tests cover desktop/mobile fit math.
- Skip Hatch is enforced as an animation-suppression preference in both hatch presentation layers. The interaction service does not start hatch animation when resolved options include `skipHatch`, and `EggHatchingService` also returns an immediate completed/skipped result without enabling the animation GUI if called directly with `skipHatch`.
- Show Hatch is a free, default-on hatch presentation preference. Players can turn it off to hide hatch animations without owning Skip Hatch; the setting persists under `Settings.AutoSystems.hatch.modes.showHatch`, flows through the server hatch options, and makes `EggHatchingService` return the same immediate skipped presentation result.
- Hatch animation now has max-count Studio coverage. `EggHatchingService` falls back to a resolved `1280x720` animation viewport if Studio reports an uninitialized tiny camera size, exposes container/frame geometry in its debug state, and `EggAnimationMaxBatchSmoke` verifies all `99` authored egg frames fit in the compact `10x10` layout.
- Hatch mode education now surfaces configured economics. Golden/Charged mode UI reads cost and luck values from `egg_system.hatching.shop_stubs`, exposes `CostMultiplier`/`LuckBonus`/`SecretLuckBonus` attributes for tests, and includes those details in help/status text.
- Expanded hatch drawer layout is now covered without relying on screenshots. `EggProximitySmoke` opens the real `PlayerGui` drawer, verifies responsive desktop/mobile fit math, and asserts visible drawer controls stay inside the configured drawer bounds.
- Special hatch reveal now includes a config-driven backdrop layer. `egg_system.hatching.animation.special_backdrop` controls a rarity-colored backdrop behind special pet reveals, `ConfigLoader` validates it, and animation debug state exposes the backdrop contract for Studio smokes.
- Egg-system config validation now cross-references hatch special rarity ids and hatch auto-delete drawer filter ids against pet config. `hatching.animation.special_rarities` must reference `pets.rarities`, while hatch drawer `rarity_filters`, `pet_type_filters`, and `variant_filters` must reference configured rarities, pet families, and variants.
- Hatch result stacking is now config-driven. `egg_system.hatching.animation.result_stack` controls whether duplicate hatch results collapse, whether name/count labels show, the minimum count label threshold, tween timing, and hold duration. The animation debug state exposes stack group/count/name metadata for Studio smokes.
- Hatch-result pet reveals consume `pet_thumbnail_assets` directly, with generated ViewportFrames only
  for catalog entries missing flat art. The animation debug state and `EggAnimationContractSmoke`
  assert that the actual reveal image is visible, not merely its rarity/variant badges.
- Egg authoring and hatch-admin testing now have a dedicated project doc at `docs/EGG_AUTHORING_AND_ADMIN_TESTING.md`. It records the current authored `EggStand` stamping contract, two-stage hatch model, hatch entitlement stubs, Show Hatch vs Skip Hatch behavior, and Studio smoke commands.

## Phase 0 Verification

Last checked: 2026-05-26

- `python3 scripts/wiki_status.py`: passes.
- Rojo 7.6.1 build: passes with `rojo build --output /tmp/rbx-template-phase0.rbxl`.
- Selene 0.25.0: passes with `selene --allow-warnings src configs tests`; current result is 0 errors, 646 warnings.
- StyLua 0.18.2 check: fails because the existing codebase has broad formatting drift. Treat formatting cleanup as a separate cleanup lane, not a Phase 0 blocker.
- Studio MCP smoke test: passes. `RBX-Template` is the active Studio instance, play mode starts/stops through MCP, screen capture works, and console output is readable.

## Phase 1 Verification

Last checked: 2026-05-27

- Rojo 7.6.1 build: passes with `rojo build --output /tmp/rbx-template-phase1-full.rbxl`.
- Targeted Selene for Phase 1 touched files: 0 errors, existing warnings only in legacy/bootstrap files.
- Full Selene: passes with warnings from the existing codebase.
- StyLua check for Phase 1 touched files: passes.
- ConfigLoader unit specs pass in Studio (`30` passed, `0` failed) and cover valid area/marker schemas plus missing-parent, cycle, and unsupported marker-attribute failures.
- Studio MCP smoke test: latest expected generated hook counts are `Zone=5`, `AreaZone=2`, `SpawnZone=2`, `EggStand=1`, `PODPodium=2`, `TeleportPad=2`, `Portal=2`. Earlier Phase 1 verification used two egg stands before golden hatching moved into `basic_egg` variant-roll config.
- Active-zone dormancy smoke check passes: after boot, Spawn had spawned breakables and Meadow had `0`; after `TravelSmoke` unlocked/traveled to Meadow, Meadow filled to its configured `8` breakables.
- Travel smoke test passes through MCP with `TravelSmoke`. It verifies locked travel rejection, unlock, server-authoritative movement to Meadow, active-area update, and state restoration.
- Egg proximity smoke test: passes through MCP with `EggProximitySmoke`. It verifies far hatch rejection, near hatch success, UI target state, currency deduction, pet inventory increase, and state restoration.
- Authored reference map smoke should now expect one authored `EggStand` for `basic_egg`; rerun `MapContractSmoke` after regenerating the reference map.
- Spawn safety smoke passes through MCP with `SpawnSafetySmoke` for `Spawn`: the player is placed above a real floor, vertical velocity is cleared, and active area state is synchronized.

## Phase 2 Verification

Last checked: 2026-05-27

- Rojo 7.6.1 build: passes with `rojo build --output /tmp/rbx-template-phase2-slice.rbxl`.
- Targeted StyLua check/format for touched Phase 2 files: passes.
- Targeted Selene for touched Phase 2 files: 0 errors, existing warnings only in older bootstrap/inventory/data/config files.
- `ConfigLoader.spec` passes in Studio with `33` passed and `0` failed, including upgrade config validation.
- `Phase2ProgressionSmoke` passes through MCP: locked Meadow rejects without crystals, paid Meadow unlock succeeds, pet equip-slot upgrade increases max pet slots from `3` to `4`, pet storage increases from `50` to `75`, and profile state is restored.
- The same Phase 2 smoke verifies `crystal_value` as a real modifier path: a base `100` crystal breakable reward resolves to `110` after level 1, proving player-specific upgrades are included in breakable reward resolution.
- Locked-zone responses include config-driven unlock requirements, so future UI can show cost/currency/prerequisite without hardcoding Meadow.
- `MeadowBreakableSmoke` verifies the first full area-gated mining loop: it unlocks/travels to Meadow, spawns a deterministic `BigBlueCrystal` through `BreakableSpawner`, breaks it through the normal contribution/death handler, pays `110 crystals` through the upgrade-aware economy path, increments `breakables_broken`, and restores the profile.
- `SyntheticExpansionSmoke` verifies the Phase 2 expansion contract without permanently changing the authored map: it temporarily injects a second synthetic world (`crystal_world -> CrystalCavern`), rebuilds bindings in synthetic mode, asserts a cross-world portal and spawn zone, travels through the portal, restores profile/map state, and leaves the authored-only marker contract at `synthetic=0`.
- Regression smokes still pass: `SpawnSafetySmoke`, authored-only `MapContractSmoke`, `TravelSmoke`, and `EggProximitySmoke`.

## Phase 3 Verification

Last checked: 2026-05-27

- Rojo 7.6.1 build: passes with `mise exec -- rojo build --output /tmp/rbx-template-phase3.rbxl`.
- Targeted StyLua check/format for touched Phase 3 files: passes.
- Targeted Selene for touched Phase 3 files/configs/tests: 0 errors, existing warnings only in older bootstrap/config/inventory/data files.
- `ConfigLoader.spec` passes in Studio with `36` passed and `0` failed, including pet index, achievements, and leaderboard config validation.
- `Phase3StatsSmoke` covers adding bear/basic twice and bunny/basic as only `2` distinct pet
  entries, syncing `distinct_pets=2`, the first pet-index milestone, the first `eggs_hatched`
  achievement, the live Crystal Crusher board, and profile restoration.
- Phase 2 regression smoke still passes after Phase 3 profile/inventory changes: `Phase2ProgressionSmoke`.
- `EternalPowerSmoke` exists as a Studio runner for verifying cached eternal pet power after Rojo sync/restart.

## Phase 4 Verification

Last checked: 2026-05-27

- Rojo 7.6.1 build: passes with `mise exec -- rojo build --output /tmp/rbx-template-phase4-enchants.rbxl`.
- Targeted Selene for touched Phase 4 files/configs/tests: 0 errors, existing warnings only in older bootstrap/inventory/breakable/config files.
- `python3 scripts/wiki_status.py`: passes.
- `git diff --check`: passes.
- `Phase4PetProgressionSmoke` passes through Studio MCP after Rojo sync/restart. It granted a Huge Rainbow Colorado, verified a hatch-time enchant, awarded `25` pet XP from a `BigBlueCrystal` breakable context, rerolled enchant slot `1`, verified player-level slot bonus `1`, verified live hatch luck `0.1`, secret luck `0.05`, pet damage about `115`, team power `131.1`, pet efficiency `1.1`, and restored profile state.

## Phase 5 Verification

Last checked: 2026-05-29

- Rojo 7.6.1 build: passes with `mise exec -- rojo build --output /tmp/rbx-template-phase5-auto.rbxl`.
- Targeted Selene for touched Phase 5 files/configs/tests: 0 errors, existing warnings only in older bootstrap/data/settings/breakable files.
- Targeted StyLua check for the new/clean Phase 5 files passes.
- `git diff --check`: passes.
- `Phase5AutoSystemsSmoke` passes through Studio MCP after Rojo edit-mode sync. It creates a temporary `Phase5Smoke` breakable world, verifies nearest/highest value/weakest/strongest/selected-currency server target selection, verifies auto-delete rarity/type/variant matches, verifies protected Exclusive Colorado is not auto-deleted, and restores profile/map state.
- `HatchEntitlementAdminSmoke` passes through Studio MCP after stopping Play to let Rojo sync the new module, then restarting Play. It verifies status, lock-all, unlock-all, reset-all, and max hatch count changes for hatch entitlement attributes, then restores the player's original state.
- `EggProximitySmoke` passes through Studio MCP with the hatch drawer help-text contract. It verifies the near-egg panel, expected Hatch/Max/Auto/count controls, mode/filter controls, and config-driven help metadata.
- `EggProximitySmoke` also verifies locked hatch-mode education: mode controls expose locked state/help attributes and the drawer renders a locked-mode status summary.
- `EggAutoHatchSmoke` passes through Studio MCP. It initializes isolated client egg targeting/hatch panel services, verifies auto-hatch stop feedback for zero currency, zero pet storage, and moving out of range, then restores the profile.
- `StudioSmokeTestService` now supports `setupPetInventoryEmpty` for egg smokes so storage-limit tests can avoid accidental success through existing pet stacks.
- `EggAnimationContractSmoke` passes through Studio MCP. It creates a synthetic special Exclusive Rainbow Colorado and an auto-deleted Common Bear hatch, then verifies frame metadata, rarity/variant/special/auto-delete badges, and visible reveal-state updates.
- `EggHatchHistorySmoke` passes through Studio MCP. It verifies a deterministic auto-deleted batch hatch is recorded in server history with cost, count, sampled pet result, and auto-delete metadata.
- `ConfigLoader.spec` passes through Studio MCP in Play mode with `52` passed, `0` failed, and `0` skipped, including the egg-system validator coverage.
- `EggHatchSimulationSmoke` passes through Studio MCP. It forces a deterministic `7`-egg basic hatch simulation and verifies result counts plus no currency, inventory, or `eggs_hatched` counter mutation.
- `EggProximitySmoke` passes through Studio MCP with the effective hatch entitlement UI contract. It now asserts a configured `MaxEntitledHatchCount` and locked Auto control state in addition to the near-egg hatch transaction.
- `EggProximitySmoke` also verifies replicated auto-delete settings reach the hatch drawer from `Player.Settings.AutoSystems.AutoDelete`, covering enabled state plus saved rarity, pet-family, and variant filters.
- `EggProximitySmoke` also verifies the auto-delete drawer summary counts selected saved filters. A direct Studio screenshot capture attempt timed out locally, so automated geometry/debug-state coverage remains the reliable hatch drawer QA path for now.
- `EggAutoHatchSmoke` still passes after the entitlement UI change, covering no-currency, no-storage, and too-far stop feedback.
- `EggAnimationContractSmoke` passes through Studio MCP after the hatch animation config polish. It verifies reveal badges plus configured grid layout metadata and special glow pulse metadata.
- Direct Studio validation of the new `egg_system` config rules passes: current config validates, invalid layout min/max fails, and invalid special glow transparency fails.
- `EggAnimationContractSmoke` also verifies configured Fast/Silent hatch timing metadata, and direct Studio validation rejects `fast_hatch_speed_scale` values above normal speed.
- `EggProximitySmoke` also verifies selected hatch count persistence by saving a count through the client interaction service, reading the replicated player setting/debug state, and resetting to one before the hatch transaction.
- `EggProximitySmoke` also verifies hatch mode persistence by toggling Silent Hatch through the client interaction service, reading the replicated hatch mode setting/debug state, and restoring the original value before the hatch transaction.
- `EggProximitySmoke` also verifies the responsive hatch panel layout contract: full scale on a desktop-sized viewport, scaled down and width-safe on a mobile-sized viewport.
- `EggAnimationMaxBatchSmoke` passes through Studio MCP. It starts a `99`-egg authored hatch animation, verifies the compact `10x10` layout, checks every frame stays inside the resolved animation viewport, and confirms all frames use the authored egg visual.
- `EggProximitySmoke` also verifies the hatch settings drawer exposes Golden/Charged cost and luck details from config.
- `EggProximitySmoke` also verifies the expanded hatch settings drawer renders with nonzero dimensions and no clipped visible controls.
- `EggAnimationContractSmoke` now verifies special hatch backdrop metadata, reveal visibility, and Skip Hatch suppression at the animation-service boundary; `ConfigLoader.spec` covers invalid backdrop transparency.
- `EggAnimationContractSmoke` also verifies configured stacked hatch result labels by hatching duplicate Bear results and checking the `Bear x2` stack metadata.
- `EggUnlockSmoke` passes through Studio MCP. It verifies `golden_egg` rejects at `9/10` configured hatch progress with `egg_locked`, succeeds at `10/10`, deducts the effective golden egg cost, grants one pet, and restores the profile/map state. `ConfigLoader.spec` now passes with `58` passed, `0` failed, and `0` skipped after adding unlock-requirement shape validation.
- `EggHatchSimulationSmoke` and `EggBatchHatchSmoke` still pass after the unlock gate change, covering the basic simulation and broader batch hatch regression paths.
- Final egg-system audit on 2026-05-29 passed local Rojo/Selene/StyLua/wiki/diff checks plus Studio MCP smokes for `EggAutoHatchSmoke`, `EggProximitySmoke`, `EggAnimationContractSmoke`, `EggHatchSimulationSmoke`, `HatchEntitlementAdminSmoke`, `EggBatchHatchSmoke`, `EggAnimationMaxBatchSmoke`, and `EggUnlockSmoke`.

## Admin/Map Test Verification

Last checked: 2026-05-27

- Studio MCP admin zone-lock smoke passes: it verifies Meadow travel rejects while locked, admin bypass unlock succeeds, portal/pad travel reaches Meadow, admin lock re-locks Meadow, and profile/travel state restores.
- Studio MCP prompt state smoke passes: locked Meadow shows the `Unlock 100 crystals` prompt, unlocking Meadow hides it for that player, and touch/server travel still moves to Meadow.

## Automation API & Remote Dev Pipeline

Last checked: 2026-05-29

- The template now has a GUI-bypassing **command boundary** so tests and tools can drive the game below the UI. `src/Shared/API/CommandBus.lua` is a pure dispatcher (register/execute, uniform `{ok, code, result}` envelope, arg validation via `src/Shared/API/Validators.lua`, test-only gating, origin tracking). `GameAPIService` owns the bus, exposes a single `GameAPICommand` RemoteFunction (untrusted clients, `isTest=false`) plus a server-side `:Execute`, and registers adapter commands that delegate to existing services via the `_G.RBXTemplateServices` locator (economy, zone, egg, inventory) — services are not rewritten.
- `AutomationService` (Studio-only) is the runtime test driver: pathfinding `NavigateTo` (with a client `AutomationControlBridge` that disables player controls during automated movement), `SnapshotState`/`RestoreState`, `TeleportForSetup`, and `GetPlayerState`, exposed as test-only `automation.*` commands. A Studio-only `RunAutomationSuite` RemoteFunction lets an MCP-driven client trigger the server-side suite.
- A **headless test loop** runs pure-logic specs with no Studio: `mise run test-headless` (lune) over `tests/headless/specs/*.spec.luau`, currently 35/35 across CommandBus, Navigation, Validators, TestReport, and the runner self-test.
- A **fast gate** `mise run ci` (selene + StyLua on owned paths + `rojo build` + headless) runs locally and in GitHub Actions (`.github/workflows/ci.yml`) on every push.
- A **release path** exists: `scripts/release.sh` / `mise run release` wraps `rojo upload` (Open Cloud), reading `ROBLOX_OPEN_CLOUD_KEY`/`ROBLOX_UNIVERSE_ID`/`ROBLOX_PLACE_ID` from env, refusing if unset (`DRY_RUN=1` validates).
- **Testing methodology** is documented in `REMOTE_DEV_PIPELINE.md`: (1) headless pure logic, (2) primary = server-side command-bus integration asserting authoritative state, (3) thin UI sanity via the MCP (`character_navigation` + `user_mouse_input`/`user_keyboard_input`) with 1–2 decisive screenshots. State proves; pixels confirm.

### Automation Pipeline Verification

Last checked: 2026-05-29

- `mise run ci` green: selene 0 errors, StyLua clean on owned paths, `rojo build` passes, headless 35/35.
- GitHub Actions fast gate green on `template/automation-api`.
- Live in Studio (Place1, Rojo on this branch): production network path verified — `system.listCommands` returns 13 network-visible commands (test-only hidden), economy/zone/egg/inventory adapters dispatch against live services, validation rejects bad args, and `test.*`/`automation.*` are forbidden over the network.
- Server-side `AutomationSuite` passed 11/11 incl. `snapshot → grant → coins increased → teleport → restore → coins restored` against `DataService`.
- Full UI-driven E2E verified live: `character_navigation` to the egg (proximity UI triggered) and a `user_keyboard_input` `E` hatch → server granted a pet (`inventory.slots{pets}` used 0→1, coins 100→0).
- Two bugs found live and fixed: `_service` now pcalls the locator (Get raises on unregistered names); `EggService` (direct-required at boot) is reached via a dedicated `_eggService()`.
- Observed (unresolved): HUD vs Pet Shop currency displays disagree for the same player — possible UI sync bug, separate from this work.
- **Release stage verified live**: `mise run release` published the build to the Rojo-owned staging experience (universe `10242349813`) via Open Cloud `rojo upload` (exit 0). The full develop → test → build → release pipeline is proven end-to-end. Gotchas (key needs `universe-places:write`; Universe ID ≠ Place ID; close the place in Studio before publishing) are documented in `REMOTE_DEV_PIPELINE.md`.

## Halo & Horns — Phase 0 (Data Spine)

Last checked: 2026-05-30

The config-driven world model + alignment + themed currencies, built test-first
(pure cores headless-tested, then wired to a service and verified live). All pure
logic is Roblox-API-free and consumes injected config (config-as-code).

- **0.1 Ring topology** (Feature 1): `configs/biomes.lua` (clockwise order
  earth→ice→lava→desert→beach, theme, dichotomy earth↔desert/ice↔lava, themed
  currency) + pure `src/Shared/Game/RingTopology.lua` (neighbors w/ wrap, theme,
  dichotomy, currency, adjacency). Adding a biome is config-only.
- **0.2 Soul stat** (Feature 2): `configs/soul.lua` (delta 5, range ±100,
  Halo/Horns bands) + pure `src/Shared/Game/SoulMath.lua` (`applyConquest`:
  clockwise +delta / ccw −delta / non-adjacent 0 / first-conquest / re-conquest
  no-op / clamp; `alignment` label). `AlignmentService` persists
  Soul/LastConqueredBiome/ConqueredBiomes via DataService (lazy-init, no schema
  migration).
- **0.3 Themed currencies** (Feature 4): `configs/layers.lua` (reward multipliers
  base 1.0 / Heaven·Hell 1.5–2.0; Light/Shadow tokens) + pure
  `src/Shared/Game/RewardResolver.lua`. Themed currencies registered (non-tradeable)
  in `configs/currencies.lua`.
- **Bus commands**: `world.ringInfo`, `soul.get` (reads); test-only `game.conquer`
  / `game.resetAlignment`.

Verification:
- Headless `mise run test-headless`: 69/69 across 9 specs (ring/soul/reward unit
  scenarios + an interconnected conquest-flow integration test). `mise run ci` green.
- Live in Halo & Horns (Rojo connected): `AutomationSuite` 18/18 incl. the
  alignment chain (ring info, reset→conquer→soul 5→halo, persisted via DataService).

Deferred (with reasons, per the implementation plan):
- Soul HUD + real-time meter/notification ([studio]) — no UI yet (UI phase).
- Live themed-currency breakable drops + Light/Shadow token drops ([integration])
  — need biomes/layers present in the world (Phase 2).
- Currency non-tradeable enforcement — needs trade (Phase 6).
- Formal ProfileStore schema entry + migration for Soul fields — currently
  lazy-initialized; can be formalized when convenient.

## Halo & Horns — Phase 1 (Pets & Power)

Last checked: 2026-05-30

Pet element identity + runtime power, built test-first (pure cores headless, then
wired live). Power is always computed, never persisted.

- **Element resonance** (Feature 6): `configs/elements.lua` + pure
  `src/Shared/Game/ElementResonance.lua` (light/shadow opposing-dominant 1.5,
  home 1.2; chaotic flat 1.3; neutral 1.0).
- **Theme utility** (Feature 6): `configs/theme_utility.lua` + pure `ThemeUtility`
  (passive active only in the theme's dichotomy biome). Module tested; live
  wiring waits on pets gaining a biome `theme` (they currently have `category`).
- **Power formula** (Feature 6): pure `PowerFormula` — multiplicative base ×
  variant × level × enchant × element × theme_utility × stack × buff (rounded).
- **Element at hatch** (Feature 5): `configs/layers.lua` `hatch_element` +
  `realm_alignment` maps + pure `PetElement` (elementForLayer, realm alignment,
  element-in-stack-key). `PetGrantService` stamps `petData.element` from the hatch
  layer (base → neutral now; Heaven/Hell activate with LayerService in Phase 2);
  additive field, no schema migration.
- **Bus command** `pet.power`: base × variant × element-resonance for a context
  (never persisted); test-only `game.grantPet` returns the granted record.

Verification:
- Headless `mise run test-headless`: 94/94 across 13 specs (all Feature 5/6 [unit]
  scenarios). `mise run ci` green.
- Live in Halo & Horns: `AutomationSuite` 25/25 incl. element neutral at grant,
  power-not-persisted, and resonance arithmetic (bear: neutral 10 / Hell 15 /
  Heaven 12; golden 15).

Deferred (with reasons):
- Element-in-stack-key — intentionally **not** used in the realized content model.
  Realm eggs hatch separate pet IDs/species (base/Heaven/Hell catalog entries), so
  stacks split naturally by pet id; element remains record metadata and power context.
- Theme-utility on live pets — needs pets to carry a biome `theme` (content/Phase 2).
- Power recalc on live biome/layer travel ([studio]) — needs the world (Phase 2);
  dynamic recalc is already shown via `pet.power` varying by realm with no save.
- Element via fusion (chaotic) — Phase 6 fusion.

## Halo & Horns — Phase 2 (Heaven Vertical Slice — logic)

Last checked: 2026-05-30

Layer access & portals (Feature 3) as server-authoritative logic; Heaven farming
reward scaling (Feature 11) is already covered by RewardResolver (Phase 0.3). The
**logic half of the vertical slice is done and live-verified**; the **visual half
(authored stacked geometry + portals + actual teleport) is deferred to map work.**

- **Layer access** (Feature 3): `configs/layers.lua` gains per-layer `access`
  (y_offset, requires_soul, token_cost) for base + heaven_1/2/3 + hell_1/2/3. Pure
  `src/Shared/Game/LayerAccess.lua` (canAccess: Heaven soul>=req, Hell soul<=req,
  cross-path visit ignores Soul, token cost; accessibleLayers).
- **LayerService** (server): AccessibleLayers + UseLayer — re-validates cost from
  config (never trusts client), deducts the token currency via DataService, sets
  `profile.CurrentLayer` (lazy-init/persist). GameAPI commands: `layer.current`,
  `layer.accessible` (reads), `layer.use` (mutate, server-authoritative).
- **Cross-cutting activations**: with `CurrentLayer` set, Heaven hatches now stamp
  `light` element (Feature 5) and `pet.power` defaults its realm to the current
  layer (Feature 6 dynamic recalculation — power follows where you are).

Verification:
- Headless `mise run test-headless`: 104/104 across 14 specs (Feature 3 [unit]
  access scenarios). `mise run ci` green.
- Live in Halo & Horns: `AutomationSuite` 36/36 incl. base default, ring-tour →
  soul 20, ascend to heaven_1 (100 light tokens deducted, server-validated),
  reject-without-tokens / reject-Hell-with-positive-soul, Heaven-hatch → light
  element, and pet.power realm following the current layer.

Deferred — needs authored map work (your hands in Studio):
- Stacked Y-offset geometry (base 0, heaven +2000/4000/6000, hell −2000/…) and the
  **visual portals + actual character teleport** ([studio]). `LayerService` sets
  the logical layer + cost now; the teleport binds when the geometry exists.
- StreamingEnabled radius tuning for the stacked world.
- Heaven farming live drops + Light-token drops ([integration]) — need breakables
  placed in the biomes/layers (world content). Reward math (RewardResolver) is done.
- Cross-path "visit" portals — pure logic supports it; wiring waits on authored
  visit portals (it's intentionally not a client-settable flag).

## Halo & Horns — Phase 3 (Pet Party Core)

Last checked: 2026-05-30

Spirit Form, the stacked-pet token-bucket pool, and the active-squad hierarchy —
pure cores test-first, then wired live.

- **Spirit Form** (Feature 7): `configs/spirit_form.lua` (cooldown tiers; Heaven 2×
  recharge) + pure `SpiritForm` (effectiveCooldown, status, down, instantRecharge).
  `SpiritFormService` persists lastDownedAt/cooldown_seconds on unique pet records
  (by uid) and auto-returns a downed pet from the squad.
- **Stack Pool** (Feature 8): `configs/stack_pool.lua` + pure `StackPool`
  (token-bucket: newStack, lazy refresh, down, linear & sqrt_diminishing
  contribution, add/remove). `StackPoolService.Simulate` runs the model live.
- **Active Squad** (Feature 9): `configs/squad.lua` (limits; 5s in-combat swap
  cooldown) + pure `ActiveSquad` (canDeploy max, canSwap cooldown).
  `ActiveSquadService` owns `profile.ActiveSquad` (deploy/remove/swap; ownership +
  Spirit-Form gating; stacked pet = 1 slot; swap cooldown session-only).
- **Bus commands**: `squad.get/deploy/remove/swap`, `spirit.status`,
  `stack.simulate`; test-only `game.downPet/rechargePet`; `game.grantPet` gained
  `huge` (unique-record) support.

Verification:
- Headless `mise run test-headless`: 129/129 across 17 specs (Feature 7/8/9 [unit]
  incl. token-bucket 29/cap/80/~89.4, cooldown/Heaven-halving, squad limits/swap).
  `mise run ci` green.
- Live in Halo & Horns: `AutomationSuite` 49/49 incl. deploy → down → auto-return
  + Spirit Form → redeploy blocked → instant recharge → redeployable, and the
  stack-pool model.

Deferred (with reasons):
- Staged degradation visuals (Strained/Critical auras), the real combat **down**
  trigger, the Recall command, and "all-squad-downed → graceful end" — [studio] /
  combat (Phase 4). Downing is exposed as a test command now.
- StackPool bound to real inventory stacks (ready_count decremented by combat
  downs) — Phase 4; the pool math is live-verified via `stack.simulate`.
- In-combat swap cooldown live verification ([studio]) — logic tested headless +
  in the service; live combat-swap arrives with combat.

## Halo & Horns — Phase 4 (Combat & Focus)

Last checked: 2026-05-30

Combat (Feature 10) + the player Focus/Spirit-Presence model (Feature 12) +
the legacy pet-damage refactor (issue #4) — pure cores test-first, then services,
then live through the bus.

- **Focus** (Feature 12): `configs/focus.lua` (focus_max 100, regen 5/s,
  `regen_pauses_at_zero=false`) + pure `FocusMath` (cast/canCast, regen clamp,
  sunder clamp-to-0). `FocusService` owns the runtime-only pool (lazy-init to max) and a
  CharacterAdded **invulnerability** hook (MaxHealth=∞, Dead state disabled — no HP,
  can't die). A mode may set transient `FocusMaxMultiplier` and `FocusRegenMultiplier` Player
  attributes; the first changes the contextual cap, while the second scales base regeneration.
  Neither changes shared config or persists current Focus. Open design Q resolved (always
  regenerate; DECISIONS.md).
- **Combat** (Feature 10): `configs/enemies.lua` (hp, attack {damage,cadence,
  sundering}, drop_table) + `configs/combat.lua` (spawners, auto_target nearest,
  group_scaling, pet-down threshold). Pure `Targeting` (nearestEnemy) +
  `CombatMath` (damage/defeat/encounter-end/group-scaling/sunder/deterministic
  loot) + `CombatSim` (dependency-injected deterministic full fight).
  `CombatService` exposes read-only `Simulate` plus the real interconnections:
  `AwardLoot` → currency, `SunderPlayer` → FocusService, `DownPetInCombat` →
  SpiritFormService (the **combat down trigger** deferred from Phase 3; auto-returns
  the pet from the squad).
- **Legacy refactor** (issue #4): pure `PetCombat` (damagePerHit floor+min1,
  applyDamage clamp+contribution, attackInterval clamp) + `CombatService:ResolvePetDamage`
  / `ResolvePetAttackInterval` route pet power through the ModifierService pipeline
  (pet_damage / pet_efficiency) then PetCombat — one tested source of truth. The
  cloned `PetScripts/Follow.server.lua` now prefers the service path with a
  behavior-identical inline fallback (no mining-loop regression). `Targeting`
  covers the pure movement-targeting side.
- **Bus**: `focus.get`, `combat.simulate` (read); test-only `focus.cast/regenTick`,
  `combat.sunder/awardLoot/downPet`. `Validators` gained a `table` type.

Verification:
- Headless `mise run test-headless`: 166/166 across 21 specs (Feature 10/12 +
  issue #4 cores; incl. CombatSim full-fight loot 62/8, 4p group-scale 2500,
  pet-down threshold, focus cast/regen/sunder clamps). `mise run ci` green.
- Live in Halo & Horns: `AutomationSuite` 64/64 incl. focus cast→80 / over-cast
  rejected / Sundering brute −20, combat.simulate clears hell_1_lava (5 defeated,
  62 lava_coins + 8 shadow_tokens), and combat.downPet → Spirit Form (trash_mob)
  → squad auto-return. Also fixed a latent light_tokens state-pollution flake in
  the suite.

Deferred — needs the user's hands (authored map) or a decision:
- **Authored Hell combat zone + enemy spawner markers** ([studio]): live enemy
  *spawning*, pet auto-attack *traversal*, the 0-damage *player-invuln visual*,
  and the ethereal alignment aura. The resolution math + economy/Spirit-Form/Focus
  interconnections are done + live-verified through the bus; what remains is
  in-world geometry/models.
- ~~Full removal of the cloned `PetScripts/*`~~ — **DONE** (issue #4 closed, see
  the PetFollowService section below).

## Pet movement (issue #4) — service movement restored (anchored + client-driven)

Last checked: 2026-08-13

**Real-hit role choreography is live in source.** `Combat_PetHit` now starts a short procedural
contact/recovery envelope in `PetAttackMotion`, layered at the final render pivot for both the
owner and nearby observers. Role defaults cover the roster; the FTUE quartet is deliberately
distinct: Doggy lunges, Bear body-slams, Kitty recoils with its existing projectile, and Bunny
casts/hops. Damage, hit cadence, targeting, and result text remain server-authoritative. The
motion state is weak-keyed and sampled inside the existing RenderStepped pass—no new per-pet loop
or network packet. Imported orientation corrections remain the final CFrame composition. Melee
pets hold stable combat slots between swings rather than continuously orbiting, so Doggy's
server-timed contact and recovery cannot disappear inside unrelated circling motion. After each
completed melee strike its resting slot advances 10 degrees around the current target; odd/even
equip slots rotate opposite ways and a new target resets the accumulated offset. Tanks, ranged,
support, and control pets retain their distinct slam, recoil, cast, and control choreography.
Crystal work now uses that same role formation, authoritative-hit envelope, and sidestep path.
The old saved mining orbit and continuous pounce flourish no longer drive live pet motion.
Blaster kiting is explicitly preserved: a ranged pet already in range fires from its player-relative
formation slot; one outside range still advances to its authored standoff before firing.

**Current approach (working, pending user confirmation).** After an earlier
service-movement attempt let pets fall off the map (it dropped the legacy
teleport-watchdog), the retry sidesteps the whole physics-fall class: the server
**anchors** each pet (anchored parts can't fall/drift), and the client
`PetFollowController` sets each pet's CFrame every RenderStepped (smooth,
frame-rate-independent lerp). Follow = config formation; **attack = surround the
target with its authored role formation and real-hit motion — `PetFormation.attackOffset` plus
`PetAttackMotion`, headless-tested. Mining and combat share that role language; old saved
`PetAttackStyle` values remain profile-compatible but no longer drive or appear in the live UI.
Server keeps damage (`CombatService:ResolvePetDamage`) + target leash. Verified
live: pets stable + upright + on-map across 35s, following in formation; mining
works (AutomationSuite 69/69). **Open follow-up:** multiplayer position replication
(other clients seeing a player's pets move) — currently drives the local view only;
the planned approach is sending pet id+position to shared state. Issue #4 stays open
until the user confirms in-session + replication lands.

----

### (history) The earlier service-movement attempt fell off the map

Both the server-positioning and an earlier client-RenderStepped variant dropped the
legacy Follow script's teleport-watchdog + tuned forces, so pets drifted/fell off
the map and were destroyed (the known ~10-months-ago bug). Early (~6s-after-spawn)
verification missed the *delayed* fall. Lesson: verify physics/visual changes over
time (30s+), not just at spawn.

Current working state:
- Legacy `PetScripts/Follow.server.lua` + `FollowBox.server.lua` restored and own
  movement (`configs/pet_follow.lua` `service_owned=false`). Pets are stable,
  upright, don't fall (verified ~28s live), and mine. The watchdog is the fix.
- **Damage stays service-owned** (Phase 4.d holds): the legacy Follow routes mining
  damage through `CombatService:ResolvePetDamage` (PowerFormula + modifier
  pipeline) with an inline fallback.
- `PetFollowService` + pure `PetFormation` remain in-tree but **inert** (flag off).
- GitHub issue #4 reopened. A future service-owned movement loop must port the
  drift/teleport watchdog + correct network-ownership for the massless pet
  assemblies, and be verified watching pets 30s+ (not just at spawn). Desired but
  still-open polish: attack pets should SURROUND the target in an animated ring
  (orbit/lunge) rather than stack on one point; smooth client-side movement.

----

## (superseded) PetFollowService — service-owned pet movement

Last checked: 2026-05-30

Replaced the legacy cloned per-pet movement scripts with a single server-owned,
config-driven follow/work loop (GitHub issue #4 closed). Flag-gated incremental
rollout, live-verified, then the dead code was removed.

- **Config + pure core**: `configs/pet_follow.lua` (formation/float/align/attack
  tuning + the `service_owned` rollout flag) + pure `src/Shared/Game/PetFormation.lua`
  (slotOffset rows/circle, targetPosition into the player frame, float bob) —
  headless-tested.
- **Service**: `src/Server/Services/PetFollowService.lua` — a throttled Heartbeat
  loop that drives one `AlignPosition` per pet to its formation slot (follow) or
  its target (attack), and runs the position-independent mining tick via
  `CombatService:ResolvePetDamage` + `PetCombat.applyDamage` (Contrib ledger
  preserved). Pets are auto-targeted by the existing `BreakableService`.
- **Cleaner formation** (user's choice): pets hold config-driven slots behind the
  player rather than the old control-box chain.
- **Legacy removed**: `PetScripts/Follow.server.lua` (1114→18 lines) and
  `FollowBox.server.lua` (101→14) gutted to inert stubs (~1180 lines of legacy
  constraint/BodyMover/damage code deleted). They remain only because `PetHandler`
  still clones them; movement is wholly service-owned.

Verification: headless 175/175 (incl. PetFormation specs); live AutomationSuite
**70/70** in Halo & Horns — service registered + owns movement, pets spawned +
unanchored + driven by `_FollowAlign`, and pets mine their auto-assigned targets
(HP drops / mining income rises). Screenshot confirmed pets holding formation.

Follow-up (low-priority, flagged): `PetHandler` still creates the now-vestigial
control boxes + clones the stub scripts each spawn (harmless dead weight) — fully
removing that box machinery + deleting the stub files is a separate cleanup with
spawn-path risk, deferred from this pass.

## Halo & Horns — Phase 5 (Build depth: Archetypes / Powers / Augmentation / Hotbar / Rosters)

Last checked: 2026-05-30

Five build-depth systems (Features 13–17), each config-driven with a pure
headless-tested core, a server service, and bus commands.

- **Archetypes (13)**: `configs/archetypes.lua` (4 archetypes + power pools) +
  pure `ArchetypeLogic`. `ArchetypeService` owns `profile.Archetype` (one-time
  select; respec resets powers + slots + hotbar). Bus `archetype.get/list/select`.
- **Power Selection (14)**: `configs/powers.lua` (12 powers + `selection_levels`)
  + pure `PowerSelection` (pending-by-level, one-per-level, archetype-gated, no
  dup). `PowerService` owns `profile.Powers` (level via PlayerProgressionService).
  Bus `power.get/select`.
- **Augmentation (15)**: `configs/augmentation.lua` (grant levels, 6 slot types,
  max 6/power, set-bonus tiers) + pure `Augmentation` (grant-by-level, placement
  rules, stacking set bonuses). `AugmentationService` owns `profile.Slots`. Bus
  `augment.get/place`.
- **Hotbar (16)**: `configs/hotbar.lua` (20 slots, 4 bind types, defaults) + pure
  `HotbarLogic` (archetype defaults, rebind validation, empty-slot no-op).
  `HotbarService` owns `profile.Hotbar`. Bus `hotbar.get/rebind`. Power-bar
  size is Auto (phone → Mobile, tablet → Tablet, desktop → Desktop) or a
  Settings pin. Mobile is the designed-for-phone size; compact HUD stacks
  Powers/Board and stacks Pets/Menu at the same 48px so the bar is
  symmetrical. Admin sits in the far lower-left corner. That
  bottom-center layout is the saved keeper. The far-left look-at-it is
  game-pass + toggle badges (`hud.power_badges.placement`), not the bar.
  The badge column hides while the battle list is up; Settings → Hide
  Toggles in Battle (default on) can keep them visible.
- **Rosters (17)**: `configs/rosters.lua` (injury rules) + pure `RosterLogic`
  (clampMaxToDeploy, removeRef, resolveDeploy for ready_only/best_available/
  deploy_anyway). `RosterService` owns `profile.Rosters` (create clamps to squad
  cap; invoke pulls Spirit-Form readiness → replaces active squad; remove-ref on
  delete/trade). Bus `roster.list/create/invoke` + test `roster.removePetRef`.

Test-only level overrides on power/augment commands are gated to `isTest`.

Verification: headless `mise run test-headless` **232/232 across 28 specs**;
`mise run ci` green; live `AutomationSuite` **86/86** in Halo & Horns (archetype
select+gate+pool, power level/archetype gating + accumulation, augment grant/lock/
set-bonus, hotbar defaults+rebind, roster max-clamp+invoke+remove-ref).

Deferred (with reasons):
- The [studio]/UI halves: archetype-selection UI, level-up power-selection prompt,
  slot-allocation UI, hotbar key-press firing + cooldown overlays, mobile layout —
  logic + bus are done; the GUI is the next layer.
- Augmentation effective-cooldown application through the live ModifierPipeline (the
  pure set-bonus/per-slot math is done; wiring to the cooldown system arrives with
  the power-cast/cooldown runtime).
- Respec ritual cost/flow ([studio]); archetype-change ritual question (open in spec).

## Halo & Horns — Phase 6 (Social / endgame: Party / Trade / Fusion / Chaos Rifts)

Last checked: 2026-05-30

Four social/endgame systems (Features 18–21), each config-driven with a pure
headless-tested core. The cross-player handshakes + UIs are [studio]; the math,
rules, and server contracts are bus-testable solo.

- **Party / Group Play (18)**: `configs/party.lua` (max 4, loot rule, MVP bonus) +
  pure `PartyMath` (canJoin, scaledHp, splitLoot, attribution). `PartyService` owns
  session membership + group math (difficulty scaling pulls
  `combat.group_scaling.per_extra_player`). Bus `party.get/simulate`.
- **Trade (19)**: `configs/trade.lua` (pets yes-unless-locked, currencies no,
  cosmetics yes) + pure `TradeLogic` (canAddItem, both-confirm canExecute,
  auditRecord). `TradeService` owns sessions (Open/Add/Confirm/Cancel), the atomic
  validate-then-apply swap (no partial-completion window → anti-dup), and a capped
  queryable trade-history audit log. Bus `trade.canAdd` + test `trade.simulate/auditLog`.
- **Chaotic Fusion (20)**: `configs/fusion.lua` (output Chaotic, Light+Shadow recipe)
  + pure `FusionLogic` (validateInputs with exact spec rejection messages,
  outputElement, resolveTheme, fusionRecord). `FusionService` validates → consumes
  both inputs → produces a Chaotic pet → logs fusion history. Bus `fusion.canFuse` +
  test `fusion.simulate/log`.
- **Chaos Rifts (21) [deferred]**: `configs/rifts.lua` (per-element multipliers:
  Chaotic 2.0×, others 0.5×) + pure `RiftMultiplier` (multiplierFor, applyToPower).
  Only the power math is implemented + tested; the event scheduler, rift spawn,
  notifications, and Aether drops remain [deferred].

Verification: headless `mise run test-headless` **261/261 across 32 specs**;
`mise run ci` green; live `AutomationSuite` **100/100** in Halo & Horns (party
scaling 1000→2500 + 100/4 loot split + MVP attribution, trade allow-pet/reject-
currency/reject-locked + both-confirm audit, fusion Light+Shadow→Chaotic with
same-element/Chaotic/Neutral rejections).

Deferred (with reasons):
- Cross-player [studio] halves: party invite/accept UI + cross-player support
  powers; trade two-player invite/confirm handshake + offer UI; fusion altar +
  confirmation modal. All server rules + contracts are done.
- Chaos Rift live event system (scheduler, spawn, notifications, Aether drops) —
  marked [deferred] in the spec; the multiplier math is ready for PowerFormula to
  call once rifts go live.
- Combat animations + a hand-authored live enemy zone (Phase 4 deferral): combat
  resolution + spirit-form-on-down are verified through the bus, but a player has
  not yet fought an authored enemy in-world. Needs Studio-authored enemy models.

## Halo & Horns — Phase 7 (Reward spine: Quests / Daily / Shop / Rewards)

Last checked: 2026-05-30

A single backbone that collapses four menu features into one machine: **Triggers
bump Counters → Conditions decide what's Claimable → a Claim grants a Reward Bundle
(once, audited) → Shop is a Claim whose gate is a cost instead of a condition.**

Pure cores (headless-tested, `src/Shared/Game/`):
- **RewardBundle** — the universal "what you get" (currencies/pets/items/effects/
  titles/slots): `normalize`, `merge`, `isEmpty`. Everything terminates here.
- **Condition** — the universal gate: `isMet` / `progress` over a snapshot
  (counters/level/currency). Types: counter_at_least, level_at_least,
  currency_at_least, all_of, any_of. `progress()` feeds UI bars.
- **ClaimLogic** — anti-replay: `canClaim(met, count, def)` → not_met /
  already_claimed / out_of_stock (claim-once | repeatable | limit).
- **DailyStreak** — `resolve(lastDay, today, streak, cfg)` (clockless; day indices
  passed in) → claimable / newStreak / claimDay (calendar wraps) / reset.
- **ShopLogic** — `affordable` / `canPurchase(offer, balances, count)` (cost is an
  inverse bundle) → insufficient_funds / out_of_stock.

Services:
- **RewardService** — `Grant(player, bundle, source)` is the one place a bundle
  becomes real: fans out to DataService (currencies), InventoryService (items),
  PetGrantService (pets), PlayerEffectsService (timed effects), Upgrades (capacity),
  and writes a capped, source-keyed grant-history audit log (`reward.log`).
- **PromoCodeService** — config-driven weekly/creator/event codes now gate and grant standard
  RewardBundles server-side, persist one-per-player claims under a stable code ID, accept optional
  launch-link prefills, and aggregate redemptions by code and campaign in the retention dashboard.
  The styled Redeem Code menu is available from Settings; `CODETEST` is Studio-only.
- **QuestService** — condition-gated claims; ledger `profile.QuestClaims`; `List`
  (progress + claimable), `Claim`, `Pending` (the badge count).
- **DailyService** — cadence-gated claims; state `profile.Daily`; `Status` / `Claim`.
- **ShopService** — cost-gated claims; counts `profile.ShopPurchases`; `List` /
  `Purchase` (spend cost → grant reward).

Bus: `quest.list/claim`, `daily.status/claim`, `shop.list/purchase`,
`rewards.summary` (the menu-badge aggregator) + test `reward.grant/simulate/log`,
`test.setCounter/setLevel`, `claim.reset`. Configs: `rewards/quests/daily/shop.lua`.

## Quest reward and finite-counter audit

Last checked: 2026-08-05

- **Protect the Realm** (First Steps capstone, id `fs_cave`) pays 1,500 Waycoins instead of resolving a movable
  `area_coins` token; **Hatch 1,000 Eggs** adds five Fortune Flasks; **Defeat 100 Enemies** still
  awards three Health Potions, which are now real common consumables that heal 25% of maximum
  endurance on every deployed, living pet (without reviving downed pets or bypassing resurrection
  sickness).
- Trailblazer's impossible **Meet 3 Creators** task is now **Unlock 4 Areas** under the stable legacy
  quest ID. Creator meetings are passive Socialite achievements at one and two creators.
- One-time area unlock and realm-visit quests read lifetime state. ZoneService reconstructs the
  area/Heaven/Hell/combined-realm counters from persisted unlocks on join, and MeetCreatorService
  reconstructs `creators_met` from its once-ever stamps, so events predating the counters are not
  lost.
- The general Trial quest chain ends at 100. The 1,000/10,000 career totals live in a dedicated
  Achievements category and award their existing gems plus permanent titles. Prior quest claims are
  migrated into the achievement ledger without a second gem grant; those players receive only the
  new title.

Verification: headless `mise run test-headless` **282/282 across 33 specs**;
`mise run ci` green; live `AutomationSuite` **113/113** in Halo & Horns (reward
grant +25 crystals + audit entry; quest not_met→claim→already_claimed; daily
day1→2 streak + same-day block; shop purchase + limit-1 out_of_stock; summary).

Deferred (with reasons):
- The [studio]/UI halves behind the existing menu buttons: Quest list + progress
  bars, Daily streak calendar, Shop grid + confirm, the Rewards badge wiring. All
  server logic + bus + the badge aggregator are done; the panels are the next layer.
- Effect-reward application reads back through PlayerEffectsService folders (the
  grant call is wired; live effect-stat assertions are [studio]).
- Achievements already carry `reward_type`/`reward` in config — routing them through
  RewardService is a small follow-up (the spine is built to absorb them).

## Halo & Horns — Phase 8 (Achievements → spine + Quest UI panel)

Last checked: 2026-05-30

- **Achievements routed through RewardService.** `AchievementsService._grantReward`
  now translates a tier reward into a RewardBundle (legacy `{type=currency,...}` +
  forward-looking `{bundle=...}`) and grants via `RewardService:Grant` — one audited
  terminal that also handles items/pets/effects/slots — with a legacy currency
  fallback if RewardService is unavailable. `test.resetAchievements` re-arms grants
  for testing.
- **Quest UI panel** (`src/Client/UI/Menus/QuestPanel.lua`): mirrors the ShopPanel
  contract (.new/Show/Hide/GetFrame/IsVisible/Destroy), registered in
  `init.client.lua` so the existing "Quest" side-menu button opens it. Teal card
  rows (name + reward + progress bar + Claim/Locked/Claimed), sorted claimable-first.
  Data is live through the `GameAPICommand` bus bridge (`quest.list`/`quest.claim`);
  claiming refreshes the list. No bespoke remotes — reuses the generic bus transport.

Verification: `mise run ci` green; headless **282/282**; selene 0 warnings; rojo
build OK; live `AutomationSuite` **114/114** (incl. "achievement reward granted
through RewardService (audited)"); Quest panel screenshot-verified rendering 4 live
quest rows with correct claimable/locked/claimed states.

Known follow-up (pre-existing, surfaced by the panel): the quest level condition
reads `PlayerProgressionService:GetLevel` (profile.Stats.Level) which can disagree
with the XP-derived HUD level (HUD showed Level 15 while "Reach level 10" read 1/10).
The level data source needs unifying; the panel faithfully shows the bus value.

## Halo & Horns — Phase 9 (Level unification + Daily & Shop panels)

Last checked: 2026-05-30

- **Player level unified on an XP source of truth.** Total XP
  (profile.Stats.Experience) is now the single source; level is derived via a pure
  curve (`src/Shared/Game/LevelCurve.lua`, config `player_progression.xp`,
  headless-tested, xpForLevel<->levelForXp inverse). `PlayerProgressionService:GetLevel`
  derives from XP; `AddExperience`/`SetLevel`/`GetProgress` added; `Start()` publishes
  Level/XP/XPForNext player attributes. `RewardBundle` gained an `experience` field so
  quests/daily/achievements/shop can award XP through the spine; `test.setLevel` now
  writes the curve's XP threshold. The HUD (BaseUI) reads the real Level/XP attributes
  (seed + live refresh), replacing the hardcoded "Level 15 / 750-1000 XP" mock. This
  fixes quests AND the Phase 5 power/augment level gates consistently.
- **Daily panel** (`DailyPanel.lua`): 7-day streak calendar (claimed/today/upcoming
  cards with per-day reward), streak count, Claim button. `daily.status` now returns
  the calendar + cycle length so the UI is config-free.
- **Shop panel** (`RewardShopPanel.lua`): offer-card grid (name, reward, cost, -% sale
  tag, Buy/Owned/Can't-afford), replacing the old mock ShopPanel. `shop.list` returns
  each offer's reward.

Both panels use the `GameAPICommand` bus bridge (no bespoke remotes) and are wired so
the existing Daily/Shop side-menu buttons open them.

Verification: `mise run ci` green; headless **291/291 across 34 specs**; selene 0
errors; rojo build OK; live `AutomationSuite` **117/117** (incl. setLevel(10)->level
quest claimable, +900xp->level 10). Screenshot-verified: Quest/Daily/Shop panels
render live data; HUD reads "Level 10 · 0/1000 XP" live after the XP grant.

Follow-up: per-breakable XP gain isn't wired yet (XP currently comes from the spine —
quests/daily/achievements/shop). Add a per-mine XP grant + curve tuning when balancing.

## Halo & Horns — Unified Pet Shop monetization

Last checked: 2026-09-01

- The **Pet Shop is Robux-only**. Its default tab lists every configured live game
  pass with the Marketplace thumbnail, authored benefit description, Robux price,
  and authoritative owned/purchase state. Earned gem/coin offers belong to the
  neighboring economy shop and are deliberately excluded from this panel.
- The Merge Quartermaster opens this same panel in a one-open filtered presentation rather than
  owning a second purchase UI. `merge_egg_prototype.quartermaster.services.game_pass_ids` is the
  ordered source of truth and currently selects the eight live passes that affect Merge play: VIP,
  Auto Collector, Speed Boost, Golden Touch, Rainbow Radiance, Huge Hunter, Extra Pet, and Second
  Wind. The Quartermaster view hides Boosts and Founder's Gift while retaining authoritative
  Marketplace prices, owned state, and purchase signals. Kade-only rocketboards remain excluded.
- Robux prices shown to players are resolved client-side with
  `MarketplaceService:GetProductInfo`, so Roblox Managed/Regional Pricing is the
  display authority. `configs/monetization.lua` retains the current dashboard
  baseline only for validation and approximate internal analytics; the storefront
  never falls back to an obsolete configured number when Marketplace data is unavailable.
- A positive dashboard ID always opens Roblox's purchase prompt, including the
  full Studio simulator; `test_mode` instant-grants only zero-ID development
  stubs. Developer-product ownership is still granted exclusively through
  `ProcessReceipt`.
- Category and purchase-state controls use the same area/citrine/emerald/amethyst
  glossy pill assets as the established menu style guide; the storefront does not
  maintain a parallel flat-button palette.
- Every streamed `Pet shop` world model receives a client-owned proximity prompt that
  opens the same panel through `MenuManager`. Prompt discovery tolerates models whose
  sign/parts stream in after the outer model. Runtime-generated prompt anchors keep the
  interaction near floor height even when the authored sign is on a roof; an explicit authored
  `PetShopPromptAnchor` remains the override.
- The lower-left HUD has a permanent Shop action, so a missing, streamed-out, or awkwardly placed
  world prompt can never strand a player. The tray stays 2x3 for both audiences: regular players
  see Daily while admins see Admin in that same entitlement-swapped cell (Daily remains available
  from its world chest).
- Game-pass purchase completion now maps the Roblox pass ID back to its authored
  config, applies the benefit, persists ownership, refreshes capacity, records
  analytics, and pushes the updated owned state to the client.
- Developer products are omitted while their Roblox IDs are zero. The **Boosts** tab
  currently exposes three live 19-Robux products: Double XP (`3708216219`), Double Coins
  (`3708216387`), and Titan Team (`3708227956`). A receipt grants one configured inventory
  token and auto-binds it into an empty hotbar slot when available; it does not start the
  timer. Every configured consumable is discovered dynamically by Inventory and the hotbar,
  so new tokens do not require a client-side item-name list and remain usable directly from
  Inventory even when the hotbar is full.
- Double XP and Double Coins last one in-session hour and double their respective shared
  stat axes. **Titan Team** lasts 20 in-session minutes: every deployed pet uses its authored
  Huge visual scale and the player's full pet team receives an external +50% combat-and-mining
  power multiplier. It never changes saved pet identity, Huge trait, serial, variant, or attack
  scope. Repeat tokens extend remaining time. Titan uses the purple-paw badge consistently in
  Inventory, the hotbar, and the active player HUD.
- Timed paid boosts never stack strength: each additional Double XP or Double Coins token adds
  another 60 minutes, and each additional Titan Team token adds another 20 minutes. Their player
  badges count down the combined remaining duration from a server-authored session deadline and
  clamp cleanly at zero. The persisted authority remains **remaining in-session seconds**, so these
  products do not drain while the player is offline. Future Call instead rejects a second token
  while that player's Future Self is active (without consuming it); its portal badge counts down
  the active two-minute summon and clears on expiry, dismissal, or admin reset.
- Successful consumable activation now explains its destination visually: the authored icon blooms
  at screen center, then flies to the exact player-status badge, splits across visible **pet HUD
  cards** for team buffs/heals (or the collapsed My Team handle), or lands on the selected enemy HUD
  card for thrown debuffs. Activations also play the shared power-up sound. The route is item/meter
  configuration, so later tokens and potions reuse the same non-blocking choreography.
- Every active player-status badge now has a shared config-derived tooltip. Desktop hover and mobile
  tap identify the source and live effect; a mobile hold inspects toggleable powers without toggling
  them. Power and potion copy reuses their existing description modules, enchants read their effect
  definitions, pet auras show live magnitude/source count, and presence badges distinguish 2x
  Creator Luck from the non-stacking 1.5x **Founder's Legacy** server aura.
- The player-status HUD is split into two truthful, independently sized rows. Full-size, high-contrast
  badges remain reserved for active/timed effects; a compact subdued row (or left-edge
  column) renders every effective owned game pass in authored catalog order using its
  Marketplace artwork with no infinity marker. The pass row consumes the existing `OwnedPasses` snapshot (including Marketplace, Founder,
  creator, and Studio-test sources), updates after purchases or creator-gate changes without polling,
  and identifies the exact entitlement source through the shared hover/tap tooltip.
- Timed player-status badges display durations of at least one minute as `M:SS` (for example,
  `19:45`) and switch to the compact seconds countdown only for the final minute.
- The early-level boost sampler grants exactly one player-controlled token at each claimed-level
  milestone: **Double Coins at Level 2**, **Titan Team at Level 3**, and **Double XP at Level 4**.
  Tokens enter the normal Inventory/Items path and auto-bind only when a hotbar slot is empty; no
  boost starts automatically. Named profile markers reconcile already-progressed players exactly
  once, independently of token consumption or paid purchases. Admin Reset re-arms the milestone
  markers for another new-player test without guessing which shared-stack tokens were purchased.
- The pet-capacity pass is presented as **Deploy an Extra Pet** and adds one to the
  player's current deploy limit (3→4 immediately, up through 10→11 after progression);
  it is not a fixed unlock that jumps every buyer directly to eleven pets.

Verification: headless **1411/1411 across 135 specs**; Rojo build OK; live Studio
walk-up/E-key test opened the Pet Shop through the real proximity prompt and rendered
all 8 game-pass cards with live Marketplace artwork.

## Halo & Horns — Phase 10 (Escrow two-player trade + Trade UI)

Last checked: 2026-05-30

Roblox has **no native in-experience trading/escrow API** (the platform Trading
System is for avatar catalog Limiteds + Robux between accounts; the old web Trade
API was deprecated). So the escrow *pattern* is implemented server-authoritatively.

- **TradeService (escrow model)** rebuilt from the Feature 19 engine:
  `Request`/`Respond` invite handshake, `ListPlayers` (online targets). **`Add`
  MOVES the pet out of inventory into a server-held escrow** the moment it's
  offered — so it can't be sold, deleted, or offered in a second trade (anti-dup at
  the source). `Remove` returns it; both-`Confirm` **delivers each side's escrow to
  the other (all-or-nothing)**; `Cancel`/decline/**disconnect refunds** escrow to
  its owner (PlayerRemoving hook). Live state pushed to both clients via the
  **TradeUpdate RemoteEvent**. `GetState`/`ListMyPets` for the UI. Pure rules
  (tradeable / both-confirm / audit) still in the shared TradeLogic core; capped
  audit log retained. Bus: `trade.players/request/respond/add/remove/confirm/
  cancel/state/myPets` (+ original `trade.canAdd` and test `trade.simulate/auditLog`).
- **TradePanel**: the "Trade" side-menu button opens the **online-player list**
  (click → request). A self-managed ScreenGui live layer shows the **incoming-request
  popup** (Accept/Decline) and the **two-player window** (your removable offer +
  pet picker, the partner's offer, per-side confirm indicators, Confirm/Cancel),
  driven by TradeUpdate so it works even when the menu is closed. No bespoke
  remotes — all via the GameAPICommand bridge. Its pill buttons render text in a
  separate white child label so the capsule's `UIGradient` cannot tint or outline
  Request/Sent, Refresh, Accept/Decline, or Confirm/Cancel text. The TextButton's
  native `Text` remains empty (its semantic copy is the `DisplayText` attribute),
  because Roblox still draws transparent native text beneath a parent gradient.

Verification: `mise run ci` green; headless **291/291 across 34 specs**; selene 0
errors on new files; rojo build OK; live `AutomationSuite` **122/122** (trade
command surface + guards: players/myPets dispatch, no-session-by-default,
self-request rejected, add-without-session rejected). Screenshot-verified: the
two-player window (You: golden bear/cat + Add Pet; partner confirmed ✓ with HUGE
dragon; Confirm/Cancel) and the Accept/Decline request popup render correctly.

Deferred (true two-client only): the full escrow swap end-to-end (request → accept →
both add+confirm → delivery) needs a 2-player session — solo Studio can't run two
real players, so it's verified by the headless rules + the solo command-surface
guards and flagged for a multiplayer test. Optional polish: a poll fallback if a
TradeUpdate push is missed (the bus `trade.state` exists for it).

## Pet Realm (Halo & Horns) — progression, power, economy & balance (CURRENT game lane)

The active game layer on top of the template baseline. Design SoT:
`docs/PET_REALM_PROGRESSION_POWER_TEAMING.md` (§1–15) + `docs/PET_REALM_DESIGN_DOCUMENT.md`.

**Zone economy (per-biome coins).** Four biome currencies — `grass_coins` / `ice_coins` /
`lava_coins` / `desert_coins` (non-tradeable; gems-only trading). Each biome's ore family pays its
own coin; HUD shows the four with a live `+N` gain indicator (legacy `coins`/`crystals` removed).
`ZoneTrackerService` resolves the current area from config bounds by raycasting biome baseplates;
farming is scoped to that area. Per-biome egg stands (Earth/Ember/Ice/Sand) place real hatch-target
eggs. **Mining income identity: `coins/sec = DPS × (value/HP) × world value multiplier`**.
`configs/breakables.lua` ORE_TIERS holds the shared 0.2 ratio; the five base-realm worlds use
`value_mult = 2` for an effective 0.4 ratio and double mining XP from the same scaled node Value.
Heaven/Hell retain their separate layer scaling. Every crystal tier pays the same rate; bigger ones
just take longer. Outer zones spawn
`max=100` with 5–60s distributed respawn; the local depletion sag is a **designed throttle**
(active>passive). Active-mining boost: clicking a node amplifies pet damage on it.

**Targeting / farm modes (`configs/auto_systems.lua`).** Free = `nearest` (min travel — the best
DPS the flat ~26 studs/s pets allow); paid gamepass = `highest_value` (camp big nodes). Hotbar cycle
Off→Near→High.

**Zone unlocks (`configs/areas.lua`).** Ring grass→Ice→Lava→Desert, each paid in the *prior* zone's
coins (no skipping). Costs tuned to a "real chapter per zone": Ice 8k / Lava 18k / Desert 35k /
Meadow 2k (Meadow = permanent +10% coins). **Open design (§12):** the ring's terminal zone should be
an on-ramp into the heaven/hell realm axis, not a dead-end.

**PetPower (mining/combat split + bounded ceiling).** `PetPower`/`PetPowerView` give every pet a
two-number profile — ⛏ mining vs ⚔ combat (role aptitude × element × variant), shown on the card.
Power S2: a bounded geometric tier curve + a code-enforced `max_pet_power` ceiling (the Creator apex;
nothing out-powers Huge Rainbow Colorado) + a shiny axis (neutral 1.0). **Eternal pets** (Huge,
Secret, Exclusive) scale dynamically: power = `power_percent` × the average of the player's top-N
non-eternal pets (Huge=120%), so they stay relevant forever without breaking the ceiling
(`PetHandler.resolveEffectivePetPower`, `configs/pets.lua`).

**Accuracy curve (combat substrate).** Pure `Accuracy` to-hit = `clamp(base + step·(atk−def),
floor, cap)` reading a single `EffectiveLevel` seam (teaming will override it); mining is flat 100%
(fixed the old 8% crystal whiff). The three identity numbers: **EffectiveLevel** (combat scaling),
**ClaimedLevel** (entitlements), **Soul** (heaven/hell alignment).

**XP + level-up (cap 50).** Mining AND combat grant XP. **Claimed-vs-earned split:** XP earns
levels; powers/slots/egg-hatch are *claimed* via a level-up sequence UI. Hybrid **Ascension Altar:**
filler levels auto-claim in the field; power/slot/milestone levels train at the altar. Caps: **10
equipped pets + 10 power picks**; +1 egg-hatch per claimed level. Dev XP reads a monotonic `XPTotal`
attribute (keeps accruing past the cap). A successful altar claim now owns the full 7.5-second
Ascension ceremony: the approved crescendo is positional for nearby players, while the claimant's
avatar is represented by a local, anchored visual clone that rises, accelerates through a spin,
crosses layered gold rings/sparkles, and lands on the level reveal. The real character is never
teleported or handed to client physics; XP-bar completion retains only lightweight feedback. The
successful `level_claimed` event synchronously closes the Power Choice menu before starting the
ceremony; rejected claims leave the menu open with their actionable error.

**Full build respec (admin-tested flow).** `RespecService` preserves exact lifetime XP and all
non-build progression, returns every installed enhancement instance to the stack inventory, clears
origin/powers/augmentation slots/hotbar, and rewinds only `ClaimedLevel` to 1. The ordinary
Ascension Altar then replays each historical choice through the prior claimed-level boundary.
Replay claims never repay level rewards or increment progression counters; normal claims resume
after the boundary. Enhancement placement is server-blocked until the replay completes. The admin
panel exposes **Full Respec (refund enhancements)** for production testing; final player cost and
ritual access remain a later product decision.

**Dev tooling.** Studio-only metrics overlay (rolling-1-min DPS / Coins-s / Pet-speed / XP-min bars).
Admin panel "Add 100k Area Coins" funds all biome currencies. Audio Effects/Music/UI volume controls
work (SoundGroups).

**Verified balance (grass/ice/lava, farming Near):** fresh dogs ≈46 DPS→~10 cps; fresh bears ≈25
DPS→~6 cps (tanks mine slow by design); graduated variant squads ≈85–150 DPS→~17–30 cps. The
"~200-egg arc" (~20k coins) ≈ graduate a starter squad ≈ ~20–33 min.

**Next (tracked tasks #149–156):** World S3 (realm axis as a non-terminal endgame — token earning
loop + traversal-sink knob + depth=desirability via Eternal pets), Teaming S4, Creator S5,
earning-rate enemy pressure (#155), support-pet targeted buff/debuff (#156), PetPower S3
(display=dealt), Power S2b balance rebase, overnight memory-leak investigation.

## Balance follow-up (config-only)
- Huge pets' base-power floor scales with pet level (huge_base_power × level mult →
  e.g. 152% at lvl 27). Flagged by the user as too high; tune later (config /
  decide whether the floor should ignore level). Logic is correct; purely balance.

## Recent Planning State

The project now has two high-level source documents:

- `docs/FOUNDATION_AND_REQUIREMENTS.md`
- `docs/IMPLEMENTATION_PLAN.md`

Those documents define the planned foundation work: stats, modifier pipeline, save migrations, config validation, feature flags, economy ledger, and the map integration contract.

## Next Likely Work

The active lane is the **Pet Realm game layer** (see the Pet Realm section above); the
template-baseline polish below is parked behind it.

Pet Realm next (tracked tasks #149–156):
1. **World S3** — heaven/hell realm axis as a non-terminal endgame (retention, not gates): expand
   layers 3→5/side + `requires_level` gate (substrate S3.1), then the token earning loop, the
   traversal-sink knob (`charge_on`), and depth=desirability via Eternal pets.
2. **Teaming S4** — guest pass + lead-anchored sidekick/exemplar (power axis only).
3. **Creator S5** — Creator class (dev-only, untradeable apex) + Meet-the-Creator + shiny pets.
4. **Earning-rate enemy pressure** (#155) — anti-cheat tool #3 (high income → enemies; seed the
   baseline off the DataStore-loaded total to skip the join spike).
5. **Support-pet targeted buff/debuff** (#156, experimental); **PetPower S3** (display=dealt, #132);
   **Power S2b** balance rebase (#153); **overnight memory-leak** investigation (#152).

**Shipped (2026-06-05): "The Watcher" (RealmHellFaces)** — a giant demon head that haunts **Hell 5
only**, kite-following the player (anchored + capped `PivotTo`, no physics fling), glowing in the
pitch-black realm via an internal face light, with a lightning pulse and stowed-but-ready Neon
pupils. Pure ambience/horror (no mechanics yet); all knobs in `configs/layers.lua → hell_faces`.
See LOG 2026-06-05 for the anchoring bug + the Rojo-sync lesson.

Template-baseline polish (parked): richer auto-target UI controls; replace the legacy pet
follow/mining clone with a service-owned loop (template issue #4); enchanter UI polish; authored-map
gate art on the `TeleportPad`/`Portal` hooks; clean up warning-level placeholder/test data.

## Pet Realm — Combat & Power (shipped 2026-06-17 → 06-26)

- **Pet combat orthogonal axes** — targeting (single / targeted_aoe / aura / contagion) × effects
  (DoT burn, on-hit Control, on-hit Shred), all config-declared; aura targeting drives buff scope
  (team / top-1 carry / top-K carries). S-tier kits (Control/Shred/Bonfire) + the Trinity kill-box.
  Pure `OnHitEffects.lua`. Pet attack geometry resolves moving enemies through their server-owned
  `MoveTarget` position; anchored model pivots are presentation fallbacks only and clients never
  choose damage centers.
- **Realm resonance live** — light/shadow species multiplier (own 0.8 / opposite 1.5 / neutral 1.0)
  wired into real mining & combat; inventory card shows the true dealt power. Squad diversity bonus
  (distinct archetypes + origins).
- **Layer-2 realms (Heaven 2 / Hell 2)** — playable: 8 zones (±4000 Y), 40 pets on a 6-tier ladder
  (new LEGENDARY tier), 8 egg pools, layer-aware egg-stand resolution gated on `Assets.ModelsReady`.
  Hell support auras are give→take (`drain`/`shred`/`curse`); L2 ice dragons have a freeze-AoE root.
- **Allegiance aggression** — heaven farms (no aggro vs heaven/neutral squads), hell fights; fielding
  a hell pet flips heaven enemies hostile. Realm patrol bands are the opposing faction invading
  (flag-gated, ships dark).
- **Mountain-time weekday event calendar** — seven daily events via `Shared/Game/MountainTime`,
  surfaced on a live HUD label + Effects panel cards.
- **Potions (BrewMeter)** — runtime per-axis draining meters (anti-runaway), use from an assignable
  power-bar slot, LOCK=auto-maintain, stack additively with powers; first-class inventory tab. Player
  meters drink; enemy meters throw at the squad's shared focus, keep charge on the target, and use
  additive `VulnMark` channels. Throw range/projectile are config-owned. Potion
  slots reuse the power hover tooltip, with name, target/type, description, charge cap, drain, sip,
  and LOCK threshold derived from `configs/potions.lua` through pure `PotionDescribe`.
- **Multi-bucket trade escrow** — pets + gems + enhancements (potions pending) through a
  category-dispatched escrow; three-column Trade UI.
- **Enhancement store** — buy/sell for gems; static rarity-scaled pricing (`EnhancementPricing` SSOT),
  naturals-only buying + single/dual grades, sell/salvage as the gem sink; buy-to-fill in the slotting
  UI. Enhancements affect player powers end-to-end (damage/healing fold to magnitude; range/accuracy/
  spark gated). New `speed`/`focus` axes; summon duration+potency.
- **Focus resource + CoH toggle economy** — runtime-only Focus pool, per-second toggle upkeep, toggles
  crash on empty; HUD Focus bar + top-left toggle badge. Hasten is a timed perma-click (recharge-only)
  that self-bootstraps and cascades cooldown reduction. Admin tabbed power bar with MIN/MAX potency.
- **Three defensive pillars** — absorb-shields, armor-curve mitigation, and **true evasion** (Mirage
  Step avoidance roll, yellow DODGE float). Sandwalker is the pet-protection origin (dodge + Quicksand
  root + Sandstorm blind + at-feet Healing Field zone); blinded enemies whiff with orange MISS floats.
- **Realm breakable presence-gating** — realm crystals spawn only where a player is present (gated on
  presence, not unlock): ~32k→~9.5k workspace instances at Spawn. (Resolves the "memory leak" — it was
  instance count, not a Lua leak.) Power range bounded to enemies near the caster; overhead HP bars
  distance-culled at 150 studs.
- **Aggro Phase 1** — farm-lock / despawn-churn fixed and live-verified; downed pets no longer latch
  the owner InCombat.
- **Currency-key normalization on load** — dedupes legacy duplicate currency keys (merge by MAX),
  killing the stale-key "CHANGED EXTERNALLY" watchdog false alarm. Per-color gem-drop rendering +
  size-invariant inventory card framing.

## 2026-07-17 — True symmetric combat holds

- **Hold is a full action lock, distinct from root.** The shared `CrowdControl` timing rule treats
  `HeldUntil` (enemy) and `PetHeldUntil` (pet) as no movement, basic attacks, powers, support output,
  damage auras, or taunt. Root remains movement-only.
- Deep Freeze / Absolute Zero / Eternal Winter are the Cryomancer 8/10/12-second full-hold ladder.
  A hold landing during a capital-enemy slam wind-up cancels the impact, and intentional long holds
  do not feed the chase-stuck despawn timer. There is no hold-break power yet.

## 2026-07-27 — Level 5–9 Future Call

- Ascending through claimed Level 2 awards **one Future Call token** as a visible new capability.
  Future Call is absent before Ascension is introduced and no automatic or quest token grant may
  bypass that gate (the admin test grant remains explicit).
  It auto-binds immediately but remains locked until earned Level 4; pressing it early displays
  **“Reach Level 4 to summon Your Future Self.”** At Level 4 it becomes usable and celebrates
  readiness without moving or replacing the player's chosen hotbar slot. Existing Level-4+
  profiles are marker-migrated without receiving a duplicate token.
- Claiming Levels 5/6/7/8/9 grants 5/4/3/2/1 **Future Call** consumable tokens, respectively,
  for 15 total. Existing profiles reconcile every missing marker-backed milestone. Profiles that
  received the original three-token Level-5 grant receive only its two-token top-up; Reset to
  Beginning re-arms the full schedule.
- A token auto-binds to the first free top-row hotbar slot without overwriting player bindings and
  uses the World Travel icon. Activation manifests the player's future self for two minutes at the
  caller's earned level +5, capped by the game's Level-50 ceiling. Every use keeps the same authored
  four-pet squad: rainbow Polar Bear, golden Dragon, rainbow Penguin, and rainbow Snow Leopard.
- The manifested squad fights first and farms the nearest crystal while combat is absent. It retains
  a live mining target instead of retargeting on every scan, and every reward/contribution is credited
  to the summoning player.
- Future Self is a full combat member by ownership, not merely by the temporary team-HUD roster:
  aggression against any real teammate's pet drafts every manifested squad owned by that team,
  including when the owner was already in a real party before summoning. Server combat positions
  Future Self pets from the live manifested character (owner fallback), never their stale spawn
  pivots, so walking away from the summon point cannot strand the visible squad out of combat.
- The admin panel's **Grant 3 Future Call Tokens** action exercises the real inventory, auto-bind,
  banner, and activation path without consuming the one-time progression marker.
- A successful Future Self visit now closes with the matching blue
  **“See you—or be you—soon 😉”** banner when its two-minute lifetime naturally expires. The
  lifecycle callback is reasoned, so admin resets, activation rollback, replacement, and the owner
  leaving do not produce a misleading farewell.

## Links

- [Decisions](DECISIONS.md)
- [Architecture](ARCHITECTURE.md)
- [Studio Workflow](STUDIO_WORKFLOW.md)
- [Map Integration Contract](MAP_INTEGRATION_CONTRACT.md)
- [Map Marker Reference](../MAP_MARKER_REFERENCE.md)
- [Implementation Plan](../IMPLEMENTATION_PLAN.md)

## Quest menu completion cleanup

Last checked: 2026-07-27

- The Quest menu filters claimed, non-repeatable quests out of both its rows and branch tabs, while
  the server continues returning and retaining the full claim ledger. Repeatable quests and all
  unclaimed rewards remain visible; an all-complete player sees a concise completion state.

## Hatchery quest and achievement pacing

Last checked: 2026-07-27

- The active Hatchery chain ends at 1,000 newly hatched eggs (25 → 100 → 1,000). Passive lifetime
  hatching achievements continue at 10,000 and 25,000 eggs beyond that capstone. The final quest's
  internal legacy ID remains unchanged to preserve existing claims and activation baselines.

## Creator pass entitlement and Resonance Range

Last checked: 2026-07-27

- Production creator accounts `coloradoplays` (`3200870803`) and `sploithunter` (`864785140`)
  receive every authored permanent game pass through the normal benefit/persistence path. This is
  independent of Studio's grant-all test mode and of the Meet-The-Creator egg registry.
- Listed creators now see a persisted `Game Passes: ON/OFF` control in the production admin panel.
  OFF is a deliberate true no-pass balance-test state: it ignores both creator grants and real
  Marketplace ownership, clears pass multipliers/features/perks/effects/runtime attributes
  immediately, refreshes equip capacity and shop ownership, and survives rejoin. ON recomputes and
  restores the full creator catalog. Non-creators cannot use the override; Premium remains separate.
- VIP (+25%) and Speed Boost (+50%) therefore publish `Eff_Speed = 1.75` with Swift off; Swift's
  +40% reaches the movement-axis ceiling and publishes `2.00`.
- Resonance declares `targeted_aoe` on both its power and effect-kind contracts. A natural Range
  enhancement expands its 30-stud pulse to 34.5 studs; stronger grades expand it further.

## Meet pets, Creator class, and Huge enchants

Last checked: 2026-07-28

- Meet-the-Creator rewards such as regular Colorado and Kade are normal-class Exclusive pets.
  Kade's eventual Creator-class apex will be a separate species; meeting Kade does not grant it.
  The same split already exists between `colorado` and `colorado_creator`.
- Runtime Creator pinning and permanent Creator enchants read the saved per-copy `creator` trait,
  not the species category. Runtime Huge pinning and permanent Huge enchants similarly read the
  saved `huge` trait, so a Huge from any egg/source receives the same contract.
- Every Huge has three fated, non-rerollable enchant slots: slot 1 at hatch, slot 2 auto-rolls at
  pet level 50, and slot 3 auto-rolls at pet level 100. The level-up path refreshes the projected
  inventory and requests persistence after filling newly unlocked slots.
- On every profile load, the server recalculates each Huge's unlocked slots from its saved level and
  fills only missing/invalid unlocked slots. Existing valid enchants—including later slots around a
  gap—are never rerolled or replaced; repaired records are projected and saved immediately.

## Tutorial completion guarantees earned level 2

Last checked: 2026-08-03

- Completing the live ten-step tutorial now tops the player up to exactly the XP threshold for
  **earned level 2**. The award preserves XP already earned and bypasses activity/game-pass/event
  multipliers, so every finisher lands at the same guaranteed threshold without losing progress or
  overshooting because a boost happened to be active.
- The eligibility marker is written only by genuine tutorial completion, not veteran skipping.
  Granting is retryable across a state pull or rejoin and carries a once-only ledger; the raw event
  `tutorial_level_awarded` records the target and actual XP added.
- Level 2 remains a normal training level: it is earned immediately, then claimed at the Ascension
  Altar for the existing power-choice flow. The completion card now celebrates Level 2 and points
  the player to the altar.

## First Steps completion guarantees earned level 4

Last checked: 2026-08-04

- Claiming **Protect the Realm**, the fifth and final First Steps mission, first applies its authored
  300 XP and then adds only the exact XP still missing for **earned level 4**. The top-up bypasses
  boosts/multipliers and never removes progress or overshoots an already-higher player.
- The same capstone grants **one additional Future Call token** through the canonical inventory path,
  preserving its historical two-token total together with the immediate locked onboarding token. It
  includes auto-bind, hotbar refresh, persistence, and the existing award banner. This reward is independent
  of, and does not consume, the marker-backed Level 5–9 token schedule.
- Per-component completion markers make the grant retry-safe. Opening the Quest menu reconciles
  older profiles that already claimed Answer the Cave before this reward existed, while Reset to
  Beginning clears those markers with the quest ledger for a faithful new-player test.

## Launch Friend Boost and pet-slot celebrations

Last checked: 2026-08-04

- The launch social promotion counts up to four Roblox friends in the same server. Each counted
  friend grants +20% additive hatch luck, +10% XP, and +10% earned biome coins; four friends grant
  +80% luck and +40% XP/coins. Mining and combat coins both participate, while gems, realm tokens,
  fixed grants, refunds, trades, and purchases do not.
- The promotion is an always-active Events-panel card and uses the same eight-second floating
  celebration banner as a Future Call token award. Its dynamic banner reports the player's live
  friend count and exact totals; raw analytics receive `friend_boost_active` with the same context.
- `configs/friend_boost.lua` records the 10,000-public-play launch target and owns the later reduced
  phase as one explicit switch. Hatch Luck Hour remains an independent global event.
- Claiming a level-derived deployable pet slot now produces its own matching banner. The existing
  configuration remains authoritative: level 8, then every seven levels through 50.

## Starter portraits, Tutorial 6 cue, and AoE-ring contract

Last checked: 2026-08-16

- The first-companion chooser no longer depends on Roblox serving four flat thumbnails. Each card
  keeps a live, already-replicated pet model underneath its flat image; only a confirmed successful
  image fetch replaces the model. A failed, timed-out, pending, or unavailable image therefore
  leaves the actual Bunny, Bear, Doggy, or Kitty visible instead of a paw placeholder.
- Tutorial 6 and **Call them back** now resolve their live `berserk_brew` and `rally` hotbar
  bindings by identity instead of assuming positions, and outline the real slots with a large,
  bobbing `CLICK HERE` callout.
- **Build your squad** and **Power up Resonance** use that same large, bobbing `CLICK HERE`
  treatment on the live Pets and Powers buttons. **Set your power** is one persisted lesson with
  three client phases: `Edit` gets the callout; slot/power selection removes it and enlarges/pulses
  the Resonance-row arrow; after Resonance is bound, `Done` gets the callout. Pressing `Done` only
  completes the lesson after the server verifies Resonance in the authoritative saved hotbar.
  Every cue is parented to its resolved control, so it follows scaled/mobile layouts instead of
  relying on screen coordinates.
- Centralized effective attack geometry for runtime and UI. Every Huge structurally receives area
  damage unless it authors a stronger Huge scope; real periodic AoE procs receive an area ring; and
  an on-hit control badge inherits the attack geometry that carries it. Inventory, egg preview, and
  squad HUD now agree.
- Next FTUE pass retained from tester feedback: Ascend notification teleport, more UI-target arrows,
  a stronger first-30-second payoff, and a short Level-3 enhancement lesson. (The Ascension
  ceremony itself is now implemented.)

## Mobile-readable tutorial typography

Last checked: 2026-08-17

- The tutorial objective capsule authors step and body copy at 18px before shared HUD scaling, with
  20px titles. Step copy and body copy no longer fall to the former unreadable 11px/12px sizes on
  phones.
- The capsule is now 420x124 authored pixels so larger wrapped instructions remain visible instead
  of clipping. It continues to use the existing shared viewport scaling and top-HUD docking path.
- After the tutorial, every quest/mission detail in the shared tracker reveals immediately on mouse
  or touch press, stays visible while held, and remains readable for ten seconds after release.
  Compact pill/ring modes temporarily expand through the same interval; desktop hover uses the same
  grace instead of disappearing the instant the pointer leaves.

## Homeworld Resonance-then-combat tutorial sequence

Last checked: 2026-08-24

- Tutorial v6: Earth egg, mine, another egg, review squad, bind / cast / enhance
  Resonance, then the Earth cave is the full combat-training loop. Rally is the
  last Homeworld beat after they walk back out at earned Level 2.
- `BaddieSpawnerEarth` ambient waves are disabled. The cave stamps lobby, frost
  door, arena spawn, and pillar. The Hall arch is not an entry.
- Completing Rally still fires the Homeworld completion card. Level 2 is granted
  when combat training finishes (idempotent if Rally also records the target).
- Migrations run one version at a time (v1–v5). Retention still matches
  `first_fight` as the cave-training handoff.
- Cave entry is an Enter prompt on a Homeworld mouth pad (`Maps.Home` only).
  FIGHT still points at the Home cave. Isolated `CombatTutorial.done` leftovers
  reopen while Homeworld is on `first_fight`.
- Cave mouth is Hall-style Press E only. The frost READY slab is no longer
  the cave facade; E warps into EarthLair.
- Cave E now opens a far-X `combat_tutorial` mission slot (10 concurrent).
  The landing pad has no Leave Mission prompt.
- Combat training uses the trial gray-box skins: grass on enter, then
  lava / heaven / hell / desert / ice as the lessons advance.

## Actionable power and potion refusals

Last checked: 2026-08-18

- A failed Resonance cast with no nearby crystal still uses the standard red refusal puff and flub
  sound, but now also floats **“No crystals in range — move closer.”** above the player.
- Failure reasons remain server-authored machine keys and player-facing wording remains in
  `configs/game_events.lua`, so every hotbar/input path receives the same explanation.
- Normal power refusals distinguish missing enemy/crystal/pet/downed-pet targets, insufficient
  Focus, cooldown, Tank requirements, and travel/Recall failures instead of relying on the bonk.
- Potion activation uses a parallel `potion_use_failed` event. Enemy debuffs report a missing,
  unavailable, or out-of-range target, and rejected activations occur before inventory consumption.

## World-space tutorial breadcrumbs

Last checked: 2026-08-18

- Tutorial travel guidance now renders as outlined, floating 3D chevrons instead of flat neon
  ground discs. The markers are ordinary anchored world parts, with no screen-space placement or
  GUI pixel offsets. Each arrow physically advances along the route and wraps back to the player
  end rather than remaining stationary under a traveling transparency pulse.
- The breadcrumb is deliberately not a navigation path. Every rendered frame samples the player's
  current position and the objective's current position, then places the moving chevrons on that
  live direct line. There is no pathfinding, periodic replan, waypoint rebuild, or route cache.
- The direct line uses a shallow world-space arc for readability and is capped at twelve chevrons.
  It disappears when the destination prompt is in range; all marker parts remain noncollidable,
  untouchable, and excluded from queries.

## Tutorial language detection and English override

Last checked: 2026-08-18

- New-player tutorial copy defaults from the local Roblox translator locale, with complete Spanish
  and Brazilian Portuguese catalogs and authored-English fallback for every other language.
- Settings exposes a persisted **Tutorial Language** choice: `Auto (<detected language>)` or
  `English`. Stable localization keys travel beside the raw English tutorial state, so older or
  untranslated clients never receive blank copy.
- Auto-mode players using a supported non-English locale receive a one-time session banner naming
  their tutorial language and pointing to the English override in Settings.

## Social invite privacy and expiry feedback

Last checked: 2026-08-23

- Team requests default to Friends only. New profiles default Trade requests to Everyone; existing
  profiles retain their saved Everyone / Friends only / Off choice without a migration. Each player
  picker owns an independent persistent control, and the receiving player's choice is enforced by
  the server and reflected in unavailable picker rows.
- Both invite types expire after 30 seconds. The sender and recipient each receive an explicit
  timeout banner, and the recipient's stale request popup closes.

## Kade's rocketboard entitlements

Last checked: 2026-08-21

- The six rocketboards are permanent, personal game passes sold only by Kade's Boards. They are
  excluded from the Pet Shop's general pass catalog and are not developer-product consumables.
- Kade and the monetization boundary both reject a purchase request when the matching board is
  already present in `GameData.Hoverboard.owned`; Roblox game-pass ownership supplies the platform
  duplicate-purchase guard as well.
- Pass reconciliation grants the matching saved board on join. A newly completed purchase grants
  and equips it immediately. All hoverboards publish `Tradeable = false`, and the trade rules
  explicitly reject the `hoverboards` category. No migration is required before release.
- The six group-owned rocketboard passes are live at the authored R$19 baseline; config contains
  their dashboard IDs, so Kade always exercises Roblox's real prompt/simulator route.

## One-way pet gifts

Last checked: 2026-08-24

- The Trade menu exposes persistent Any / Uncommon+ / Rare+ / Mythical+ / Off gift policies and
  shows each online receiver's current policy before the giver selects exactly one eligible pet.
- Delivery is noninteractive and crash-safe: the exact pet is durably escrowed before its stable
  cross-profile message is queued, duplicates are permanently suppressed, and the receiver opens a
  wrapped inventory present to run the normal pet reveal. A full pet inventory preserves the gift.
- Three independent global top-three rankings track Mythicals, Secrets, and Exclusives given;
  Huge pets count with Exclusives. Wrapper colors are blue for Legendary and below, purple for
  Mythical, crimson for Secret, and gold for Exclusive/Huge. All supplied transparent icons and
  present models are group-owned and traceable through repository upload manifests.
- Mythical and higher gifts announce in server chat on first finalize, without naming the pet.

## Gift-giver point weights

Last checked: 2026-08-24

- All three giver rankings score qualifying pets by hatch variant: Basic = 1 point, Golden = 5,
  and Rainbow = 25. Fresh point counters and v2 OrderedDataStores prevent legacy raw counts from
  mixing with weighted scores; persisted pre-weight outboxes recover points from the exact pet.
- A raw total adds one for every gift in `gifts_given`, without exposing an all-gifts board yet.

## Realm layer-state integrity

Last checked: 2026-08-25

- `LayerService` now keeps logical `CurrentLayer` and the character's physical stacked-map Y offset
  synchronized after respawns and other desync paths. Live Hell 3 recovery restored the character
  from Home to Y -6000 and restored the locked `Hell_3_Grass` area prompt.

## Hell 3 environment glow

Last checked: 2026-08-25

- Selected Hell 3 flora and both ambient-fauna families use emissive textured MeshParts; 28
  signature instances also carry low-cost, no-shadow red/purple PointLights. Live verification
  preserved the black silhouettes while making their authored color veins readable in the dark.

## Layer 3 eggs and pet-kit configuration

Last checked: 2026-08-24

- Eight Layer 3 origin eggs and two realm stands are production-complete locally, including alpha
  cards, selected textured GLBs below 10,000 triangles, integrity reports, and contact sheets.
  Roblox publication and live `configs/pets.lua` egg records remain pending asset IDs; no fake ids
  are present in runtime config.
- Studio replacement contract: swap the visible assembly of the four existing Heaven 3 stands for
  the Heaven 3 model and the four existing Hell 3 stands for the Hell 3 model, preserving each
  area-named fixture and its transform, attributes, tags, and `UIanchor`. These eight fixtures are
  currently Layer 2 duplicates; do not add parallel stands or alter Heaven 2/Hell 2.
- All 40 Layer 3 pets have reserved role/support mappings. The approved design direction is a mix of
  ordinary single attacks, four intermittent splash blasters, apex continuous-area kits, live
  control, and Heaven sustain/farming versus Hell drain/debuff support.
- Layer 3 support now uses a total-value rarity budget rather than requiring every individual
  support number to rise. The Legendary Light Tortoise trades down to a 5% focused heal for planned
  persistent radiant AoE damage; the Legendary Obsidian Tortoise trades down to a 15% focused curse
  for a live area heal-block field. Focused Legendary buffs/curses were strengthened above their
  Rare/Uncommon counterparts.
- Drain is damage-free but now heals an ally and suppresses healer casts plus passive regeneration
  on its affected enemy scope. Common drains are focused, the Mythical Dreadthorn Grovekeeper uses
  an aura, and the Secret Dreadglass Dragon suppresses its targeted-AoE cluster. A replicated red
  heal-down badge appears on affected enemies and on drain/anti-heal ability marks.
- Curse and shred now consume the existing Basic/Golden/Rainbow effect multipliers; suppression
  remains binary and never extends its duration or recharge for a variant.
- Huge pets now differentiate progression: base-single species gain the existing targeted splash;
  base-area species retain AoE and additionally gain a spreading burn with global defaults and an
  optional per-pet `huge_attack_dot` override.

## Status chip (2026-08-30)

The worn title pill (Novice / Spark → Skilled / leaderboard) docks to the left of
`PlayerBar.Emblem`, not the quest column. Compact inherits the capsule scale.

## Merge HUD (2026-08-30)

Dedicated Merge place hides the Farm quest tracker. Wave status lives in
`MergeWaveBar` in that same upper-right chrome slot. The People list selects
its configured Merge top ratio for the current DisplayClass so it sits under
the wave bar on phone, tablet, desktop, and ten-foot displays. Hatcher captains stand on
the floor on the gate side of their egg; new slots get a cloned `EggStand`.
