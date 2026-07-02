#!/usr/bin/env node
/*
  upload_eggs.js — the EASY PATH for egg assets (mirror of upload_pets.js). Each egg carries TWO
  asset kinds, matching the solar_egg entry in scripts/egg_assets.json:
    - 2D inventory icon : assets/source/eggs/<egg>.png            -> Decal -> resolve Image
    - 3D mesh + texture : assets/exports/eggs/<egg>/<egg>_5k.fbx  -> Model (untextured)
                          assets/exports/eggs/<egg>/<egg>.png     -> Decal -> resolve Image
                          (the Model's raw MeshId is resolved in-engine, like pets)

  Records ids into scripts/egg_assets.json:
    icon_decal, icon_image, model_asset, mesh_id, mesh_image  (+ realm/origin/sources/uploadedBy)

  Like the pet tool, the only step that can't be headless is resolving the Model's raw MeshId and a
  Decal's Image id (needs InsertService:LoadAsset). So it splits into three steps:

    1) UPLOAD  — create the assets; mesh_id/icon_image/mesh_image = PENDING_RESOLVE.
         node scripts/upload_eggs.js upload --eggs aurora_egg,bloom_egg --realm heaven --origin ice
         (reads icon from assets/source/eggs/<egg>.png and mesh from assets/exports/eggs/<egg>/)

    2) EMIT-RESOLVE — print a Luau table of every PENDING egg. Paste into Studio (execute_luau).
         node scripts/upload_eggs.js emit-resolve

    3) APPLY-RESOLVE — feed the Studio output back; writes mesh_id/icon_image/mesh_image.
         node scripts/upload_eggs.js apply-resolve --file resolve_out.txt   (or --stdin)

  Creator defaults to the group (15872767). Reads ROBLOX_OPEN_CLOUD_KEY from env or .env.local.
*/
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const REGISTRY = path.join(root, "scripts", "egg_assets.json");
const EGG_EXPORTS = path.join(root, "assets", "exports", "eggs");
const EGG_SOURCE = path.join(root, "assets", "source", "eggs");
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
  fs.writeFileSync(REGISTRY, JSON.stringify(d, null, 1));
}

// Generic Open Cloud asset upload (Model for FBX, Decal for PNG); returns the created assetId.
async function uploadAsset(file, displayName, assetType, fileMime) {
  if (!KEY) throw new Error("ROBLOX_OPEN_CLOUD_KEY not set (env or .env.local)");
  const creator = arg("creator-user", null)
    ? { userId: arg("creator-user", null) }
    : { groupId: arg("creator-group", DEFAULT_GROUP) };
  const buf = fs.readFileSync(file);
  const request = {
    assetType,
    displayName: displayName.slice(0, 50),
    description: "Egg " + assetType.toLowerCase() + " (auto-uploaded).",
    creationContext: { creator },
  };
  const boundary = "----rbxEggUpload" + Date.now() + Math.floor(Math.random() * 1e6);
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
      return String(id);
    }
  }
  throw new Error(`poll ${displayName}: timed out`);
}

// Source files for an egg: 2D icon + recommended mesh (*_5k.fbx) + mesh texture png.
function filesFor(egg) {
  const icon = path.join(EGG_SOURCE, egg + ".png");
  const dir = path.join(EGG_EXPORTS, egg);
  if (!fs.existsSync(dir)) return null;
  const entries = fs.readdirSync(dir);
  const fbx =
    entries.find((f) => /_10k\.fbx$/i.test(f)) ||
    entries.find((f) => /_5k\.fbx$/i.test(f)) ||
    entries.find((f) => /\.fbx$/i.test(f));
  const tex = entries.find((f) => /\.png$/i.test(f) && !/contact/i.test(f));
  if (!fbx || !tex || !fs.existsSync(icon)) return null;
  return { icon, fbx: path.join(dir, fbx), tex: path.join(dir, tex) };
}

async function doUpload() {
  const eggs = (arg("eggs", "") || "").split(",").map((s) => s.trim()).filter(Boolean);
  const realm = arg("realm", null);
  const origin = arg("origin", null);
  const force = argv.includes("--force");
  if (!eggs.length) throw new Error("--eggs a,b,c required");

  const reg = readRegistry();
  for (const egg of eggs) {
    if (reg[egg] && reg[egg].model_asset && !force) {
      console.log(`skip ${egg} (already model_asset=${reg[egg].model_asset})`);
      continue;
    }
    const files = filesFor(egg);
    if (!files) {
      console.error(
        `FAIL ${egg}: need ${path.join("assets/source/eggs", egg + ".png")} + _5k.fbx & .png in ${path.join("assets/exports/eggs", egg)}`
      );
      continue;
    }
    try {
      console.log(`Uploading ${egg} icon ...`);
      const iconDecal = await uploadAsset(files.icon, egg + "_icon", "Decal", "image/png");
      console.log(`Uploading ${egg} mesh ...`);
      const modelId = await uploadAsset(files.fbx, egg, "Model", "model/fbx");
      console.log(`Uploading ${egg} mesh texture ...`);
      const texDecal = await uploadAsset(files.tex, egg + "_tex", "Decal", "image/png");
      reg[egg] = {
        icon_decal: iconDecal,
        icon_image: "PENDING_RESOLVE",
        model_asset: modelId,
        mesh_id: "PENDING_RESOLVE",
        mesh_image: "PENDING_RESOLVE",
        _mesh_tex_decal: texDecal, // transient — used by resolve, dropped after apply
        creator: "Open Simulator Group (" + DEFAULT_GROUP + ")",
        realm: realm || (reg[egg] && reg[egg].realm) || undefined,
        origin: origin || (reg[egg] && reg[egg].origin) || undefined,
        sources: {
          icon: path.relative(root, files.icon),
          fbx: path.relative(root, files.fbx),
          texture: path.relative(root, files.tex),
        },
        uploadedBy: "upload_eggs.js " + new Date().toISOString().slice(0, 10),
      };
      writeRegistry(reg);
      console.log(`OK   ${egg}  icon=${iconDecal}  model=${modelId}  tex=${texDecal}`);
    } catch (e) {
      console.error(`FAIL ${egg}: ${e.message}`);
    }
  }
  console.log(`\nWrote ${REGISTRY}. Next: node scripts/upload_eggs.js emit-resolve`);
}

function doEmitResolve() {
  const reg = readRegistry();
  const pend = Object.entries(reg).filter(
    ([, v]) =>
      v &&
      (v.mesh_id === "PENDING_RESOLVE" ||
        v.icon_image === "PENDING_RESOLVE" ||
        v.mesh_image === "PENDING_RESOLVE")
  );
  if (!pend.length) {
    console.error("-- nothing pending");
    return;
  }
  console.log(`-- ${pend.length} pending. Paste the block below into Studio execute_luau (Edit or Server):`);
  console.log("local InsertService = game:GetService('InsertService')");
  console.log("local PENDING = {");
  for (const [name, v] of pend) {
    console.log(
      `  { name="${name}", model=${v.model_asset}, icon=${v.icon_decal}, tex=${v._mesh_tex_decal} },`
    );
  }
  console.log("}");
  console.log(
    `local function mesh(id) local a=InsertService:LoadAsset(id); local m for _,d in ipairs(a:GetDescendants()) do if d:IsA('MeshPart') then m=d break end end a:Destroy() return m and m.MeshId end`
  );
  console.log(
    `local function img(id) local a=InsertService:LoadAsset(id); local t for _,d in ipairs(a:GetDescendants()) do if d:IsA('Decal') then t=d.Texture break end end a:Destroy() return t end`
  );
  console.log(
    `local out={} for _,p in ipairs(PENDING) do table.insert(out, p.name..'|mesh='..tostring(mesh(p.model))..'|icon='..tostring(img(p.icon))..'|tex='..tostring(img(p.tex))) end return table.concat(out,'\\n')`
  );
  console.log("-- then: node scripts/upload_eggs.js apply-resolve --file <studio_output.txt>");
}

function normId(s) {
  const m = String(s).match(/id=(\d+)/) || String(s).match(/(\d+)/);
  return m ? "rbxassetid://" + m[1] : s;
}
function doApplyResolve() {
  let raw;
  if (argv.includes("--stdin")) raw = fs.readFileSync(0, "utf8");
  else {
    const file = arg("file", null);
    if (!file) throw new Error("apply-resolve needs --file <path> or --stdin");
    raw = fs.readFileSync(file, "utf8");
  }
  const reg = readRegistry();
  let n = 0;
  for (const line of raw.split(/\r?\n/)) {
    const m = line.match(/^([a-z0-9_]+)\|mesh=(\S+)\|icon=(\S+)\|tex=(\S+)/i);
    if (!m) continue;
    const [, name, mesh, icon, tex] = m;
    if (!reg[name]) {
      console.error(`?? ${name} not in registry`);
      continue;
    }
    reg[name].mesh_id = normId(mesh);
    reg[name].icon_image = (icon.match(/\d+/) || [""])[0]; // icon_image stored as bare id (matches solar_egg)
    reg[name].mesh_image = normId(tex);
    delete reg[name]._mesh_tex_decal;
    n++;
  }
  writeRegistry(reg);
  const stillPend = Object.entries(reg).filter(
    ([, v]) => v && (v.mesh_id === "PENDING_RESOLVE" || v.mesh_image === "PENDING_RESOLVE")
  );
  console.log(`applied ${n}; still PENDING: ${stillPend.length} ${stillPend.map((e) => e[0]).join(",")}`);
}

(async () => {
  try {
    if (sub === "upload") await doUpload();
    else if (sub === "emit-resolve") doEmitResolve();
    else if (sub === "apply-resolve") doApplyResolve();
    else {
      console.error("usage: upload_eggs.js <upload|emit-resolve|apply-resolve> [flags] (see header)");
      process.exit(1);
    }
  } catch (e) {
    console.error("ERROR:", e.message);
    process.exit(1);
  }
})();
