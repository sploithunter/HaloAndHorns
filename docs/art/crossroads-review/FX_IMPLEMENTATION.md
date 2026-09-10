# Small FX additions worth building in RBX-FX-GEN

The user's clarification is the implementation policy: a useful effect that is a modest
extension should be built in RBX-FX-GEN. The current crystal-only renderer is a starting
point, not a creative ceiling. A general timeline editor is not a prerequisite for shipping
a small, polished map effect. Larger tooling investments remain separate decisions.

This is a scoped implementation backlog, not a claim that these renderers already exist.
Inspected the current CrystalEruption renderer, saved crystal preset, architecture and
status documents in `/Users/jason/Documents/RBX-FX-GEN`. The renderer already demonstrates
config-owned layers, sprite hosts, mesh templates, seeded timing, cleanup and local lights.
Those patterns are reusable; its crystal-specific construction should not be loaded for
an effect that only needs a few particles.

## Highest-value candidates

| Candidate | Areas and intended result | Smallest useful pipeline addition | Scope and acceptance |
|---|---|---|---|
| **Ambient field presets** | Hell pond low green mist; sparse Heaven petals; restrained Hell-gate cinders | A lightweight native ParticleEmitter field renderer with region/ellipse masks, preset-owned density, size, lifetime, tint and distance/reduced-FX policy. Port the existing map mist parameters as the first preset; petals/cinders share implementation with different sprites and motion. | **Small**, because the map already has a 20-source mist implementation. No new art for first mist preset. It must match the approved live mist, avoid off-water sources, clean all hosts on stop and remain bounded across reloads. |
| **Water ripple and splash burst** | Fishing activity preview; small shoreline life | One short-lived ring mesh/Beam plus a small splash emitter at a supplied water point. Separate size/timing/color presets for subtle ambient and future catch feedback. | **Small–medium**: native composition is straightforward; exact surface alignment and alpha art need review. Ripples sit deliberately above the water with bounded lift, never as an overlapping static pool replacement. No fake catches, damage or reward code. |
| **Flowing-water ribbon** | Low Heaven spring and small architectural water features | A two-attachment Beam renderer with preset-owned width/curve/texture scroll and one bounded splash emitter; share the ambient/burst lifecycle. | **Small–medium**, with source/destination sockets and water contact verified in native Roblox. No fluid simulation or mesh waterfall generation prerequisite; stop destroys all attachments it owns. |
| **Soft landmark pulse** | A restrained arrival-seal reveal, gate threshold invitation or Bragg accent | One analytic opacity/scale envelope over an authored inset/mesh light layer, optional shadowless local light, explicit play/stop. Reuse timing/seed utilities where appropriate. | **Small** for one authored target. No always-looping spawn fireworks. Must preserve readable lettering and have a static/reduced-motion fallback; repeated playback cannot leak instances or leave lighting changed. |
| **Localized fountain vapor/glints** | Confluence Heaven spray and tiny Hell heat accents | Native emitter preset anchored to supplied fountain sockets; shared ambient renderer with emission masks and short lifetimes. Existing beams and scrolling pool surfaces stay unchanged. | **Small** after socket survey. First prototype reuses available sprites. Check all six fountain views; no broad smoke obscuring sculpted detail, podium text or fluid split. |
| **Feather/petal hatch bloom** | Future weekly-egg presentation, manually triggered art preview first | A small burst renderer combining 1–2 alpha sprites, optional separately authored feather meshes, and a timed ring. Supply trigger point and palette through preset; no hatch system in the renderer. | **Medium but bounded** if built from existing particles/feathers; larger if a new rig is requested. ImageGen can supply alpha-art concepts; Blender handles controlled mesh feathers. Fifty repeated previews must return to baseline and reduced-FX mode must remain legible. |
| **Champion salute** | Bragg honor moment or future arena winner presentation | A compact upward glint/cinder flourish within a podium footprint using the burst renderer. Heaven/Hell presets share a lifetime contract; no arena-wide crystal eruption. | **Small–medium** after burst primitive exists. A manual lab trigger only until a real server-approved event supplies the target. Avoid implying that static dummies are live winners. |
| **Pool bubbles and occasional wisps** | Hell fishing pool feels active between casts | Masked, low-rate waterline spawn points feeding the ripple/splash primitive and a short wisp preset. This adds controlled variation to the approved continuous mist rather than another large fog layer. | **Small** once ambient and ripple primitives exist. Proposed motion must not resemble a bite signal everywhere; keep true bite/catch feedback visually distinct for later gameplay. |

These are relative scope judgments based on current source and native-effect primitives,
not a delivery estimate. Artist iteration, texture suitability and device profiling can
increase effort. The first prototypes should prove a single effect in daylight before
turning it into a reusable family.

## Minimal pipeline work

1. **Verify the extracted lab.** Rebuild and smoke-test its current crystal preset before
   changing dispatch, save or schema behavior. Preserve that known route and its preset.
2. **Add a narrow effect registry.** Select among an explicit small set of effect families;
   each family supplies renderer, schema, defaults and preview behavior. Do not build a
   multi-track editor, shader graph or generalized asset browser for this map pass.
3. **Keep save paths explicit.** The current loopback writer is fixed-path and validated.
   Extend it with a small allowlist mapping effect/preset names to fixed owned files;
   never accept an arbitrary filesystem path or silently overwrite the crystal preset.
4. **Introduce the ambient renderer first.** It owns native emitter hosts and exposes
   create/start/update-settings/stop. Where a native emitter cannot reproduce the crystal
   timeline's backward seeking exactly, the lab should clearly reset/reseed/restart its
   preview rather than falsely promise deterministic particle scrubbing.
5. **Add one burst primitive next.** Use a simple analytic envelope for meshes/lights and
   bounded particle emission; subsequent bloom/salute presets share it where sensible.
   Do not turn every small effect into another full crystal renderer.
6. **Integrate by config-owned anchors.** Bake static sockets into section models. The map
   asks the renderer to show an effect at a point or region; FX neither selects rewards
   nor modifies combat, fishing, hatching, rankings or server authority.
7. **Document reusable export.** Keep source textures/meshes, native templates, preset
   schema, version, config IDs, preview scene and tests together. Review native Roblox
   output before accepting the asset, including low/high graphics and daylight.

## Asset decisions

Use the existing smoke/glint/ember texture library before generating anything. ImageGen
is useful for a clean alpha petal, feather or splash texture when the library lacks it.
Meshy is optional for an organic decorative source form; it is unnecessary for rings,
precise beam paths or simple particle cards. Blender supplies exact ring geometry, clean
UVs, pivots and separately moving pieces. Imported PBR map assignments belong in authored
templates/config, following the extraction's existing capability constraints.

## Validation required for each candidate

- Same placement, density and silhouette from the section's review cameras; test both
  still composition and a 10–20-second motion view. Never claim a still proves motion.
- Stop/restart, settings change and 50-repeat cleanup checks. No accumulating hosts,
  lights, connections or global state changes. Respect the existing game quality owner.
- Profile with adjacent sections visible, especially stands + pond mist and both gates
  from spawn. Counts are not enough: transparent screen coverage and overlapping layers
  matter. Agree target hardware and baseline before approving a runtime budget.
- Reduced-FX and muted-audio modes preserve destinations and meaningful interaction cues.
  No rapid strobe, forced camera or ambient burst that looks like a collectible/reward.
- Effect code receives a target/anchor and owns only presentation. Future gameplay callers
  remain separately reviewed and server-authorized.

## What would be a larger project

A universal multitrack editor, arbitrary shader-equivalent volumetrics, water simulation,
procedural rigging, a broad asset browser, multiplayer event orchestration or automatic
production deployment is not needed to ship the candidates above. Specify and evaluate
those separately if a selected design actually requires them. Their absence is not a
reason to reject a straightforward native mist, ripple, petal or burst effect.
