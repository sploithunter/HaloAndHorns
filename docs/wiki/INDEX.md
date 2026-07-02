# Project Wiki

This is the living project wiki for the RBX Template pet/clicker game. It follows the LLM Wiki pattern: raw/reference material is preserved, and agents maintain concise Markdown pages that compile current project knowledge.

## Start Here

- [Current Status](CURRENT_STATUS.md) — what exists right now.
- [Decisions](DECISIONS.md) — durable decisions and rationale.
- [Architecture](ARCHITECTURE.md) — system shape and service boundaries.
- [Template vs Game](TEMPLATE_VS_GAME.md) — which systems are reusable template (trading, hatching, rewards…), which are Pet-Realm reference examples, which are game-only content. The pick-list for a future template extraction.
- [Pet Inventory SSOT](PET_INVENTORY_SSOT.md) — the single-source-of-truth pet model: ownership in `Inventory.pets.items`, equip as a separate validated layer. Read before touching pet inventory/equip/trade.
- [Studio Workflow](STUDIO_WORKFLOW.md) — Rojo, Roblox Studio, MCP, and verification workflow.
- [Remote Dev Pipeline](REMOTE_DEV_PIPELINE.md) — develop → test → build → release from a CLI/AI agent; the layered testing methodology and hard-limit gap analysis.
- [Automation API Design](AUTOMATION_API_DESIGN.md) — the CommandBus boundary, GameAPIService, and AutomationService that let tests drive the game below the GUI.
- [Map Integration Contract](MAP_INTEGRATION_CONTRACT.md) — how Rojo systems bind to Studio-authored worlds.
- [Area Bounds & Movement Leash](AREA_BOUNDS_LEASH.md) — the pure union clamp (`EnemyLeash`) that walls enemies inside their spawn area (sourced from live map parts; GrassSpawn = Grass ∪ SpawnCircle), plus the recorded possibility of reusing it to confine the player (flying-power containment).
- [Egg System Plan](EGG_SYSTEM_PLAN.md) — planned hatch modes, auto hatch, multi hatch, animation, and egg config architecture.
- [Hatch Luck & Pacing](HATCH_LUCK.md) — the staged luck channels (species/variant/huge), the curved index bonus and how it was fit, locked balance baselines (endgame = bunnies equipped), paid-luck rules (additive, species-only), and the off-Roblox progression simulator.
- [Reference Game Insights](REFERENCE_GAME_INSIGHTS.md) — useful ideas from ColorfulClickers.
- [Emergent Behaviors](EMERGENT_BEHAVIORS.md) — mechanics that fell out of systems interacting (dormant zones, window-shopping locked biomes); recorded so refactors don't "fix" them.
- [Open Questions](OPEN_QUESTIONS.md) — decisions still pending.
- [Log](LOG.md) — dated session notes.
- [Schema](SCHEMA.md) — how to maintain this wiki.

## Source Documents

Formal requirements and plans live outside the wiki and should be treated as source material:

- [Foundation & Requirements](../FOUNDATION_AND_REQUIREMENTS.md)
- [Pet Realm Design Document](../PET_REALM_DESIGN_DOCUMENT.md) — the full game design SoT (ring map, realms, soul, pets, rebirth).
- [Heaven & Hell Rosters](../PET_REALM_HEAVEN_HELL_ROSTER.md) — per-realm pet pools (4–5 per origin, ascended/fallen) + the 11-dragon rebirth set.
- [Implementation Plan](../IMPLEMENTATION_PLAN.md)
- [Asset Pipeline](../ASSET_PIPELINE.md)
- [Map Marker Reference](../MAP_MARKER_REFERENCE.md)
- [Egg Authoring And Admin Testing](../EGG_AUTHORING_AND_ADMIN_TESTING.md)

## Maintenance Rule

When code, configs, requirements, or Studio workflow decisions change in a way a future agent would need to know, update the relevant wiki page before finishing the task.
