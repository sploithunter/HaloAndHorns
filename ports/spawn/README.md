# HH Merge bay on Spawn

[Open the development world](https://www.spawn.co/@coloradoplays/halo-horns-merge-bay-lab@dev).
[Capability assessment](../../docs/wiki/SPAWN_CAPABILITY_ASSESSMENT.md).

This is a playable porting slice of Heaven bay 01, exported read-only from the open Roblox Merge
place (84544653387905), rather than a replacement arena. The scene retains 513 authored parts,
16 distinct meshes, the 300-stud lane, board, stairs, hatcher stands, portal, and outer grove.
Coordinates convert at 0.28 metres per stud. Built-in Roblox marble is replaced by a procedural
Spawn material; the agent avatar remains a placeholder. The 28 source egg models and doggy/bear rigs are imported.

## Play

Claim the bay, collect the opening 600 Waycoins, then buy eggs. Drag a physical egg from the
board onto an empty stand to install it. Drop an egg onto another egg of the same tier to combine
them into the next tier; this works on the board and on an occupied stand. The catalog follows HH’s
56 configured tiers: 28 normal eggs, then the same 28 prototype Huge eggs. Tier 56 is the source terminal tier. An empty board tile accepts a move. Wrong tiers, maximum-tier stacks, changed source or
target values, and stand changes during a wave are rejected without consuming either egg.

Valid drop targets turn green. Release outside a target, press Escape, or cancel a touch to return
the egg. The B panel and the right-side hatcher cards support the same gestures; click-to-select
and install remain available. Installed eggs can be recalled between waves.
The wall-mounted UPGRADES board contains Buy Egg and Upgrade Spawn. Walk up to use it; it shows
the current/next egg and live Waycoin prices. The generator control no longer floats in the side HUD.
WASD walks, right mouse drag turns the camera, wheel zooms, and B opens the compact egg board.
One player owns this bay per room; other players can watch. Leaving releases the bay.

The opening ten wave compositions, prices, rewards, early difficulty relief, and checkpoint
interval come from HH's existing config. Combat is deliberately limited to basic attacks,
armor mitigation, pursuit, recovery, escapes and rewards. Source formations, stable targets,
contact/rebound envelopes, alternating sidesteps and received-hit flinches drive the defenders.
The root-pose sampler runs at 30 Hz separately from the 10 Hz combat rules; cosmetic motion never
feeds back into hit distances. One resolved hit starts its attack clip, whole-body motion, floating
damage number, elemental impact and flinch. Numbers include only HP actually removed, including
lethal hits, and expire independently of their target. Grass/ice/lava/desert impacts, death bursts
and merge sparks use native Spawn FX. Full HH combat roles, powers,
threat, hatcher endurance, workshops, equipment, trading and live player migration are outside this slice.

## Build and test

From the HH repository root:

```sh
mise exec -- lune run ports/spawn/export-source.luau
mise exec -- lune run ports/spawn/export-account-source.luau
python3 ports/spawn/tools/build_world.py
node --test ports/spawn/tests/*.test.js
mise run ci
```

`configs/spawn_merge_*` own the scene, tuning, UI and asset manifest. Generated runtime data lives
under `ports/spawn/world/scripts/lib/data`. `export-source.luau` generates parity fixtures by
executing the real HH pricing/combat/wave modules. Do not edit the generated data independently.
The shipped scene and CDN references work without Blender or Studio.

To rebuild the mesh cache from an open, authorized Studio session, use
`tools/export_studio_assets.py <studio-id> <output-dir>` (Pillow and zstandard required), then
Blender `-b --python tools/build_source_bay.py -- <output-dir>`. These tools read the committed
placement snapshot and use supported EditableMesh/EditableImage APIs; they do not alter the place.
`pack_glb_textures.py` packs opaque image maps for delivery. `spawn_api.py upload <file>` uploads
bytes using the token in `~/.spawn/token` or `SPAWN_TOKEN_FILE`. Tokens never belong in this tree.

Egg rebuilds use the same extractor with `--manifest configs/spawn_merge_egg_sources.json`, then
Blender `-b --python ports/spawn/tools/build_source_eggs.py -- <output-dir>`. The first four source
model IDs were resolved read-only through Studio; the snapshot records their actual mesh/texture
IDs. `export_pet.py <rig.blend> <output.glb> --attack-source <doggy_wolfattack.blend>` exports distinct
Walk and Attack clips on the shared 19-bone skeleton. The earlier 6.5-second walk action was
mislabeled Attack; both served rigs now contain the actual 1.708-second attack action as well as Walk.
Keep the returned CDN **name**: asset cooking can return a processed SHA different from the
source file digest, and an existing upload may omit byte/SHA fields.

The Spawn world has its own git repository. Copy `world/` into its clone, preserving its `.git`,
AGENTS.md, CLAUDE.md and Spawn-owned migration markers, review the diff, and push to its main branch.
Spawn restores `spawn6/flat-anchor.yaml` when removed; keep that marker in sync. That updates development
rooms, not the public published version. This lab has not been published to the feed.

## Evidence and limits

2026-11-09: eighteen Node test groups pass, including source-Luau parity, idempotency, invalid
commands, actor ownership, and all ten waves/checkpoint 10 in an in-memory engine adapter.
Two real client bodies observed the same room. Browser controls completed collect → buy → merge
→ deploy → wave 2 clear; a visitor purchase was rejected. Leaving freed the bay, and a new client
session restored 320 coins, two Tier-2 hatchers and cleared wave 2 before reclaiming it.

Live preview input also crossed T4→T5, T28→T29 and T55→T56; installed T5/T29 hatchers spawned
4/9 pets. A wave-10 fight with four T4 hatchers cleared with reserve 5, checkpoint 10, actual root
lunges, attack channels and independent damage markers. All seven formation styles (273 fixtures)
and five role strike profiles/starter overrides match fixtures executed from the real Luau modules.
Only the melee Doggy defender is currently used; exported role curves do not mean the full roster
or power rules are implemented. Source-priced wallets retain Lua-compatible finite double semantics.
The deployed dev build also cleared wave 10 with reserve 5 and an empty error console; actual
checkpoint-10 leave/rejoin and visible rising/fading damage numbers passed. Failure recovery remains unverified. Both live bodies have editor
standing, so this is not an ordinary-player anti-cheat test. No runtime AI inference was invoked.
See the assessment for authority, performance, save, engine-version and asset-ingestion limits.

Browser regression: `PLAYWRIGHT_MODULE=<installed Playwright module> node ports/spawn/tools/verify_drag_playwright.mjs <CDP URL>` exercises actual mouse/touch input. Use a fresh `--as` test body in an isolated development room with a claimed fresh bay, four T1 board eggs and 200 coins. The check refuses other egg layouts and consumes only that test run's eggs.

## Shared inventory foundation

[Assessment and source rules](../../docs/wiki/SPAWN_SHARED_ACCOUNT.md) distinguish owned HH pets,
Full Merge personal hatches and temporary squads. `scripts/lib/pet-inventory.js` is a pure ownership/
equip port with 144 cases executed from the actual Luau source plus conservation/rejection checks.
It has no engine/save dependency and is not yet bound to the production UI or director. The exported
`shared-account.yml` records source configuration (including Roblox-only entitlement references),
not active Spawn purchases. All 22 Node groups pass.

[Isolated place/account protocol](../../docs/research/spawn-account-probe-2026-11-09.md) records
normal-browser persistence, instance lifecycle and rendering tests. It does not settle full imported
map streaming, security or the deployment choice. Do not copy research fixtures into the live world.
