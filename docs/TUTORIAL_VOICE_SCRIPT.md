# Farm & Fight — angel and demon recording script

Draft 1 · 2026-09-08 · English · 88 clips / 1,521 spoken words

**Status:** complete recording script; audio has not been generated, uploaded, or connected to the tutorial. The canonical spoken copy is `configs/tutorial_voice_lines.lua`. No gameplay or existing tutorial text changes are enabled by this catalog.

## Performance

**Angel:** the existing Heaven face and warm female voice. Encouraging, patient, quietly delighted. Speak to one player, as a companion. Let praise feel earned; keep it light and natural.

**Demon:** the existing Hell face and voice. Sly, amused, slightly mocking, with reluctant respect as the player improves. Match the Watcher’s “Still here? How irritating” character. He enjoys a theatrical challenge; his actual lesson advice stays accurate. No shouting or constant growling. Use the demon throughout the combat courses, including their preparation lobbies, regardless of the room’s visual theme.

Read only the quoted dialogue. IDs and cue names are production notes. One file per ID (`A01.mp3`, `D01.mp3`, etc.); keep the same ID if a take is revised. Use natural pauses at punctuation. “Enter,” “Done,” “Apply,” and “Activate” name actions, not particular keyboard keys. The visual tutorial continues to supply device-specific input guidance.

## How these lines fit the tutorial

- **Main lesson and completion lines: 46 clips.** Cover all nine Homeworld steps, all 33 combat lessons, the Homeworld conclusion, and the three course conclusions.
- **Optional help and conditional lines: 42 clips.** Use when a player needs a nudge, requests help, encounters a blocked door, or takes a particular branch. Do not narrate every menu click or play every reminder automatically.
- Normal route: A01–A08 → Basic D01–D14 → D34 → A24 when returning from Basic → A09 → A10. If the player chooses Later at the cave handoff, use A22 and continue to A09; do not play A24 as though they completed training.
- Advanced 1 (D15–D23, then D35) and Advanced 2 (D24–D33, then D36) are optional later courses. They are not a required extension of Basic.
- Use D51 instead of a first-completion reward line on replays. Reward lines run only after the corresponding completion/reward succeeds. Spoken copy avoids promising an extra earned level at the level cap; the existing reward UI supplies the exact level and item amounts.

## Playback and face staging notes for implementation

These are integration notes, not implemented behavior. Play only the relevant current line; never queue stale lesson instructions behind new ones. Fast menu progress should skip obsolete help. Do not repeatedly interrupt the player with the same nudge. Keep written objectives, subtitles, and input cues available, including when voice is muted or unavailable. Existing tutorial translations remain authoritative; this recording pack is English only.

Outside combat, use the encouraging angel apparition. In a training room, place a smaller local demon face within the active room rather than beyond a wall; a portrait fallback can keep him visible when room geometry or an open menu blocks the view. Keep faces clear of enemies, health cards, doors, pillars, and actionable UI. Pause ambient Watcher taunts while tutorial dialogue owns the scene. The existing Merge Watcher deliberately suppresses itself during combat training and menus, so it cannot simply be switched on as the tutorial narrator.

## Recording lines

### Angel — Farm & Fight introduction

| Clip | Cue | Spoken line |
| --- | --- | --- |
| **A01** | `tutorial.hatch_first_egg` | “There you are, little light. Your companion could use a friend. Follow the trail to the Earth Egg, and let’s wake one.” |
| **A02** | `tutorial.farm_crystals` | “See those crystals? With Farm Near on, your pets will mine beside you. Help them along, and we’ll soon have coins for another friend.” |
| **A03** | `tutorial.hatch_another` | “You’ve earned another egg. Shall we see who’s waiting inside? Every new friend gives your little squad more strength.” |
| **A04** | `tutorial.build_squad` | “I’ve left a Rainbow Kitty in your inventory. Open Pets, and let’s make room for that bright little spark on your squad.” |
| **A05** | `tutorial.bind_power` | “There’s a gift within you, too. It’s called Resonance. Open Edit on your power bar, and give it a place where you can reach it.” |
| **A06** | `tutorial.cast_power` | “Now, try Resonance near the crystals. Feel that? Your power helps them break faster and yield a little more.” |
| **A07** | `tutorial.slot_power` | “A little Potency will make that gift stronger. Open Powers, and let’s add your new enhancement to Resonance.” |
| **A08** | `tutorial.first_fight` | “The Earth cave is a place to practice fighting. Follow the trail when you’re ready. Its instructor has rather more horns than patience.” |
| **A09** | `tutorial.rally_call` | “A good leader knows when to call everyone home. Try Rally—the flag on your power bar—and bring your pets back to your side.” |
| **A10** | `tutorial.completion` | “Look how far you’ve come. The Ascension Altar is ready for you. Choose your next power, then follow your missions. There’s a whole world waiting.” |

### Demon — Basic Combat Training

| Clip | Cue | Spoken line |
| --- | --- | --- |
| **D01** | `combat_tutorial.ready` | “So. The angel sent me another promising little soul. Choose Enter on that frost door. I’ve found you something suitably unimpressive to fight.” |
| **D02** | `combat_tutorial.first_fight` | “There’s your opponent. Get close and let your pets do the fighting. Yes, they do most of the work. Try to look involved.” |
| **D03** | `combat_tutorial.advance_stage` | “One training dog defeated. Terrifying. The glowing pillar takes you back to the lobby. We’ll see if that was luck.” |
| **D04** | `combat_tutorial.battle_brew` | “Berserk Brew. A little borrowed ferocity for your pets. Take a sip from your power bar. This is the safe room, after all.” |
| **D05** | `combat_tutorial.ready_brew` | “Feeling fierce? Enter the arena. Let’s find out whether your pets agree.” |
| **D06** | `combat_tutorial.brew_fight` | “Notice the harder hits? That’s the brew. Finish this one before you start taking all the credit.” |
| **D07** | `combat_tutorial.advance_brew` | “Better. The pillar will bring you back. Next, we address your squad’s regrettable habit of getting hurt.” |
| **D08** | `combat_tutorial.bind_heal` | “You have Heal. How inconvenient for me. Open Edit, put it on your power bar, and finish with Done.” |
| **D09** | `combat_tutorial.enhance_heal` | “Let’s make Heal worth using. Open Powers and give it the Healing enhancement I provided. I prefer my opponents properly prepared.” |
| **D10** | `combat_tutorial.ready_heal` | “Your healing lesson awaits. Enter the arena—and do pay attention to your pets this time.” |
| **D11** | `combat_tutorial.select_pet` | “That yellow health bar belongs to your wounded pet. Select its card. Admiring the problem won’t mend it.” |
| **D12** | `combat_tutorial.cast_heal` | “Now use Heal on the pet you selected. Once it recovers, those enemy shields come down. Consider that your warning.” |
| **D13** | `combat_tutorial.heal_fight` | “Shields down. Finish both training dogs. The exit pillar is for winners, little hero.” |
| **D14** | `combat_tutorial.advance_heal` | “The room is clear. Use the glowing pillar to finish Basic Training. You’ve become slightly less likely to embarrass yourself.” |

### Demon — Advanced 1: weakening and brew stacking

| Clip | Cue | Spoken line |
| --- | --- | --- |
| **D15** | `combat_tutorial.ready_weaken` | “Back for more? How irritatingly diligent. I’ve given you Weakening Vials. Enter the arena, and we’ll spoil someone’s defenses.” |
| **D16** | `combat_tutorial.select_enemy` | “Choose the marked enemy’s card. The vial needs a target. Throwing it at your own feet would make a very short lesson.” |
| **D17** | `combat_tutorial.throw_weaken` | “Throw the Weakening Vial at your target. Down come the shields. Then you can get on with the unpleasant business of winning.” |
| **D18** | `combat_tutorial.weaken_fight` | “Their shields are gone. Defeat both dogs. No, the pillar won’t rescue you from unfinished work.” |
| **D19** | `combat_tutorial.advance_weaken` | “You found a weakness and used it. Almost devious. Take the pillar back to the lobby.” |
| **D20** | `combat_tutorial.stack_brew` | “More Berserk Brew means bigger hits, not a longer timer. Drink five sips. We’re building a damage meter, not a collection.” |
| **D21** | `combat_tutorial.ready_stack` | “There. A proper dose of trouble. Enter the arena while that damage meter has something left to give.” |
| **D22** | `combat_tutorial.stack_fight` | “Now watch those hits. Much more convincing. Finish the dog before your borrowed courage wears off.” |
| **D23** | `combat_tutorial.advance_stack` | “That was almost efficient. The glowing pillar finishes this course. I suppose you’ll want your reward.” |

### Demon — Advanced 2: tanks, healers, and the final room

| Clip | Cue | Spoken line |
| --- | --- | --- |
| **D24** | `combat_tutorial.ready_tank` | “Let’s put something sturdier between your squad and disaster. Open Pets. One doggy is making room for a bear.” |
| **D25** | `combat_tutorial.tank_fight` | “The tank draws attention and takes the punishment. It hits less hard, but your other pets get to keep their dignity—and their health. Finish the fight.” |
| **D26** | `combat_tutorial.advance_tank` | “Still standing. How tiresome. Take the pillar back; your next opponents have learned a little trick.” |
| **D27** | `combat_tutorial.ready_healer` | “The next pack brought a healer. Leave it alone and it will keep repairing your hard work. Enter when you’ve grasped the problem.” |
| **D28** | `combat_tutorial.healer_hunt` | “That green healing mark is your clue. Send your pets after the healer first. I’d rather you didn’t, which should tell you everything.” |
| **D29** | `combat_tutorial.healer_fight` | “Healer down. Now finish the rest of the pack. They’re suddenly much less optimistic.” |
| **D30** | `combat_tutorial.advance_healer` | “There. No one left to patch them up. Back through the pillar. One last room, and I stop holding your hand.” |
| **D31** | `combat_tutorial.ready_together` | “Final room. Two dogs, one healer, and no helpful arrows. You have the tools. Enter when you’re ready to make me regret teaching you.” |
| **D32** | `combat_tutorial.together_fight` | “All yours, little hero. Clear the room. Let’s see what you remember when I stop telling you.” |
| **D33** | `combat_tutorial.advance_together` | “No arrows, and you still managed it. Deeply inconvenient. Take the glowing pillar and finish your training.” |

### Demon — Course completion lines

| Clip | Cue | Spoken line |
| --- | --- | --- |
| **D34** | `combat_courses.basic.completion` | “Basic Training, complete. Your pets and powers are ready for the world. Advanced lessons are optional. I’m sure you’ll miss my encouragement.” |
| **D35** | `combat_courses.advanced_1.completion` | “Advanced One, complete. You’ve earned a Double XP token. Use it from your inventory when you want the extra experience. Do try to make it count.” |
| **D36** | `combat_courses.advanced_2.completion` | “All courses complete. There’s a Double Coins token waiting in your inventory. Use it when you’re ready. You’ve become a rather troublesome little hero.” |

### Angel — Short help lines for menu substeps

| Clip | Cue | Spoken line |
| --- | --- | --- |
| **A11** | `tutorial.build_squad.guide.unequip` | “Your active squad is full. Let one pet rest in your inventory, and we can welcome the Kitty.” |
| **A12** | `tutorial.build_squad.guide.pick` | “There’s your Rainbow Kitty. Choose that little one for the open place on your squad.” |
| **A13** | `tutorial.build_squad.guide.activate` | “They’re ready. Choose Activate, and your new squad will join you.” |
| **A14** | `tutorial.bind_power.choose` | “Choose Resonance and an open place on your power bar. Put it wherever feels right to you.” |
| **A15** | `tutorial.bind_power.done` | “There it is. Choose Done to finish setting your power bar.” |
| **A16** | `tutorial.slot_power.pick_power` | “Choose Resonance. That’s the power we’re making stronger.” |
| **A17** | `tutorial.slot_power.pick_slot` | “An empty enhancement slot is a little room to grow. Choose one on Resonance.” |
| **A18** | `tutorial.slot_power.pick_enhancement` | “Choose Potency. It gives your crystal-boosting pulse a little more strength.” |
| **A19** | `tutorial.slot_power.apply` | “Choose Apply, and that extra strength becomes yours.” |
| **A20** | `tutorial.farm_crystals.reminder` | “Try a small crystal nearby. Keep Farm Near on, and let your squad earn the coins together.” |
| **A21** | `tutorial.cast_power.reminder` | “Bring your squad close to the crystals before you use Resonance. That’s where its gift can help.” |

### Demon — Short help lines for combat menu substeps

| Clip | Cue | Spoken line |
| --- | --- | --- |
| **D37** | `combat_tutorial.bind_heal.choose` | “Choose Heal, then give it a place on your power bar. Ideally somewhere you’ll remember when things start biting.” |
| **D38** | `combat_tutorial.bind_heal.done` | “Now choose Done. You can admire your arrangement after you survive.” |
| **D39** | `combat_tutorial.enhance_heal.pick_power` | “Choose Heal. We’re improving that power, not browsing for something prettier.” |
| **D40** | `combat_tutorial.enhance_heal.pick_slot` | “Choose an empty slot on Heal. Even your good intentions need somewhere to go.” |
| **D41** | `combat_tutorial.enhance_heal.pick_enhancement` | “Choose Healing. The name is a subtle clue.” |
| **D42** | `combat_tutorial.enhance_heal.apply` | “Apply it. A staged enhancement is doing precisely nothing for you.” |
| **D43** | `combat_tutorial.ready_tank.guide.unequip` | “Take a doggy off your active squad. The bear needs a place, not an invitation to an already full party.” |
| **D44** | `combat_tutorial.ready_tank.guide.pick` | “Choose your strongest bear. The Tank option in Best Pets can find it for you, if counting muscles proves difficult.” |
| **D45** | `combat_tutorial.ready_tank.guide.activate` | “Choose Activate. I need the bear in the fight, not posing in your inventory.” |
| **D46** | `combat_tutorial.ready_tank.guide.close` | “The bear is on your squad. Close Pets so we can get on with it.” |
| **D47** | `combat_tutorial.ready_tank.guide.enter` | “Your tank is ready. Enter the arena and let it earn its place.” |

### Angel — Handoffs and returning players

| Clip | Cue | Spoken line |
| --- | --- | --- |
| **A22** | `tutorial.first_fight.handoff` | “Of course. Training will be waiting in Quest whenever you’re ready. You can return to the Earth cave then.” |
| **A23** | `tutorial.resume` | “Welcome back, little light. We’ll carry on from where you left off. Follow your current lesson when you’re ready.” |
| **A24** | `tutorial.basic_return` | “Welcome back. I hope he remembered his manners. You’ve learned to look after your squad—and that matters far more than looking fearless.” |

### Demon — Course selection, interruptions, and blocked doors

| Clip | Cue | Spoken line |
| --- | --- | --- |
| **D48** | `combat_courses.menu` | “Basic first. Then, if you insist on improving, two advanced courses await. Choose your lesson, little hero.” |
| **D49** | `combat_courses.locked` | “Finish the earlier course first. Skipping the lesson is not the same as mastering it.” |
| **D50** | `combat_courses.replay.start` | “A repeat performance? Very well. The practice is yours; the first-time reward stays first-time.” |
| **D51** | `combat_courses.replay.completion` | “Finished again. No second reward, of course. Surely my company was compensation enough.” |
| **D52** | `combat_tutorial.leave_confirm` | “Leaving already? Your progress is saved. Come back when you’re ready to disappoint me properly.” |
| **D53** | `combat_tutorial.resume` | “Back, are you? Your completed lessons still count. We’ll prepare this round again before you enter.” |
| **D54** | `combat_tutorial.door.pets_equipped` | “Bring at least one pet. This is combat training, not an audition for the role of bait.” |
| **D55** | `combat_tutorial.door.hotbar_not_editing` | “Choose Done on your power bar first. I prefer my opponents assembled before the fight.” |
| **D56** | `combat_tutorial.door.heal_unbound` | “Heal belongs on your power bar. Put it there before asking that door to open.” |
| **D57** | `combat_tutorial.door.heal_unenhanced` | “Add Healing to Heal and apply it. Then we can discuss opening the door.” |
| **D58** | `combat_tutorial.door.brew_unused` | “The Berserk Brew is for drinking. One sip, little hero. Then you may enter.” |
| **D59** | `combat_tutorial.door.tank_missing` | “A bear on your active squad, please. Owning a tank is not the same as bringing one.” |
| **D60** | `combat_tutorial.stack_brew.remaining_4` | “Four more sips. That meter isn’t filling itself.” |
| **D61** | `combat_tutorial.stack_brew.remaining_3` | “Three more. I admire your commitment to doing this slowly.” |
| **D62** | `combat_tutorial.stack_brew.remaining_2` | “Two more sips. Even I can see you’re nearly there.” |
| **D63** | `combat_tutorial.stack_brew.remaining_1` | “One more. Let’s not lose our nerve at the finish.” |
| **D64** | `combat_tutorial.healer_hunt.lost` | “Your pets have wandered off the healer. Select it again. We were so close to having a strategy.” |

## Cue mapping and coverage

Cue names are planned voice bindings, not newly installed runtime events. `tutorial.*` maps to `configs/tutorial.lua`; `combat_tutorial.*` maps to `configs/combat_tutorial.lua`; course boundaries/completions map to `configs/combat_courses.lua`.

The main line supplies the opening cue for multi-part lessons: A04 also covers `build_squad.guide.open`; A05 covers `bind_power.edit`; A07 covers `slot_power.open`; D08 covers `bind_heal.edit`; D09 covers `enhance_heal.open`; D24 covers `ready_tank.guide.open`. Their additional phases have separate help recordings. The five-remaining Berserk reminder can reuse D20; D60–D63 cover four through one remaining. Do not announce every sip in a rapid sequence.

A23 is an optional session-resume greeting, followed by the current lesson only when helpful. D53 is for resuming an unfinished fight after the game rewinds it to preparation; for a saved pillar step, use that pillar’s existing main line instead. D54–D59 map to the existing blocked-door checks. D64 maps to `healer_hunt.lost_banner`. Course-menu/replay/leave lines apply only when those existing choices occur.

Coverage audit loaded the actual Lua configs: 9/9 Homeworld steps, 33/33 combat steps, 3/3 course completions, both bind-power phase sets, both enhancement phase sets, and both squad-edit guide sets are covered. All 88 clip IDs and cue keys are unique. Existing course projection, rather than the older monolithic 33-step completion block, determines each course’s final-pillar dialogue.
