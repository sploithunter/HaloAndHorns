# Farm & Fight tutorial voices

2026-09-08: user-directed recording script, not yet a playback feature.

- Angel/Heaven face: encouraging outside combat. Demon/Hell face: slightly mocking throughout
  combat training, including room/lobby preparation. Keep the established Watcher personalities.
- Canonical spoken copy: `configs/tutorial_voice_lines.lua` (`status = "script_only"`).
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
