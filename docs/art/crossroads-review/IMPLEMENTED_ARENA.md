# Arena craftsmanship — source delivery

2026-09-08. This is a bounded first construction pass. Source is ready; the lead owns application to the same Studio preview, sightline measurement, screenshots, save and native acceptance. No Studio tools were called by this section agent.

## Apply contract

Read `configs/realm_crossroads_polish_arena.json`, evaluate `tools/realm_crossroads/polish_arena.luau`, and call its returned `function(world,cfg)` with `workspace.RealmCrossroadsR4`. Run in Edit only after the existing R9 stands/R10 ponds and current fishing polish. Never rebuild older leisure/activities over the current preview. No dependency on fishing internals: the sole shared dimensional contract is **all rear façade geometry X≤199**, preserving the newly recovered nominal strip X199–211 behind Hell station5.

The output is `world.ArenaPolishR11`. Each rerun replaces only that group and recreates from original pieces retained in `ServerStorage.CrossroadsArenaPolishBackup`. This folder contains ChairVisuals, Steps, RearTiers, Rails and RuinMasonry. Original pieces are moved, not destroyed, with `ArenaPolishOriginalParent` path attributes. Original Seat colors/materials and native banner pivots are stored as attributes before modification. Restoration requires removing ArenaPolishR11, returning archived parts to recorded parent groups, restoring Seat material/color and banner pivot; there is no blind all-map restore operation.

## Authored changes

- **32 chairs:** Original native Seat objects, CFrames, sizes, Disabled/Occupant state and podium-slot attributes stay intact. Seat material becomes the leather-like Fabric pad, eliminating a separate coplanar cushion. New charcoal frames, four floor-reaching legs, crossbars, inset back cushion, bronze armrests and small fasteners surround it. Old generic ChairBack/ChairLeg/ArmRest visuals are archived. Shell decoration is noncolliding; original sitting behavior remains native. No dummy or Humanoid edits.
- **Central stair:** Every archived AisleStep is rebuilt as two disjoint volumes: original-depth-minus-0.3 body and 0.3-stud contrasting front nosing. Their summed footprint equals the original exactly, and tops remain at original heights. This is replacement, not an added slab/paint plane. All eight studs of aisle width remain.
- **Rear façade:** Original two Tier4 blocks are replaced within their existing volumes: a structural core, flush footing/cap, engaged piers and eight recessed masonry bays with actual joints. Everything ends at or inside X199. Four small existing native animal_skull ornaments fit inside the recessed depth when cache available; no external asset load. Tier heights and chair positions remain unchanged. The central stair still occupies the central eight-stud bay.
- **Rails:** Existing end/rear guard pieces are archived and replaced with paired top/mid rails and stronger posts. Rear parts end before X199. Rails retain physical collision; chair decoration does not. No new canopy, standards or protruding buttresses.
- **Encounter pavilion:** Existing RuinPier/RuinCap/RearRuinWall masonry is archived, replaced by course-built piers, larger low feet/capitals and eight rear wall bays. Native Heaven/Hell banners and existing text/anchor remain. Two raised stone banner bases begin at existing floor Y4.6; the existing banner models are lifted by base height 0.45 from saved original pivots, idempotently, so their feet remain supported. No coincident floor overlay, new portal, lintel over the approach or new organic hero.
- **Inert integration anchors:** Battle(120,5,8), Alliance(120,5,79), Stand(157,5,8) are transparent, noncolliding Parts each holding a same-named Attachment and `IntendedBinding` text with `GameplayConnected=false`. No prompts, scripts, live tags or outcome logic.

Arena floor **64×102**, both **14-stud** gateway spans, native Impaler bulwarks and their transforms, cover blocks, patrol/encounter/bounds markers, current row heights, **24 static dummies**, **eight available seats**, fishing art/water/mist and island barriers are untouched.

## Validation / lead checks

StyLua formatting and Selene pass with zero errors/warnings; JSON parses. No native screenshot or seat test has been claimed. Return report should show **seats=32**, **enabledSeats=8**, **steps=16**, **facadeBays=8**. Ornaments may be zero if the existing `CrossroadsActivityAssets.animal_skull` Model is unavailable. That is a reuse omission, not permission to generate a primitive substitute.

Apply twice and compare all Seat CFrames and Disabled values, unchanged 24 dummies, no duplicate shell count, two tier-core groups, stable banner pivots and absence of repeated upward lift. Inspect eight visitor seats with actual sitting/egress; new arms are slightly outside the seat cushion while retaining the original bay. Root should measure seated eye rays before any later row-height alteration: this pass intentionally does not solve unmeasured visibility by raising stands.

Walk the central stairs both ways at 24; inspect low-angle tread/body joins and any original tier-to-stair discontinuity. Inspect rear façade from Hell station 5, confirm actual max X≤199 and measure 12 studs to the corrected deck. Inspect native skull visibility: they are uniformly fit to shallow recesses, so quality may favor omission over a miniature relief. End rails may require a local visual join correction after eye review; no clearance assumption substitutes for this check. Compare pavilion banner grounding and native text visibility before/after.

## Section06 twenty-item coverage

| # | Design item | Status in this pass |
| --- | --- | --- |
|01|Seat sightlines/raised tiers|Deferred measurement; original heights explicitly preserved|
|02|Spectator promenade|Deferred; no added floor in shared pond passage|
|03|Alternate access ramp|Deferred until heights/routes settled|
|04|Central stair clarity|Built-source disjoint contrasting nosing replacements|
|05|Rear retaining façade|Built-source inside original X≤199 envelope|
|06|Crafted chair kit|Built-source around all 32 native Seats|
|07|Audience posing/tints|Preserved 24 existing dummies; no reposing|
|08|Physical row/seat markers|Deferred; native seating metadata preserved|
|09|Arena floor identity|Deferred; current floor/bounds preserved|
|10|Bulwark receivers|Deferred; all native bulwarks untouched|
|11|Broken monument cover|Deferred; cover unchanged|
|12|Marshal pavilion|Partial: masonry/support finish and native banner bases; no new lintel/hero|
|13|Southern social room|Deferred; Alliance anchor only|
|14|Stand skyline standards|Deferred pending sightlines|
|15|Integrated ironwork rails|Built-source end/rear rails and grounded posts|
|16|Landscape planting at architecture|Deferred; no new planting in constrained circulation|
|17|Forge warmth at anchors|Deferred; no new lights or emitters|
|18|Celebration FX|Deferred; no match outcomes invented|
|19|Pool transition|Partial: hard X199 protection, no additional route dressing|
|20|Champion story relief|Partial: native ornament only; actual pet/egg story relief still needs asset workflow|

The broader artwork proposals remain options, not a declaration that 20 design tasks are finished. Missing organic reliefs/hero ornaments should follow ImageGen → Meshy → Blender → Assets → Roblox after their spatial envelope is accepted. Precise masonry/chair geometry is authored directly here; no generated asset or upload occurred.

## Future integration

Use Battle as an art reference for a validated bounded encounter, Alliance as an outside-combat opt-in reference, and Stand as an arrival hint; none is an active service tag. Existing native Seat behavior already handles visitors. Real podium-member audience loading needs bounded avatar caching, approved leaderboard source/rules and no false ranking claims. Combatant-only confinement, patrol recruitment/chase bounds, alliance opt-in, arena start/finish authority and FX acknowledgements require existing gameplay-service integration. The wider island barrier must remain a separate system. Never make scenic bulwarks universally collidable as a shortcut.
