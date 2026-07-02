# Enhancements — CoH-style power slotting (Jason's design)

## The design
- **Single-origin** — disc + ring in the SAME color group. **Stronger** (+33% default), usable
  only when the **player's origin matches**.
- **Dual-origin** — disc + ring in DIFFERENT color groups. **Weaker** (+20% default), usable by
  **either** of its two origins — twice as often useful, deliberately less potent.
- Identity is **hidden on the ground** (semi-generic drop model) and **revealed at pickup**
  (floating name + sting via the GameEvents bus).

## 9 types → stat axis → allowed power families
| Type | Icon | Axis | Fits |
|---|---|---|---|
| Damage | fist | damage | attack/vulnerable, damage buffs, rage, DoT |
| Accuracy | target | accuracy | attack + control (root/taunt/fear) |
| Recharge | history | recharge (÷) | everything |
| Armor | armor_chest | magnitude | defense_buff / armor / fortify |
| Shield | shield | magnitude | absorb |
| Health | heart | magnitude | heal / absorb / defense (survivability) |
| Range | range | radius | **AoE only — blocked on melee/single-target** |
| Duration | hourglass | duration | buffs, debuffs, control |
| Healing | plus | heal | heal powers |

Values are additive per axis within a power (two single Damage = +66%). Recharge DIVIDES the
cooldown (300s with one single = ~225s) and stacks with Hasten.

## Pipeline (all built)
| Piece | Where |
|---|---|
| Rules config (types/values/drops/cap) | `configs/enhancements.lua` |
| Pure core (validity/usability/compat/aggregate/badge) | `src/Shared/Game/Enhancements.lua` (+ spec) |
| Inventory + slotting service | `src/Server/Services/EnhancementService.lua` |
| Bus | `enh.get` / `enh.slot` / `enh.grant` (admin: random or explicit) |
| Effects at cast | `PowerStats.resolveEffective(ctx.enhancements)` + cooldown stamp in `PowerService:Cast` |
| Drops | `DropService:TrySpawnEnhancementDrop` — breakables (first Contrib) + enemy defeats; placeholder gold "?" orb until `drops.model_name` points at the authored model |
| Pickup reveal | `_collect` → Grant + `enhancement_pickup` GameEvent → `float` reaction (name) + sting |
| Slotting UI | PowerChoiceMenu: outside a level-up beat, click an OWNED power → ENHANCE strip (slots row + compatible/usable inventory row; click to slot into first empty) |
| Storage (E6) | InventoryService bucket `enhancements` (`data.Inventory.enhancements`, unique uid records, 60 slots) — shows in the Inventory UI, positioned for trade |
| Inventory cards (E7) | InventoryPanel ⚙️ Enhancements category: name + Single/Dual + origin-colored cards (`origins_csv` mirrors origins into the replication folder) |
| Trading (E8) | PENDING — TradeService is pets-bucket-only today; extending escrow to enhancement records needs a two-player live session (task #206) |

## Slot data shape
`data.Slots[powerId]` (earned at slot levels): `{}` empty · `{ inherent = true }` free first slot ·
`{ enh = { type, origins } }` filled. Replacing a filled slot **destroys** the old one
(`replace_destroys`). Inventory: `data.EnhancementInv[uid] = { type, origins }` (cap 60).

## For the authored model (Jason)
Drop the Model under `ReplicatedStorage.Assets.Models` and set
`configs/enhancements.lua → drops.model_name` to its name. PrimaryPart (or first BasePart) is the
pickup body; DropService anchors, spins, and magnet-pulls it like coin drops.

## Tuning levers (config-only)
`values.single/dual` · `drops.breakable_chance/enemy_chance/single_chance/type_weights` ·
per-type `families`/`requires_aoe` · `replace_destroys`.

There is **no inventory cap** — enhancements stack by identity and auto-expand (the bucket is
`stacks_count_toward_limit = false`, so drops never fail on space). The old `inventory_cap = 60`
was a dead, never-enforced field and has been removed. Runaway-growth protection is a SOFT dev
alert, not a block: `configs/inventory.lua → buckets.enhancements.storage_alert` (`stack_count`,
`serialized_bytes`) makes DataService fire `OpsAlert("bucket_storage_high")` at load when the
bucket's stack count or estimated serialized size approaches the ~4MB DataStore key limit.
