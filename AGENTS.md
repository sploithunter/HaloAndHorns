# Agent Instructions

This project uses a lightweight Karpathy-style LLM wiki. Treat the wiki as persistent project memory.

## Multi-Agent Collaboration

This is a single open **monorepo** worked by multiple agents across multiple
machines — currently game development (Pet Realm content) and template
development (reusable infrastructure) — and designed to add more (e.g. fast
Cursor agents for small, well-scoped tasks). Follow these rules so agents don't
conflict.

### Repo model
- **One repo.** The template (reusable infra) and the game (Pet Realm) coexist,
  separated by **path ownership** (`.github/CODEOWNERS`), not by separate repos.
  The template can be extracted later via `git filter-repo` if it ever becomes a
  standalone starter. (See the "Multi-Agent Collaboration" decision in
  `docs/wiki/DECISIONS.md`.)

### Ownership — who edits what
- **Template paths** (reusable infra): `src/Shared/`, infrastructure services in
  `src/Server/Services/`, `scripts/`, `.github/`, `tests/headless/`, `.mise.toml`,
  and the pipeline/architecture wiki pages (`REMOTE_DEV_PIPELINE.md`,
  `AUTOMATION_API_DESIGN.md`).
- **Game paths** (Pet Realm): game-specific configs and services, maps, and the
  Pet Realm design/wiki pages.
- `.github/CODEOWNERS` is the authoritative map.

### Branches & PRs — everything lands via PR
- Branch by domain: `template/*` (template work), `game/*` or `pet-realm/*`
  (game work), `agent/<who>/*` for ad-hoc/delegated tasks.
- **Never commit directly to `main`.** Open a PR. `main` is gated by CI
  (`mise run ci`: selene + StyLua + rojo build + headless) — it must pass.
- Keep PRs small and frequent; rebase on `main` often to minimize drift.
- **Claim your work first.** Before starting, add a row to the pinned
  **🚦 Active Work** issue (#2) — agent · domain · branch · scope — and open a
  **draft PR** early so your branch is visible. Remove your row when done. This
  is how agents (sharing one GitHub identity) avoid grabbing the same work.

### Communication
GitHub is the single channel: **issues** (work requests + threads), **PRs** (the
change + review), the **wiki** (durable memory), and the pinned **🚦 Active Work**
issue (#2) for who's-doing-what-now. No off-repo chat (Slack/Docs) for
agent↔agent coordination — keep one canonical, versioned source of truth.

### Cross-domain changes — hybrid by size
When game work uncovers a **template** improvement (or vice versa):
- **Small / obvious** → make it on a `template/*` branch + PR (CODEOWNERS routes
  review).
- **Larger / needs design** → open a GitHub issue labeled `template`, then build
  around it or stub it.
Label issues/PRs `template` or `game`. `good first issue` marks small
self-contained tasks suitable for a fast delegated agent.

### Shared files — the real conflict surfaces, handle with care
- `docs/wiki/LOG.md`, `docs/wiki/CURRENT_STATUS.md`: **append-only**. Add new
  lines; don't reflow existing ones. Additive conflicts resolve trivially.
- `.mise.toml`, `default.project.json`, `wally.toml`: change only in small,
  dedicated PRs, and call it out — every agent depends on these.

### Before opening a PR
- `mise run ci` passes.
- Wiki updated per the rules below (dated `docs/wiki/LOG.md` entry; relevant page).

## Start Of Work

1. Read `docs/wiki/INDEX.md`.
2. Read any linked wiki page relevant to the task before making architectural or gameplay changes.
3. Prefer the wiki for current project decisions, but verify against source files before editing code.

## During Work

Update the wiki when you make or discover anything that should survive the chat:

- Architecture decisions or reversals.
- Map/Studio/Rojo contract changes.
- New services, configs, data shapes, network packets, or save fields.
- Important implementation gotchas.
- Reference-game findings worth preserving.
- Manual Studio workflow discoveries.
- Open questions that block or shape future work.

Do not update the wiki for tiny mechanical edits, formatting-only changes, or facts that are already captured accurately.

## Wiki Rules

- Keep pages short and linked.
- Prefer updating an existing page over creating a duplicate.
- Add a dated entry to `docs/wiki/LOG.md` for meaningful sessions.
- If a page may be stale, mark it clearly rather than silently trusting it.
- Raw source notes belong in `docs/wiki/raw/`; synthesized project knowledge belongs in normal wiki pages.
- The wiki is maintained by agents, but source code and formal requirements remain the final authority.

## Useful Commands

- `mise run ci` — fast gate (selene + StyLua + rojo build + headless tests) before any PR.
- `mise run test-headless` — pure-logic unit tests (no Studio).
- `python3 scripts/wiki_status.py` — wiki consistency check.

