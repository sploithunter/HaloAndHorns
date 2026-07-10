# Evidence Inventory and Verification Notes

## Audit snapshot

The original review was performed across 2026-07-09 and 2026-07-10 against the HaloAndHorns working tree. This documentation branch was created from commit `4e29984d3d7ccde54fcc2b7c78a4cddbdca1a10a`.

The audit was static and read-only until these documents were requested. No runtime behavior was changed.

## Method

The review combined:

- project-memory review (`docs/wiki/INDEX.md`, decisions, architecture, status, boot design, requirements, and implementation plan);
- repository inventory with `rg`, `find`, and `wc`;
- targeted reading of composition roots, services, configs, shared infrastructure, UI, and tests;
- searches for manual remotes, global service access, direct mutations, pet mint paths, gameplay-event publication, hardcoded assets, UI constructors, and timing calls;
- a `mise run ci` baseline attempt.

## Static inventory

These counts are search results used to locate risk. They are not all defects by themselves.

| Signal | Count | Interpretation |
|---|---:|---|
| Config modules in `configs/` | 90 | Total declarative surface at the audit snapshot |
| Focused names in `ConfigLoader:ValidateConfig` | 28 | Remaining names take the default acceptance path unless checked elsewhere |
| Code-declared `Net:RemoteEvent` values in `Signals.lua` | 98 | Active network registry is code, not generated from `network.lua` |
| Manually constructed server remotes outside `NetworkBridge` | 8 | Additional service-specific network paths |
| `_G` references under runtime `src/` | 156 | Global coordination remains common |
| `_G.RBXTemplateServices` references in service files | 78 across 36 files | Runtime global discovery coexists with dependency injection |
| Direct client UI instance constructors for common controls | 669 | UI construction is broadly decentralized |
| Runtime `task.wait`/`task.delay` calls after excluding obvious test files | 232 | Requires classification; only synchronization guesses violate the rule |
| Direct currency mutations outside `EconomyService` | 24 | Economy ownership is not exclusive |
| Direct gameplay-event sends in `DropService` | 3 | Bypass `FireGameEvent` server taps/world sound |
| Production pet `AddItem` calls outside `PetGrantService` | 2, both in fusion | New pet creation bypasses configured minting |

## Largest relevant files

Large files are not automatically poor architecture, but these concentrate multiple responsibilities and extension branches.

| File | Approximate lines at audit |
|---|---:|
| `src/Client/UI/Menus/InventoryPanel.lua` | 8,077 |
| `configs/pets.lua` | 6,891 |
| `src/Server/Services/EnemyService.lua` | 5,647 |
| `src/Shared/ConfigLoader.lua` | 5,045 |
| `src/Client/UI/BaseUI.lua` | 3,549 |
| `src/Server/Services/PowerService.lua` | 2,854 |
| `src/Server/Services/DataService.lua` | 2,693 |
| `src/Shared/Services/EggHatchingService.lua` | 2,666 |
| `src/Server/Services/BreakableSpawner.lua` | 2,569 |
| `src/Server/Services/GameAPIService.lua` | 2,448 |
| `src/Shared/Services/EggInteractionService.lua` | 2,419 |
| `src/Server/Services/InventoryService.lua` | 2,412 |
| `src/Server/Services/PetHandler.server.lua` | 1,867 |

## Source evidence by finding

### Network split

- `configs/network.lua:1-3` — declares the network configuration as the single source of truth.
- `docs/FOUNDATION_AND_REQUIREMENTS.md:148-154` — requires rate limits, handlers, validation, and no manual remotes.
- `docs/IMPLEMENTATION_PLAN.md:48-60` — standard recipe for config-declared packets.
- `src/Client/init.client.lua:49,67,841` — says `NetworkConfig`/old `NetworkBridge` were removed.
- `src/Shared/Network/Signals.lua:7-130` — code-declared signal registry.
- `src/Server/Services/TradeService.lua:45-53` — manually recreates `TradeUpdate`.
- `src/Server/Services/EggService.lua:1652-1669` — manually creates `EggOpened` and `setLastEgg` remote functions.
- `src/Server/Services/PotionService.lua:44` — manual remote event.
- `src/Server/Services/AutomationService.lua:85,97` — manual test remotes.
- `src/Server/Services/GameAPIService.lua:158` — manual command remote.
- `src/Server/Services/StudioSmokeTestService.lua:175` — manual Studio remote.

### Split service and pet lifecycle

- `docs/IMPLEMENTATION_PLAN.md:52-58` — loader-managed service recipe.
- `docs/BOOT_ORCHESTRATION.md:88-92` — milestone-only dependency invariant.
- `src/Server/init.server.lua:927-984` — direct egg initialization after fixed waits.
- `src/Server/Services/PetEquipmentBridge.server.lua:33-37` — global registration callback.
- `src/Server/Services/PetEquipmentBridge.server.lua:200-286` — fixed debounce and fallback global handler.
- `src/Server/Services/PetHandler.server.lua:1-12` — direct adaptation of an imported system.
- `src/Server/Services/PetHandler.server.lua:98-107` — hardcoded formation and diagnostic constants.
- `src/Server/Services/PetHandler.server.lua:1720-1734` — global rebuild callback and recursive readiness wait.
- `src/Server/Services/PetHandler.server.lua:1769-1865` — generated legacy values and perpetual timing loops.
- `src/Server/Services/PetCharacterAttachments.server.lua:1-62` — hardcoded attachments and per-player loop.
- `src/Server/Services/PetCompatibilityService.server.lua:15-17,56-68` — hardcoded defaults and one-second setup waits.
- `docs/wiki/ARCHITECTURE.md:34-35` — wiki acknowledges the legacy pet bridge is not the desired shape.

### Mutation and event bypasses

- `docs/wiki/ARCHITECTURE.md:15` — `EconomyService` owns currency mutation.
- `docs/wiki/ARCHITECTURE.md:25` — `PetGrantService` is the single pet creation boundary.
- `src/Server/Services/PetGrantService.lua:260-316` — normal pet mint path and side effects.
- `src/Server/Services/FusionService.lua:79-105` — direct pet add and rollback reconstruction.
- `src/Server/Services/RewardService.lua:1-12` — claims to be the single reward terminal.
- `src/Server/Services/RewardService.lua:75-83` — direct currency write through `DataService`.
- Direct currency calls appear in trade, enhancement shop, shop, layer, egg, combat, zone, upgrade, rewards, index, enchant, automation, admin, and achievements services.
- `src/Server/Services/DropService.lua:794-841` — direct `Signals.GameEvent` sends.
- `src/Shared/Network/FireGameEvent.lua:52-75` — shared path includes server taps, world sound, and client dispatch.

### Timing-based synchronization

- `src/Server/init.server.lua:927-960` — fixed service-start delays.
- `src/Client/init.client.lua:1212-1219,1332-1354` — fixed UI and egg-service delays.
- `src/Shared/Services/EggSpawner.lua:297-309` — timed spawn-point poll.
- `src/Shared/Services/EggHatchingService.lua:900-945` — shake completion inferred from duration.
- `src/Shared/Services/EggHatchingService.lua:1353-1368` — completion callback contains another timed wait.
- `src/Shared/Services/EggHatchingService.lua:1460-1471` — reveal completion inferred from the configured duration.
- `src/Shared/Services/EggHatchingService.lua:1750-1868` — batch synchronization via several waits and `completionWait`.
- `src/Client/UI/Menus/InventoryPanel.lua:7524-7543` — blocking wait before click listener plus duplicate close timer.

### Partial configuration and UI registries

- `docs/wiki/DECISIONS.md:9-11` — content and tuning should live in config.
- `src/Shared/ConfigLoader.lua:69-220` — hardcoded fallback content.
- `src/Shared/ConfigLoader.lua:652-713` — focused config-name switch and default acceptance.
- `src/Server/Services/DataService.lua:58-186` — handwritten profile template with only selected sections generated from config.
- `src/Client/UI/Menus/InventoryPanel.lua:238-247` — hardcoded support-action metadata.
- `src/Client/UI/Menus/InventoryPanel.lua:1334-1367` — custom close-button implementation despite a shared component.
- `src/Client/Systems/CurrencyStyle.lua:23-76` — hardcoded asset IDs, colors, and pane mapping.
- `src/Server/Services/PowerService.lua:1452-2142` — large effect-family conditional dispatcher.
- `src/Server/Services/EnemyService.lua:3632-3825` — separate aura-family conditional dispatcher.

## CI baseline

Command attempted:

```text
mise run ci
```

Observed result at the audit snapshot:

- Selene: `0 errors`, `573 warnings`, `0 parse errors`.
- Numerous warnings were for `_G` usage, unused variables, empty blocks, and shadowing in the exact high-risk areas identified by the audit.
- The gate then failed at `stylua --check` because several existing files were not formatted.
- Because the task list is sequential, the Rojo build and headless suite did not run in that attempt.

The audit did not reformat or otherwise repair those unrelated existing files.

## Count caveats

- Searches are intentionally simple and reproducible. They are not an AST-level proof.
- Direct config `require` calls and `ConfigLoader:LoadConfig` calls can coexist in the same file.
- Some manual remotes are Studio-only, but they still need declaration in the canonical manifest with an environment policy.
- Some direct `DataService` mutation is legitimate inside migrations, restore paths, or the owning lower-level service. Guardrails need narrow allowlists.
- `task.wait()` used only to yield a frame or respect a work budget is different from sleeping to infer readiness.
- UI constructor counts include legitimate low-level component implementations; the architectural concern is repeated high-level construction outside those components.

## Reproduction command examples

```text
find configs -maxdepth 1 -type f -name '*.lua' | wc -l
rg -o 'configName == "[^"]+"' src/Shared/ConfigLoader.lua | sort -u | wc -l
rg -n 'Net:RemoteEvent' src/Shared/Network/Signals.lua
rg -n 'Instance\.new\("Remote(Event|Function)"\)' src/Server
rg -n '_G\.RBXTemplateServices' src/Server/Services
rg -n '_dataService:(AddCurrency|RemoveCurrency|SetCurrency)\(' src/Server/Services
rg -n 'AddItem\(player, "pets"' src/Server/Services
rg -n 'Signals\.GameEvent:(FireClient|FireAllClients)' src/Server
rg -n 'task\.(wait|delay)\s*\(' src
```
