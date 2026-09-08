# Tutorial localization listening pilot

Open `listen.html` for four listening reels, individual originals, translated text, and English
meanings. Each reel contains welcome → instruction → reminder. Spanish aims for a neutral Latin
American delivery; Portuguese targets Brazil. The same approved angel/demon ElevenLabs voices
and multilingual-v2 settings are used throughout.

`configs/voice_pilots/spanish_portuguese.json` is the canonical script/settings source.
`manifest.json` contains generation provenance, request IDs, billed character costs, hashes,
voice IDs, and durations. Original MP3s and alignment sidecars are kept in locale/character
folders. `validation.json` records successful technical checks for all 12 originals; provider
alignment is not independent transcription or a fluent-speaker listening review.

`reels/` contains derived listening copies with one-second gaps and loudness normalization to
-18 LUFS, targeting -1.5 dBTP. `reels.json` records actual measured loudness/peaks and original
clip ordering. This only matches review volume; it does not modify original clips or the
existing in-game angel/demon gain settings.

This is a pilot for approval. No runtime voice-language selection and no Roblox uploads are
included. Keep full-batch generation pending review of accents, character, pacing, and game-term
pronunciation, especially Waycoins and incubadoras.
