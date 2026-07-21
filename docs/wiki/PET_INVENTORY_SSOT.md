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

The one-time chosen starter companion is intentionally a special uid record even when its species
is normally stackable. `grant_source = "starter_choice"`, `unique = true`, and `locked = true`
preserve its one-time provenance and keep the free grant out of trading. It is always the basic
variant; the following Earth Egg remains a separate normal hatch. Admin Reset to Beginning removes
only this reproducible starter special and re-arms the selector while retaining all other protected
unique/huge pets.

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
- **Squad-draft UI counts** must treat replicated `Quantity` as unequipped availability, not total
  ownership. While editing locally, a stack card's total is `Quantity + live deployed copies`, and
  its working-grid availability is that total minus working-draft copies. The client retains display
  metadata for quantity-zero stacks and reads the stable `Quantity` value object live (not a possibly
  pre-projection cached count), so removing the only deployed copy immediately returns its card to
  the inventory grid before Activate commits the draft.

### Rebuild tiers (do NOT re-validate equip on every mutation)

- `RebuildPetProjections(player)` — **FULL reconcile**: re-validate equip (`Equipped ∩ inventory`,
  drop dangling/over-cap) + incrementally reconcile both folders. Use ONLY where equip can change:
  remove / delete / trade / equip-toggle / **load** (the reboot self-heal). Stable folder/value
  instances are retained when unchanged; a full reconcile is no longer a tree teardown.
- `RefreshPetInventory(player)` — **LIGHT**: inventory folder + slot count only. Use on
  ownership-only changes that can't invalidate equip: add/hatch, XP, enchant. Keeps mass hatching
  and per-breakable XP cheap.
- `RefreshPetRecords(player, keys)` — **TARGETED**: update only the listed pet card records. Use for
  progression/enchant mutations that cannot change ownership or equip. Squad pet XP mutates every
  eligible pet first, then emits one targeted projection call and one debounced save request per
  contributing player; different miners still resolve and commit independent award amounts. Every
  completed projection transaction increments `Inventory/pets/Info/ProjectionVersion` once; clients
  observe that explicit event instead of relying on folder teardown/recreation side effects.
- `Inventory/pets/Info/RenderVersion` is the narrower client-render event. It advances only when a
  transaction may change visible card state or ordering. Ordinary XP progress updates the stable
  replicated special records and `ProjectionVersion`, but not `RenderVersion`; pet tooltips read the
  current record on hover. Level/power changes and enchant changes still advance `RenderVersion` and
  trigger one refresh/re-sort.
- Pet cards are sorted by their displayed effective power, which depends on live biome and realm
  context. `CurrentArea` and `CurrentRealm` changes therefore coalesce into one full client inventory
  refresh/re-sort after the transition; this contextual rebuild is intentional even when no pet
  ownership record changed.

## Invariants to preserve when extending

1. Never store equip state on an ownership record.
2. Never trust `Equipped.pets` without `resolveEquipped` validation.
3. Never decrement ownership on equip.
4. Any new pet-mutation path must call the correct rebuild tier (full only if it can invalidate equip).
5. Any storage-shape change needs a conservation-guarded migration step.
