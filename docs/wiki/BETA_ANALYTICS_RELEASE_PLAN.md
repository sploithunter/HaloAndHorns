# Beta Analytics and Incremental Release Plan

Status: provisional operating plan, 2026-07-19. This is a decision framework, not an irreversible
launch commitment. Replace provisional thresholds with observed baselines after the first clean
stranger cohort.

## Technical summary

Halo & Horns should launch in three paid waves, with one stable build per wave and a full
instrumentation rehearsal before any ad spend. The recommended cadence is Tuesday–Wednesday
acquisition, Thursday retention maturation, Friday diagnosis, Monday release, then a same-time
Tuesday comparison cohort. This is an operational choice, not a claim that Tuesday traffic is
intrinsically better.

The game already has the right dual-path foundation:

- Roblox `AnalyticsService` supplies native onboarding, retention, acquisition, platform, and
  benchmark views.
- `RetentionEvents_v1` preserves the bounded server-observed event stream and daily counter shards
  needed for event-sequence, cohort, timing, and distributional analysis.
- The player profile holds only durable milestones and current gameplay state.

Do not replace the raw store with Creator Hub-only reporting for this beta. Native Roblox analytics
is the operational dashboard; the raw store is the reproducible analytical record. Neither should
control gameplay.

Before Wave A, ship analytics schema v2 with immutable build identity, acquisition attribution, an
unambiguous first-play cohort, and export completeness checks. The current raw payload has
`cohortDate`, but it is the session's UTC date, not necessarily the player's first-play cohort. It
also lacks build/commit and campaign identity. Those are launch blockers because a build comparison
could otherwise mix populations without showing it.

## Decision this plan supports

The beta must answer, quickly and credibly:

1. Can a stranger load the game and reach the fun without help?
2. At which tutorial, quest, level, or area step do players leave?
3. Are the losses primarily comprehension, technical quality, pacing, or difficulty?
4. Do players return the next day?
5. Did a specific released change improve the intended metric without harming downstream behavior?
6. Is the data complete enough to trust any of the answers?

The immediate objective is learning, not maximizing DAU or revenue. Spend is released only when the
previous wave produced trustworthy data and no stop-the-line defect remains.

## What is already implemented

The source-of-truth implementation is documented in
[Retention Analytics](RETENTION_ANALYTICS.md):

- `RetentionService` observes server-authoritative semantic `FireGameEvent` events.
- The native one-time onboarding funnel covers join, all ten tutorial objectives, first quest,
  First Steps completion, and first area unlock.
- Player profiles persist one-time milestone timestamps and session numbers.
- `RetentionEvents_v1` stores partitioned raw event chunks and server-sharded daily aggregates.
- Session start/end events include progression snapshots.
- A whitelisted client-context event captures device class, viewport, locale, and input modes.
- `tools/export_retention.py` exports JSONL/CSV events, aggregate summaries, tutorial funnel,
  level exits, and event counts through a read-only Open Cloud key.
- `retention.get` provides an individual live-player admin snapshot.

This is enough to diagnose the basic funnel. The pre-launch work below makes wave-to-wave attribution
safe and the daily process repeatable.

## Launch blockers: analytics schema v2

All items in this section must be complete and verified in a published production server before
paid traffic.

### 1. Stamp immutable build identity into every session

Add the following fields to the raw session/chunk and aggregate envelope:

| Field | Definition |
| --- | --- |
| `buildVersion` | Release version from `configs/build_info.lua`, such as `0.3.1` |
| `buildCommit` | Exact Git commit published to Roblox |
| `buildBranch` | Expected to be `main` for production |
| `builtAt` | Published build stamp |
| `analyticsSchemaVersion` | Event/envelope schema, incremented when meaning changes |
| `contentVersion` | Optional stable content/balance identifier |

The build stamp must be server-resolved. Never accept it from the client.

### 2. Separate session date from acquisition cohort

Do not call a per-session partition date `cohortDate`. Schema v2 should expose:

| Field | Definition |
| --- | --- |
| `sessionDateUtc` | UTC date on which this session began; used for key partitioning |
| `firstPlayDateUtc` | Player's first genuine production-play UTC date |
| `firstSession` | Whether this is the first profile session |
| `sessionNumber` | Durable ordinal from the player profile |
| `sessionId` | Server-generated unique ID for deduplication and retries |

Historical schema-v1 exports must interpret `cohortDate` as `sessionDateUtc`. Never use it as an
acquisition cohort without deriving the player's first play.

### 3. Capture acquisition attribution

For paid campaigns, use an allowlisted campaign ID in Ads Manager advanced join launch data. Read it
server-side with `Player:GetJoinData()`, sanitize it, and attach it to the session envelope:

```text
HNH-BETA-WAVE-A-20260721
HNH-BETA-WAVE-B-20260728
HNH-BETA-WAVE-C-20260804
```

Launch data is visible and shareable, so it is supporting attribution rather than proof of ad
delivery. Ads Manager remains authoritative for spend, impressions, clicks, attributed plays, and
cost per play. Also record:

- `trafficClass`: `paid`, `organic`, `invited_test`, `internal`, or `unknown`
- `campaignId`: allowlisted ID or `none`
- `privateServer`: already present
- `isInternalTester`: server-owned allowlist, never a client claim

Do not segment the first small campaign into separate device campaigns. Use Roblox's platform
dimension and the raw client-context event; fragmenting five ad credits would make every slice less
useful.

### 4. Add export trust checks

The daily export must fail visibly or mark the dataset incomplete when it finds:

- duplicate `(userId, sessionNumber, sequence)` events;
- gaps or reversals in event sequence;
- a session start without any written chunk;
- missing build, schema, campaign, or traffic classification;
- conflicting build identities within one session;
- impossible timestamps or negative durations;
- first-session players with conflicting first-play dates;
- unknown event/schema versions;
- malformed client context;
- aggregate totals that cannot be reconciled to raw rows within documented tolerances.

`session_ended` will be missing for some crashes or hard shutdowns. Report that missingness; do not
silently drop those sessions from all analyses. Duration analyses may use completed sessions, while
completion coverage remains a guardrail.

### 5. Rehearse both data paths in production

Roblox funnel events are emitted only from servers in published experiences, not Studio. The
rehearsal therefore requires genuine published sessions:

1. Publish the intended build from Studio to the authored-map place.
2. Restart outdated servers so no test session lands on a mixed build.
3. Join with at least three clean test accounts covering touch and desktop.
4. Have one account exit at an early tutorial step, one complete the tutorial, and one complete the
   first quest/area path.
5. Export `RetentionEvents_v1` and verify exact event order, build, campaign, platform, exit step,
   session duration, and progression snapshots.
6. Verify the native onboarding funnel and custom events in Creator Hub after processing.
7. Verify a read-only Analytics Query API key can retrieve aggregate experience metrics.
8. Delete or classify the rehearsal accounts as `internal` so they never enter stranger results.

## Measurement model

### Canonical populations

| Population | Exact rule |
| --- | --- |
| Stranger new player | First genuine production session, not internal/private/invited, acquired during the wave window |
| First-session cohort | Stranger new players with `sessionNumber = 1` |
| Completed session | A session with a recorded `session_ended` event |
| Mature D1 cohort | A Roblox new-player cohort whose D1 observation window has closed |
| Build cohort | Stranger sessions whose server-stamped `buildCommit` is identical |
| Campaign cohort | Stranger sessions linked to one allowlisted campaign, reconciled to Ads Manager |
| Activated new player | Tutorial complete and `fs_boost` first quest complete in the first session |

Filter order matters: environment and build validity first, acquisition classification second, then
platform/locale/gameplay segments.

### Primary KPIs

Use only three launch-level outcomes:

| KPI | Definition | Source | Decision |
| --- | --- | --- | --- |
| D1 retention | Roblox's percentage of new users returning on D1 | Creator Hub / Analytics Query API | Whether the experience creates a reason to return |
| First-session activation | New strangers completing tutorial **and** `fs_boost` in session 1 / eligible new strangers | Raw event store | Whether strangers reach the first complete game loop |
| First-session tutorial completion | New strangers completing the final tutorial objective in session 1 / eligible new strangers | Raw + native funnel | Whether onboarding is traversable |

Roblox D1 is the canonical platform retention measure. If raw data is used to calculate a rolling
return measure, name it explicitly (for example, `R24–48`) and do not label it D1.

### Diagnostic drivers

These explain movement in the primary KPIs:

- tutorial reach, previous-step conversion, and exit count for every objective;
- median, p25, p75, and p90 seconds to each tutorial step;
- first quest (`fs_boost`) and First Steps (`fs_cave`) completion;
- first area unlock rate and time;
- earned and claimed level at first-session exit;
- median and distribution of first-session duration;
- hatch, deploy, first crystal, first enemy, potion, Rally, bind, and Resonance success/failure;
- mobile/touch versus desktop conversion and time-to-step;
- viewport/orientation group where sample size permits;
- error/failure events immediately preceding exit;
- event sequences in the last 30, 60, and 120 seconds before abandonment;
- balance proxies: combat start-to-win time, pet downs, retries, quest/mission start-to-complete,
  and exit before the next level or objective.

The raw bus already observes completions and many semantic actions. Add explicit
`quest_started`, `mission_started`, `mission_failed_or_abandoned`, and meaningful
`area_unlock_failed`/`hatch_failed` events before using attempt-to-completion rates. Absence of a
completion event is not automatically evidence that an attempt occurred.

### Guardrails

| Guardrail | Provisional stop/hold rule |
| --- | --- |
| Save integrity | Any confirmed durable data loss, duplication, purchase loss, or reward exploit: stop immediately |
| Join/data load | Repeated load blocker or >1% confirmed load failure once denominator is reliable: stop |
| Crash/runtime quality | Reproducible crash or error that blocks onboarding on a supported device: stop |
| Telemetry coverage | <90% of observed production sessions have a valid raw start/chunk/build envelope: stop spend |
| Completed-session coverage | <85% without a known server-shutdown explanation: hold interpretation |
| Funnel integrity | Skipped, duplicated, renamed, or out-of-order production steps: stop and version the funnel |
| Platform disparity | ≥20 percentage-point activation gap with at least 20 users per platform: investigate before scale |
| Economy integrity | Negative balances, mismatched ending balances, or purchase/reward disagreement: stop |

These are operational tripwires, not claims about healthy long-run product benchmarks.

## Statistical interpretation

This beta budget is designed to find large failures, not estimate small uplifts.

- Always report numerator, denominator, point estimate, and a 95% Wilson interval for a rate.
- For `n < 30`, treat rates as anecdotes with structure. Use session traces and reproduction.
- For `30 ≤ n < 100`, screen for catastrophic drop-offs and large platform differences.
- For `n ≥ 100`, rate comparisons become more informative, but interval width still governs.
- Report medians and quantiles for skewed timing/session measures; do not rely on averages alone.
- Do not declare a build improvement because its point estimate is higher.
- A sequential build cohort comparison is descriptive, not randomized causal evidence.
- Compare Wave A and B on the same weekday, time, campaign goal, audience, creative, and targeting.
- If enough organic traffic later exists, prefer a server-assigned experiment with sticky
  assignment and a prespecified analysis over sequential before/after comparison.

The first clean wave establishes the baseline. A provisional yellow signal is:

- tutorial step conversion below 70%;
- first-session tutorial completion below 50%;
- first-session activation below 30%;
- median time to one step more than twice its preceding comparable step;
- an exit spike at one objective materially larger than neighboring objectives.

These thresholds prioritize investigation only. They are not ship targets and must not be optimized
without examining downstream retention and sample uncertainty.

## The 5,000-Robux learning budget

Current Roblox Ads Manager converts Robux to ad credits at 263 Robux per credit. Conversion is
irreversible. Therefore 5,000 Robux buys 19 credits for 4,997 Robux, leaving 3 Robux.

Convert only the credits approved for the next wave:

| Wave | Ad credits | Robux | Purpose |
| --- | ---: | ---: | --- |
| A | 5 | 1,315 | Establish a clean stranger baseline and find the largest blocker |
| B | 5 | 1,315 | Validate one deliberate fix under comparable weekday conditions |
| C | 9 | 2,367 | Scale only after B is stable and directionally acceptable |
| Total | 19 | 4,997 | Preserve 3 Robux; do not pre-convert the reserve |

Campaign setup for all waves:

- Objective: `Plays`.
- Audience: `New Players`.
- Device targeting: all supported devices.
- Geography/language: one stable choice across A and B; start with the intended English-speaking
  launch market rather than mixing localization tests into onboarding diagnosis.
- Creative: one approved 16:9 thumbnail for A and B. Multiple creatives would split a tiny sample.
- Budget: lifetime budget for a fixed wave window.
- Launch data: the allowlisted wave campaign ID.
- No ad-only gameplay reward in the baseline waves.

Ads Manager can take up to 24 hours to moderate a campaign, its first 24 active hours are a learning
period, and post-click reporting can lag up to 48 hours. Create/schedule campaigns early and never
use Ads Manager's same-day post-click totals as the only denominator.

## Concrete release calendar

All operating times below are Mountain Daylight Time (MDT, UTC−6). Analytics partitions remain UTC.

### Sunday, July 19 — freeze definitions

- Approve this provisional plan.
- Freeze onboarding funnel v1 step names and meanings.
- Freeze semantic event names needed for Wave A.
- Implement the schema-v2 attribution blockers.
- Confirm analytics owner, release owner, and rollback operator.
- Prepare one honest 16:9 ad creative and exact experience metadata.
- Do not advertise.

### Monday, July 20 — publish and rehearse

**08:30–10:00**

- Merge only release-approved changes to `main`.
- Run CI, headless tests, Rojo build, and focused Studio smoke.
- Stamp the immutable build.
- Publish through Studio to the authored-map production place. Do not use a Rojo upload that would
  replace the authored Workspace.
- Restart outdated servers so every production session runs the same build.

**10:00–13:00**

- Run the three-account published-server instrumentation rehearsal.
- Execute the read-only raw export and data-quality checks.
- Verify native analytics ingestion has begun.
- Verify mobile rotation, tutorial hotbar grants, pet inventory reconciliation, Rally, Resonance,
  potion use, crystal bars, quest completion, and first-area unlock on the published build.
- Rehearse republishing the previous known-good build without actually rolling back.

**By 10:00**

- Submit/schedule Wave A for moderation, targeting Tuesday at 10:00.
- Convert only five ad credits.

**15:00 go/no-go**

- If any launch blocker remains, cancel or reschedule before the six-hour cancellation boundary.
- No “we will watch it live” exceptions for save, purchase, join, telemetry, or tutorial blockers.

### Tuesday, July 21 — Wave A begins

**09:00**

- Verify campaign approval, production build/commit, server population, error logs, DataStore health,
  API-key access, and empty/known baseline export.
- Record a release manifest: build, commit, schema, campaign ID, creative, audience, budget, start,
  and operator.

**10:00**

- Start Wave A with five ad credits and a fixed lifetime window through Wednesday 18:00.

**10:00–18:00**

- Monitor operational guardrails hourly.
- Export raw data at 12:00, 15:00, and 18:00.
- Do not tune balance or onboarding based on the first few players.
- Stop only for a red guardrail; if stopped or hotfixed, mark the cohort contaminated at the exact
  timestamp/build boundary.

### Wednesday, July 22 — diagnose without changing the build

- Let Wave A continue.
- Produce the first complete funnel, device cut, exit-step table, timing quantiles, and last-event
  paths.
- Reproduce the single largest observed failure in Studio and then in a published private test.
- Select at most one candidate intervention.
- Do not publish a normal gameplay change while the acquisition window is open.

### Thursday, July 23 — observe D1 and close Wave A

- Confirm the fixed campaign window closed Wednesday at 18:00.
- Review mature D1 only for Tuesday entrants whose observation window has closed; Wednesday
  entrants mature later and must not be pulled into the early estimate.
- Reconcile Ads Manager plays against campaign-classified raw first sessions.
- Write the Wave A readout with sample sizes and uncertainty.
- Decision:
  - red: hold all remaining spend and fix;
  - yellow: fix one dominant issue, keep reserve;
  - green: still run one controlled improvement/confirmation wave before scaling.

### Friday, July 24 — decision and implementation, not a launch

- Freeze the Wave A dataset and analysis notebook/query.
- Write one hypothesis, intended metric, guardrails, and expected mechanism.
- Implement the smallest change that tests it.
- Do not start Wave B on Friday: weekend audience composition would confound the A/B comparison, and
  a Friday launch shortens the staffed correction window.

### Saturday–Sunday, July 25–26 — soak

- Test the candidate build with internal/invited accounts.
- Complete mobile/tablet/desktop regression and accessibility checks.
- No paid traffic and no unrelated feature work in the release branch.

### Monday, July 27 — publish candidate B

- Complete the same publish, restart, three-account rehearsal, export, and rollback checks.
- Submit/schedule Wave B for Tuesday 10:00; convert only five additional ad credits.
- Lock the campaign goal, audience, geography, device targeting, time, and creative to Wave A.

### Tuesday–Wednesday, July 28–29 — Wave B

- Run five ad credits on the same window as Wave A.
- Keep one build for the whole wave.
- Monitor the intended metric and all guardrails.
- Treat the comparison as descriptive unless a randomized experiment was used.

### Thursday–Friday, July 30–31 — compare and decide

- Compare A versus B for the same population and mature windows.
- Publish the full denominators, Wilson intervals, timing distributions, and platform cuts.
- If B is stable and directionally acceptable, approve Wave C.
- If B is mixed or data is incomplete, retain all nine credits and run another five-credit wave
  only after a new hypothesis and comparable Tuesday window.

### Tuesday, August 4 — Wave C scale gate

Run the remaining nine credits only if:

- no red operational guardrail is open;
- schema/build/campaign attribution is complete;
- published-server raw and native analytics reconcile;
- no supported-device onboarding blocker remains;
- Wave B did not materially damage activation or D1;
- the release owner signs the manifest and rollback plan.

If those conditions are not met, August 4 becomes another hold/fix/rehearsal day. The date never
overrides the gate.

## Release and rollback procedure

### Normal release

1. Create a release commit on `main`; no dirty Studio sync.
2. Run the repository gate and targeted live smoke.
3. Stamp version, commit, branch, build time, and analytics schema.
4. Sync Rojo into the correct authored-map Studio place.
5. Publish from Studio.
6. Restart outdated servers before admitting a paid cohort.
7. Confirm the running build from the in-game build display and raw session envelope.
8. Run the three-account production rehearsal.
9. Record the release manifest and approve campaign start.

Roblox does not immediately move existing players to a new published server version. Restarting
outdated servers is required for a clean paid build cohort. For a non-critical future update, a
non-disruptive drain may be preferable, but not during these small controlled waves.

### Rollback

Rollback triggers include data corruption, purchases/rewards failing, join failure, a universal
onboarding blocker, or telemetry that cannot identify the running build.

1. Stop/cancel paid acquisition where possible.
2. Record the incident timestamp, build, server jobs, and campaign state.
3. Republish the last known-good production version.
4. Restart outdated servers.
5. Verify player data compatibility and run the minimum production smoke.
6. Mark all sessions during the mixed/failed interval as contaminated.
7. Do not reuse that traffic in clean build comparisons.
8. Complete an incident note before resuming spend.

## Daily analytics runbook

### Same-day operational readout

Run after each export:

1. Data completeness: chunks, sessions, sequence gaps, duplicates, build/campaign missingness.
2. Join health: starts, loaded profiles, load/save errors, crashes.
3. Tutorial funnel: reached, conversion, exits, time-to-step.
4. Activation: tutorial + `fs_boost` in session 1.
5. Progression: first area, exit levels, quest/mission attempts and completions.
6. Segments: touch/desktop first, then locale/viewport only if denominators support them.
7. Session paths: last meaningful events before exit.
8. Economy integrity: currency source/sink ending-balance reconciliation when those events land.

### D1+ readout

- Creator Hub D1 retention and Analytics Query API export.
- Raw `R24–48` supplemental return metric, clearly named.
- D1 by build, campaign, and platform where supported.
- Activated versus non-activated return rate, reported as association only.
- First-session behaviors associated with return, with no causal claim.

### Required daily record

```text
Wave:
Snapshot time (UTC):
Build version / commit:
Analytics schema:
Campaign / creative / audience:
Spend and ad credits:

Raw sessions / new strangers:
Data completeness exceptions:
Supported platform counts:

Tutorial completion: numerator / denominator / Wilson interval
Activation: numerator / denominator / Wilson interval
First quest, First Steps, first area:
Median first-session duration [p25, p75, p90]:
Largest tutorial drop:
Most common exit level:

Roblox D1 (mature cohorts only):
Raw R24–48 (if mature):

Errors, crashes, load/save failures:
Economy integrity exceptions:
Top reproduced blocker:

Decision: stop / hold / continue / scale
Hypothesis for next change:
Metric intended to move:
Guardrails:
Owner and deadline:
```

## Data access and storage

### Operational views

- Creator Hub Analytics: retention, engagement, acquisition, funnels, custom events, platform cuts,
  and eventual benchmark scorecards.
- Ads Manager: spend, impressions, clicks, attributed plays, cost per play, learning state, and
  campaign attribution.
- Creator Hub monitoring: errors, crashes, performance, and DataStore health.

### Reproducible analysis

- `RetentionEvents_v1`: complete bounded server-observed trace and aggregate shards.
- `tools/export_retention.py`: read-only JSONL/CSV export for notebooks and SQL.
- Roblox Analytics Query API: automated aggregate retention/acquisition metric retrieval.
- Release manifest: immutable mapping of build, campaign, dates, targeting, and changes.

Creator Hub Data Stores Manager is adequate for spot inspection, not as the analytical workflow.
Export the raw store into a local/controlled analytical environment and retain the exact extraction
manifest with every readout.

### Access control and retention

- Use separate read-only Open Cloud keys for raw DataStore and analytics-query access.
- Keep keys in the environment or a secret manager, never the repository, Studio, or client.
- Restrict raw user-level exports to admins doing analysis/support.
- Do not export usernames, chat, free-form personal text, device identifiers, or payment details.
- Treat Roblox user IDs and detailed session paths as restricted data.
- Keep raw beta events for a provisional 90 days, then delete or pseudonymize user-level exports
  after the analysis window; retain aggregate summaries and release decisions.
- Document any longer retention need before the public launch.

## Hypothesis and change discipline

Every non-emergency change between waves gets a one-page record:

```text
Observed problem:
Evidence and denominators:
Alternative explanations:
Hypothesis:
Single intended change:
Primary metric:
Expected direction and minimum practically meaningful change:
Guardrails:
Population:
Build / schema / campaign:
Analysis window:
Decision rule:
```

Do not bundle tutorial copy, combat balance, rewards, UI layout, and performance changes into one
comparison. If an emergency forces multiple changes, describe the next cohort as a new baseline, not
proof of one mechanism.

## Known limitations and robustness checks

- The 19-credit budget may yield too few strangers for a precise D1 estimate.
- Ads Manager post-click reporting can lag up to 48 hours.
- Creator Hub analytics can require processing time and some benchmark/performance views need at
  least 100 DAU or prior enrollment.
- Advanced join launch data can be copied or shared; reconcile it with Ads Manager.
- Session-end events are not guaranteed on every crash/disconnect.
- Client environment context is useful for segmentation but not authoritative gameplay evidence.
- Sequential waves can differ because of day, campaign learning, auction conditions, or audience
  composition. Matching weekday/time/targeting reduces but does not remove confounding.
- Existing schema-v1 `cohortDate` is not a first-play cohort.
- Funnel step meanings must remain stable. If they change, create a new funnel/schema version.

Robustness checks:

- raw versus native funnel counts;
- Ads Manager attributed plays versus raw campaign-classified first sessions;
- completed-session-only versus all-started-session denominators;
- desktop/touch stratified and pooled results;
- exclusion/inclusion of unknown campaign traffic;
- result with internal/private sessions removed;
- build-exact versus calendar-window cohorts;
- point estimate plus interval, never point estimate alone.

## Owners and sign-off

One person can hold multiple roles, but each role must be explicitly assigned:

| Role | Responsibility |
| --- | --- |
| Release owner | Final go/no-go, release manifest, campaign start/stop |
| Engineering owner | Build, instrumentation, tests, production smoke, rollback |
| Analytics owner | Exports, QA, metric definitions, daily readout, cohort freeze |
| Incident owner | Stops spend, captures timeline, coordinates rollback |
| Product owner | Chooses the one problem/hypothesis for the next wave |

Wave approval requires release, engineering, and analytics sign-off—even if Jason is all three.

## Further questions to resolve before Wave A

1. Which exact geography/language audience should remain fixed across Waves A and B?
2. Which one ad creative is the honest baseline?
3. Who has group analytics, Ads Manager, DataStore Manager, and server-management permissions?
4. What is the last known-good production version for rollback?
5. Are Robux purchases/developer products enabled during beta, and what purchase audit is required?
6. Is 90-day raw retention sufficient for the planned analysis?
7. Which accounts are classified as internal/invited so they are excluded automatically?

## External platform references

- [Roblox Analytics overview](https://create.roblox.com/docs/production/analytics)
- [Roblox funnel events](https://create.roblox.com/docs/production/analytics/funnel-events)
- [Roblox retention](https://create.roblox.com/docs/production/analytics/retention)
- [Roblox acquisition](https://create.roblox.com/docs/production/analytics/acquisition)
- [Roblox Analytics Query API](https://create.roblox.com/docs/cloud/guides/analytics)
- [Roblox Ads Manager](https://create.roblox.com/docs/production/promotion/ads-manager)
- [Roblox Open Cloud Data Stores](https://create.roblox.com/docs/cloud/guides/data-stores)
- [Roblox DataStore limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits)
- [Roblox release updates and server restart behavior](https://create.roblox.com/docs/projects/update-experiences)
