# Project Wiki

This is the living project wiki for **Pet Realm — Halo & Horns**, a Rojo Roblox pet game. It follows the LLM Wiki pattern: raw/reference material is preserved, and agents maintain concise Markdown pages that compile current project knowledge.

**▶ The published game:** <https://www.roblox.com/games/77766176054993/Halo-and-Horns> (universe 10307183003, group-owned 15872767).

> **Repo lineage (2026-07-02):** this repo (`sploithunter/HaloAndHorns`) began as a fresh single-commit
> import of the working tree — deliberately no history. The predecessor `sploithunter/RBX-Template`
> holds all pre-import commit history AND the alpha GitHub-issue queue; look there for archaeology,
> work HERE going forward. Older wiki/docs text saying "RBX Template" refers to this same codebase.

## Start Here

- [Current Status](CURRENT_STATUS.md) — what exists right now.
- [Decisions](DECISIONS.md) — durable decisions and rationale. **Config as
  code:** IDs, art, and tuning live in `configs/` only. Never hardcode
  model/asset numbers in `src/`.
- [Architecture](ARCHITECTURE.md) — system shape and service boundaries.
- [Client Performance](CLIENT_PERFORMANCE.md) — measured Merge baseline, nearby adaptive shadows,
  persisted graphics controls, and next performance targets.
- [Merge Autoplay](MERGE_AUTOPLAY.md) — coin-only online character automation, pass gating,
  strategy reports, and isolated Studio-only testing controls.
- [Configuration-As-Code Audit](CONFIG_AS_CODE_AUDIT.md) — complete runtime literal/fallback
  inventory, CI ratchet, and remediation priorities.
- [Console Support](CONSOLE_SUPPORT.md) — controller mapping, semantic input routing, modal focus,
  ten-foot HUD behavior, and the console QA matrix.
- [UI Layout Policy](UI_LAYOUT_POLICY.md) — responsive placement, the narrow role of pixel offsets,
  and the required justification for every non-zero placement nudge.
- [Retention Analytics](RETENTION_ANALYTICS.md) — onboarding funnel, player milestones, admin access, and internal-account ID exclusions.
- [Tutorial Localization](TUTORIAL_LOCALIZATION.md) — Roblox locale detection, supported tutorial
  languages, persisted Auto/English preference, and safe English fallback.
- [Combat Tutorial](COMBAT_TUTORIAL.md) — live Homeworld combat beat in the Earth
  cave (lobby → ENTER → fight → pillar), then Rally at Level 2.
- [Founder's Choice](FOUNDERS_CHOICE.md) — exact first-10,000 cohort reservation, permanent
  pass-benefit selection, entitlement-source union, purchase reconciliation, and shop UX.
- [Beta Tester Rewards](TESTER_REWARDS.md) — one-egg campaign grants, level-based Golden/Rainbow
  progression, immutable award provenance, and trade-safe freezing/catch-up.
- [Trial Egg Rewards](TRIAL_EGG_REWARDS.md) — one evolving Celestial/Obsidian egg per named-trial
  track, milestone odds, canonical award identity, permanent hatching, and trade behavior.
- [Promo / Reward Codes](PROMO_CODES.md) — weekly, creator, event, and launch-link codes; reward
  bundles, claim persistence, attribution, analytics, and operational safety.
- [Beta Analytics & Release Plan](BETA_ANALYTICS_RELEASE_PLAN.md) — provisional three-wave launch
  calendar, KPI definitions, data-quality gates, ad-credit budget, and rollback runbook.
- [Template vs Game](TEMPLATE_VS_GAME.md) — which systems are reusable template (trading, hatching, rewards…), which are Pet-Realm reference examples, which are game-only content. The pick-list for a future template extraction.
- [Pet Inventory SSOT](PET_INVENTORY_SSOT.md) — the single-source-of-truth pet model: ownership in `Inventory.pets.items`, equip as a separate validated layer. Read before touching pet inventory/equip/trade.
- [One-Way Pet Gifts](GIFT_SYSTEM.md) — receiver rarity policies, exact-record durable delivery,
  wrapped inventory presentation, and the three gift-giver rankings.
- [Studio Workflow](STUDIO_WORKFLOW.md) — Rojo, Roblox Studio, MCP, and verification workflow.
- [Remote Dev Pipeline](REMOTE_DEV_PIPELINE.md) — develop → test → build → release from a CLI/AI agent; the layered testing methodology and hard-limit gap analysis.
- [Automation API Design](AUTOMATION_API_DESIGN.md) — the CommandBus boundary, GameAPIService, and AutomationService that let tests drive the game below the GUI.
- [Map Integration Contract](MAP_INTEGRATION_CONTRACT.md) — how Rojo systems bind to Studio-authored worlds.
- [Hall of Worlds](HALL_OF_WORLDS.md) — the authored but release-disabled Hall route, Homeworld
  rollback contract, and the relocated Lava Range / Desert Training Ground fixtures.
- [Merge an Egg Prototype](MERGE_EGG_PROTOTYPE.md) — Phase 6: a permanent Studio-authored ten-bay
  Heaven/Hell realm around a sunken public mall, opposing lava/water plazas and a central
  convergence landmark, random empty-bay allocation,
  durable Wave-10 checkpoint wallet/board/deployment state,
  four empty hatcher positions, a rear-wall base-egg creator plus separate two-to-one merge station,
  world-owned Home/Heaven-1 capacity, composition-aware tier-N drafts, an actual-walk-speed
  continuous Home→Heaven 1 economy runner, eight ungated egg tiers, a Wave 10
  restart checkpoint plus Waves 11–13 recovery ramp inside a 20-wave lieutenant/boss plan capped at
  32 enemies, stationary 5,000-HP hatcher-egg objectives behind the breach line, a five-egg reserve,
  stable-slot reinforcement FIFOs, and Simple synthetic-reserve versus Full durable-player-pet
  combat modes.
- [Marketing Plan](../MARKETING_PLAN.md) — the 50k-Robux test plan (creative screening → funnel gate → scale), icon/thumbnail prompt matrix, capture shot list, KPI cheat sheet, and the 500-engaged-players unlock strategy.
- [Map Builder's Kit](../MAP_BUILDERS_KIT.md) — the production-world commissioning spec: hub-and-spoke layout, the 11-layer heaven/hell ladder (one layout, eleven skins), the full marker/binding contract, per-layer art briefs, phased delivery + acceptance checks.
- Heaven/Hell flora–fauna + altar quote pack: [LAYER_1_2_FLORA_FAUNA.md](../art/LAYER_1_2_FLORA_FAUNA.md)
  · sheets `docs/art/quote_refs/` (local textures only).
- [Mission Worldgen](../MISSION_WORLDGEN.md) — the Trials endgame SSOT: CoH door missions, deterministic tile-kit procgen, shared sequences, the 8-trial matrix, quest-steered gates, and evolving-egg centuries (§13 = shipped contract).
- [Area Bounds & Movement Leash](AREA_BOUNDS_LEASH.md) — the pure union clamp (`EnemyLeash`) that walls enemies inside their spawn area (sourced from live map parts; GrassSpawn = Grass ∪ SpawnCircle), plus the recorded possibility of reusing it to confine the player (flying-power containment).
- [Pet Rigging Pipeline](PET_RIGGING_PIPELINE.md) — the canonical quadruped skeleton: one command skins any Meshy quadruped so all pets share attack clips; Blender headless pipeline, gotchas, and the Roblox import path.
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
- [Pet Rig Onboarding](../PET_RIG_ONBOARDING.md) — the reproducible rig runbook: onboard_pet_rig.sh front half + manual tail + every gotcha.
- [Skybox Pipeline](../SKYBOX_PIPELINE.md) — HDRI (Hyper3D) → cubemap faces (panorama-to-cubemap) → stage/upload/resolve/wire per realm layer; the one-Sky rule.
- [Roblox Mesh Texture Kaleidoscope](../ROBLOX_MESH_TEXTURE_KALEIDOSCOPE.md) — public root-cause writeup: Open Cloud collapses per-corner UVs; welded meshes must be seam-split before upload.
- [Authored Map Workflow](../AUTHORED_MAP_WORKFLOW.md) — Studio-authored world editing, incl. duplicating Terrain-Editor work between realm layers (CopyRegion/PasteRegion, +2000Y = +500 voxels).
- [Map Marker Reference](../MAP_MARKER_REFERENCE.md)
- [Egg Authoring And Admin Testing](../EGG_AUTHORING_AND_ADMIN_TESTING.md)

## Maintenance Rule

When code, configs, requirements, or Studio workflow decisions change in a way a future agent would need to know, update the relevant wiki page before finishing the task.
