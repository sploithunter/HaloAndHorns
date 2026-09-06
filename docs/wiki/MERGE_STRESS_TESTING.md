# Merge eight-bay performance testing

## Contract (2026-09-05)

- Baseline: reconciled main `da1830abd57c79b560bb70ae73dacedf4d219443`, full CI 2,701 tests passing; fresh Merge Play without client errors.
- Start with one real viewing client and seven isolated offline-actor fixtures, for eight occupied bays. This is **not** an eight-client network test.
- Fixtures use in-memory copies of account profiles under negative IDs. No profile locks, saves, rewards, analytics, or offline-presence writes may target the source accounts.
- Use the existing Merge combat/autoplay runtime, including real pet models, eggs, projectiles, and navigation. Keep combat and economy authoritative.
- Measure client frame percentiles, rendering passes, server heartbeat, instance counts, and presentation records/batches under recorded camera and workload conditions. Report missing engine telemetry honestly.
- Compare matched workloads before/after each change. Prioritize audience filtering, compact/batched presentation, and bounded client work; do not delete living pets to reclaim caches.
- Test controls exist only in Studio through server-only BindableFunctions. Leave both Studio applications open. Do not publish production changes without separate authorization.

Results and reproducible commands will be added as measurements complete.
