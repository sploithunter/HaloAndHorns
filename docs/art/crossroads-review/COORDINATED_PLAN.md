# Coordinated implementation plan

This is the lead review of eight section proposals. The proposals are options to prioritize,
not 160 independent instructions to implement indiscriminately. The map already has its
important destinations and an approved personality. The next pass should make its construction,
foreground composition and social spaces match the quality of its best existing assets.

## What to preserve

Keep the Heaven and Hell gate silhouettes, sculpted mode titles, correct face orientation,
Confluence fountain and animated fluid tops, repaired branch junctions, native bulwarks,
32 spectator Seats, the ten-angler Heaven pond, real Terrain water and Hell green mist.
Retain 24-stud/sec movement and current functional footprints. Additional land expansion is
not a default solution. The proposal names in the individual documents are internal art
working titles; they do not replace Farm & Fight, Pet Siege or the current ranking names.

## The main design decision

Use one construction language with two material families. Heaven gets pale worked stone,
aged gold, flowers and luminous quartz; Hell gets charcoal worked stone, oxidized metal,
bone and ember planting. Both use the same rules for paver scale, believable supports,
finished rear faces, retaining-wall modules and route edges. Neutral arrival and Bragg
bring those families together. Ornament differs; engineering and craft remain consistent.

The agents repeatedly identified a gap between detailed hero assets and plain surrounding
slabs. Filling that gap has more value than replacing the gates or adding a second hero to
every camera. Each scene should have a foreground frame, a usable middle ground and a
clear destination. Tree rows alone do not supply all three.

## Shared interfaces to resolve before asset production

| Interface | Existing evidence | Required decision and owner pairing |
|---|---|---|
| Arrival → Bragg | Central strip ends at Z6; entry stairs/ramps require one deliberate connection | Arrival + Bragg draw one continuous boundary/height plan, then walk it before decoration |
| Arrival → each gate | Corrected branches and shared surface heights are user-approved | Arrival owns common stone module; gate agents own local fan pattern; one polygon owns each face |
| Gate rear → Bragg-facing routes | Both heraldic backs and information panels look unfinished | Shared crest-back mounting specification; different relief artwork without increasing silhouette |
| Coin Garden → Heaven pond | West promenade meets eastmost angler platform | Garden + fishing share an actual 12-stud circulation envelope; no lawn or platform capacity loss by assumption |
| Stands → Hell pool | Stand rear near X199 and water shore near X216; west platform projects into that gap | Current west-deck back edge X209 leaves only 10 studs; trial +2 X dock shift gives 12 nominal. Arena + fishing verify final bounds and end routes before buttresses or ramps |
| Bragg ring → exterior | Rear slit appears in a screenshot, but collision/terrain condition is unverified | Bragg surveys it and chooses deliberate opening or complete enclosure; never conceal an unknown gap with props |
| Each area → outer planting | Repeated peripheral trees, sparse foreground, some apparently ungrounded rocks | Shared landscape owner redistributes existing assets, verifies grounding and preserves escape barriers |

Distances above come from current config or section review, not a final construction survey.
Screen-space impressions such as blocked sightlines are hypotheses until checked at the
actual seated camera and with representative character sizes.

## Build sequence

### 1. Survey and lock the circulation drawing

Capture the current eight scenes using the supplied manifest and record native baseline
performance. Make an architectural plan showing every usable floor polygon, its top
height, stair/ramp run, waterline, doorway and seating envelope. Overlay ten occupied
Heaven stations, eight Hell stations, 24 audience dummies, eight visitors, and arena
low-height action proxies. These figures define the clear routes before art is added.

Resolve the interface table. Keep the old terrain and architecture as reversible backups.
Do not regenerate the whole map from an older baker: later fountain, grading, pond, mist
and paving passes must survive. Establish a repeatable finish-pass order in the config
registry and explicitly test a rebuild against the current preview.

**Exit condition:** every primary route and social circulation loop works at speed 24;
seated sightlines are measured; shared boundaries are owned once; no speculative widening.

### 2. Build one approved architectural kit

Prototype a short pavement/edge junction, one retaining-wall bay, one finished crest back,
one rail segment and one chair shell in the existing preview. Use precise Blender/native
geometry with broad readable bevels and economical shared material maps. Repeat the kit
only after inspecting front, rear, underside and grazing-angle views.

Use the two gate settings as the material-quality benchmark. Correct the detached slab
appearance with grounded foundation edges, complete rear heraldry and integrated relief
lecterns. Carry the shared pavement language into arrival, Bragg and garden circuits.
Preserve actual native Seat objects while improving the spectator chair appearance.

**Exit condition:** craftsmanship looks deliberate in daylight with effects disabled;
no coplanar top-face overlaps, ragged notches, reversed rear text or hidden route obstacles.

### 3. Finish social architecture and focal settings

Prioritize the weekly-egg pavilion as the largest new architectural hero: an open,
sculpted celestial structure that presents the existing stand and egg from all sides.
Bragg receives properly supported continuous architecture, readable champion presentation,
and a floor composition that frames the Confluence. The stands receive readable stairs,
end access and a crafted rear façade facing the Hell pool; sightline geometry takes
precedence over decorative height.

Arrival receives a flush meeting seal and a finished overlook. Neither may compete with
mode titles or introduce a mandatory detour. A proposed seal is fitted into a cut opening,
not placed as another plane above the existing path.

**Exit condition:** each area looks complete from its reverse route as well as its hero
camera. All existing capacities remain usable with proxies in place.

### 4. Landscape the spaces people actually occupy

Redistribute current trees and native flowers, ash, skulls, quartz and bone assets into
intentional groups: low foreground, occasional middle-height forms and tall backdrop.
Ground every root and rock; retain natural variation. Plant the empty path wedges and
terrace shoulders while keeping the central sight cones and activity floors clear.

Develop fishing banks as places rather than rings of tables. Differentiate a small family
of crafted platforms, shore access, wet/dry bank transitions and resting pockets. Heaven
and Hell use the same functional dock standard with different materials and props. Keep
the water surfaces real Terrain and reserve dense green haze for the Hell pool.

**Exit condition:** anglers can arrive, pass behind others and leave without stepping
through a fishing position; no flora blocks arena views or conceals a boundary failure.

### 5. Add focused motion, sound and optional hero FX

Add small ambient accents only after architecture and landscape read well: local gate
embers or drifting petals, limited warm lights, restrained positional sound. Keep existing
fountain motion and the approved Hell mist. A scene should still work when the effects
are disabled. Avoid global color changes that unintentionally repaint both ponds.

Build worthwhile modest effects directly in RBX-FX-GEN, following the user's clarification.
See [the scoped FX backlog](FX_IMPLEMENTATION.md); no universal editor is required.
Use its deterministic preview and preset patterns where useful, but treat each
new flourish as a new effect and integration task. Prototype future hatch, catch or winner
moments through explicit artist triggers; no fake collectible bursts, invented reward
logic or automatic gameplay hooks. Fishing rods, fish rigs and catch interactions receive
separate asset and gameplay contracts.

**Exit condition:** no endless celebration loops, no visual competition with destination
names, bounded lifetime/cleanup, reduced-effects behavior and a measured whole-map cost.

### 6. Review the whole composition, then integrate gameplay separately

Repeat the screenshot manifest and add eight occupied visitor-seat views, an arrival
first-impression test, ten simultaneous angler views and low-angle seam checks. Compare
the same camera, graphics setting, resolution and population. Record median/p95 frame
time, memory, visible instances and transparency coverage on agreed target hardware.
Local triangle/particle suggestions in section plans are starting budgets, not numbers
to add blindly. Profile shared views such as stands + Hell mist and spawn + both gates.

Deliver the map with remaining gameplay bindings explicitly listed. Routing, actual
leaderboard avatars, patrol/alliance behavior, fishing movement, rod actions, catches,
Enhancements/potions/egg rewards and weekly refresh rules remain separate implementation.

## Asset production order

1. **Reuse inventory:** native gates, existing crest solids, fountain, flora, skulls,
   quartz/bone, bulwarks, stand and egg. Verify scale, pivots, texture visibility and ownership.
2. **Precision kit in Blender/native solids:** pavement, bevels, wall bays, chair shells,
   rails, mounts, exact text and dock structure. Controlled dimensions and repeated joins
   matter more here than generative variety.
3. **ImageGen concept sheets:** only the selected new hero/organic motifs; include neutral
   front/side/isometric views, a player-size reference, material family and component split.
   Do not bake legible lettering, water, terrain or the whole scene into one generated mesh.
4. **Meshy organic forms:** selected pavilion ornament, reliefs, fishing props or creatures
   where the current library is insufficient. Generate separate rigid components for any
   piece that may move; mesh generation alone is not rigging.
5. **Blender refinement:** dimensional fitting, topology cleanup, UV seams, normals, material
   slots, texture atlas reuse, collision proxies and verified pivots; rig fish/rods only
   after movement/articulation requirements are agreed.
6. **Assets and Roblox:** retain source/provenance, export native assembly, upload using the
   established pipeline, record IDs in config and inspect the native result in daylight.
   A good turntable or web mockup does not certify an in-game asset.

## Recommended first implementation package

Start with the shared stone/retaining/rail kit and the four interface measurements that
prevent rework: gate joints, Bragg approach, garden–pond passage and stand–dock passage.
Then finish both gate backs and one representative Bragg/stand wall bay. This produces
visible quality improvements quickly and establishes the standard for the larger pavilion,
landscape and fishing passes. Defer optional flourishes until these samples are approved
in the actual map.
