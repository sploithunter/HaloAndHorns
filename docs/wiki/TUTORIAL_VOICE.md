# Farm & Fight tutorial voices

2026-09-08: 88 generated source recordings, not yet a playback feature.

- Angel/Heaven face: encouraging outside combat. Demon/Hell face: slightly mocking throughout
  combat training, including room/lobby preparation. Keep the established Watcher personalities.
- Canonical spoken copy: `configs/tutorial_voice_lines.lua` (`status = "audio_generated"`).
  [Complete recording sheet](../TUTORIAL_VOICE_SCRIPT.md) has all 88 lines, performance notes,
  cue mapping, optional help, and branch conditions. No audio IDs or runtime hooks are installed.
- Coverage follows the current 9-step Homeworld path and three independent combat courses
  (14 Basic, 9 Advanced 1, 10 Advanced 2). Advanced lessons stay optional. Do not use the historical
  monolithic combat completion text for course exits.
- Short help clips supplement the main performance; do not read every UI action or queue obsolete
  instructions. Keep written/device-specific guidance and existing localization available.
- Room staging still needs implementation/verification. Keep the demon inside the current room,
  with a portrait fallback if geometry obscures him, and preserve visible targets/actions.
  `MergeWatcher` currently suppresses itself during training and menus; tutorial narration needs
  its own lifecycle and priority over ambient taunts.

Related: [Combat Tutorial](COMBAT_TUTORIAL.md), [Tutorial Localization](TUTORIAL_LOCALIZATION.md),
[Watcher encounters](MERGE_EGG_PROTOTYPE.md#watcher-encounters-and-early-activity-xp-2026-09-05).

## Recorded source audio — 2026-09-08

All 88 MP3s (24 angel / 64 demon) are in `assets/audio/voices/tutorial/`, with a
manifest, provider character timing sidecars, and technical validation. Both supplied
voice IDs were used unchanged; the user listened to A01/D01 and approved the voices.
Exact copy/cue mapping, hashes, full decoding, timing bounds, non-silence, and clipping
checks pass. Provider alignment is not independent transcription or a full listening review.

The user requested the merged Watcher volume balance for tutorial playback. The catalog's
`playbackVolumeSource` references the existing Merge values (angel 1.2 / demon 2.34 now);
resolve those references during integration rather than baking gain into the MP3s.
Roblox upload/permissions and face/playback lifecycle remain pending.
