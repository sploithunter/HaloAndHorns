# Farm & Fight tutorial recordings

English source recordings generated with ElevenLabs on 2026-09-08 from the
approved dialogue in `configs/tutorial_voice_lines.lua`. One MP3 per stable cue ID:
27 encouraging angel clips (`angel/A01.mp3`–`A27.mp3`) and 65 lightly mocking demon
clips (`demon/D01.mp3`–`D65.mp3`). Optional help clips are separate from the lesson route.

- Angel voice: `thfYL0Elyru2qqTtNQsE`.
- Demon voice: `NxGA8X3YhTrnf3TRQf6Q`.
- Model: `eleven_multilingual_v2`; original 44.1 kHz, 128 kbps MP3 output.
- `manifest.json` records exact submitted text, cue/speaker mapping, voice settings,
  per-clip seed, request metadata, timestamps, duration, size, and SHA-256.
- Each MP3 has an `.alignment.json` sidecar with provider character timings for
  future subtitle/playback work. This is provider alignment, not independent ASR.
- `validation.json` records complete-file decoding, hashes, mapping, timing,
  non-silence, and clipping checks. These checks do not replace a listening review.
- Files are the original response bytes, without normalization or other processing.

Generation uses POST `/v1/text-to-speech/{voice_id}/with-timestamps` with the
manifest model, speaker settings, clip text, and seed; query
`output_format=mp3_44100_128`. A seed is best-effort, not guaranteed reproducibility.
The API key is loaded locally and is never stored in this recording pack. Completed
clips are checkpointed individually; reuse them instead of spending credits again.

The user listened to A01 and D01 and approved both voices. They requested the
existing merged Watcher volume tuning for tutorial playback: angel 1.2 and demon
2.34 at recording time. `tutorial_voice_lines.playbackVolumeSource` points to the
canonical Merge config paths; resolve those paths when implementing playback,
respect the existing audio bus/preferences, and do not apply these gains twice.
The source MP3s intentionally retain their original levels.

`roblox_ids.json` records the group-owned Roblox uploads; `configs/tutorial_voice_assets.lua`
binds each cue and decoded duration. TutorialNarrator plays them through the Voices mix and
stages the approved angel/demon faces. A25 welcomes the starter choice; the revised A01 begins
only after that choice succeeds. Source validation covers all 92 recordings. Roblox delivery
checks are recorded separately in `runtime_validation.json`.

See [`docs/TUTORIAL_VOICE_SCRIPT.md`](../../../../docs/TUTORIAL_VOICE_SCRIPT.md) for the
full recording sheet, conditional cues, and runtime notes.
