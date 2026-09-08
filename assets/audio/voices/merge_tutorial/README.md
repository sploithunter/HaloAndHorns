# Merge tutorial performances

80 English recordings: 40 Heaven/angel cues and 40 Hell/demon cues. Canonical dialogue and
cue mappings are in `configs/merge_tutorial_voice_lines.lua`; the readable recording sheet is
`docs/MERGE_TUTORIAL_VOICE_SCRIPT.md`. Runtime IDs/durations are config-owned in
`configs/merge_tutorial_voice_assets.lua`.

The supplied, previously approved ElevenLabs voices use `eleven_multilingual_v2` and the same
settings as Farm & Fight. `manifest.json` records text, voice, settings, source hashes, timings,
and Roblox IDs. MP3s are original provider outputs; alignment sidecars retain character timing.
`roblox_ids.json` records uploads owned by group 15872767. No credentials are included.

`validation.json` checks all 80 clips: decode, SHA-256, voice/cue/input mapping, alignment bounds,
non-silence, and clipping below 0.1%. Duration totals 857.699 seconds. Provider alignment is not
an independent transcription or a complete human listening review.

Studio validation uses actual Sound instances with `PreloadAsync({sound})`, `IsLoaded`, and
positive `TimeLength`; upload success alone does not prove moderation or delivery readiness.
The native smoke exercises 38 main step/side combinations and shared playback lifecycle without
writing profile progress. Farm & Fight's 42-step smoke remains a regression check.
