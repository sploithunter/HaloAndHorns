# Occupied fishing layout QA

2026-09-08. **Ten Heaven and eight Hell static angler proxies fit their stations without measured figure/rod overlap; both rear-bank loops remained navigable.** This is occupied-layout geometry evidence, not 18-player multiplayer acceptance.

## Native construction and measurements

In existing Client Play only, cloned existing `BraggRotundaR6.PodiumHeightDummies.Alcove01_Rank1` eighteen times, preserving native appearance. Uniformly scaled each from its measured 5.183 height to 5.5 studs. Removed only cloned Humanoid/scripts; anchored noncolliding/nontouch/nonquery parts. Original source and audience models were never edited. Aligned each clone's root facing to its original deck/Standing frame and grounded its bounding bottom to deck topY 4.5.

[Proxy inventory](occupied-fishing-qa/proxies.json) records all 18: bottomsY 4.5, topsapproximately 10, standardized local body envelope approximately 4.246 wide×5.5 high×1.232 deep. These use the same native preview body, not a sample of all catalog avatars/accessories. Native figures visibly stand on the dock surfaces in the captured views.

[Visible-part envelope audit](occupied-fishing-qa/envelopes.json) excludes fully transparent parts, transforms each visible mesh/part's eight bounding corners into its own deck frame, and compares conservative bounds. All 18 figure footprints lie inside the 10×12 deck. Typical figure localX±2.123, Z−1.616…−0.384; existing displayed rod localX−4.382…−3.739, Z2.033…4.161. Thus body/rod bounding volumes are disjoint on every station, with roughly 1.616 stud X separation between these conservative bounds. The 18 visible figure world bounds have zero pair overlaps. This proves separation for the fixed display pose/rod rest, not a casting animation sweep or hand-held Tool grip.

## Six native views

| Pond | Entrance | Overhead from north | Overhead from south |
| --- | --- | --- | --- |
| Heaven | [Entrance](occupied-fishing-qa/heaven-entrance.jpg) | [North](occupied-fishing-qa/heaven-overhead-north.jpg) | [South](occupied-fishing-qa/heaven-overhead-south.jpg) |
| Hell | [Entrance](occupied-fishing-qa/hell-entrance.jpg) | [North](occupied-fishing-qa/hell-overhead-north.jpg) | [South](occupied-fishing-qa/hell-overhead-south.jpg) |

All figures rendered natively. Each occupied station retains visible free deck area and separates from its neighbors; neither pond looks crowded at this standard-body occupancy. The rear bank remains distinct from occupied Standing positions. Heaven's larger water area reads more spacious, while Hell has tighter but still clearly separated docks. Existing shelter/trees, bank planting and stand façade remain. Particle/mist appearance in these captures is not a quality acceptance check.

## Rear-bank navigation while occupied

[18 native navigation edges and actual endpoints](occupied-fishing-qa/bank-navigation.json): one documented reset per pond at its initial back point+4Y, then all consecutive back points and closure, using WalkSpeed 24 and multiplier 1. Heaven 1→2…10→1; Hell 5→6→7→8→1→2→3→4→5. No occupied Standing position was requested or traversed as a route waypoint. All 18 calls returnedSuccess; all sampled endpoints wereRunning. Hell eastern-bank rootY 8.291 follows its existing grade; other typical dry-bank rootY 7.406. Proxies remained present throughout both loops.

Because proxies were deliberately noncolliding and client-local, this demonstrates geometric clearance/composition and navigation around the occupied footprints, not crowd pushing, server ownership, eighteen Humanoids, physics load, streaming cost or simultaneous fishing sessions. Endpoint states do not continuously trace intermediate pathfinding actions. No live reservation/casting/catch/economy logic was invoked.

## Cleanup and recommendation

Destroyed `OccupiedFishingQA`, restored saved player pivot and camera type/subject/CFrame, and verified original 24 Bragg reference models and 24 stand audience models remained. WalkSpeed 24 retained. Native cleanup returnedremoved=true/restored=true. Control released with Play left to the lead; no further native operations after release.

Keep current pond/dock sizes for this phase. Standard 5.5-stud occupied geometry supports the intended 10+8 station count, and current bank routes remain usable. Production acceptance still needs actual concurrent clients, supported avatar/accessory envelopes, equipped rod/cast movement, shared station ownership and real device/performance tests. No terrain or map change is justified by this bounded occupied-layout check.
