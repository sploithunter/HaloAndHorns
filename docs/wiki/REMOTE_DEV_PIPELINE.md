# Remote Development Pipeline

Status: building

## Goal

Develop, test, build, and **release** a Roblox game from an AI/CLI agent with
**no GUI computer-use** — driving the game through code (the CommandBus boundary)
and the Roblox Studio MCP, not by clicking the screen.

## Stages

```
  edit ─► static checks ─► headless tests ─► Studio integration ─► build ─► release
  (src)   selene/stylua    lune (pure)       MCP + CommandBus       rojo     rojo upload
          /rojo build                        /AutomationService     build    (Open Cloud)
  └────────── fully automatable, no Studio ──────────┘ └─ needs open Studio ─┘ └ automatable* ┘
```

| Stage | Tool | Automatable unattended? | Notes |
|-------|------|--------------------------|-------|
| Static checks | `selene`, `stylua --check`, `rojo build` | ✅ yes | Pure CLI. Runs in GitHub Actions. |
| Headless tests | `lune` (`mise run test-headless`) | ✅ yes | Pure-logic only (no Roblox runtime). Runs in CI. |
| Studio integration | Roblox Studio MCP + CommandBus | ⚠️ partial | Needs an **open Studio** + Rojo connected (one-time human bring-up). Test *execution* is automated via `execute_luau`. |
| Build artifact | `rojo build --output game.rbxl` | ✅ yes | Place/model file. Runs in CI. |
| Release | `rojo upload` (Open Cloud) | ✅ yes* | *Needs an Open Cloud API key + universe/place IDs (user-provisioned) and per-release authorization. No GUI. |

## Testing methodology (the layered process)

The test pyramid for this project. **Push every assertion down to the cheapest
layer that can catch the bug. State proves; pixels only confirm.**

1. **Headless pure logic (lune)** — the bulk. `CommandBus`, `Navigation`,
   `Validators`, `TestReport`, and any Roblox-API-free game math. Instant, no
   Studio, runs in CI. Most logic bugs die here.
2. **Server-side integration via the command bus — the PRIMARY validation.**
   Fire commands through `GameAPIService:Execute` / the `AutomationSuite`
   (server-side, via the `RunAutomationSuite` bridge) and assert on
   **authoritative state** (currency, inventory, position, zone) read back
   through the bus. Fast, deterministic, **no screenshots**. This is where the
   vast majority of runtime behavior is verified.
3. **UI sanity check — thin, last-mile, sparing.** Drive the *real* player UI
   with the MCP (`character_navigation` + `user_mouse_input` /
   `user_keyboard_input`) and capture **one or two decisive screenshots**. This
   only confirms the human-facing path renders and wires up — it is NOT for
   logic correctness (that's layer 2's job). Used sparingly because screenshots
   are slow and occasionally flaky (`screen_capture` can time out — see G5).

Per feature: write the logic pure (1) → register the command and validate it
through the bus (2) → run a single UI-sanity pass (3) before calling it done.

**Worked example — egg hatch (verified live in Place1):**
- *Action via the real UI (layer 3):* `character_navigation` walks the avatar to
  the egg; `user_keyboard_input` presses `E`; one `screen_capture` confirms the
  proximity UI + result.
- *Validation via the bus (layer 2):* read `inventory.slots { bucket = "pets" }`
  before/after → `used` went `0 → 1`, confirming the server granted a pet (and
  coins `100 → 0`). The screenshot is the sanity check; the bus read is the proof.

These input tools already exist in the Studio MCP (`user_mouse_input`,
`user_keyboard_input`, `character_navigation`) — no custom MCP server is needed
for UI-driven E2E.

## GAP ANALYSIS — hard limits

These cannot be closed with the current Claude Code harness + Roblox Studio
tooling. They are the reasons the pipeline is not 100% unattended.

### G1 — No headless Roblox runtime (fundamental)
Roblox's runtime (DataModel, Instances, services, physics, replication) only
exists inside Studio or a live Roblox server. There is **no official headless
engine**. Consequence: anything touching Roblox APIs (services, movement, UI,
replication) **must run in Studio**. Only Roblox-API-free pure logic can be
tested headlessly (lune). This is why the architecture pushes logic into pure
modules (`CommandBus`, `Navigation`, formulas) — to maximize the headless tier.

### G2 — Claude Code cannot launch or click Studio
This harness has **no desktop control** (only the browser MCP and the Roblox
Studio MCP). It cannot:
- launch Roblox Studio,
- click the Rojo plugin **Connect** button,
- open a `.rbxl` place file,
- toggle **Enable Studio as MCP server**, or
- restart Play from the GUI (it *can* via the MCP `start_stop_play` once connected).

These are **one-time, per-session human setup actions**. After bring-up, the MCP
automates the rest (`execute_luau`, `start_stop_play`, `screen_capture`,
`character_navigation`, `get_console_output`, inspection).

**macOS caveat (partial workaround):** with an **Accessibility** grant, a headless
agent *can* drive Studio's **menu bar** via AppleScript (`osascript` → System
Events) — e.g. `scripts/studio_publish.sh` clicks File → Publish. This is
script-driven, not vision-based, so it covers menu-bar actions (publish, etc.)
but not in-canvas widgets like the Rojo plugin's Connect button, nor launching
Studio itself.

### G3 — Studio integration tier is not CI-runnable
GitHub-hosted runners have no Roblox Studio. `run-in-roblox` (the community
headless-Studio test launcher) needs Studio installed and is unreliable on
macOS; it also launches the GUI app. So the integration tier runs **locally,
against an open Studio via the MCP** — it cannot run in cloud CI today. The fast
gate (static + headless + build) is the CI-runnable portion.

### G4 — Release requires user-provisioned credentials + authorization
`rojo upload` is fully scriptable, but needs:
- an **Open Cloud API key** with publish scope (created by the user at
  create.roblox.com/credentials),
- the target **universe ID + place ID**, and
- per-release **authorization** (publishing mutates a public resource).

The agent never handles the secret value — the release script reads it from the
`ROBLOX_OPEN_CLOUD_KEY` environment variable (or a gitignored `.env.local`).
Account/credential creation is a user-only action.

**Footgun — `rojo upload` assumes Rojo owns the whole place.** A `rojo build`
produces a place from the project tree, so a `Workspace` defined as just
`{ "$ignoreUnknownInstances": true }` (this project) builds an **empty
Workspace**. Uploading that to a place with a **Studio-authored map would wipe
the map.** Therefore:
- **Games with Studio-authored maps** (this project) publish from **Studio
  (File → Publish)**, which keeps the synced code *and* the authored map. No key
  needed.
- **`rojo upload` / Open Cloud** is for places where **Rojo is the full source
  of truth** — code-only or Rojo-defined-map places.

**Agent-publish pattern (safe):** point the release script at a **dedicated
staging experience that Rojo fully owns** (no authored map; the template
synthesizes its hooks on a blank map). The Open Cloud key is scoped to that
staging universe only, so automated publishes can never touch the real
authored-map game. The real game is published from Studio; staging is the
agent's deploy/test sandbox.

**Choosing a publish method (by who/what is publishing):**

| Publisher | Method | Needs | Best for |
|-----------|--------|-------|----------|
| Headless / CLI agent (MCP-only), or CI | `rojo upload` (Open Cloud) | Rojo-owned tree, API key, **place closed in Studio** | automated deploys to a code-only / staging place |
| Agent **with computer use**, or a human | Studio **File → Publish to Roblox** | an open Studio session (no key) | the real **Studio-authored-map** game — preserves the map, no key, no close needed |
| **Headless agent on macOS** (no computer use) | **`mise run publish-studio`** — AppleScript drives File → Publish | Studio open on an associated place + **Accessibility** grant | shipping a Studio-authored-map game from a headless agent — preserves the map, no key |

The Studio MCP exposes no publish action, so an MCP-only agent can't publish
through the MCP. But on **macOS** it doesn't need Open Cloud for an authored-map
game: `scripts/studio_publish.sh` uses **AppleScript (`osascript` → System
Events)** to click **File → Publish to Roblox** by name — script-driven GUI
automation, not vision-based "computer use." It publishes the open session (code
**and** the authored map), needing no key and no close. This is **verified live**
(Place1). Requirements/caveats:
- Studio must be **open on the target place** and that place must already be
  **associated** with a Roblox place (a brand-new place opens a "Publish As"
  dialog the script doesn't drive).
- The controlling app needs **Accessibility** (System Settings → Privacy &
  Security → Accessibility); without it, System Events errors `-1719`.
- It's **UI-dependent** (menu item name "Publish to Roblox"), so it can need
  re-tuning across Studio versions — less robust than the Open Cloud API.

**Why an MCP-only agent should prefer the AppleScript lane over Open Cloud:** the
Open Cloud path requires **closing the place in Studio** (to avoid the `Conflict`
error), which **drops the Rojo plugin connection** — and reconnecting means
clicking the in-canvas **"Connect"** button, which *is* vision-based computer use
the agent doesn't have. So Open Cloud silently breaks the live dev loop. The
AppleScript publish keeps **Studio + Rojo connected the whole time** — publish
in place, keep iterating. Reserve Open Cloud for CI / Rojo-owned staging where no
Studio session is involved.

For a **computer-use** agent or human, plain **File → Publish** is simplest.

**Open Cloud path — setup gotchas (learned live):**
- The Open Cloud key needs the **`universe-places`** API system with **Write**
  (not plain `universe`), scoped to the staging universe. Wrong/missing scope →
  `Unauthorized: API Key has insufficient scopes`.
- **Universe ID ≠ Place ID** even with one place — read both from the
  create.roblox.com experience URL, or resolve the universe from a place via
  `GET https://apis.roblox.com/universes/v1/places/{placeId}/universe` (public).
- **Close the place in Studio before publishing.** Open Cloud cannot save a new
  version over a place that's open in a Studio session — it returns
  `Conflict: "Save failed. Server is busy..."`. Closing Studio clears it.
- Status: **verified live** — a real `rojo upload` to the staging place
  (universe `10242349813`) returned exit 0 after closing Studio.

### G5 — `screen_capture` is a backstop, not a gate
The MCP screenshot can time out (observed locally). Visual checks confirm "the
UI rendered / the player is where expected" but **state read back through the
CommandBus is the source of truth** for pass/fail. Do not gate a test purely on
a screenshot.

### G7 — MCP `execute_luau` is client-attached during Play
In play-solo, the Studio MCP runs `execute_luau` in the **client** Lua state, and
`get_console_output` surfaces client output only. So `_G.RBXTemplateServices` and
server services aren't directly reachable from the MCP during Play. Two
consequences, both handled:
- **Production commands** are driven over the `GameAPICommand` RemoteFunction
  (client → server bus), exactly as a real client would — and test-only commands
  are correctly *forbidden* on that path.
- **Test-only / automation commands** need server context, so AutomationService
  exposes a Studio-only `RunAutomationSuite` RemoteFunction the client invokes;
  the suite then runs server-side (isTest=true). Server boot errors aren't
  visible via the MCP in Play — diagnose those in edit mode (init-simulate) or by
  reading state through these remotes.

### G6 — Player control vs. automated movement (mitigated, pending live verify)
In play-solo the player's client control module can fight server `MoveTo`.
`AutomationService:NavigateTo` now disables the player's controls for the
duration via the `AutomationControl` RemoteEvent + the client
`AutomationControlBridge` (Studio-only), always re-enabling afterward
(pcall-wrapped), and still re-issues MoveTo + detects stalls as a backstop. The
control-disable path needs one live Studio confirmation. Not a hard limit.

## One-time setup (human)

1. Install toolchain: `mise install` (rojo, wally, selene, stylua, lune), then
   `wally install`.
2. Open Roblox Studio on a place; enable **Enable Studio as MCP server**.
3. In Studio, install/Connect the Rojo plugin to `rojo serve` (port 34872) from
   this repo checkout.
4. For release: create an Open Cloud API key (publish scope) and export
   `ROBLOX_OPEN_CLOUD_KEY`, plus set the universe/place IDs.

## Running the pipeline

```bash
# Fast gate — fully automatable, also runs in GitHub Actions
mise run ci                 # selene + stylua --check + rojo build + test-headless

# Individual stages
mise run lint               # selene
mise run format             # stylua (write)
mise run test-headless      # lune pure-logic tests
mise run build              # rojo build --output game.rbxl

# Studio integration (needs open Studio + Rojo connected; driven via MCP)
#   The agent calls GameAPIService:Execute(...) through execute_luau and runs
#   the scenario orchestrator (tests/studio/AutomationSuite). See below.

# Release (needs ROBLOX_OPEN_CLOUD_KEY + IDs + authorization)
mise run release            # wraps `rojo upload` via Open Cloud; refuses if env unset
```

## What the agent can do end-to-end today

- ✅ Edit → fast gate (static + headless + build) → green, unattended.
- ⚠️ Studio integration: once a human brings up Studio + Rojo, the agent runs the
  command-bus scenarios via the MCP and asserts on state.
- ⏸️ Release: the agent prepares and validates the publish command; the user
  provisions the key and authorizes the actual upload.
