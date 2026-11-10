# Shared HH account and Spawn deployment assessment

2026-11-09. Deployment decision **open**: one world with separate places versus separate worlds.
This supplements [Spawn capability assessment](SPAWN_CAPABILITY_ASSESSMENT.md).
Source code wins over older wiki paragraphs. No production inventory UI or Full Merge mode has
been deployed by this assessment; the development world remains version 25.

## What is shared in Roblox

Farm & Fight (77766176054993) and Merge (84544653387905) belong to universe 10307183003.
`DataService` opens `PlayerData_v2_mixedPets`, key `Player_<UserId>`. Both games use the same
profile: currencies, owned inventory, equipped references, player experience/level/claimed level,
upgrades, Pet Index, powers/enhancements and game-specific progress. A Spawn identity is not a
Roblox identity; no account linking or save migration has been implemented.

| Record | Meaning and required port behavior |
| --- | --- |
| `Inventory.pets.items` | Ownership authority. Common stack identity is `id:variant:enchant`; quantity is the total owned, including equipped copies. Unique pets use stable UID keys and retain levels, XP, enchantments and provenance. |
| `Equipped.pets.slot_n` | Soft references (`stack\|key` or UID). Resolve against ownership, quantities and unlocked capacity. Equipping never subtracts ownership. |
| Temporary hatcher squads | Best-of-N Merge drafts; NPC combat actors, not inventory records. |
| Simple-mode player escort | Temporary draft castoffs, separate from owned pets. Three fixed core seats (tank/ranged/melee), optional fourth support seat; not four arbitrary best pets. |
| Merge checkpoint roster | Can save a temporary run/bench snapshot for resume. Saving it does not make it owned inventory. |
| Full-mode player squad | The actual owned/equipped HH pets, alongside separate hatcher NPC squads, using the ordinary player pet/power systems. |
| Shared progression | Player XP/level, claimed rewards/equip capacity, inventory and relevant unlocks work in both games. Merge run state, recovery and Farm & Fight combat state have distinct lifecycles. |

The inventory configuration identifies secret/exclusive/huge/creator rarities as special records;
mythic can remain an enchanted stack. A card list must use flat images rather than one live 3D
viewport per card, following HH's inventory SSOT.
Equip capacity is resolved from earned and replicated bonuses plus the additive extra-pet
entitlement. The source progression ceiling of 10 increases by that paid delta; 11-slot squads
are valid. See the [screenshot/source reconciliation](SPAWN_MENU_TRANSLATION.md).

## Merge rules that must survive the port

* **Full access:** level 2 **or** `CombatTutorial.done`. The older Level-10 description is stale.
  Personal hatches do not currently require Combat Training.
* **First Full activation:** four independent Earth Egg rolls, each with a fresh configured 50x
  first-hatch luck multiplier. Persist `GameData.MergeFullStarterPets.refs`; resume a partial
  batch and never regrant on mode toggle/rebirth. These are not four fixed species.
* **Hatcher draft:** roll the configured best-of-N (2/3/4/5 by egg quartet), remove the weakest
  before selecting the hatcher winner; fill missing tank/support roles before comparing power.
  In Simple, appropriate castoffs feed the temporary escort.
* **Full personal hatch:** each completed hatcher draft also performs an independent real hatch.
  It does not award the hatcher's winner or its discarded pet. Use the player's Merge rebirth-owned
  egg source, capped by the producing hatcher tier.
* **Egg progression:** the ordinary source catalog has 28 eggs. Prototype Huge tiers 29–56 wrap
  to ordinary personal-hatch sources; they do not automatically grant real Huge inventory pets.
  Farm & Fight egg purchases do not unlock these Merge personal sources. Merge rebirth egg ownership
  grants mapped Farm & Fight areas, with realm level gates still checked independently.
* **Mode lifecycle:** Simple parks durable runtime pets without erasing ownership/loadout;
  exiting restores them. Full deploys the validated owned loadout. A downed normal Merge slot
  recovers in 10 seconds; an exact Huge UID in 60. Farm & Fight has separate recovery tuning.
* **Rewards:** owned-pet final hits can earn shared combat XP; wider Farm & Fight loot/events/counters
  remain Combat-Tutorial gated. Do not credit NPC, temporary, summoned or player-power kills as
  owned-pet kills. Participation XP has explicit participation and denominator rules. Merge power
  lessons ensure earned level floors at waves 6 and 10; do not invent an arbitrary Full unlock.

Primary source: [inventory config](../../configs/inventory.lua),
[inventory resolver](../../src/Shared/Inventory/PetInventoryView.lua),
[inventory service](../../src/Server/Services/InventoryService.lua),
[Merge config](../../configs/merge_egg_prototype.lua),
[Merge service](../../src/Server/Services/MergeEggPrototypeService.lua),
[starter runtime](../../src/Server/Services/MergeFullStarterRuntime.lua),
[draft rules](../../src/Shared/Game/MergeEggDraft.lua),
[progression](../../configs/player_progression.lua),
[power lessons](../../src/Shared/Game/MergePowerLessons.lua),
[inventory SSOT](PET_INVENTORY_SSOT.md).

## Spawn storage and lifecycle contracts

Reviewed the authenticated API reference and platform-systems, portals, rooms/matchmaking,
uploaded-model, heightmap and voxel guides. Docs repository revision
`45303e2434b43467e261cbe2a690ca9fe36faa31`; observed runtime
`289ba86c6f19761f5e9d178636ff5633` (rolling 6.0.0, unpinned). The repository contains documentation,
not the engine implementation; this is an API-contract audit plus measured experiments.

| Layout | What the contract supplies | Remaining concern |
| --- | --- | --- |
| Same world, separate places | Shared durable `player.state`; room transient state remains separate. Places can be session/persistent or instanced solo/party. | Rendering, asset residency, server simulation and instance disposal require separate measurements. Two places are not automatically two isolated servers. |
| Separate worlds/listings | Portal can carry player state to the destination. Destination saved keys win over carried keys; absent carried keys must be written to become durable there. | This is not a synchronized HH account. Returning to an older save risks stale ownership/XP. No documented shared cross-world SQL namespace was found. |
| Separate worlds + account service | Possible architecture, not implemented or tested. Central revisioned transactions and idempotent reward receipts could serve both games. | A verified Spawn player JWT proves identity, not a claimed kill/reward amount. Platform behaviors cannot directly fetch arbitrary external addresses; a trusted reward bridge must be established. |

`player.state` loads the complete saved record. Prefer keyed collections and scoped mutations to
repeatedly rewriting large arrays/strings. Dev/live SQL databases are separate. Protected player
keys have creator/editor exceptions; platform-simulated rows themselves are not documented as
immune to other players' writes/destruction. Editor-only tests do not settle production authority.

**Build a shared HH account interface now, without choosing deployment:** ownership/query,
validated equip, real-hatch grants, XP/unlock awards, recovery, revision and reward receipts.
Keep pure rules independent of storage; use one adapter for same-world saves, or a central
transactional service if separate worlds prove necessary. Each game owns explicit enter/leave,
temporary roster and combat lifecycle. A Merge director must not own the shared inventory service.

Primary documentation: [docs door](https://www.spawn.co/api/sdk/v1/a19e63cf-decf-46c7-9912-6505c59515d5/agent/docs),
[platform systems](https://www.spawn.co/api/sdk/v1/a19e63cf-decf-46c7-9912-6505c59515d5/agent/skills/platform-systems),
[portals](https://www.spawn.co/api/sdk/v1/a19e63cf-decf-46c7-9912-6505c59515d5/agent/skills/portals),
[public integration contract](https://www.spawn.co/llms.txt). Authenticated doors require editor access.

## Streaming: documented versus observed

The actual open Roblox Merge place reports `StreamingEnabled=true`, minimum radius 64 studs,
target 1024, integrity `PauseOutsideLoadedArea`. These differ from the Rojo project's authored
defaults (1024/1536); keep the actual Studio observation distinct. HH's comment about no runtime
chunk lifecycle does not mean Roblox streaming is disabled.

Spawn documents terrain streaming/LOD. Its 128-metre scene cells are authoring partitions;
we did not find a general Roblox-equivalent guarantee for eviction of arbitrary GLB meshes and
textures. Object behavior locality (default about 500 metres) is also not proof of asset eviction.
Portals with live views can preload/render destinations; the experiment used opaque keyboard travel.
The existing exporter combines parts by mesh group; importing all Farm & Fight in similarly giant
GLBs would undermine spatial asset separation. Region-level assets and shared instancing need testing.

## Isolated experiment and results

An unpublished preview overlay based on dev v25 added a separate synthetic place with 12 real
egg GLBs and 384 primitives, a solo ephemeral variant, clocks, and a far model/clock at 4096 metres.
Only the agent's mock `hhAccountProbe` data was changed. This is not a Farm & Fight port or a
production HH account. No creator progress, authored Roblox map, Spawn main branch or publication
was changed. [Protocol and sanitized evidence](../research/spawn-account-probe-2026-11-09.md).

| Check | Result |
| --- | --- |
| Owned common stack + unique UID + equip + XP across places | Passed. Changed quantity 3→4, XP 731→748, equipped unique plus two copies of the common stack through the real JS inventory core. |
| Duplicate artificial reward | Passed: second invocation did not grant again. This is a test receipt, not the real hatch/reward pipeline. |
| Ordinary browser reload | Passed with HTTP cache cleared/disabled: the changed entire profile survived reload, a return trip and an instanced-place visit. This tests one account, not concurrent sessions/crash rollback. |
| Source inventory parity | 48 build, 48 resolve and 48 fill cases executed from actual HH Luau agree with JS; conservation/atomic rejection also checked. |
| Place rendering | At 1440×1000, main return reported 29 draw calls/476k triangles/217 MB GPU; synthetic place after reload 11/105k/148 MB; later main 31/464k/213 MB. Individual observations, not a benchmark. |
| Cold asset lookups | Reloading main did not request metadata for the 12 other-place egg IDs; entering that place requested all 12. The far same-place model was resolved even while distant. Metadata lookup is not proof of decoded model residency or complete download bytes. |
| Instance cleanup | Solo visit created a distinct place ID. It still existed on immediate return and disappeared by the later 15-second-wait sample. Do not assume synchronous disposal. |
| Simulation locality | Far ordinary clock paused/resumed with approach. Platform clocks kept advancing across place changes, including inactive shared places. Explicitly stop/reset inactive game simulation. |
| GPU eviction/full maps | Unproven. GPU counters changed but did not consistently return to baseline. Small synthetic place, local desktop, few hops, no full Farm & Fight geometry or mobile test. |
| Cross-world shared account/security | Contract assessed; cross-world conflicts, non-editor attacks, concurrent mutations and production reward trust not tested. |

Validation: 22 Spawn Node groups and HH CI (2,846 tests/323 specs) passed, along with wiki,
source regeneration and fixture reconstruction checks.

## Next implementation gate

The committed inventory core and generated source contract are storage-independent foundations,
not a shipped feature. Next wire a shared account provider and flat owned-pet UI to the one-bay
prototype, then Full/Simple lifecycle, real personal hatches and source reward attribution. Verify
ownership conservation, starter receipts/partial retries and transfer/restore in both game adapters.
The [menu source audit](SPAWN_MENU_TRANSLATION.md) adds the required local draft/Reset/Activate,
acknowledgement, safe-area/input and bounded-rendering contracts; preserve these before replacing
the temporary lab HUD with the owned inventory menu.
In parallel with later gameplay expansion, test a representative Farm & Fight region and repeated
travel on target desktop/mobile devices, recording asset/network/GPU residency and inactive simulation.
Only then choose one world with separate places or separate worlds with a trusted account service.
