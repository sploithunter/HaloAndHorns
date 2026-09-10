# Crossroads roaming host voices

Twenty English ElevenLabs performances using the approved existing angel/demon voices.
Canonical generation input: `configs/voice_comments/crossroads_hosts.json`.
Runtime copy and asset IDs: `configs/crossroads_host_lines.lua` and
`configs/crossroads_host_voice_assets.lua`.

`manifest.json` preserves settings, text, duration, file hashes and request provenance.
Each MP3 has character alignment; `validation.json` records decoding/alignment checks.
`uploaded-angel.json` and `uploaded-demon.json` record group-owned Roblox uploads.
All 20 assets passed native Studio preload checks on 2026-09-09. Three initial fetch
failures succeeded on retry after confirming Approved/Active status; no reuploads.

HOST_A01 and HOST_D01 supersede the original Crossroads welcome and hell introduction.
The other original exchange recordings remain in use. New recordings currently provide
English fallback for all languages. Physical heads are shared world actors; audio and
captions are delivered separately to nearby listeners through the existing Voices bus.
