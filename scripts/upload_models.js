#!/usr/bin/env node
/*
  Upload FBX meshes to Roblox as Model assets via Open Cloud (mirror of upload_icons.js, which does
  Decals). Each FBX -> one Model asset (a MeshPart inside a Model). Textures referenced by a separate
  .png are NOT embedded, so the mesh imports untextured; pair each Model with a separately-uploaded
  Image id (see upload_icons.js / --texture) and set MeshPart.TextureID in-engine.

  Usage:
    node scripts/upload_models.js --fbx <path.fbx> --name <displayName> --creator-user <userId>
    node scripts/upload_models.js --dir assets/exports/gems --creator-user <userId> --out scripts/gem_model_ids.json
        (--dir walks <dir>/<name>/<name>_*.fbx, uploads each, writes {name: assetId})

  Reads ROBLOX_OPEN_CLOUD_KEY from env or .env.local.
*/
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
function loadEnv() {
  const p = path.join(root, ".env.local");
  if (!fs.existsSync(p)) return;
  for (const line of fs.readFileSync(p, "utf8").split(/\r?\n/)) {
    const m = line.trim().match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!m || process.env[m[1]]) continue;
    let v = m[2];
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
    process.env[m[1]] = v;
  }
}
loadEnv();

const argv = process.argv.slice(2);
const arg = (k, d) => {
  const i = argv.indexOf("--" + k);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : d;
};
const KEY = process.env.ROBLOX_OPEN_CLOUD_KEY || process.env.OPEN_CLOUD_KEY;
if (!KEY) {
  console.error("Missing ROBLOX_OPEN_CLOUD_KEY (env or .env.local).");
  process.exit(1);
}
const CREATOR_USER = arg("creator-user", null);
// Default to the PROJECT GROUP (15872767) so an omitted creator NEVER uploads to a personal
// account — that was the recurring asset-ownership leak. Pass --creator-user <id> only to
// deliberately override (rare).
const CREATOR_GROUP = arg("creator-group", "15872767");
const creator = CREATOR_USER ? { userId: String(CREATOR_USER) } : { groupId: String(CREATOR_GROUP) };

const ASSETS = "https://apis.roblox.com/assets/v1/assets";
const OPS = "https://apis.roblox.com/assets/v1/operations/";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function uploadFbx(file, displayName) {
  const buf = fs.readFileSync(file);
  const request = {
    assetType: "Model",
    displayName: displayName.slice(0, 50),
    description: "Gem drop model (auto-uploaded FBX).",
    creationContext: { creator },
  };
  const boundary = "----rbxModelUpload" + Date.now() + Math.floor(Math.random() * 1e6);
  const pre = Buffer.from(
    `--${boundary}\r\n` +
      `Content-Disposition: form-data; name="request"\r\n` +
      `Content-Type: application/json\r\n\r\n` +
      JSON.stringify(request) +
      `\r\n--${boundary}\r\n` +
      `Content-Disposition: form-data; name="fileContent"; filename="${path.basename(file)}"\r\n` +
      `Content-Type: model/fbx\r\n\r\n`,
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
  if (!opId) throw new Error(`upload ${displayName}: no operationId in ${text.slice(0, 200)}`);

  for (let i = 0; i < 60; i++) {
    await sleep(2000);
    const pr = await fetch(OPS + opId, { headers: { "x-api-key": KEY } });
    const pt = await pr.text();
    if (!pr.ok) throw new Error(`poll ${displayName}: HTTP ${pr.status} ${pt.slice(0, 300)}`);
    const pj = JSON.parse(pt);
    if (pj.done) {
      const assetId = pj.response && (pj.response.assetId || pj.response.id);
      if (!assetId) throw new Error(`poll ${displayName}: done but no assetId — ${pt.slice(0, 400)}`);
      return assetId;
    }
  }
  throw new Error(`poll ${displayName}: timed out (model import can be slow)`);
}

(async () => {
  const single = arg("fbx", null);
  const dir = arg("dir", null);
  const outPath = arg("out", null);

  if (single) {
    const name = arg("name", path.basename(single).replace(/\.fbx$/i, ""));
    console.log(`Uploading ${name} ...`);
    const id = await uploadFbx(single, name);
    console.log(`OK  ${name} -> ${id}`);
    return;
  }
  if (!dir) {
    console.error("Provide --fbx <path> or --dir <dir>.");
    process.exit(1);
  }
  const out = outPath && fs.existsSync(outPath) ? JSON.parse(fs.readFileSync(outPath, "utf8")) : {};
  const FORCE = argv.includes("--force");
  const subdirs = fs
    .readdirSync(dir)
    .filter((d) => fs.statSync(path.join(dir, d)).isDirectory());
  for (const name of subdirs) {
    if (out[name] && !FORCE) {
      console.log(`skip ${name} (already ${out[name]})`);
      continue;
    }
    const folder = path.join(dir, name);
    const fbx = fs.readdirSync(folder).find((f) => /\.fbx$/i.test(f));
    if (!fbx) {
      console.log(`skip ${name} (no .fbx)`);
      continue;
    }
    try {
      console.log(`Uploading ${name} (${fbx}) ...`);
      const id = await uploadFbx(path.join(folder, fbx), name);
      out[name] = id;
      console.log(`OK   ${name} -> ${id}`);
      if (outPath) fs.writeFileSync(outPath, JSON.stringify(out, null, 2));
    } catch (e) {
      console.error(`FAIL ${name}: ${e.message}`);
    }
  }
  if (outPath) console.log(`Wrote ${outPath}`);
})();
