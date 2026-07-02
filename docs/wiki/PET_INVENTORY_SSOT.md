# Pet Inventory — Single Source of Truth

The template invariant for pets. Pet trading/equip/counts are core to many games built on this
template, so this is intentionally strict. Read this before touching anything under
`src/Shared/Inventory/`, `InventoryService`, or the pet equip/trade paths.

## The invariant

**Ownership lives in exactly one place: `profile.Data.Inventory.pets.items`.** Equip is a
*separate* layer that is *validated against ownership*, never trusted on its own.

### Ownership (`Inventory.pets.items`) — two entry shapes

- **Common (fungible)** — one entry per kind, keyed by the stack key `"id:variant"`:
  ```
  items["bear:basic"] = { id = "bear", variant = "basic", quantity = N, obtained_at = … }
  ```
  One entry regardless of count → storage is O(distinct kinds), not O(total pets). A player can
  own millions of a common and it stays one entry (no datastore explosion).

- **Special (unique per instance)** — one entry per instance, keyed by a generated `uid`:
  ```
  items[uid] = { uid, id, variant, obtained_at, level, exp, enchantments, huge, serial, rarity_id, … }
  ```
  Specials carry per-instance state, so they can never be stacked.

Discriminator: an entry is a **common stack** iff its key is exactly `id:variant` (contains `:`);
a **special** is keyed by its uid (never contains `:`). There is **no `_kind` field**, **no
`equipped_slot`/`equipped_slots` on records**, and a common never carries per-instance state.

### Equip (`Equipped.pets`) — a separate, validated restore/preference layer

```
Equipped.pets["slot_1"] = "<uid>"             -- a special
Equipped.pets["slot_2"] = "stack|id:variant"  -- one copy of a common (several slots may
                                              --   reference the same kind)
```

**The safety rule:** `Equipped.pets` is a *soft reference*. The live equipped set is computed as
`Equipped ∩ inventory` by `PetInventoryView.resolveEquipped`:

- a special slot is live only if that uid is still owned;
- a common kind can be equipped at most `quantity` times (extra slot-refs are ignored);
- a slot outside `[1..maxSlots]` is ignored.

A dangling or over-cap ref (from a trade, delete, or a crash before teardown) is simply **ignored
and lazily swept** — it can never become a phantom. And because equip/unequip only touch
`Equipped.pets` (never `quantity`), no equip action can ever create or destroy a pet (crash-safe).

## Why this shape

- **No phantom.** Equipping doesn't decrement ownership; counts are a pure function of `items`.
- **No dup/loss on crash.** Equip toggles never mutate ownership.
- **Scales.** Commons are O(distinct kinds).
- **Reboot self-heal.** On load, equip is rebuilt from saved inventory (`Equipped ∩ inventory`),
  never trusted blindly. A corrupt equip state heals itself on the next join.

## Modules (`src/Shared/Inventory/`, pure + headless-tested)

- **`PetInventoryView`** — the projection authority. `groups` (ownership + equipped overlay),
  `resolveEquipped` (validated live equip), `usedSlots`/`categoryCounts`, `normalize`,
  `isSpecial`/`isLevelable`/`isEnchantable` (capability), `parseRef`, `stackKey`.
- **`PetMigrationV5`** — v4→v5: explode legacy mixed storage into uid records.
- **`PetCompaction`** — v5→v6: collapse exploded commons back into compact stacks.
- **`PetEquipMigration`** — v6→v7: lift equip off records into `Equipped.pets`.

All three migrations are ownership-conservation-guarded (they assert owned counts are preserved
before committing) and run in `DataService.SchemaMigrations` (current schema version **7**).

## Server contract (`InventoryService`)

- **Add** (hatch): commons increment the stack; specials mint a uid record.
- **Remove / delete / trade**: change ownership only; the equip layer is re-validated afterward.
- **Equip toggle**: mutates `Equipped.pets` (guards: already-equipped? enough unequipped stock?).
- **Projection** replicates the SSOT to the client as a stable folder view — `Stacks/<id:variant>`
  (Quantity = *unequipped* count), `Special/<uid>`, and the `Equipped` slot folder. This is the
  intended replication layer, not legacy debt. The client renders these folders; equipped commons
  show as "ghost" cards from the equipped folder. `ResolvePetTarget` maps client identifiers back
  to a `{kind, uid|stackKey, slot?}` target.

### Rebuild tiers (do NOT re-validate equip on every mutation)

- `RebuildPetProjections(player)` — **FULL**: re-validate equip (`Equipped ∩ inventory`, drop
  dangling/over-cap) + rebuild both folders. Use ONLY where equip can change: remove / delete /
  trade / equip-toggle / **load** (the reboot self-heal).
- `RefreshPetInventory(player)` — **LIGHT**: inventory folder + slot count only. Use on
  ownership-only changes that can't invalidate equip: add/hatch, XP, enchant. Keeps mass hatching
  and per-breakable XP cheap.

## Invariants to preserve when extending

1. Never store equip state on an ownership record.
2. Never trust `Equipped.pets` without `resolveEquipped` validation.
3. Never decrement ownership on equip.
4. Any new pet-mutation path must call the correct rebuild tier (full only if it can invalidate equip).
5. Any storage-shape change needs a conservation-guarded migration step.
