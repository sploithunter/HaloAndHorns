# Crossroads arena audio

User-supplied Downloads clips, uploaded to the project group (15872767).

- `arena_lets_go.mp3`: unchanged `SPRTMisc-An_excited_sport_com-Elevenlabs.mp3`, 5.88 seconds.
  Plays locally for the entrant, through the Voices preference, once on crossing into the arena.
- `arena_thunderclap.mp3`: `DSGNBoom-Hyper-realistic_thun-Elevenlabs.mp3`, trimmed at 3.51 seconds
  just before the main transient at approximately 3.524 seconds. Retains the full rumble tail.
  Gain 0.44 reduces decoded overshoot; a 5 ms fade at the cut prevents a click without softening
  the strike. Plays through Effects once per enemy arrival batch, including reduced-motion mode.

The source Downloads are untouched. Asset IDs are recorded in `asset_ids.json`; runtime IDs,
levels and entry cooldown live in `configs/crossroads_arena.lua`.

Reproduce the thunder edit with FFmpeg:

```sh
ffmpeg -i "$HOME/Downloads/DSGNBoom-Hyper-realistic_thun-Elevenlabs.mp3" \
  -af 'atrim=start=3.51,asetpts=PTS-STARTPTS,volume=0.44,afade=t=in:st=0:d=0.005' \
  -codec:a libmp3lame -b:a 192k arena_thunderclap.mp3
```
