# Native finishing-pass replay

2026-09-08. All 17 registered finishing passes executed twice in order in the existing editable PlaceId 0 preview, using fresh ModuleScripts to avoid require caching. No second Studio file was opened. The world, authoring/runtime stores and Terrain region were backed up before mutation.

This tests reapplication to the current authored R11 world. It is not a clean build from an empty place: original native R10 geometry and retained asset caches remain required inputs.

The [first](rebuild-qa/first-pass.json) and [second](rebuild-qa/second-pass.json) results preserve native responses. Both returned 300 fitted paving pieces, 14 Bragg bays/24 figures, 18 fishing stations/17 dry approaches, 32 spectator seats/eight enabled visitor seats, eight emblems, 18 rods/tips, two signs, 28 arena panels, 37 bulwark bindings, two FX fields, 96 pond-life path samples and 18 preview cast targets. Terrain finish reruns changed zero already-painted material cells and verified unchanged occupancy.

A geometry comparison matched 5,448 parts, with zero added/missing part instances. Names are not unique: two Coin Garden quartz models deliberately share names, so comparison must match duplicate-name groups spatially rather than overwrite them in a dictionary. Twenty-four Humanoid Status objects and four Seat TouchTransmitters recreated by Roblox account for descendant-count differences; these are not new geometry.

The replay exposed small vertical drift in retained landscape models because grounding rays started relative to the previous model height. The fishing pass now samples these roots from a fixed world-height ray at the same X/Z. Reapplying the corrected pass yielded zero retained mesh-model pivot changes above 0.001 stud. Rods, pond life and cast-preview installers were reapplied afterward because fishing recreates their authored anchors. One Hell station approach differed from the earlier checkpoint by about 0.0425 stud in center and 0.0097 stud in size; no cumulative movement was identified there.

Supplementary inputs are decoded glyph JSON for wayfinding, decoded ambient-bundle JSON for FX, and raw client source for pond life and interactions. Saving an installer/config without replaying it does not update already-installed runtime objects. The checkpoint companion validator addresses this distinction; its current results belong with the final save.

Final native visual/route smoke checks and the subsequent ramp pass are recorded separately. Foreground frame timing remains unverified while the Mac is locked.

Final save after independently applied/reapplied ramp: 18 archived installers/configs, four supplemental inputs, three runtime clients and 300 pavers pass source validation. Five negative fixtures correctly fail. Native round-trip preserves 18 rods/stations and 16 visitor Seats. Checkpoint has 17,695 instances, SHA256 `0eec7c9c25f1fa8f09ed376907b3e17ff3150ae5cb8ddbf82452e858263a725a`; temporary replay backup/export buffer removed. The new ramp was tested after its upstream arena pass, rather than claiming a third full 18-pass replay.
