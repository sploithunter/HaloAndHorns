# Spawn capability assessment for HH

Status: first playable assessed, 2026-11-09. [Lab](https://www.spawn.co/@coloradoplays/halo-horns-merge-bay-lab@dev) · [Implementation](../../ports/spawn/README.md) · [Draft PR #501](https://github.com/sploithunter/HaloAndHorns/pull/501).

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
| Saves | Existing HH profiles/DataStore services | Protected `player.state.merge` holds wallet, eggs, progression and dedup history. Actual leave/rejoin retained wave-2 and checkpoint-10 progress. No Roblox identity/profile import. |
| Art | Studio geometry, IDs, rigs, built-in materials | Actual bay read from Studio; meshes/UVs/normals/textures reconstructed as GLB groups. Real pet rigs with distinct Walk/Attack imports work. Materials, scale and collision need explicit conversion. |
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
approximated procedurally; the agent's body remains a placeholder. All 28 source egg models are imported. The floor/rail/pad colliders
use source boxes; decorative collisions and terrain are simplified, with a mesh collider on the gate.
The imported doggy/bear rigs contain separate Walk and Attack actions. The earlier action labeled
Attack was actually Walk; the corrected export appends the canonical wolf-attack action to both
compatible 19-bone rigs. Full HH character catalogs/powers have not been ported. Unlinked white
emission inputs in both source rigs were corrected during export.
[EditableMesh](https://create.roblox.com/docs/reference/engine/classes/EditableMesh),
[AssetService](https://create.roblox.com/docs/reference/engine/classes/AssetService).

## Verification ledger

| Check | Result |
| --- | --- |
| HH CI | `mise run ci`: 2,846 headless tests, 323 specs passed, plus repository checks. |
| Source parity | Prices, 20 mitigation cases, early-relief points and all ten opening wave counts pass against executed Luau fixtures. |
| Gameplay adapter | Eighteen Node test groups pass; includes full ten-wave combat run with Tier-4 hatchers and checkpoint 10 in an in-memory adapter. |
| Real input | Browser buttons and movement completed buy/merge/deploy and waves 1–2; right-drag orbit and wheel zoom exercised. |
| Two peers | Shared room state observed; visitor purchase rejected; owner departure freed the bay. Both peers are editors. |
| Save/rejoin | Fresh client session retained 320 coins, two installed Tier-2 eggs, cleared wave 2 and pending rewards. Deployed version 23 also retained cleared wave/checkpoint 10 on actual leave/rejoin. |
| Rendering | One local idle sample: 59 fps, 50 draw calls, 364,795 triangles including passes, 1440×1000, renderScale 1. This is not a mobile or load benchmark. |
| Errors | Client error-filter log empty after the corrected scene and material loaded. |
| AI | API assessed from docs; no runtime inference or billable generation tested. |
| Unverified | Ordinary-player security, room/server failure, hostile concurrency, mobile UX/performance, latency/loss, SQL migration and production billing. |

Two engine runtime hashes were observed during the same session: `83b794dcf076ede95d16203f09cc9306`
and, on rejoin, `5c977dd743ae41f3c7a7407c6a9fb82d`, both under the 6.0.0 contract. The starter's
engine metadata uses `hash: null`; a fixed runtime release/rollback guarantee was not established.
Keep reproducible version pinning on the next assessment list rather than calling this frozen.

## Next port milestones

1. Review this source bay's presentation and basic interaction in ColoradoPlays' world.
2. Establish the non-editor authority boundary and save recovery guarantees with Spawn.
3. Complete HH squad drafts, roster and role/power rules; compare recorded fights and economy. Source egg art and the initial melee choreography are now ported.
4. Measure one representative full bay on desktop/mobile, then multiple concurrent bays.
5. Design cross-platform identity/data migration only after those gates pass.

## Dragging and stacking (2026-11-09)

Physical eggs and the B panel support pointer-captured mouse/touch drag. World anchors align
pointer surfaces with the source board and stands; a local ghost and target highlight preview
the result. The same tier can be stacked on the board or an occupied stand, through the source terminal tier T56. An empty
board slot accepts a move; an empty stand accepts installation. Stand changes are locked during
combat. All drops use one platform-validated `drop` command with source/target slots, observed
tiers and the existing dedup nonce. A stale or invalid drop consumes neither egg. Mouse/touch
stacking, stand install/upgrade, panel-to-world drag, wrong-tier rejection and Escape/touch
cancellation were exercised in an isolated browser preview. The HUD mount holds pointer capture
across reactive updates and clears it on cancellation/unmount.

## Source egg progression and combat choreography (2026-11-09)

The default HH stage currently contains **56 tiers**, not the older eight-tier wiki summary:
28 normal eggs across Home and Heaven/Hell 1–3, then the same identities as prototype Huge eggs.
The Huge pass does not establish ownership of real Huge inventory pets. The exporter reads the
stage's egg catalog, 3–9 team positions, best-of-N draft metadata, creation prices and generator
quotes directly from config. Two equal eggs advance one tier, terminal at 56; source formatting
uses M/B/T/Q suffixes. Wallet checks allow finite integer-valued doubles, matching Luau's numeric
semantics at late-tier prices. Full best-of-N species drafts and full combat balance are not ported.

All 28 actual egg meshes/textures were read through authorized Studio APIs, normalized to source
height and uploaded as immutable GLB assets. Both pet CDN assets were inspected after upload:
Walk and the real 1.708-second Attack action each retain 58 animation channels.

Attack is a sequence: acquire/retain a target, travel to a stable formation slot, face it, plant,
apply a real hit, lunge/slam and rebound, sidestep after recovery, react when hit, then rejoin the
formation or acquire the next target. Numeric ports of `PetFormation.attackOffset`, `PetAttackMotion`
and `HitReact` consume exported source parameters. The existing single-bay combat rules still use
Doggy melee defenders and Bear enemy art. All seven formation curves and five role profiles are
verified against executed Luau fixtures; this does not claim all five roles/powers are playable.
A density adapter expands the minimum ring radius using the source footprint when several hatchers
focus the same enemy, with an equivalent reach allowance; it is not exact HH range/balance parity.
The ring pole uses the hatcher squad's home anchor because these NPC squads do not follow the player.

The director preserves clean combat coordinates at 10 Hz; a separate platform actor behavior samples
cosmetic root motion at 30 Hz. Per-hit state drives a once-only attack clip, contact/recovery,
received flinch, elemental impact/flash and a separate lifetime-bound damage marker. Floating numbers
show actual HP removed, including overkill clamping, and survive target deletion. No invented crit,
miss, heal or power outcomes are emitted by the basic simulation. Death and merge use native FX;
all-peer effect audience is explicit. No additional inference is used.

Verification: 18 Node groups, including 273 formation fixtures, all five strike profiles and all ten
waves; HH CI 2,846 tests/323 specs. Real mouse drags crossed T4→5, T28→29 and T55→56, and T5/T29
installations spawned 4/9 defenders. A live preview wave-10 fight using four T4 hatchers cleared at
checkpoint 10 with reserve 5; native actor snapshots confirmed whole-body offsets and attack channels
alongside actual damage markers. A local 640×360 render sample reported 60 fps; this is not a mobile,
full-resolution or multi-bay performance measurement. Preview hot writes log expected
`teach.save.published-room` notices because its base is a published version; gameplay errors were
checked separately. Runtime hash `0d454803…` was observed, further evidence of rolling engine versions.

Deployed dev version 23 was also exercised at 1440×1000 on engine `289ba86c…`: T5/T29 capacities,
wave-10 clear with reserve 5, distinct attack channels/root offsets, visible rising/fading damage
text (DOM opacity/animation time and screenshot verified), and empty gameplay error log. Actual
leave/rejoin retained cleared wave/checkpoint 10. Reclaim now preserves completed status instead
of offering wave 11; the ten-wave director regression covers this. Crash/rollback recovery remains
unverified. Both tests used the agent's own separate profile/room, without editing the creator's save.

## Wall-mounted upgrade board (2026-11-09)

The creator's screenshot identifies `Heaven_01_WallBoard`. A native object-UI panel now sits on
its inward face, using the source management-board dimensions (14x8x0.6 studs), bottom height
(3.5 studs) and the service's 1.6-stud wall inset. Buy Egg and Upgrade Spawn show live names,
capacities and canonical Waycoin prices; the floating generator HUD button was removed. This
places the existing lab actions; full Gem-rank/rebirth controls are still outside the slice.

Spawn object faces use native `ui:<button-id>` ears, not HUD `onclick` functions. The board rings
the presser's player behavior; that behavior accepts only the board's event and emits the ordinary
command with its real source identity. The director retains ownership, funds, wave and dedup
validation, and rejects wall actions/generator upgrades beyond the configured 8-metre radius.
Put the physical width/class on the same `face="front"` root: a nested fixed-width wrapper shrank
the content in testing. Yaw -90 faces into this bay; +90 showed its back. Identical HTML updates
are deduplicated by the engine, allowing live script/style edits to refresh without a stale cache.

Live pointer checks upgraded T4→T5 for 16,000 Waycoins, then bought the new T5 egg for 2,000.
A remote upgrade left both wallet and generator unchanged after the test body settled at the far
position. All 18 Node groups and HH CI (2,846/323) passed. Preview expected published-room file-write
notices were separated from gameplay errors. Tests touched only the agent's isolated preview profile.

## Shared inventory and deployment follow-up (2026-11-09)

[Shared HH account assessment](SPAWN_SHARED_ACCOUNT.md) supersedes any assumption that Merge
uses only temporary pets: Full Merge uses actual owned/equipped pets as well as NPC hatchers.
The shared inventory core now passes source-executed fixtures; it is not yet wired into the live
UI. Ordinary-browser tests verified a changed mock account across places and HTTP-cache-cleared
reload. Roblox Merge streaming is enabled; equivalent imported-model eviction for two full Spawn
games is unproven. One-world/separate-world deployment stays open while representative load and
authority tests continue. No live Spawn main change or publication in this assessment.
