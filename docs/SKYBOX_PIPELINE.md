# Skybox pipeline — HDRI to per-layer realm sky

The end-to-end recipe for giving a realm layer its own sky. Reference runs:
hell_1..5 (original), heaven_1 (2026-07-16, blue day), heaven_2 (2026-07-16,
pink dawn — the run this doc was written against).

## 1. Generate the panorama (Jason, ~minutes)

<https://hyper3d.ai/workspace/omnicraft/hdri> — generate an HDRI panorama
for the layer's mood (prompt for the realm: e.g. "serene heavenly dawn,
pink clouds, ringed planet").

## 2. Convert to the 6 cubemap faces (Jason, ~1 minute)

<https://shinjiesk.github.io/panorama-to-cubemap/roblox-skybox/> — feed it
the HDRI; it emits the six Roblox-oriented faces named
`hdr_high_{Rt,Lf,Ft,Bk,Up,Dn}.png`. Download all six (they land in
`~/Downloads`, possibly with a ` (n)` suffix).

## 3. Stage into the repo (agent)

```sh
mkdir -p assets/skybox/<layer_id>
for face in Ft Bk Lf Rt Up Dn; do
  cp ~/Downloads/"hdr_high_${face} (n).png" assets/skybox/<layer_id>/Skybox${face}.png
done
```

Face name mapping is 1:1 (`Rt`→`SkyboxRt`, etc.) — the converter already
speaks Roblox's orientation.

## 4. Upload as Decals (agent)

```sh
node scripts/upload_icons.js --dir assets/skybox/<layer_id> \
  --creator-group 15872767 --out /tmp/skybox_ids.json
```

Record the Decal ids in `scripts/skybox_<layer_id>_ids.json` (see
`skybox_heaven_2_ids.json` for the shape — include `source` and `layer`
fields). Uploads occasionally fail silently; re-run individual faces with
`--only Skybox<Face>` (exact basename, no extension) until all six exist.

## 5. Resolve Decal → Image (agent, in Studio via MCP)

**Sky faces require IMAGE content ids, not Decal ids** — a Decal id on a
Sky face renders nothing. Resolve each:

```lua
local asset = game:GetService("InsertService"):LoadAsset(<decalId>)
local imageId = asset:FindFirstChildWhichIsA("Decal", true).Texture
```

## 6. Wire the config (agent)

`configs/layers.lua` → `atmosphere.sky.per_layer.<layer_id>.textures`:

```lua
<layer_id> = {
    textures = {
        ft = <imageId>, bk = <imageId>, lf = <imageId>,
        rt = <imageId>, up = <imageId>, dn = <imageId>,
        celestial_bodies_shown = false, -- custom skies hide the default sun/moon
        -- optional: star_count, sun/moon texture + angular sizes
    },
},
```

`RealmAtmosphere` (client) swaps the place's Sky to these faces whenever
the player's `CurrentLayer` attribute becomes `<layer_id>`, and restores
the captured base sky (the Home aurora) for layers with `textures = nil`.

## 7. Verify (agent + Jason)

- Live preview without travel: set the Sky faces directly on the client
  (or stamp `player:SetAttribute("CurrentLayer", "<layer_id>")` server-side
  in a Play session) and eyeball.
- Real path: descend/ascend to the layer via a portal.

## Gotchas (each one cost a debugging session)

- **ONE Sky object in Lighting, ever.** A second Sky (e.g. a hand-staged
  preview left behind) makes the engine's active-sky pick arbitrary, so
  the per-layer swap mutates a Sky the renderer may ignore — every layer
  shows the base aurora (the 2026-07-16 hell-sky outage). LayerService
  boots with a singleton sweep (keeps the first Sky, purges extras,
  warns), but don't leave preview skies around anyway.
- **Image ids, not Decal ids** (step 5). Decal ids silently no-op.
- The base sky is CAPTURED at client boot for restore — whatever Sky the
  place ships is what `textures = nil` layers show.
- If the sky looks wrong only in Studio, run the mesh-corruption standing
  test first (restart Studio / check production) — see the wiki LOG
  2026-07-15 entries.
