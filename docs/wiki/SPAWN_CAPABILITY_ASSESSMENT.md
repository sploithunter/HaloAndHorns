# Spawn capability assessment for HH

Status: first playable assessed, 2026-11-09. [Lab](https://www.spawn.co/@coloradoplays/hh-merge-bay-lab@dev) · [Implementation](../../ports/spawn/README.md) · [Draft PR #501](https://github.com/sploithunter/HaloAndHorns/pull/501).

## Decision

Proceed with a faithful single-bay porting experiment. Defer a full HH migration until ordinary-player
adversarial tests, persistence failure tests, full combat parity and a representative multi-bay load
pass. The initial generic isometric arena was rejected by the creator; it has been replaced by the
authored Heaven bay, a third-person camera and physical board/hatcher positions.

## Programming and events compared with Roblox

| Concern | Existing Roblox HH | Spawn adaptation and evidence |
| --- | --- | --- |
| Code | Luau, Roblox Instances/services, Rojo and headless modules | JavaScript behavior modules, YAML placements, Three.js geometry/materials, HTML HUD. Source Luau cannot run unchanged. |
| Update loop | HH's server/client service lifecycle | `update(ctx, dt)` per behavior; this director runs every 0.1 seconds on a platform-simulated row. Live `simulatedBy` was `platform`. |
| Commands | RemoteEvents and server validation | Body input emits `hh:command` to the director's declared ear. Identity comes from event `meta.sourceId`; payload actor claims are ignored. Validate ownership, indices, tier, funds, status, nonce and rate. |
| Replication | Explicit client/server boundaries and network ownership | Shared object/state rows replicate; player bodies move on their devices. Built-in multiplayer removes much transport work but is a different trust model. |
| Saves | Existing HH profiles/DataStore services | Protected `player.state.merge` holds wallet, eggs, progression and dedup history. Actual leave/rejoin retained wave-2 progress. No Roblox identity/profile import. |
| Art | Studio geometry, IDs, rigs, built-in materials | Actual bay read from Studio; meshes/UVs/normals/textures reconstructed as GLB groups. Real pet rig/Attack clip imports work. Materials, scale and collision need explicit conversion. |
| UI | Roblox UI hierarchy | HTML and world anchors; compact HUD plus real board/hatcher anchors. All layout must be rebuilt. |
| Iteration | Rojo/Studio tests and published places | Git push updates open dev rooms; publishing is a separate action. Live reload is useful, but explicit engine shapes and asset ingestion failures require runtime checks. |

Spawn is faster to iterate on text-owned scenes and browser UI. Roblox HH already has substantial
production gameplay, tooling and service contracts; converting those is the main work. This is a
rewrite of engine adapters around reusable game rules and assets, not an automatic place conversion.
Roblox itself requires server-side validation at its client boundary and server-side DataStore access.
[Roblox security](https://create.roblox.com/docs/scripting/security/client-server-boundary),
[Data stores](https://create.roblox.com/docs/cloud-services/data-stores).

## Authority is the migration gate

Spawn's current platform-systems contract says `platformState` excludes ordinary player writes to
named player-state keys, with creator/editor exceptions. It also explicitly says other players can
still write/destroy a platform-simulated object. Moving the director to the platform therefore does
not establish Roblox-equivalent authority over the entire scene. Public `world.state.mergeBay` is
only a projection; its contents never authorize rewards or commands. Private runtime session state
holds the current owner and combat actors.

Observed: the visitor's normal command path could not buy in the owner's bay. Unverified: hostile
non-editor mutation of protected nested keys, destroying/replacing the director, forged entity/event
sources, reconnect races, multi-session writes, save rollback, room teardown and crash recovery.
The official tester facility required workshop credentials unavailable to this external client; the
two `--as` bodies were both editors. Do not describe these tests as proving cheat resistance.
Runtime combat is room-local and restarts after the owner returns; only completed progression is saved.

The relevant primary contract is the world's authenticated engine docs and `platform-systems` skill:
[Spawn docs door](https://www.spawn.co/api/sdk/v1/a19e63cf-decf-46c7-9912-6505c59515d5/agent/docs),
[public integration contract](https://www.spawn.co/llms.txt).

## AI and foundation models

The engine contract exposes asynchronous `llm:chat` and schema-based `llm:generate` jobs, conversation
IDs, optional media and streamed parts. Model selection accepts Spawn's `fast`/`smart` aliases or an
OpenRouter model ID. The aliases are not evidence of proprietary foundation-model training, nor do
the docs establish the provider behind Savi. Verify exact provider, version, retention and price at
the time of adopting one; those were not measured here. OpenRouter selection provides a documented
route to external foundation models; no inference call was needed for this Merge slice.

Use deterministic source rules for combat, wallet and reward decisions. AI can later supply NPC
conversation or other optional asynchronous content with failure fallbacks and explicit budgets.
Do not put inference in the combat tick. Linked agent generation uses the creator's allowance;
an external agent does not invoke Savi's private build chat. Roblox can call external services
through server-side HttpService, but that requires its own integration and operation.
[Spawn agent contract](https://www.spawn.co/llms.txt),
[Roblox HttpService](https://create.roblox.com/docs/reference/engine/classes/HttpService).

## 3D models and source fidelity

The committed snapshot contains 513 placed parts and 16 unique meshes from Heaven bay 01 and its
outer grove, exported from Merge place 84544653387905 through Studio's supported APIs. Nothing was
written to the authored Roblox place. Source coordinates convert at 0.28 metres per stud, rotating
the source lane onto Spawn's -Z forward. A 300-stud lane therefore remains 84 metres long.
Nine authored hatcher pads remain visible; the four installed stands are the four playable slots.

The 18 scene asset groups include architecture, terrain and repeated mesh types. All are below the
single-request upload cap. A 14.9 MB combined upload failed during finalization with HTTP 503;
smaller groups succeeded. GLB image packing retains opaque base-color maps at up to 1024 pixels
and normal maps at up to 512. Geometry/placements are source-derived. Built-in Roblox marble is
approximated procedurally; eggs and the agent's body are placeholders. The floor/rail/pad colliders
use source boxes; decorative collisions and terrain are simplified, with a mesh collider on the gate.
The imported doggy/bear rigs retain the Attack clip; full HH character catalogs and animation states
have not been ported. An unlinked white emission input in Blender was corrected during export.
[EditableMesh](https://create.roblox.com/docs/reference/engine/classes/EditableMesh),
[AssetService](https://create.roblox.com/docs/reference/engine/classes/AssetService).

## Verification ledger

| Check | Result |
| --- | --- |
| HH CI | `mise run ci`: 2,846 headless tests, 323 specs passed, plus repository checks. |
| Source parity | Prices, 20 mitigation cases, early-relief points and all ten opening wave counts pass against executed Luau fixtures. |
| Gameplay adapter | Eight Node test groups pass; includes full ten-wave combat run with Tier-4 hatchers and checkpoint 10 in an in-memory adapter. |
| Real input | Browser buttons and movement completed buy/merge/deploy and waves 1–2; right-drag orbit and wheel zoom exercised. |
| Two peers | Shared room state observed; visitor purchase rejected; owner departure freed the bay. Both peers are editors. |
| Save/rejoin | Fresh client session retained 320 coins, two installed Tier-2 eggs, cleared wave 2 and pending rewards; owner reclaimed the bay. |
| Rendering | One local idle sample: 59 fps, 50 draw calls, 364,795 triangles including passes, 1440×1000, renderScale 1. This is not a mobile or load benchmark. |
| Errors | Client error-filter log empty after the corrected scene and material loaded. |
| AI | API assessed from docs; no runtime inference or billable generation tested. |
| Unverified | Ordinary-player security, live ten-wave checkpoint reconnect, room/server failure, hostile concurrency, mobile UX/performance, latency/loss, SQL migration and production billing. |

Two engine runtime hashes were observed during the same session: `83b794dcf076ede95d16203f09cc9306`
and, on rejoin, `5c977dd743ae41f3c7a7407c6a9fb82d`, both under the 6.0.0 contract. The starter's
engine metadata uses `hash: null`; a fixed runtime release/rollback guarantee was not established.
Keep reproducible version pinning on the next assessment list rather than calling this frozen.

## Next port milestones

1. Review this source bay's presentation and basic interaction in ColoradoPlays' world.
2. Establish the non-editor authority boundary and save recovery guarantees with Spawn.
3. Port one complete HH combat role and actual tier-egg art, then compare recorded fights and economy.
4. Measure one representative full bay on desktop/mobile, then multiple concurrent bays.
5. Design cross-platform identity/data migration only after those gates pass.
