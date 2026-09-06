# Merge eight-bay performance testing

## Contract (2026-09-05)

- Baseline: reconciled main `da1830abd57c79b560bb70ae73dacedf4d219443`, full CI 2,701 tests passing; fresh Merge Play without client errors.
- Target one real viewing client and seven isolated offline-actor fixtures, for eight occupied bays. After the memory failure below, begin with the viewer alone, then two/four/eight occupied bays only after each smaller stage passes memory and cleanup checks. This is **not** an eight-client network test.
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
- Studio controls: `ServerStorage.MergeOfflineStudioControl:Invoke("stress_start", {sources = {{userId = avatarSourceId, data = inMemorySnapshot}}, occupiedBayTarget = 2})`, `stress_status`, `stress_stop`, `stress_profile` and `stress_profile_status`. Start disables ordinary filling and fills only empty bays. The default is now **two total occupied bays**, with a 120-second run cap; larger targets (maximum eight) must be explicit. `stress_profile` returns immediately; poll status for the 20-second result. Stopping a run also restores profiling wrappers. No user-facing controls or production remote.

## Continuation checkpoint

- Draft PR #460; no production publish. First proposed optimization moves the existing proximity-radius test before allegiance/team resolution in `_petAggroPass`; no range or hostility rule changes. Runtime before/after validation remains required.
- At roughly 02:06 UTC Sep 6, Merge's Studio control connection stopped answering. `execute_luau`, status and Play-stop requests timed out; native app accessibility also timed out. The user subsequently reported system-memory exhaustion and performed a hard reboot. Do not infer that the pending Play-stop or timed capture completed.
- **Lost evidence:** the reboot removed `/tmp/hnh-eight-bay-fixture.rKXzr5` and native sample files. The numerical summaries above survived in this wiki, but the raw captures and restricted fixture copy did not. Reacquire a read-only snapshot and record its identity before any new matched comparison; do not claim it is the exact old workload. Keep source account data out of the repository. Capture scripts must match remote suffix `Combat_PresentationBatch$`; the first capture's zero batch counter was an instrumentation-name mismatch, not absent traffic.
- GitHub CI for `8f473612` failed the architecture guard on the harness's blocking `task.wait`, despite the earlier recorded local pass. The non-blocking capture fixes that debt. New local full CI: 2,706/2,706 tests, plus seven watchdog unit tests and isolated Edit-mode harness smoke. Hosted checks must still pass before merge.

## Daytime passive investigation (2026-09-06, supersedes guard requirement below)

- User explicitly requested **no guards**, one occupied bay, measure, then two and measure. `--observe-seconds` logs physical footprint/pressure without applying memory thresholds or sending signals. Overnight automation remains paused. Do not silently reinstate the earlier startup refusal as the current instruction.
- Fixed missing explicit `merge_stress_host` schema: the JSON host configuration is mapped into the shared configuration folder by Rojo, so both client and server must recognize its shape. Verified a fresh successful boot; the failed boot is excluded from gameplay baselines.
- Durable raw evidence lives in `/Users/jason/Documents/merge-performance-20260906.g8lFBb`, plus `/Users/jason/Documents/merge-passive-memory-20260906.jsonl`. Fresh sanitized source snapshot SHA-256: `7360ade4a2c80f85ab5d0221012ccdd0094c19c15e8f4b75a1bfeef1d0bf598a`. Keep the profile itself out of Git. It is a new Macros snapshot (rebirth 18, wave 60, nine tier-17/18 slots), **not** the lost wave-530 snapshot.
- Viewer is Colorado Plays: level 50, rebirth 9, nine hatchers, roughly 50–56 pet models. One negative-ID fixture adds the second bay, roughly 138 total pet models. Source accounts are read-only; fixture saves stay in memory. Fixed fake `OnAfterSave` to supply the saved snapshot expected by DataService's confirmation token. Hatcher avatar requests for synthetic IDs use placeholder rigs, a fidelity limitation; pet models/combat remain normal runtime.
- First one/two/one sequence: sampled frame intervals around 16.7 ms at one bay, around 19–22 ms at two. Memory did not immediately explode on adding a bay; it continued growing after fixture teardown. At about four minutes, `Internal` released ~1.6 GB, but `BaseParts`, `Instances`, and `Signals` continued upward. By ~22.6 minutes, total Stats memory was ~10,015 MB, `BaseParts` ~2,414 MB, `Signals` ~214 MB, while live instance/pet counts and texture memory were comparatively stable. These are elapsed-time diagnostics, **not matched FPS or per-client/server allocation comparisons**: Play Solo shares a process, camera/workload were not fixed, and normal viewer progression persists between runs.
- SceneAnalysis unparented queries found the client `DropVisibility` retaining 603 detached drop Models, and Merge retaining 930 then 1,318 Models. The watcher accumulated connections across pooled reparent cycles; detach now disconnects each model. Merge's append-only enemy history now releases at complete-wave resolution. Further testing identified **additional replaced-pet histories**, including an unused run-wide `units` list and non-pruned team/escort modifier lists. Removed unused history and derive modifier membership from existing live-folder scans; no living pets are destroyed or unloaded.
- Event-driven `PetDownedVisibility` replaces per-frame descendant visibility writes and a 4 Hz remote sweep. Healthy pets retain normal visibility policy. Isolated native tests pass down/revive, late descendants, external billboard writes, detach/reparent/disposal, plus 20 recycled-drop ownership cycles. Initial fresh queries show zero detached drop Models held by the fixed watcher. Total memory still grew before the replacement-history fix was loaded; **do not claim OOM solved or memory savings yet**.
- Replacement-history fix is verified in fresh Play: waves 101→110 advanced with 32–36 current squad references and zero detached modifier-list models. SceneAnalysis then exposed PetFollowService's strong mining-cooldown keys (59 retired Models): expire only elapsed timestamps during the existing tick, preserving unexpired cooldowns even for temporarily detached pets. Isolated native expiry/preservation test passes; after another fresh boot the service no longer appears in the unparented-model result. The first attempted expiry smoke correctly failed against the **old running source**, since Rojo updated Edit, not that Play simulation; rerun against fresh Edit source passed.
- All-fixes native run: viewer waves 112→123, fixture 60→mid-60s, 175 viewer replacements by the final query. Merge held one detached Model, DropVisibility and PetFollowService held zero. Current squad audit still had zero detached unit references. Fixture teardown completed with no harness errors. Confirmed object-lifetime cleanup, **not a quantified total-memory or FPS win**.
- In that run, one bay (0–165 s) grew 12,585→13,204 MB in whole-Studio Stats; two bays (170–286 s) 13,343→13,803 MB; back to one (291–386 s) 13,909→14,375 MB. `BaseParts` grew 4,760→5,560 MB over the run. Weighted sampled Heartbeat intervals were 20.8/23.9/19.7 ms respectively, with changed waves/view, so do not use them as matched optimization percentages. Earlier Play allocations had not been reclaimed; these are **not cold-process measurements**.
- After stopping Play, idle Edit stabilized: total 13,206→13,181 MB, `BaseParts` flat 5,539.5 MB, 27,503 instances over ~126 s. Darwin physical footprint stabilized around 13.82 GB decimal (~12.87 GiB). This separates continuing gameplay-associated growth from a continuing idle leak, but does not identify the remaining allocator owner or prove deployment behaves identically. User explicitly reiterated that Studio combines server and client; do not sum their readouts or label these as production memory budgets.
- Local CI now 2,710/2,710 tests plus eight host-monitor tests. PR #460 remains draft. Next: investigate remaining native allocation/retention and obtain separated deployment-representative telemetry before increasing bay count. Roblox's [performance guidance](https://create.roblox.com/docs/performance-optimization/identify) recommends actual client measurements for accurate client memory; these shared-process Studio totals are not live-server/client budgets.
- Bounded Edit-mode isolation did **not** reproduce the growth: 150 clone/destroy operations across the three `frostblight_lamb` variants added only ~0.38 MB transient BaseParts; 10,000 unparented pivots were flat; 10,000 pivots of one anchored, invisible Workspace clone were also effectively flat. Each clone was destroyed, the original templates were untouched, and live instance count returned to baseline. Evidence: `edit-clone-isolation.json`, `edit-pivot-isolation.json`, and `edit-workspace-pivot-isolation.json` in the durable directory above. These synchronous Edit tests exclude frame-to-frame rendering, replication, combat, and runtime listeners: they do **not** exonerate the full live movement/spawn lifecycle or identify an engine defect.

## Later daytime eight-bay capture (2026-09-06)

- Successfully stepped through one/two/four/eight occupied bays with passive logging
  and bounded fixtures. The eight-bay stage reached 617–630 pet/objective models and
  79 NPC squads and tore down normally. Raw files: `npc-budget-stages-server.json`,
  `npc-budget-stages-client.json`, `npc-budget-host.jsonl` in the durable directory above.
- Before bay hiding, weighted sampled client frame intervals were ~21.5 ms at two
  bays, ~27.7 ms at four, ~61.0 ms at eight. Eight-bay Stats total grew approximately
  15,040→15,509 MB; BaseParts 5,956→6,201 MB. This is the already-warm shared Studio
  process, **not** matched deployment performance or an improvement over the lost
  previous eight-bay workload. Memory pressure remained normal; memory growth persists.
- Rejected the 12-second on/off NPC-cadence windows as an FPS comparison: camera drift
  reached 158–221 studs. Preserve `npc-budget-ab-rejected-camera.json`, not a claimed win.
- A later eight-bay test verified character-local bay hiding; see [Client Performance](CLIENT_PERFORMANCE.md).
  The repaired default profiling selection produced a 20.002-second capture: inclusive
  EnemyService combat ticks 5.599 s (147 calls), pet aggro 1.343 s, target assignment
  1.130 s, enemy engagement 2.593 s; PetFollow ticks 3.482 s (163 calls), including
  24,743 `_findBreakable` calls totaling 2.035 s. **Nested times must not be added.**
  These identify follow-up targets, not script-exclusive CPU or a before/after comparison.
  Evidence: `bay-detail-server-profile.json` and `bay-detail-*-memory.json`.
- Harness fixes: an empty explicit selection legitimately captured no methods; the
  default also contained nonexistent `CombatService.ResolveEnemyDamage`. Removed that
  obsolete default and added CI validation against actual service definitions. A fresh
  Play verified populated counters and automatic restoration. No production publish.

## Enemy target lookup verification (2026-09-06)

- `PetFollowService._findBreakable` now asks the existing EnemyService spawn/despawn
  registry before scanning every enemy rig descendant. Identity and folder scope are
  checked; authored/unregistered enemies retain the old traversal fallback. No new
  model cache, attack-range relaxation, damage change, or spatial grid is introduced.
- Isolated production-method tests cover changed IDs, destroyed/reparented targets,
  unregistered fallback, unchanged HP policy and world-scoped crystals. Four alternating
  1,000-lookup rounds measured indexed 0.500–0.547 ms versus traversal 142–162 ms.
  This is a microbenchmark, not an FPS result. `tools/pet_target_lookup_smoke.luau`
  destroys its fixtures and does not initialize services or access player profiles.
- Fresh Play with the same sanitized seven-worker source reached 625–630 pet/egg
  models in eight occupied bays. A 20.010 s default capture measured 25,018 lookups
  totaling **0.027534 s**, versus the preceding eight-bay capture's 24,743 totaling
  **2.034852 s** (~1.10 versus 82.24 microseconds/call). PetFollow tick inclusive
  time was 1.490 s versus 3.482 s. Workloads/waves differ, so these are observed
  function timings, not a controlled whole-game improvement percentage.
- A second 20.044 s capture added nested registry instrumentation: 35,270 lookups,
  0.050361 s total, with 35,270 registry calls totaling 0.024105 s. The extra wrapper
  affects timing. Workers advanced from wave 60 through 63 and beyond; teardown
  returned zero workers and no harness errors. Client census retained all 72 eggs,
  with 438 of 630 models hidden and no hidden eggs at Heaven 1.
- Performance is **not solved**: the first capture still spent 7.542 s inclusive in
  enemy combat ticks (including 4.503 s engagement), and low-FPS/server-frame warnings
  remain. Whole-Studio Stats grew 15,472→16,061 MB over ~140 s including teardown;
  BaseParts grew 6,713→6,980 MB. Do not sum client/server counters or claim a production
  memory budget. Play was stopped, Studio left open, no production publish.
- Raw evidence in the durable directory above: `target-index-live-profile.json`,
  `target-index-live-profile-2.json`, `target-index-isolated-smoke.json`,
  `target-index-server-memory.json`, `target-index-client-memory.json`,
  `target-index-console.json`, and passive `target-index-live-host.jsonl`.
  Full local CI: 2,727 tests / 305 specs. The user's zone-square targeting suggestion
  remains an optional future idea; test this exact lookup improvement first.

## Historical memory incident and restart gate (2026-09-06)

- Persistent macOS evidence: `/Library/Logs/DiagnosticReports/JetsamEvent-2026-09-05-202648.ips` identifies `RobloxStudio` as the largest process. Merge PID 45162 had 5,413,905 accounted pages versus Farm PID 43412's 326,964, with 16,384-byte pages. These are memory-accounting figures, **not a claim of 88 GB physically resident on the machine**. `/Library/Logs/DiagnosticReports/ResetCounter-2026-09-06-071804.diag` records a button reset. Root allocation cause remains unproven.
- Overnight automation is paused. No eight-bay retry until a smaller controlled workload is safe. The old engine-side timer was insufficient when Studio stopped responding.
- `tools/merge_stress_watchdog.py` independently reads Darwin `proc_pid_rusage` physical footprint (including memory missed by RSS-only monitoring), process birth identity, and system pressure. Settings are in `configs/merge_stress_host.json`: refuse startup at 6 GiB; trip at 8 GiB, 2 GiB growth, or any non-normal system pressure; sample twice per second. Maximum observation is 180 seconds, longer than the 120-second fixture cap. Its expiration requires stopping/rechecking the test, not silently proceeding without monitoring.
- Default watchdog mode is read-only. **Only after explicit user authorization**, `--suspend-on-limit` may send SIGSTOP to the exact tested Studio executable and birth identity. It never kills, resumes, reopens, publishes, or signals a replacement PID. Expiration alone does not suspend Studio. On an alarm, leave the instance suspended, notify the user, and agree on safe recovery before resuming. Suspension arrests further work; it does not reclaim already-allocated memory or guarantee against every OOM.
- Run in an independent terminal before Play/stress; require its `ready` event with `suspension_enabled: true`, verified live PID, and durable JSONL output outside `/tmp`. Do not start on `refused_start`. Stop fixtures/Play and confirm memory stabilizes before disarming. The host guard is an operator-run safety gate, **not automatically coupled to the Studio harness**.
- Fresh Edit-mode measurement (PID 2385): 6.17 GiB footprint / 5.10 GiB resident, normal pressure. A real read-only arming attempt returned `refused_start: startup_footprint` at 6.20 GiB; no signal was sent and no load added. Evidence: `/Users/jason/Documents/merge-memory-baseline-20260906.jsonl` and `/Users/jason/Documents/merge-memory-start-check-20260906.jsonl`.
- Same-session read-only Studio Stats, **Edit mode**: total 6,320.38 MB; `Internal` 3,508.14, `LuaHeap` 742.89, `GraphicsTexture` 134.21, `Instances` 86.94, `GraphicsTerrain` 47.94, `PhysicsParts` 28.33, `Signals` 17.73, `GraphicsMeshParts` 6.10. These selected categories are not a complete sum. This is not a running-game client measurement and does not identify which plugin/engine allocation owns `Internal` or `LuaHeap`; it does show that current Edit footprint is not predominantly textures.
- Next: investigate retained Edit/Play memory without increasing load; verify the guard with disposable-process tests and authorized suspension behavior, then obtain a safe one-bay baseline before any escalation. Profile `_petAggroPass` specifically (now included by default) and compare distance-first filtering with matched new captures. Do not attribute unmeasured enemy-loop time conclusively.
