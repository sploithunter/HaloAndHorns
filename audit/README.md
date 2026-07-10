# Halo & Horns Architecture Audit

Audit date: 2026-07-10  
Scope: repository-wide, read-only architecture review converted into durable project documentation  
Status: findings complete; remediation is proposed, not implemented

## Purpose

This directory records the repository audit against three priority-one architecture principles:

1. **Configuration first:** content, tuning, and adaptations should be declared in configuration wherever practical. When static code is useful, generate it from configuration.
2. **Modular reuse:** each kind of operation—network action, gameplay event, icon, item creation, pet mint, reward, currency mutation, and similar concepts—should have one authoritative path.
3. **Event-driven sequencing:** readiness and completion should be communicated by events or latched state. Elapsed time must not be used to guess that another operation has started or finished.

## Executive conclusion

The intended architecture is present but not governing. Newer systems such as `BootReadiness`, `PetGrantService`, `RewardService`, the modifier pipeline, and many content configs follow the principles. The largest deviations come from older parallel paths that remain live and allow callers to bypass those systems.

The remediation should therefore focus on removing alternate paths and adding automated architecture checks, not replacing the whole game.

## Documents

- [Architecture principles](ARCHITECTURE_PRINCIPLES.md) — the rules used to judge the code, including what counts as a legitimate timer.
- [Ranked findings](ARCHITECTURE_AUDIT.md) — the largest deviations, evidence, impact, and current good foundations.
- [Evidence inventory](EVIDENCE.md) — source locations, static counts, audit commands, caveats, and CI baseline.
- [Remediation roadmap](REMEDIATION_PLAN.md) — staged migration plan designed for small PRs without a flag-day rewrite.
- [Proposed guardrails](PROPOSED_GUARDRAILS.md) — CI fitness checks and target ownership rules that prevent recurrence.

## Highest-priority findings

1. The network configuration is not the runtime source of truth; code declares a second remote registry and services create additional remotes.
2. Service startup and pet runtime behavior are split between `ModuleLoader`, direct initialization, auto-running scripts, global callbacks, polling, and perpetual timing loops.
3. Pet, reward, inventory, currency, and gameplay-event boundaries are documented as singular but remain bypassable.
4. Fixed waits still synchronize boot, UI, and hatch choreography despite the event-driven boot contract.
5. Config validation, generated registries, and reusable UI/action construction cover only part of the repository.

## Non-goals

- This audit does not claim every `task.wait` or `task.delay` is wrong. Cooldowns, deadlines, periodic persistence, animation durations, and frame-budget yielding can be legitimate. The violation is using elapsed time to infer readiness or completion of another operation.
- This audit does not propose moving arbitrary executable logic into data files. Configuration should select registered capabilities; generic code should implement those capabilities.
- This audit does not change runtime behavior or save data.

## Canonical project sources consulted

- `AGENTS.md`
- `docs/wiki/INDEX.md`
- `docs/wiki/DECISIONS.md`
- `docs/wiki/ARCHITECTURE.md`
- `docs/wiki/CURRENT_STATUS.md`
- `docs/BOOT_ORCHESTRATION.md`
- `docs/FOUNDATION_AND_REQUIREMENTS.md`
- `docs/IMPLEMENTATION_PLAN.md`
- Runtime source under `src/`, configuration under `configs/`, and existing automated tests
