# Pet Storage v2 — uniques-only cap, stackable enchanted mythics, ops telemetry

Status: **IMPLEMENTED & LIVE-VERIFIED** (2026-06-12). All four stages shipped.
Deviation from D6: the Max button still computes from coins/entitlement only — with
stacks never consuming slots, Max IS what lands except the sub-1% case of a secret+
jackpot at a full unique cap, which the readable toast + storage_truncated alert cover.
Origin: live bug on the published game — auto-hatch max-9 yielded fewer than 9 pets
with ample coins, then "pet storage is not available." Root cause: the pets bucket's
`base_limit = 50` is a template-era fossil (commit 7a082256, 2025-07-31, pre-Pet-Realm)
and every mythic consumed a permanent slot because enchantable ⇒ per-uid record.

## The principle

Stacks are **self-bounding**: a stack kind can exist at most once, so the maximum
slots commons can consume equals the catalog size — which grows only when we ship
content. A per-player cap on stacks protects nothing. The only resource that needs
bounding is **unique records** (per-uid documents carrying enchants/serials/provenance):
they grow without bound from grinding and they are what costs profile size and UI weight.

## Decisions (all blessed)

### D1 — Unique = secret and above
`special_rarities` for the pets bucket becomes `{ secret, exclusive, huge, creator }`.
Mythic is demoted to stackable.

### D2 — Mythics stay enchantable via the stack key
The pets stack key grows a third component: **(species, variant, enchant_effect)**.
A mythic's hatch-rolled enchant becomes part of its stack identity — "Mythic Scorpion ·
Coin Finder" is its own pile. Kind-space stays self-bounding: catalog × variants ×
(9 effects + none), and only held kinds occupy anything.

### D3 — Mythic enchant strength is FLAT: "Mythic Strength"
No strength ranges on stackable enchants (ranges would ~40× the kind-space and clutter
the pets tab). All mythic enchants roll at one configured value — mid-level — in
configs/enchants.lua (e.g. `mythic_stack_strength = 2`), tweakable at will, applies
live to effect resolution (strength is read at resolve time, not baked into the stack).
Tier story sharpens: mythics give you the EFFECT; secrets+ play the MAGNITUDE game.

### D4 — No rerolls on stacks
Re-enchanting is per-copy gambling; stacks have no copies. Mythic enchant gambling IS
hatching (want a Luck mythic? hatch more mythics) — feeds the egg economy instead of a
reroll sink. Rerolling remains the privilege of secrets+ (which are getting rarer).
The `legendary` roll pool stays dormant; `mythical` pool keeps `secret_luck` as the
early lottery ticket.

### D5 — Cap: flat 500 uniques (for now)
`unique_limit = 500` on the pets bucket; counts ONLY unique records. Stacks never count.
Gamepass limit_extensions become honest "+N unique slots" monetization (IDs still TODO).
FUTURE OPTION (shelved, keep the seam): dynamic cap derived from the live obtainable
index size × multiplier (the index is computable at all times — huge entries via the
serial census, the rest static from egg defs).

### D6 — Enforcement points (all existing seams, new meaning)
- `EggService.ResolveStorageLimitedOutcomes`: only SPECIAL outcomes require a slot;
  the new-stack slot requirement disappears. Commons/mythics never truncate a batch.
- `InventoryService.AddItem`: same rule at the authoritative write (covers trade-in).
- Effective-max display (Max button): includes free unique slots, so Max is what lands.
- The `storage` rejection becomes a readable toast: "Unique pet storage full (N/500)".

### D7 — Migration: collapse + grandfather (on profile load, version-bumped)
- Existing mythic uid records WITHOUT enchants → collapsed into stacks.
- Existing mythic uid records WITH enchants → choose at build time:
  collapse into the matching (species, variant, effect) stack with strength flattened
  to Mythic Strength (preferred — data is pre-launch and ours), or grandfather as
  legacy records that no longer count toward the cap. Default: collapse-and-flatten.
- Pattern: the existing v4→v5 migration machinery.

### D8 — Ops telemetry (first consumer of the logging service)
- New server module `OpsAlert`: `OpsAlert.send(kind, payload)` — pcall'd, batched,
  transport-swappable.
- Transport v1: DataStore ring buffer (`OpsAlerts_v1`, day-keyed, capped entries),
  readable on demand from Studio/MCP. Zero external dependencies.
- Transport v2 (later, same API): push (Discord webhook / external sink).
- Wired alerts:
  - `unique_storage_high` — on profile load when uniqueCount ≥ 80% of cap.
  - `bucket_storage_high` — on profile load when a stacks-free bucket's stack count or
    estimated serialized size crosses its `buckets.*.storage_alert` threshold (catches
    enhancements/potions growth that `used_slots` is blind to; soft alert, never a cap).
  - `storage_truncated` — whenever a hatch batch is cut by the unique cap.

## Explicitly unchanged
Equip layer · trade semantics · deletion policy (exclusive+ undeletable) · index keys
(species:variant:huge — enchant sub-stacks do NOT inflate collection math) · eternal &
power math · enchant foreground display (the stack card shows the effect badge it
already knows how to draw — the whole stack honestly shares one effect).

## Build sequence (each stage: CI + live verify before the next)
1. **Core reclassification** — special_rarities minus mythic; enchant-aware stack key;
   flat Mythic Strength knob; slot accounting counts uniques only; unique_limit = 500;
   storage resolver + AddItem rule.
2. **Migration** — collapse mythic uid records per D7 (version bump).
3. **Surfaces** — effective-max includes slots; "Unique pet storage full (N/500)" toast;
   stack-card enchant badge for mythic piles.
4. **OpsAlert** — module + ring-buffer transport + the two alerts + a Studio/MCP reader.

## Open questions (defaults chosen, flag if wrong)
- Enchanted-mythic migration: collapse-and-flatten (default) vs grandfather.
- Alert threshold: 80% of cap.
- Mythic Strength default value: 2 (mid of the old 1–3 common ranges).
