# Focused desktop renderer QA

September 8, 2026 local / September 9 UTC. **13 of24 planned conditions produced usable short desktop samples.** Three subsequent samples were rejected after the session locked; eight conditions were not attempted. This is evidence, not a budget pass, phone certification or complete FX comparison.

## Device and method

- Apple M3 Max:14-core CPU,30-core GPU,36GB RAM; two2560×1440@60Hz Thunderbolt displays. Three Studio processes were open; this is a shared desktop Studio environment, not an isolated published client benchmark.
- AppKit/CGWindow verified foreground Roblox Studio PID86750, window7140, correct Crossroads checkpoint title. Outer bounds2438×1374 at(2645,39); actual native client viewport1807×950. No viewport OS crop is inferred from those bounds.
- Low = actual `settings().Rendering.QualityLevel = Level04`; high = `Level21`. Both writes succeeded and each sample records readback. `UserGameSettings.SavedQualityLevel` remained Automatic: attempted write raised `std::exception`. These are Studio rendering levels, not claims of mobile quality3/10. Cosmetic tier was explicitly overridden with `CrossroadsFXQuality` full/reduced/off.
- Four fixed planned viewpoints: arrival(0,7,108)→(0,6,40); Bragg(37,12,-65)→(0,8,-88); Heaven pond(-265,9,32)→(-216,2,8); Hell pond/stands(281,10,40)→(244,3,8). Scriptable camera, FOV70. Player was not moved. The actual runtime fish/emitter counts are recorded, so distance culling is part of each observation.
- Every condition warmed9seconds, then collected two3-second RenderStepped event windows. Arrays contain actual event delta and three Stats timing fields. Standard median (averaging the middle pair for even counts) and nearest-rank p95 below pool both windows; raw data and per-repeat summaries are retained. The two windows are adjacent repeat observations, not independent randomized trials.
- CPU/GPU columns are sampled `Stats.RenderCPUFrameTime`/`RenderGPUFrameTime` telemetry, not independently timed MicroProfiler scope work. CPU time may include cadence/pacing; these numbers do not prove a CPU bottleneck. No MicroProfiler capture/settings were changed.
- SceneAnalysis triangle/draw pass snapshot, total client memory and simple projected-part-center counts were taken outside frame sampling. Memory includes the Studio client/editor context and cannot be read as a standalone game footprint. Frustum center counts exclude invisible parts but do not perform occlusion testing or bounds intersection.
- No screenshots, video or geometry edits occurred during sampling. Opposing-passage QA proxies had been removed before the run. Native scene/performance skill guidance informed snapshot interpretation; no hotspot markers, mode switching or optimization edits were performed.

## Accepted timing observations

Milliseconds. CPU/GPU entries show median / p95. All accepted windows contained180frames except two181-frame windows. Frame cadence was around60Hz; no agreed target was used to issue a pass.

| View | Graphics | FX | RenderStep median / p95 | CPU median / p95 | GPU median / p95 | Memory MB range |
|---|---|---|---:|---:|---:|---:|
| arrival | Level04 | full | 16.74 / 19.21 | 16.31 / 18.71 | 4.52 / 5.26 | 5508–5509 |
| arrival | Level04 | reduced | 16.64 / 19.15 | 16.16 / 18.68 | 4.47 / 4.96 | 5507–5510 |
| arrival | Level04 | off | 16.74 / 19.45 | 16.25 / 18.87 | 4.54 / 5.48 | 5508–5509 |
| arrival | Level21 | full | 16.67 / 19.12 | 16.24 / 18.59 | 6.67 / 8.70 | 5661–5661 |
| arrival | Level21 | reduced | 16.75 / 18.98 | 16.27 / 18.62 | 5.85 / 8.74 | 5661–5661 |
| arrival | Level21 | off | 16.70 / 19.08 | 16.24 / 18.64 | 7.44 / 8.47 | 5656–5657 |
| bragg | Level04 | full | 16.69 / 18.89 | 16.20 / 18.42 | 2.97 / 3.30 | 5594–5595 |
| bragg | Level04 | reduced | 16.70 / 19.01 | 16.20 / 18.46 | 2.97 / 3.30 | 5594–5595 |
| bragg | Level04 | off | 16.68 / 18.91 | 16.20 / 18.42 | 2.98 / 3.29 | 5594–5594 |
| bragg | Level21 | full | 16.73 / 19.06 | 16.23 / 18.59 | 5.80 / 6.48 | 5656–5656 |
| bragg | Level21 | reduced | 16.71 / 19.06 | 16.22 / 18.56 | 5.81 / 6.73 | 5657–5657 |
| bragg | Level21 | off | 16.66 / 18.95 | 16.20 / 18.43 | 5.70 / 6.10 | 5654–5654 |
| heaven | Level04 | full | 16.71 / 19.13 | 16.20 / 18.64 | 4.60 / 4.90 | 5595–5595 |

## Scene snapshots

Draws/triangles below exclude the engine shadow pass. These are view snapshots, not triangle counts of the complete map. Visible = projected part centers, not occlusion-aware visible geometry. Transparent = visible centers with 0 < Transparency < 1; this does not count Terrain water, particle alpha or texture alpha. Screen-space transparency coverage was not measured and is not 0%.

| View / graphics / FX | Draws | Triangles | Visible / transparent centers | Enabled emitters / rate | Fish |
|---|---:|---:|---:|---:|---:|
| arrival / Level04 / full | 469 | 1,671,129 | 3044 / 0 | 2 / 2.0 | 0 |
| arrival / Level04 / reduced | 469 | 1,671,129 | 3044 / 0 | 2 / 1.0 | 0 |
| arrival / Level04 / off | 466 | 1,671,121 | 3044 / 0 | 0 / 0.0 | 0 |
| arrival / Level21 / full | 469 | 1,720,151 | 3044 / 0 | 2 / 2.0 | 0 |
| arrival / Level21 / reduced | 469 | 1,720,151 | 3044 / 0 | 2 / 1.0 | 0 |
| arrival / Level21 / off | 466 | 1,720,143 | 3044 / 0 | 0 / 0.0 | 0 |
| bragg / Level04 / full | 154 | 695,243 | 1816 / 0 | 2 / 2.0 | 0 |
| bragg / Level04 / reduced | 154 | 695,243 | 1816 / 0 | 2 / 1.0 | 0 |
| bragg / Level04 / off | 154 | 695,243 | 1816 / 0 | 0 / 0.0 | 0 |
| bragg / Level21 / full | 154 | 695,243 | 1816 / 0 | 2 / 2.0 | 0 |
| bragg / Level21 / reduced | 154 | 695,243 | 1816 / 0 | 2 / 1.0 | 0 |
| bragg / Level21 / off | 154 | 695,243 | 1816 / 0 | 0 / 0.0 | 0 |
| heaven / Level04 / full | 258 | 1,763,227 | 5028 / 0 | 0 / 0.0 | 2 |

Arrival and Bragg Full/Reduced/Off frame distributions overlap in these short runs. The arrival view includes a small active emitter rate; Bragg does not exercise the dense Hell mist. Therefore these results do **not** establish the cost or appearance of full pool mist. High graphics increases reported GPU time in these views, but this experiment is neither randomized nor long enough for a causal cost estimate.

## Completion, rejection and restoration

| View | Level04 full/reduced/off | Level21 full/reduced/off |
|---|---|---|
| Arrival | accepted / accepted / accepted | accepted / accepted / accepted |
| Bragg | accepted / accepted / accepted | accepted / accepted / accepted |
| Heaven | accepted / rejected / rejected | rejected / not attempted / not attempted |
| Hell | not attempted / not attempted / not attempted | not attempted / not attempted / not attempted |

The final accepted Heaven window began00:51:36UTC and finished approximately00:51:42. The next condition had `loginwindow` foreground before its9-second warm-up; its sample began00:52:01UTC. This bounds the observed transition to roughly the interval after00:51:42 and before00:52:01; the exact timestamp for that transition was not available. A later root query recorded CGSSessionScreenLockedTime=1788915404 (00:56:44 UTC), which is later than this sampling transition and must not be substituted for its start time. Crucially, the first loginwindow precheck happened before its warm-up, so the lock/foreground change was already present earlier than00:52:01. Three already-batched conditions completed with6events per3seconds and zero GPU timing; all are rejected and kept in raw results for audit.

A sanitized depth-one ioreg read then confirmed **CGSSessionScreenIsLocked=Yes while IOConsoleLocked=No**. The per-session lock plus loginwindow and2Hz samples is the verified blocker. IOConsoleLocked alone is insufficient. Correct Studio foreground was checked before each accepted condition after the first; the first used the preparatory foreground verification. Foreground/session lock was not continuously monitored during the accepted windows, so acceptance is qualified by those checks and continuous rendering evidence.

Restored and read back Rendering QualityLevel Automatic, SavedQualityLevel Automatic, camera Custom and FOV70; restored starting CFrame/Focus and removed the temporary player FX quality attribute. The player was not moved. At handoff Studio remained Play with Client focused. Root subsequently stopped Play after restoration; the final state is Edit, with native checkpoint hash unchanged (root verification). No saved geometry, lighting, runtime source or effect tuning changed. Camera ownership was released. The requested final Hell/full screenshot could not be reached before the lock.

Resume only after per-session unlock and correct foreground are verified: rerun the five unfinished Heaven conditions and all six Hell conditions, with foreground and per-session lock checks before **and after** every sample and immediate stop on change. Finish a separate warmed Hell/full screenshot after timing, then restore settings. Longer randomized samples and target-device testing remain necessary before setting or certifying a performance budget.

[Raw arrays, per-repeat summaries and rejected records](focused-render-results.json).
