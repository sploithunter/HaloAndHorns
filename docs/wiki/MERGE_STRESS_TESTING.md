# Merge eight-bay performance testing

## Contract (2026-09-05)

- Baseline: reconciled main `da1830abd57c79b560bb70ae73dacedf4d219443`, full CI 2,701 tests passing; fresh Merge Play without client errors.
- Start with one real viewing client and seven isolated offline-actor fixtures, for eight occupied bays. This is **not** an eight-client network test.
- Fixtures use in-memory copies of account profiles under negative IDs. No profile locks, saves, rewards, analytics, or offline-presence writes may target the source accounts.
- Use the existing Merge combat/autoplay runtime, including real pet models, eggs, projectiles, and navigation. Keep combat and economy authoritative.
- Measure client frame percentiles, rendering passes, server heartbeat, instance counts, and presentation records/batches under recorded camera and workload conditions. Report missing engine telemetry honestly.
- Compare matched workloads before/after each change. Prioritize audience filtering, compact/batched presentation, and bounded client work; do not delete living pets to reclaim caches.
- Test controls exist only in Studio through server-only BindableFunctions. Leave both Studio applications open. Do not publish production changes without separate authorization.

## Initial captures (Studio, not published)

- Eight bays: one real viewer plus seven negative-ID clones of the level-50 Macros profile, starting wave 530. Each fixture has nine tier-23 deployed eggs, 11 equipped personal pets, and saved tier-four defenses. Snapshots omit history and unequipped inventory; source saves are read-only and unchanged. This deliberately repeats one high-load profile, rather than pretending seven distinct accounts are connected.
- Runtime census: approximately 718 models in 78 pet folders, with seven workers around wave 531. One current-view sample rendered 5.4M triangles / 1,134 draws; later repeated fixed-view samples were around 5.2M triangles / 400–700 draws. These differing workloads are not an optimization comparison.
- Initial client 20s capture: frame mean 153ms / p95 236ms; render CPU mean 7.83ms, GPU mean 9.61ms. Server capture: frame mean 206ms / p95 308ms, heartbeat work mean 183ms. Server and client share a Studio machine; not a device-independent throughput claim.
- Inclusive service timing over 20s: 83 enemy ticks used 14.50s total; target assignment 2.12s, engagement 0.99s, pet-follow tick 1.15s. Inclusive nested measurements must not be added together. Remaining enemy passes are being narrowed down.
- Engine limitations: MicroProfiler buffers return no frame history despite reporting ready; script memory needs unavailable `STUDIOPLAT37936`. Raw receive statistics are zero in this Play Solo setup, so do not interpret them as zero network traffic.
- Studio controls: `ServerStorage.MergeOfflineStudioControl:Invoke("stress_start", {{userId = avatarSourceId, data = inMemorySnapshot}})`, `stress_status`, `stress_stop`, and bounded `stress_profile` (optional service-to-method-list selection). Start disables ordinary filling and fills only empty bays up to eight total; fixtures auto-stop after 30 minutes. No user-facing controls or production remote.

## Continuation checkpoint

- Draft PR #460; no production publish. First proposed optimization moves the existing proximity-radius test before allegiance/team resolution in `_petAggroPass`; no range or hostility rule changes. Runtime before/after validation remains required.
- At roughly 02:06 UTC Sep 6, Merge's Studio control connection stopped answering. `execute_luau`, status and Play-stop requests timed out; native app accessibility also timed out. Both Studio processes were preserved. Do not infer that the pending Play-stop succeeded or that the timed capture completed. Native process samples are in `/tmp/hnh-studio-main-sample.txt` and `/tmp/hnh-studio-stress-sample.txt`.
- Local evidence and a restricted fixture copy: `/tmp/hnh-eight-bay-fixture.rKXzr5` (equipped profile snapshot, baseline client/server JSON, corrected capture script). Keep source account data out of the repository. Capture script must match remote suffix `Combat_PresentationBatch$`, because actual instances are named `RE/Combat_PresentationBatch`; the first capture's zero batch counter was an instrumentation-name mismatch, not absent traffic.
- Next: restore responsive Play without closing Studio, profile `_petAggroPass` specifically (it was absent from the detailed component selection), then compare the cheap-distance-first change under the same fixture snapshot. The initial detailed sums leave approximately 10s of the 20s capture in uninstrumented enemy-loop work; do not attribute that remainder conclusively before measuring.
