#!/usr/bin/env node
/*
  upload_pets.js — the EASY PATH for meshy pets. One command uploads every pet/variant's
  mesh (FBX -> Model) AND texture (PNG -> Decal) via Open Cloud, then records the ids in
  scripts/pet_mesh_ids.json. The model imports UNTEXTURED, so pets use the runtime combine
  (configs/pets.lua variant: mesh_asset + texture_asset -> AssetService:CreateMeshPartAsync +
  MeshPart.TextureID; see AssetPreloadService:BuildMeshPartModelIntoFolder).

  The only step that can't be headless is resolving the Model's raw MeshId and the Decal's
  Image id — that needs the Roblox engine (InsertService:LoadAsset). So this tool splits into:

    1) UPLOAD  — create the assets, record {modelAssetId, textureDecalId, meshId/imageId=PENDING}.
         node scripts/upload_pets.js upload \
           --pets solar_roc,dawn_camel,gilded_sphinx,mirage_jackal,sun_scarab \
           --variants basic,gold --realm heaven --origin desert
         (reads FBX + PNG from assets/exports/pets/<pet>_<variant>/)

    2) EMIT-RESOLVE — print a Luau table of every PENDING entry. Paste into Studio
       (execute_luau) — it LoadAssets each, reads MeshId + Decal.Texture, prints lines.
         node scripts/upload_pets.js emit-resolve

    3) APPLY-RESOLVE — feed the Studio output back; writes meshId/imageId into the registry.
         node scripts/upload_pets.js apply-resolve --file resolve_out.txt
         (or: ... apply-resolve --stdin   then paste + Ctrl-D)

  Creator defaults to the group (15872767). Reads ROBLOX_OPEN_CLOUD_KEY from env or .env.local.
*/
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const REGISTRY = path.join(root, "scripts", "pet_mesh_ids.json");
const EXPORTS = path.join(root, "assets", "exports", "pets");
const DEFAULT_GROUP = "15872767";

function loadEnv() {
  const p = path.join(root, ".env.local");
  if (!fs.existsSync(p)) return;
  for (const line of fs.readFileSync(p, "utf8").split(/\r?\n/)) {
    const m = line.trim().match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!m || process.env[m[1]]) continue;
    let v = m[2];
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'")))
      v = v.slice(1, -1);
    process.env[m[1]] = v;
  }
}
loadEnv();

const argv = process.argv.slice(2);
const sub = argv[0];
function arg(k, d) {
  const i = argv.indexOf("--" + k);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : d;
}

const KEY = process.env.ROBLOX_OPEN_CLOUD_KEY;
const ASSETS = "https://apis.roblox.com/assets/v1/assets";
const OPS = "https://apis.roblox.com/assets/v1/operations/";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function readRegistry() {
  return fs.existsSync(REGISTRY) ? JSON.parse(fs.readFileSync(REGISTRY, "utf8")) : {};
}
function writeRegistry(d) {
  fs.writeFileSync(REGISTRY, JSON.stringify(d, null, 2));
}

// Generic Open Cloud asset upload (Model for FBX, Decal for PNG). Mirrors upload_models.js /
// upload_icons.js; returns the created assetId.
async function uploadAsset(file, displayName, assetType, contentType, fileMime) {
  if (!KEY) throw new Error("ROBLOX_OPEN_CLOUD_KEY not set (env or .env.local)");
  const creator = arg("creator-user", null)
    ? { userId: arg("creator-user", null) }
    : { groupId: arg("creator-group", DEFAULT_GROUP) };
  const buf = fs.readFileSync(file);
  const request = {
    assetType,
    displayName: displayName.slice(0, 50),
    description: "Pet " + assetType.toLowerCase() + " (auto-uploaded).",
    creationContext: { creator },
  };
  const boundary = "----rbxPetUpload" + Date.now() + Math.floor(Math.random() * 1e6);
  const pre = Buffer.from(
    `--${boundary}\r\n` +
      `Content-Disposition: form-data; name="request"\r\n` +
      `Content-Type: application/json\r\n\r\n` +
      JSON.stringify(request) +
      `\r\n--${boundary}\r\n` +
      `Content-Disposition: form-data; name="fileContent"; filename="${path.basename(file)}"\r\n` +
      `Content-Type: ${fileMime}\r\n\r\n`,
    "utf8"
  );
  const post = Buffer.from(`\r\n--${boundary}--\r\n`, "utf8");
  const body = Buffer.concat([pre, buf, post]);

  const res = await fetch(ASSETS, {
    method: "POST",
    headers: { "x-api-key": KEY, "Content-Type": `multipart/form-data; boundary=${boundary}` },
    body,
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`upload ${displayName}: HTTP ${res.status} ${text.slice(0, 400)}`);
  const op = JSON.parse(text);
  const opId = op.operationId || (op.path && op.path.split("/").pop());
  if (!opId) throw new Error(`upload ${displayName}: no operationId`);

  for (let i = 0; i < 90; i++) {
    await sleep(2000);
    const pr = await fetch(OPS + opId, { headers: { "x-api-key": KEY } });
    const pt = await pr.text();
    if (!pr.ok) throw new Error(`poll ${displayName}: HTTP ${pr.status} ${pt.slice(0, 300)}`);
    const pj = JSON.parse(pt);
    if (pj.done) {
      const id = pj.response && (pj.response.assetId || pj.response.id);
      if (!id) throw new Error(`poll ${displayName}: done but no assetId — ${pt.slice(0, 300)}`);
      return id;
    }
  }
  throw new Error(`poll ${displayName}: timed out`);
}

// Find the recommended upload files in assets/exports/pets/<stem>/: the mesh fbx + the texture png.
// Prefer the _10k.fbx (native when source <= 10k, decimated to the Roblox 10k limit otherwise),
// then _5k, then any fbx. The 2026-06-23 realm batch ships only _10k.
function filesFor(stem) {
  const dir = path.join(EXPORTS, stem);
  if (!fs.existsSync(dir)) return null;
  const entries = fs.readdirSync(dir);
  const fbx =
    entries.find((f) => /_10k\.fbx$/i.test(f)) ||
    entries.find((f) => /_5k\.fbx$/i.test(f)) ||
    entries.find((f) => /\.fbx$/i.test(f));
  const png = entries.find((f) => /\.png$/i.test(f) && !/contact/i.test(f));
  if (!fbx || !png) return null;
  return { fbx: path.join(dir, fbx), png: path.join(dir, png) };
}

async function doUpload() {
  const pets = (arg("pets", "") || "").split(",").map((s) => s.trim()).filter(Boolean);
  const variants = (arg("variants", "basic") || "").split(",").map((s) => s.trim()).filter(Boolean);
  const realm = arg("realm", null);
  const origin = arg("origin", null);
  const force = argv.includes("--force");
  // --shared-mesh: non-basic variants (e.g. gold) reuse the basic stem's uploaded Model
  // (identical geometry, texture reskin only) and upload ONLY their own texture Decal.
  // Requires the basic stem to be uploaded first (variants order: basic before gold).
  const sharedMesh = argv.includes("--shared-mesh");
  if (!pets.length) throw new Error("--pets a,b,c required");

  const reg = readRegistry();
  for (const pet of pets) {
    for (const variant of variants) {
      const stem = `${pet}_${variant}`;
      const key = stem; // registry key, e.g. solar_roc_basic
      if (reg[key] && reg[key].modelAssetId && !force) {
        console.log(`skip ${key} (already ${reg[key].modelAssetId})`);
        continue;
      }
      const files = filesFor(stem);
      if (!files) {
        console.error(`FAIL ${key}: no fbx + .png in ${path.join("assets/exports/pets", stem)}`);
        continue;
      }
      try {
        const basicKey = `${pet}_basic`;
        const reuse =
          sharedMesh && variant !== "basic" && reg[basicKey] && reg[basicKey].modelAssetId;
        let modelId;
        if (reuse) {
          modelId = reg[basicKey].modelAssetId;
          console.log(`Reusing ${basicKey} mesh for ${key} (shared-mesh, model=${modelId}) ...`);
        } else {
          console.log(`Uploading ${key} mesh ...`);
          modelId = await uploadAsset(files.fbx, stem, "Model", null, "model/fbx");
        }
        console.log(`Uploading ${key} texture ...`);
        const decalId = await uploadAsset(files.png, stem + "_tex", "Decal", null, "image/png");
        reg[key] = {
          modelAssetId: String(modelId),
          textureDecalId: String(decalId),
          meshId: "PENDING_RESOLVE",
          imageId: "PENDING_RESOLVE",
          realm: realm || (reg[key] && reg[key].realm) || undefined,
          origin: origin || (reg[key] && reg[key].origin) || undefined,
          variant,
          sharedMeshFrom: reuse ? basicKey : undefined,
          uploadedBy: "upload_pets.js " + new Date().toISOString().slice(0, 10),
        };
        writeRegistry(reg);
        console.log(`OK   ${key}  model=${modelId}  decal=${decalId}`);
      } catch (e) {
        console.error(`FAIL ${key}: ${e.message}`);
      }
    }
  }
  console.log(`\nWrote ${REGISTRY}. Next: node scripts/upload_pets.js emit-resolve`);
}

function doEmitResolve() {
  const reg = readRegistry();
  const pend = Object.entries(reg).filter(
    ([, v]) => v && (v.meshId === "PENDING_RESOLVE" || v.imageId === "PENDING_RESOLVE")
  );
  if (!pend.length) {
    console.error("-- nothing pending");
    return;
  }
  console.log(`-- ${pend.length} pending. Paste the block below into Studio execute_luau (Edit or Server):`);
  console.log("local InsertService = game:GetService('InsertService')");
  console.log("local PENDING = {");
  for (const [name, v] of pend) {
    console.log(`  { name="${name}", model=${v.modelAssetId}, decal=${v.textureDecalId} },`);
  }
  console.log("}");
  console.log(`local function mesh(id) local a=InsertService:LoadAsset(id); local m for _,d in ipairs(a:GetDescendants()) do if d:IsA('MeshPart') then m=d break end end a:Destroy() return m and m.MeshId end`);
  console.log(`local function img(id) local a=InsertService:LoadAsset(id); local t for _,d in ipairs(a:GetDescendants()) do if d:IsA('Decal') then t=d.Texture break end end a:Destroy() return t end`);
  console.log(`local out={} for _,p in ipairs(PENDING) do table.insert(out, p.name..'|mesh='..tostring(mesh(p.model))..'|img='..tostring(img(p.decal))) end return table.concat(out,'\\n')`);
  console.log("-- then: node scripts/upload_pets.js apply-resolve --file <studio_output.txt>");
}

function normImg(s) {
  const m = String(s).match(/id=(\d+)/) || String(s).match(/(\d+)/);
  return m ? "rbxassetid://" + m[1] : s;
}
function doApplyResolve() {
  let raw;
  if (argv.includes("--stdin")) {
    raw = fs.readFileSync(0, "utf8");
  } else {
    const file = arg("file", null);
    if (!file) throw new Error("apply-resolve needs --file <path> or --stdin");
    raw = fs.readFileSync(file, "utf8");
  }
  const reg = readRegistry();
  let n = 0;
  for (const line of raw.split(/\r?\n/)) {
    const m = line.match(/^([a-z0-9_]+)\|mesh=(\S+)\|img=(\S+)/i);
    if (!m) continue;
    const [, name, mesh, img] = m;
    if (!reg[name]) {
      console.error(`?? ${name} not in registry`);
      continue;
    }
    reg[name].meshId = mesh.startsWith("rbxassetid://") ? mesh : "rbxassetid://" + (mesh.match(/\d+/) || [""])[0];
    reg[name].imageId = normImg(img);
    n++;
  }
  writeRegistry(reg);
  const stillPend = Object.entries(reg).filter(
    ([, v]) => v && (v.meshId === "PENDING_RESOLVE" || v.imageId === "PENDING_RESOLVE")
  );
  console.log(`applied ${n}; still PENDING: ${stillPend.length} ${stillPend.map((e) => e[0]).join(",")}`);
}

(async () => {
  try {
    if (sub === "upload") await doUpload();
    else if (sub === "emit-resolve") doEmitResolve();
    else if (sub === "apply-resolve") doApplyResolve();
    else {
      console.error("usage: upload_pets.js <upload|emit-resolve|apply-resolve> [flags] (see header)");
      process.exit(1);
    }
  } catch (e) {
    console.error("ERROR:", e.message);
    process.exit(1);
  }
})();
