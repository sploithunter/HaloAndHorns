# Area-vocabulary reconciliation — base/Home: earth/ember/sand → grass/lava/desert

**Decision (Jason):** one canonical area vocabulary everywhere — **grass / lava / ice / desert**. The
base/Home realm still uses legacy `earth` / `ember` / `sand`; reconcile to canonical, **including the
egg IDs** (full rename, not just the area keys). Ice already canonical.

**Why coordinated:** `EggStandResolver` matches *stand-name-contains-area-key*, and `EggStandPlacement`
loads `ReplicatedStorage.Assets.Models.Eggs[eggId]`. So the config keys, the authored **map stands**,
and the **egg model instances** must all rename together — doing only part breaks Home egg hatching.

**Data safety:** ✅ no per-player data is keyed by egg id (`eggs_hatched` is a global counter; no
per-egg unlock/owned/maxSeen save). Eggs are world-placed, not per-player unlocked. So the rename is
save-safe — no migration.

## Rename map
| Old area key | New | Old egg id | New egg id | Old stand | New stand |
|---|---|---|---|---|---|
| earth | grass | earth_egg | grass_egg | BasicEarth | BasicGrass |
| ember | lava | ember_egg | lava_egg | BasicEmber | BasicLava |
| sand | desert | sand_egg | desert_egg | BasicSand | BasicDesert |
| ice | ice (unchanged) | ice_egg | ice_egg | BasicIce | BasicIce |

## Change set
**Code (configs):**
- `configs/pets.lua`: `realm_area_eggs.base` keys earth/ember/sand → grass/lava/desert; values →
  grass_egg/lava_egg/desert_egg. Rename the `egg_sources` entries `earth_egg`/`ember_egg`/`sand_egg`
  → `grass_egg`/`lava_egg`/`desert_egg`. Update the in-file comments referencing BasicEarth/Ember/Sand.
- `configs/areas.lua`: `egg_id = "earth_egg"` → `grass_egg`; stand `spawn_id = "BasicEarth"` → `BasicGrass`.
- `configs/breakables.lua`: `egg_type = "earth_egg"` → `grass_egg`; `spawn_id = "BasicEarth"` → `BasicGrass`.
- `configs/tutorial.lua`: `prefer = "BasicEarth"` (×2) → `BasicGrass`.
- `configs/egg_system.lua`: the commented `["earth_egg"]` line.
- `src/Client/Systems/TutorialController.lua`: comment mentions only.

**Map (Studio, EDIT mode — via MCP `execute_luau` datamodel=Edit):**
- Rename authored stands under `Workspace.Maps.<HomeWorld>`: `BasicEarth→BasicGrass`,
  `BasicEmber→BasicLava`, `BasicSand→BasicDesert` (enumerate first; there may be >1 per area).
- Rename egg model instances under `ReplicatedStorage.Assets.Models.Eggs`:
  `earth_egg→grass_egg`, `ember_egg→lava_egg`, `sand_egg→desert_egg`.
- Check `markers.lua` / any map markers stamping `EggId = "ember_egg"` etc.

## Execute (one coordinated pass)
1. Studio in **Edit mode** (Stop Play first).
2. Apply the config renames (code) + the map renames (MCP) together.
3. `mise run ci` (rojo + headless + the pet_origin_integrity guard — area keys must stay canonical).
4. Re-run `mise exec -- lune run scripts/gen_pet_catalog.luau` (catalog should still show base/grass etc.).
5. **Live verify (re-Play):** Home stands resolve, the four Home eggs hatch their families, tutorial
   "prefer" still steers to the grass stand.
6. Commit + push.

## Optional follow-up (separate)
- A transitional alias (keep earth/ember/sand as extra `realm_area_eggs.base` keys pointing at the new
  eggs) would let already-published places with old stand names keep working during rollout — drop
  after the map is updated. Only needed if there are live servers on the old map.
