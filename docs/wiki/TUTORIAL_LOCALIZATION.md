# Tutorial Localization

Last checked: 2026-09-08

## Current contract

- `TutorialLanguageState` observes the local player's Roblox translator locale. The saved
  preference defaults to `auto`; the Settings menu can force `en` (English), and that choice is
  persisted in `Settings.ClientPrefs.tutorialLanguage`.
- The tutorial currently has explicit Spanish and Brazilian Portuguese catalogs. Roblox locale
  variants such as `es-MX` and `pt-PT` resolve into those catalogs. Every other locale keeps the
  authored English config copy, so missing translations can never blank or expose a key.
- Tutorial config entries publish stable `localization_key` values. `TutorialFlow` includes the
  derived title/body keys in client state while retaining raw English title/body fields as the
  compatibility fallback.
- In Auto mode, a supported non-English player receives one session banner naming the detected
  language and explaining that the tutorial can be changed to English in Settings. The banner
  deliberately says **tutorial**, because the rest of the game has not yet been claimed as fully
  localized.

## Extending coverage

Add a locale catalog to `src/Shared/Game/TutorialLocalization.lua`, update `languageFor` and
`DISPLAY_NAMES`, and add coverage to `tests/headless/specs/tutorial_localization.spec.luau`.
Do not translate only the visible current step: every authored tutorial key must exist before a
language is advertised as supported.

## Spoken tutorials

The user approved the Spanish/Brazilian Portuguese angel and demon pilot on 2026-09-08.
Full voice coverage is 172 cues per language: 92 Farm & Fight/Homeworld/combat-course cues,
plus 40 Heaven and 40 Hell Merge cues. This includes conditional menu/door help, reminders,
replays, completion, Auto Collector branches and optional hatcher-distribution advice.

- `configs/voice_localization/spanish_portuguese.json` owns translated performances, their
  English meanings, source cue identities, approved ElevenLabs voices and generation settings.
  English button/power labels are retained where those are the labels on the live menus.
- `configs/tutorial_voice_locales.lua` maps each normalized language and canonical cue to its
  group-owned Sound ID and decoded duration. It names the recording catalog above. English
  catalogs still determine speaker, cue sequencing and the established character gains.
- Both tracks use the shared `TutorialNarrator`. `TutorialLocaleId` (already resolved by
  `TutorialLanguageState`) selects speech as well as written guidance. Settings stays Auto/English;
  locale variants resolve through the same `TutorialLocalization.languageFor` function.
- Changing language replaces an active performance, preserving its completion/reminder flags
  and queued instruction. An idle/completed/cancelled lesson is never revived by a locale change.
  Locale changes within the same language do not restart a clip.
- Missing localized entries fall back per cue to English. Failed loads/timeouts retry that cue
  once in English, retaining its queue. The failed localized asset is remembered by that narrator
  for the session, so a reminder cannot repeatedly hit the same unavailable recording. English
  load failure ends normally; it never retries in a loop or blocks tutorial progress.
- No new server requests, saved settings, bulk preload, or per-locale face/mixer copies are added.
  Gameplay faces remain in world; menus use portraits. Voices Volume and background ducking
  use the existing audio bus and character tuning.

Original recordings, exact-input alignment, request provenance, byte hashes, technical checks,
upload IDs and Studio delivery results live in `assets/audio/voices/tutorial_localized/` and
`assets/audio/voices/merge_tutorial_localized/`. The 12 approved pilot MP3s are reused byte for
byte, not regenerated. Normalized pilot listening reels are never uploaded for game playback.
The full listening page is `assets/audio/voices/tutorial_localized/listen.html`; serve the parent
`assets/audio/voices` directory so it can also access the Merge recordings.

`tutorial_voice_locale.spec.luau` checks complete coverage, shared normalization and per-cue
fallback. `TutorialVoiceLocaleSmoke` checks runtime switching, queue/flag preservation, unchanged
mix, failure fallback, cancellation and connection cleanup on both track catalogs. Existing
Farm and Merge voice smoke tests remain regression gates. Upload success alone is not delivery
approval; validate actual Sound instances in Studio and preserve IDs while moderation completes.
