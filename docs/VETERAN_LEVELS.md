# Veteran Levels — the post-50 XP track

**Decision (Jason, 2026-07-02):** level **50 stays the build cap** — no stats, no power past it;
the endgame power chase stays enhancements/sets/perma. But XP keeps counting, and every
`xp_per_level` past the cap becomes a **Veteran Level**. This is the *"keep going"* branch for
players who don't want the **Rebirth** climb (playing for dragons — see
`docs/PET_REALM_DESIGN_DOCUMENT.md` § "Dragons, Secrets, and Player Class (Rebirth)"). The two
coexist: at 50 you either rebirth (class 2, dragon teams) or stay and accrue vet levels.

## What a vet level pays

Deliberately **valuable but never a power ceiling** — everything it pays already exists in the
economy; vet levels are a reliable drumbeat of it:

| Beat | Reward |
| --- | --- |
| every vet level | `rolls_per_level` enhancement cog roll(s) — the DROPS economy (deliberately **not** a currency faucet; per-level gem bundles are being retired from level_track for the same reason) |
| every `premium_every`th | `premium_bonus_rolls` extra roll(s) — the premium beat |
| every `announce_every`th | STATUS milestone — celebration event fires with `milestone = true` (world announcement / titles hang here later) |

**Flat curve** (`xp_per_level`, constant): a metronome, not an escalating wall — the escalation
lives in content (bosses, arch-villains, hell-hatch), not the track.

## Where it lives

- `configs/veteran.lua` — all knobs (own file, NOT level_track — that file has in-flight economy
  edits and this track is orthogonal to the claim machinery).
- `src/Shared/Game/VeteranTrack.lua` — pure math (level/progress/rolls/milestone), headless-tested
  in `tests/headless/specs/veteran_track.spec.luau`.
- `PlayerProgressionService` — at the cap, `_publish` computes vet progress off the already-
  monotonic total XP and publishes `VetLevel` / `VetXP` / `VetXPForNext` attributes; a paid-level
  ledger (`data.VeteranPaid`) grants rewards exactly once per vet level (offline-safe: whatever
  was earned since last save pays out on the next publish).
- `configs/game_events.lua` `veteran_level` — the celebration row (jingle + burst; milestone
  variants later).
- `PlayerBar` — at the cap the pegged XP bar becomes the vet bar: fills toward the next vet level
  and reads `VET N · x / y XP` instead of freezing at `34300 / 34300`.

## Rewards flow

`VeteranTrack.level(totalXp, capXp)` rises → `_veteranPass` grants `EnhancementService:RollDrop`
(player's current area flavors the origin, like world drops) → `Grant` → the celebration event.
`capXp = LevelCurve.xpForLevel(max_level)` — the XP at which level 50 was earned.

## Future

- Titles/nameplate pips at milestone vet levels (10/25/50…), world-first-style announcements.
- Rebirth interaction: rebirthing resets the LEVEL climb; whether vet levels persist across
  classes (lifetime veteran-ness) or reset with it is an open design call — leaning PERSIST
  (they're status + economy, not power).
