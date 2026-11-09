# HH Merge bay on Spawn

[Open the development world](https://www.spawn.co/@coloradoplays/hh-merge-bay-lab@dev).
[Capability assessment](../../docs/wiki/SPAWN_CAPABILITY_ASSESSMENT.md).

This is a playable porting slice of Heaven bay 01, exported read-only from the open Roblox Merge
place (84544653387905), rather than a replacement arena. The scene retains 513 authored parts,
16 distinct meshes, the 300-stud lane, board, stairs, hatcher stands, portal, and outer grove.
Coordinates convert at 0.28 metres per stud. Built-in Roblox marble is replaced by a procedural
Spawn material; eggs and the agent's avatar remain placeholders. Source doggy/bear rigs are imported.

## Play

Claim the bay, collect the opening 600 Waycoins, buy two eggs, select an egg and merge the pair.
Select the resulting egg and install it using an empty hatcher button. Start a wave and collect
its rewards. Equal eggs merge upward; installed eggs can be recalled between waves.
WASD walks, right mouse drag turns the camera, wheel zooms, and B opens the compact egg board.
One player owns this bay per room; other players can watch. Leaving releases the bay.

The opening ten wave compositions, prices, rewards, early difficulty relief, and checkpoint
interval come from HH's existing config. Combat is deliberately limited to basic attacks,
armor mitigation, pursuit, recovery, escapes and rewards. Full HH combat roles, powers,
threat, hatcher endurance, workshops, equipment, trading and live player migration are outside this slice.

## Build and test

From the HH repository root:

```sh
mise exec -- lune run ports/spawn/export-source.luau
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
Keep the returned CDN **name**: asset cooking can return a processed SHA different from the
source file digest, and an existing upload may omit byte/SHA fields.

The Spawn world has its own git repository. Copy `world/` into its clone, preserving its `.git`,
AGENTS.md and CLAUDE.md, review the diff, and push to its main branch. That updates development
rooms, not the public published version. This lab has not been published to the feed.

## Evidence and limits

2026-11-09: eight Node test groups pass, including source-Luau parity, idempotency, invalid
commands, actor ownership, and all ten waves/checkpoint 10 in an in-memory engine adapter.
Two real client bodies observed the same room. Browser controls completed collect → buy → merge
→ deploy → wave 2 clear; a visitor purchase was rejected. Leaving freed the bay, and a new client
session restored 320 coins, two Tier-2 hatchers and cleared wave 2 before reclaiming it.

The live ten-wave/checkpoint reconnect case remains unverified. Both live bodies have editor
standing, so this is not an ordinary-player anti-cheat test. No runtime AI inference was invoked.
See the assessment for authority, performance, save, engine-version and asset-ingestion limits.
