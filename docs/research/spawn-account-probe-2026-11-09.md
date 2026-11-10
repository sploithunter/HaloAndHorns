# Spawn shared-account/place probe, 2026-11-09

Companion to [the architecture assessment](../wiki/SPAWN_SHARED_ACCOUNT.md).

## Provenance and scope

Unpublished preview overlay of ColoradoPlays' development v25. Runtime
`289ba86c6f19761f5e9d178636ff5633`, rolling 6.0.0. Engine docs revision
`45303e2434b43467e261cbe2a690ca9fe36faa31` contains documentation, not runtime implementation.
The open Roblox Merge streaming properties were read without edits.

Only the agent's editor account and mock `hhAccountProbe` profile were used. Artificial reward =
one bear and 17 XP, not HH game tuning. Unique test UID retains Doggy/rainbow/level 7/XP 23.
No real migration, production reward trust, non-editor security or concurrency is claimed.

## Fixture and reproduction

[Configuration](../../configs/spawn_account_probe.json) names the assets/scale.
[Fixture code and sanitized results](../../ports/spawn/research/account-probe/) preserve the trial.

1. Run `python3 ports/spawn/tools/prepare_account_probe.py /tmp/<new-probe-directory>`.
   It refuses existing destinations, copies the world and adds only isolated fixture instrumentation.
   It never pushes or publishes. Never copy the generated probe back into the production world.
2. Start the Spawn CLI native preview on that directory in a dedicated room under an agent-owned
   profile. The native body's Page.reload is disallowed by its protocol; use an ordinary browser
   for actual reload testing.
3. Obtain a one-use link for the agent's own account to that exact preview room/version using
   `POST /api/agent/v1/login-link` with the `next` path. Save returned JSON privately (0600), outside
   the checkout; never print its URL or use a creator/player session. The runner deletes this input.
4. Run `PLAYWRIGHT_MODULE=<module> CHROME_EXECUTABLE=<optional Chrome executable> node
   ports/spawn/research/account-probe/verify-browser.mjs <private-login.json> <new-output-directory>`.
   The recorded trial used system Chrome headless, Metal/WebGPU, 1440×1000.
5. Key 1 enters `farm_probe`, 2 main, 3 the solo ephemeral variant, 4 the mock reward. A platform
   behavior checks event actor identity, records a test receipt and calls the actual portable
   inventory core to equip one unique plus two common copies. This is not the real hatch pipeline.
6. Compare the whole profile after duplicate reward, travel, actual HTTP-cache-cleared/disabled
   reload, repeat travel and a solo-instance visit. Wait 15 seconds after return to sample cleanup.
   Screenshots force rendering before metrics. The runner writes assertions, screenshots and evidence.

The synthetic second place has 12 distinct real egg GLBs and 384 boxes. A same-place model and
ordinary/platform clocks sit 4096 metres away in cell `x32z0`. The native trial also moved there
and back to inspect clock locality. The ordinary-browser trial used normal declared inputs.
The generator reconstructs the scenario, with small irrelevant box/clock-row differences; it is
not a full Farm & Fight map or a performance-equivalent map conversion.

## Assertions and observations

Final runner result:
`PASS normal browser durable mutation, UID/equip, duplicate receipt, cold reload, places/instance`.

Before: quantity 3, XP 731, common+unique equipped. After: quantity 4, XP 748, unique+two common
copies equipped and `normal_browser_reward=true`. Complete changed profile and UID details survived.
This distinguishes actual saving from reseeding the same initial fixture on every entry.

| Stage | Draw calls | Triangles, including passes | Engine GPU MB | FPS |
| --- | ---: | ---: | ---: | ---: |
| Main return before reload | 29 | 476488 | 217 | 60 |
| Main after HTTP-cache-cleared reload | 37 | 492103 | 187 | 59 |
| Other place after reload | 11 | 105140 | 148 | 59 |
| Main after subsequent return | 31 | 466283 | 215 | 60 |
| Solo ephemeral place | 11 | 105140 | 155 | 60 |
| Main after instance cleanup wait | 31 | 463929 | 213 | 60 |

Local samples, not an engine/mobile benchmark. Earlier ordinary-browser results varied (main
~186–225 MB, other place ~149–161 MB). Native 640×360 results are not mixed into this table.
The engine GPU counter does not establish whole-process memory or complete GLB/texture eviction.

Request phases are captured at request start, not finish. Sanitized records retain host/type,
content type, numeric sizes and public asset IDs; auth/login/session/token paths and URL queries
are omitted. Main cold reload resolved the far same-place egg but none of the 12 other-place eggs;
the next travel resolved all 12. Metadata lookup is not proof of full binary transfer or decoded
residency. Aggregate bytes include engine/application traffic, not just scene downloads. HTTP-cache
clearing does not guarantee cleared GPU/driver, service-worker or origin-storage caches.

The dynamic ephemeral instance ID remained on immediate return, then disappeared by the later
wait sample. This establishes observed eventual cleanup, not synchronous disposal or load timing.

Native clocks: far ordinary clock held at 571, advanced to 590 on approach, then held at 593 after
return. Main/far platform clocks advanced while the body was in the other place, and that place's
platform clock advanced after returning. Explicitly stop/reset inactive game simulation. Cross-place
clock reads were removed from the final ordinary-browser HUD to avoid affecting lazy loads.

## Limits and next measurements

No cross-world conflict experiment, ordinary-player attack, concurrent award/equip, crash rollback,
full-map textures, player load, live-view portal, mobile or sustained travel test. Authoring cells,
behavior locality, terrain LOD, rendering and imported-model eviction are separate concerns.

No production Full mode, starter/personal hatch, permanent inventory UI or shared account provider
was shipped. The actual core was exercised inside this fixture but remains unbound in production.
Keep deployment open. Test a representative Farm & Fight region, region-level assets, repeated
travel/residency and inactive simulation. Separate worlds need a trusted central transaction/reward
path before portal-carried state can be treated as a shared inventory.
