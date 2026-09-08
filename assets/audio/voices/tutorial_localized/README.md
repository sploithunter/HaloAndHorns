# Localized Farm & Fight tutorial recordings

184 original MP3s: all 92 Farm & Fight cues in Spanish and Brazilian Portuguese.
The approved voice IDs, settings, translated copy, English meanings and source cue IDs live in
`configs/voice_localization/spanish_portuguese.json`. The manifest records exact requests,
durations, SHA-256 hashes, character alignments and any reused pilot source.

Keep original provider audio for Roblox. Playback uses the existing angel/demon base gains and
Voices Volume curve; do not bake the review-reel normalization into these recordings.
`roblox_ids.json` and `upload_operations.json` record group-owned assets. An accepted upload can
still be awaiting Roblox moderation. Do not re-upload a pending asset to bypass moderation.

Technical validation checks decode, canonical text/cue/voice identity, timing, hashes, non-silence
and clipping. Provider alignment is not an independent transcription or a human review of every
performance. The short pilot was listened to and approved by the user.

To review all 344 Farm & Fight and Merge recordings locally:

```sh
python3 -m http.server 34881 --bind 127.0.0.1 --directory assets/audio/voices
```

Open `http://127.0.0.1:34881/tutorial_localized/listen.html` and choose language, game and character.
Each clip has its translated script and English meaning. The player never autoplays another line.
