# Crossroads orientation recordings

Seven original performances using the existing approved ElevenLabs angel/demon voices and
settings. Canonical copy/settings: `configs/voice_comments/crossroads.json`; runtime captions and
sequences: `configs/crossroads_tutorial.lua`; uploaded IDs: `configs/crossroads_voice_assets.lua`.
The two upload manifests contain group-owned Roblox Audio IDs (group 15872767).

`manifest.json` records exact input, voice IDs, model, seed, request IDs, source hashes and durations.
`validation.json` covers decode, alignment metadata, hashes, non-silence and clipping. Alignment
is provider metadata, not independent transcription. Native Studio Sound PreloadAsync + IsLoaded
passed all seven clips on 2026-09-09. Runtime uses the existing character gains and Voices bus.
New hub lines currently fall back to English for all tutorial locale preferences.
