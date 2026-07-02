# Titan Mode — the player pinnacle (FUTURE WORK / ON HOLD)

**Status:** On hold — design captured, no code written. Candidate for a future branch.
**Owner:** Jason (concept) · design notes from the 2026-06 session.
**Not to be confused with** the *ice titan* enemy/lair content (`assets/.../ice_titan_lair`,
`configs/guardians.lua`, `configs/enemies.lua`) — that is a boss/mob. THIS is a player mode.

---

## 1. What it is & why

A creator pet is the **pinnacle of a pet** (apex class, granted only to the creator). Titan
Mode is the **pinnacle of the player** — a temporary, toggleable state that turns a dev
account into a fully-built, max-level character so we can *see and balance* "what a top-level
character looks like."

**Primary purpose: scaling / balance tuning — it is combat-real, not a cosmetic flex.** The
build must behave in combat exactly as a legitimately-maxed player would, so the numbers we
read off it are trustworthy for balancing.

**Dev-account setup:** four dev accounts, one per origin
(geomancer / pyromancer / cryomancer / sandwalker), each toggling Titan to inspect that
origin's top-end.

---

## 2. Locked design decisions (from the session)

- **Combat-real**, not cosmetic. Routes through the real power/combat pipeline.
- **Magnitudes capped as in-game.** It's the *honest* best a real player could be, NOT
  uncapped god-mode. Enhancements scale through the normal `Enhancements.aggregate()` level
  factor + axis caps.
- **Identity = max level (currently 50).** While Titan is active the account is treated as
  L50 so the capped build reads as genuine end-game (`aggregate()` scales magnitude by level
  and gates slot level vs player level — a L1 account would otherwise read low).
- **All powers granted**, every power slot filled.
- **Enhancements: random single-origin per slot.** Each filled slot gets a single-origin
  enhancement; the origin is chosen at random per slot (so a power wears a mixed-origin
  "rainbow"). For powers that accept multiple modifier types, fill each slot with a random
  single-origin of a compatible type.
- **Temporary + toggleable off.**
- **Admin / dev-userId gated** (not a player-facing ability).
- **Pet squad: equip 10.** (See §4 — the squad cap is *already* 10, so this is about what
  *fills* the squad, plus a reboot safeguard.)

---

## 3. Architecture — power loadout (in-memory overlay; profile never mutated)

The player loadout lives in persistent profile data (`data.Powers` = ordered picks,
`data.Slots[powerId]` = slot/enhancement records) and is read by combat, passives, the
hotbar, and the HUD — almost all of it via `PowerService:GetState` and
`PowerService:ReapplyPassives`. There are ~33 readers across ~9 files, but they're
**concentrated in PowerService** (combat/client don't read `data.Slots` directly — they go
through PowerService).

**Decision: never mutate `data.Powers` / `data.Slots`. Use a transient overlay.**

- `PowerService._titan[player] = { powers, slots }` — in memory only, never written to `data`.
- Add `PowerService:_effectivePowers(player)` / `:_effectiveSlots(player)` that return the
  Titan tables when active, else the real `data.*`.
- Route the **read** sites through those accessors:
  - `PowerService:GetState` (the wire view → hotbar/HUD)
  - the cast / magnitude resolver
  - `PowerService:ReapplyPassives`
  - `EnhancementService:GetState` aggregate (reads `data.Slots`)
- **Writes** (`PowerService:Select`, `EnhancementService:Slot`, `AugmentationService:Place`)
  keep targeting real `data` and are **blocked while Titan is active**.
- Toggle off / `Players.PlayerRemoving` / `game:BindToClose` → drop the table + one
  `ReapplyPassives` to re-derive stamped stats.

**Why overlay, not mutate-and-restore:** these are dev accounts. If the profile autosaved a
synthetic god-build and the server died before restore, the account's real progression would
be permanently overwritten. The overlay makes that impossible by construction — the Titan
state is never in `data`.

**Level identity:** while active, also stamp the reference level (config; currently 50) and
any derived stats so the capped enhancements aren't level-gated down; restore on toggle-off.
`data.Archetype` is left **untouched**, so per-origin combat resonance still reads each dev
account's true origin.

### Loadout builder (pure, headless-testable)
- All power ids from `configs/powers.lua`.
- For each power, read its compatible modifier types and fill its slots with
  `slot.enh = { type = <compatible kind>, origins = { random_single_origin }, level = <ref L50> }`.
- Constructing `slot.enh` directly **bypasses** the normal `Enhancements.usableBy` origin gate
  (intentional — Titan mixes all origins regardless of the account's archetype). No gate-hack
  needed; just don't route through `EnhancementService:Slot`.
- This is a pure function over config → unit-testable with no Roblox APIs.

---

## 4. Pet squad — the reboot-safe part (the bit Jason flagged)

**Finding:** the active-squad cap is *already* 10 — `configs/squad.lua` `active_squad = 10`,
flat, checked directly by `ActiveSquad.canDeploy`. So Titan does not need to *raise* a cap;
the question is what *fills* the squad, and how to keep that off disk across a reboot.

**Risk:** the squad persists. Every deploy writes `data.ActiveSquad` and `RequestSave`s
critically (`ActiveSquadService:Deploy`). So whatever Titan equips is on disk immediately;
an accidental reboot would leave it saved as if legitimate.

**Recommended safeguard — write-through + backup + reconcile-on-load:**
- **Titan ON:** snapshot the real squad → `data.TitanSquadBackup`, set `data.TitanActive =
  true` (critical save), *then* set the Titan squad.
- **Titan OFF:** restore `data.ActiveSquad` from the backup, clear both fields, save.
- **Reboot safeguard:** on data load, if `data.TitanActive` is still set (died mid-Titan),
  restore `ActiveSquad` from `TitanSquadBackup` and clear the flag. The player **always**
  returns with their real pre-Titan squad — never the Titan one.

Write-through-with-backup (rather than an in-memory overlay like the powers) is chosen here
specifically because the squad must be reboot-recoverable: the backup is the recoverable
source of truth, and it needs zero combat/team-power reader rerouting.

### OPEN QUESTION (undecided — was interrupted)
When Titan turns on, **where do the 10 squad pets come from?**
1. **Auto-equip 10 best owned** — equip up to 10 of the account's strongest owned pets; back
   up the prior squad; restore on toggle-off / reboot. (Assumes the account owns the pets.)
2. **Grant a temp reference squad** — temporarily grant + equip a standardized set of 10
   idealized max pets (synthetic) so every origin uses the same reference squad; the
   safeguard must also strip the temp pets + refs on reboot so nothing dangles.
3. **Don't touch the squad** — leave it alone; equip 10 manually (already allowed); Titan
   only does powers. No squad backup needed.

---

## 5. Surface & gating
- Admin/dev-userId-gated toggle command on the GameAPIService bus.
- Client toggle button.
- A Titan aura / nameplate so it visibly reads as the pinnacle.

---

## 6. Effort & risks
- **Estimate:** ~2–3 focused days for the clean version. A quick mutate-and-restore demo is
  ~1 day but carries the profile-corruption risk above — not acceptable on real dev accounts.
- **Biggest variable / risk:** read-site exhaustiveness. If a combat/passive reader of the
  loadout is missed when routing through the effective-loadout accessors, Titan looks right
  in the hotbar/HUD but under-buffs in an actual fight — confusing for balance work. Audit
  every reader of `data.Powers` / `data.Slots` before trusting the numbers.
- Persistence corruption is otherwise designed out (powers via overlay, squad via backup +
  reconcile-on-load).

## 7. Other open questions
- Exact reference level + which derived stats the L50 bump must stamp (and restore).
- Squad source (§4 open question).
- Cosmetic treatment (aura/nameplate spec).

---

## 8. Grounding references (where to pick this up)
- Powers / loadout: `src/Server/Services/PowerService.lua` (`GetState`, `ReapplyPassives`,
  `data.Powers`/`data.Slots`).
- Enhancements: `src/Shared/Game/Enhancements.lua` (`aggregate`, `levelFactor`, `usableBy`,
  `compatibleWith`), `configs/enhancements.lua` (types/origins/values).
- Augmentation slots: `src/Server/Services/AugmentationService.lua`,
  `src/Shared/Game/Augmentation.lua`.
- Pet squad: `src/Server/Services/ActiveSquadService.lua`, `src/Shared/Game/ActiveSquad.lua`,
  `configs/squad.lua` (`limits.active_squad = 10`).
- Archetype/origin: `src/Server/Services/ArchetypeService.lua`, `configs/archetypes.lua`,
  `configs/biomes.lua`.
- Reference pattern for a bus-toggled, admin-gated behavior: `RealmPortalService` /
  `AscensionAltarService`.
