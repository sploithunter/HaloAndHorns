# Farm & Fight tutorial voices

2026-09-08: runtime integration for 92 recorded cues (27 angel / 65 demon).

- `configs/tutorial_voice_lines.lua` owns English spoken copy and references the established
  Watcher volume tuning. `tutorial_voice_assets.lua` binds group-owned uploaded Sound IDs and
  decoded durations; `tutorial_voice.lua` owns presentation, delays, and face models.
- [Recording sheet](../TUTORIAL_VOICE_SCRIPT.md) covers the starter choice, 9 Homeworld steps,
  and 3 independent combat courses (14 Basic, 9 Advanced 1, 10 Advanced 2), plus conditional help.
- StarterPetController opens A25's angel welcome with the companion chooser. Homeworld speech
  waits for the authoritative successful-choice/ineligible response. Revised A01 follows closure;
  duplicate tutorial/menu updates neither restart the welcome nor skip the choice.
- TutorialController feeds authoritative TutorialState into TutorialNarrator. Course selection,
  locked choices, leave confirmation, blocked doors, power/hotbar phases, squad preparation,
  stack counts, and losing the healer target supply conditional cues. Help waits 12 seconds;
  optional help plays at most once per lesson. Replaced phases discard obsolete help.
  Idle reminders begin after 45 seconds and repeat every 60 idle seconds. Menus and active
  combat pause the timer; count/lesson progress resets it. Completed/left lessons never remind.
- One current Sound and one replaceable next cue keep narration bounded. Only the current clip
  preloads. Lesson changes replace old speech; live course completion finishes before the angel's
  Basic return and Homeworld lesson. Initial completed profiles never hear completion praise.
  Replays use their own intro/exit and do not announce first-time rewards.
- CombatTutorialService pushes completion before mission teardown, including replays without
  a rank ceremony delay. Narration does not grant rewards or advance saved tutorial progress.
- TutorialVoiceTemplates shares two sanitized MeshParts from the approved Watcher models.
  Both faces stay in the world during gameplay, including combat rooms. They follow the camera
  periphery near 45 degrees, capped by the current field of view. World size/distance and smooth
  follow/turn tuning come from Merge; nearby walls shorten distance and scale smoothly. Only
  menus use a header portrait drawn above their UI. Presentation stays local and creates no NPC
  or server animation. There is no visibility-based world/portrait switching.
- Prologue/death cancel speech; Roblox's native menu pauses it. TutorialNarrationActive suppresses
  ambient Merge Watcher and RealmHellFaces encounters. Sounds, faces, mixer effects, and the
  bus-volume connection have explicit cleanup. Voices mute also releases background ducking.
- Written/device-specific guidance and existing localization stay authoritative. These spoken
  recordings are English; unavailable/muted audio never blocks play.

## Verification and recording provenance

All 92 source MP3s are in `assets/audio/voices/tutorial/`, alongside the generation manifest,
character timing sidecars, technical validation, uploaded IDs, and Studio delivery results.
Both supplied ElevenLabs voice IDs are unchanged. The user approved the original A01/D01 voices;
A25 and revised A01 follow their requested starter-choice correction. Decode, SHA-256, exact
input/cue mapping, timing bounds, non-silence, and clipping checks pass. Provider alignment is
not an independent transcription or a full listening review.

`tests/headless/specs/tutorial_voice.spec.luau` checks cue coverage/selection.
`tests/studio/TutorialVoiceSmoke.lua` exercises all 42 main lesson states, starter gating,
duplicate suppression, recurring reminder timing, replay/completion handoff, face creation, Voices routing, and cleanup
without changing progress or saved settings. Asset delivery is checked with actual Sound
instances (`PreloadAsync({sound})` + `IsLoaded`), not raw content strings, which produced misleading
failures. Upload completion does not imply moderation completion; check each new recording.

Related: [Combat Tutorial](COMBAT_TUTORIAL.md), [Tutorial Localization](TUTORIAL_LOCALIZATION.md),
[Watcher encounters](MERGE_EGG_PROTOTYPE.md#watcher-encounters-and-early-activity-xp-2026-09-05).

## Voices preference — 2026-09-08

Settings → Audio → Voices Volume is saved as `Settings.ClientPrefs.audio.voicesVolume`
(a 0–1 slider level), restored by `AudioPrefs` at boot, and defaults to 50% for old/new
profiles. `configs/audio.lua` owns the label, default, curve, and bus limits. Gain is
`4 * level^2`: 0% mutes, 50% preserves the tuned base volume, 100% amplifies it fourfold.
The outer 3% of the voice slider snaps to mute/max for reliable touch endpoints.
Master scales voices; Effects and Music remain independent. Existing angel/demon Watcher
speech now mirrors the `voices` bus, preserving its 1.2/2.34 per-character base levels and
background ducking. Muting voices releases ducking. Tutorial playback uses this same bus.

## Merge narration — implementation in progress (2026-09-08)

[Paired Heaven/Hell scripts](../MERGE_TUTORIAL_VOICE_SCRIPT.md) cover the current Wave 0–14
onboarding, Auto Collector branches, skippable egg improvement, power menu help, and idle
encouragement. Both scripts advise spreading defenders across hatchers without making it a gate.
The owned bay’s replicated side selects the speaker; shared playback/presentation and Voices
preferences are reused. Recording, delivery, and runtime validation are in progress.
