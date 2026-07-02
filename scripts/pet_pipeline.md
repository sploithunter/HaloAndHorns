# Self-serve pet/enemy mesh pipeline (Meshy → Roblox group → in-game)

Turns a Meshy export (FBX + PNG) into an in-game textured creature with **no manual Studio
import** — uploads happen over Open Cloud, and the two Studio-only steps (Decal→Image resolve,
Model→MeshId extract) are one `execute_luau` each. Proven end-to-end on the **jackalope**
(2026-06-14). This is the path that scales to thousands of pets.

## Easy batch path for PETS — `scripts/upload_pets.js` (use this; don't do them individually)

`scripts/upload_pets.js` wraps the whole pet flow so a fresh batch is three commands, not N
manual uploads. Exports must be staged at `assets/exports/pets/<pet>_<variant>/` (the
`<stem>_5k.fbx` + texture `.png` — exactly what `decimate_mesh.sh` produces).

```
# 1) upload mesh + texture for every pet/variant; records ids in scripts/pet_mesh_ids.json
node scripts/upload_pets.js upload \
  --pets solar_roc,dawn_camel,gilded_sphinx,mirage_jackal,sun_scarab \
  --variants basic,gold --realm heaven --origin desert

# 2) print a Luau resolve block for ALL pending entries (no hand-typed id lists)
node scripts/upload_pets.js emit-resolve
#    -> paste the block into Studio execute_luau (Edit or Server); it returns
#       "name|mesh=...|img=..." lines. Save them to a file.

# 3) write the resolved MeshId + Image id back into the registry
node scripts/upload_pets.js apply-resolve --file studio_out.txt
```

Registry keys are `<pet>_<variant>` (e.g. `solar_roc_basic`, `solar_roc_gold`); each carries
`modelAssetId, textureDecalId, meshId, imageId, realm, origin, variant`. Creator defaults to the
group `15872767`. The resolve is the only non-headless step (it needs the engine's `LoadAsset`).

## Wiring a meshy pet into `configs/pets.lua` (the combine path)

A pet variant supplies its art as **`mesh_asset` + `texture_asset`** (the resolved `meshId` /
`imageId` from the registry) — NOT `asset_id`. `asset_id` loads a packaged Model, but FBX→Model
uploads are untextured (grey). `AssetPreloadService:BuildMeshPartModelIntoFolder` combines mesh +
texture at load (`CreateMeshPartAsync` + `TextureID`). Example variant:
```lua
basic = {
    mesh_asset = "rbxassetid://97859401243319",   -- registry meshId
    texture_asset = "rbxassetid://140706326750464", -- registry imageId (IMAGE, not Decal)
    display_name = "Solar Phoenix",
    abilities = { "dawn_bolt" },
},
```

## Why mesh + texture SEPARATELY (not a textured Model)

A Meshy FBX imports **untextured** (the texture is a sibling `.png`, not embedded). So we upload the
mesh and the texture as two assets and combine them at spawn via
`AssetService:CreateMeshPartAsync(Content.fromUri(meshId))` + `mesh.TextureID = imageId` — the same
"gem pattern" `EnemyService:_meshTemplate` / `DropService` already use. No `InsertService` Model
load at runtime (which is what the group-migration moved us off of).

## The one gotcha that bites every time

`MeshPart.TextureID` needs the underlying **Image** id, NOT the **Decal** id that the Open Cloud
upload returns. Set it to the Decal id and the mesh renders **flat grey**. You must resolve
Decal→Image once in Studio (step 3). `mesh_asset` is the raw **MeshId** inside the uploaded Model,
not the Model id (step 5).

## Recipe

Group = Open Simulator `15872767`. Key = `ROBLOX_OPEN_CLOUD_KEY` in `.env.local` (has group rights).

**1. Pre-process the texture** — Roblox caps textures at 1024². Meshy ships 2048².
```
python3 -c "from PIL import Image; im=Image.open('SRC.png').convert('RGBA'); \
  im.resize((1024,1024), Image.LANCZOS).save('OUT_1024.png', optimize=True)"
```

**2. Upload the mesh (FBX → Model) + the texture (PNG → Decal)** to the group:
```
node scripts/upload_models.js --fbx EXPORT_5k.fbx --name "Name" --creator-group 15872767
#   -> Model assetId  (a MeshPart wrapped in a Model; imports untextured)
mkdir -p /tmp/tex && cp OUT_1024.png /tmp/tex/name.png
node scripts/upload_icons.js --dir /tmp/tex --creator-group 15872767 --out /tmp/tex/ids.json
#   -> Decal assetId
```

**3 + 5. Resolve Decal→Image and extract the MeshId** — one `execute_luau` (Server datamodel; Edit
is unavailable in Play). Replace MODEL_ID / DECAL_ID:
```lua
local InsertService, AssetService = game:GetService("InsertService"), game:GetService("AssetService")
local out = {}
local m = InsertService:LoadAsset(MODEL_ID)
for _, d in ipairs(m:GetDescendants()) do if d:IsA("MeshPart") then out.meshId = d.MeshId break end end
local dec = InsertService:LoadAsset(DECAL_ID)
for _, d in ipairs(dec:GetDescendants()) do if d:IsA("Decal") then out.imageId = d.Texture break end end
m:Destroy(); dec:Destroy(); return out   -- imageId may come back as http://.../id=NNN; use rbxassetid://NNN
```

**4. (optional) Visual check** — build it and `screen_capture`; grey = you used the Decal id.
```lua
local mp = game:GetService("AssetService"):CreateMeshPartAsync(Content.fromUri(MESH_ID))
mp.TextureID = "rbxassetid://IMAGE_ID"; mp.Anchored = true; mp.Size = mp.Size*4
mp.CFrame = CFrame.new(0,100,0); mp.Parent = workspace
```

**6. Wire the config** — in `configs/enemies.lua` / `configs/pets.lua`:
```lua
mesh_asset    = "rbxassetid://MESH_ID",   -- the raw MeshId from step 3/5
texture_asset = "rbxassetid://IMAGE_ID",  -- the resolved IMAGE id, NOT the Decal id
model_scale   = 4,                         -- native Meshy mesh is ~1.9 studs; 4x -> ~7.6
```

## Batching thousands

Steps 1–2 are pure CLI (loop over a manifest). Steps 3/5 are a single `execute_luau` that can take an
**array** of {model,decal} and return a map of {meshId,imageId} in one round-trip — so the Studio
touch is O(1) calls, not O(pets). The only human-in-the-loop bit is pointing the loop at the export
list. See `scripts/pet_mesh_ids.json` for the recorded ids.

## Viewport preview PNGs from the actual FBX (Blender)

Meshy concept art in `assets/exports/pets/basic/` and `gold/` often predates the final mesh.
To regenerate contact-sheet previews from the **textured decimated FBX** in each export folder:

```
# dry-run: list what would render
python3 scripts/render_pet_previews.py --dry-run

# render all (uses *_5k.fbx + sibling texture PNG; ~6s/model)
python3 scripts/render_pet_previews.py --crop --size 1024

# or via mise
mise run render-pet-previews
```

Gameplay viewport renders go to `assets/exports/pets/model_renders/` (separate from concept
art in `basic/` and `gold/`). Two camera views, separate folders:

| View | Folder | Camera |
|------|--------|--------|
| **front** | `model_renders/front/{basic\|gold}/` | Face-on (azimuth 0°) |
| **hero** | `model_renders/hero/{basic\|gold}/` | 3/4 angle (azimuth 35°) |

```
# both views (default)
python3 scripts/render_pet_previews.py --views front,hero --crop --size 1024

# one view only
python3 scripts/render_pet_previews.py --views hero --only bear_basic --crop

# mise task runs front + hero for all exports
mise run render-pet-previews
```

Requires Blender (macOS default: `/Applications/Blender.app`). Override with `--blender`.
