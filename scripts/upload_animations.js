#!/usr/bin/env node
/*
  Upload KeyframeSequence .rbxm files to Roblox as ANIMATION assets via Open Cloud (mirror of
  upload_models.js). Open Cloud added assetType "Animation" (.rbxm/.rbxmx of a KeyframeSequence)
  on 2025-10-23 — this replaces the deprecated cookie-based UploadNewAnimation endpoint and the
  per-clip Animation Editor publish click.

  The .rbxm inputs come from anim2rbx (FBX -> KeyframeSequence): see docs in the animated-pet
  pipeline notes. Caveat from Roblox: externally-generated .rbxm "might not upload successfully
  or function correctly" — always play one uploaded id on a rig before trusting a batch.

  Usage:
    node scripts/upload_animations.js --rbxm <clip.rbxm> --name <displayName>
    node scripts/upload_animations.js --dir <folder> --out scripts/animation_ids.json
        (--dir uploads every .rbxm in <folder>, name = filename; merges into --out {name: assetId})

  Reads ROBLOX_OPEN_CLOUD_KEY from env or .env.local. Defaults to the PROJECT GROUP creator.
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
// Default to the PROJECT GROUP (15872767): a Me-owned animation will NOT play in the group game.
const CREATOR_GROUP = arg("creator-group", "15872767");
const creator = CREATOR_USER ? { userId: String(CREATOR_USER) } : { groupId: String(CREATOR_GROUP) };

const ASSETS = "https://apis.roblox.com/assets/v1/assets";
const OPS = "https://apis.roblox.com/assets/v1/operations/";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function uploadRbxm(file, displayName) {
  const buf = fs.readFileSync(file);
  const request = {
    assetType: "Animation",
    displayName: displayName.slice(0, 50),
    description: "Pet animation clip (auto-uploaded KeyframeSequence).",
    creationContext: { creator },
  };
  const boundary = "----rbxAnimUpload" + Date.now() + Math.floor(Math.random() * 1e6);
  const pre = Buffer.from(
    `--${boundary}\r\n` +
      `Content-Disposition: form-data; name="request"\r\n` +
      `Content-Type: application/json\r\n\r\n` +
      JSON.stringify(request) +
      `\r\n--${boundary}\r\n` +
      `Content-Disposition: form-data; name="fileContent"; filename="${path.basename(file)}"\r\n` +
      `Content-Type: model/x-rbxm\r\n\r\n`,
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
  throw new Error(`poll ${displayName}: timed out`);
}

async function main() {
  const single = arg("rbxm", null);
  const dir = arg("dir", null);
  const out = arg("out", null);

  const jobs = [];
  if (single) {
    jobs.push({ file: single, name: arg("name", path.basename(single).replace(/\.rbxmx?$/i, "")) });
  } else if (dir) {
    for (const f of fs.readdirSync(dir)) {
      if (/\.rbxmx?$/i.test(f)) jobs.push({ file: path.join(dir, f), name: f.replace(/\.rbxmx?$/i, "") });
    }
  } else {
    console.error("Provide --rbxm <file> or --dir <folder>.");
    process.exit(1);
  }

  const ids = out && fs.existsSync(out) ? JSON.parse(fs.readFileSync(out, "utf8")) : {};
  let failed = 0;
  for (const j of jobs) {
    try {
      console.log(`Uploading ${j.name} ...`);
      const id = await uploadRbxm(j.file, j.name);
      ids[j.name] = id;
      console.log(`OK  ${j.name} -> ${id}`);
      if (out) fs.writeFileSync(out, JSON.stringify(ids, null, 2) + "\n");
    } catch (e) {
      failed++;
      console.error(`FAIL ${j.name}: ${e.message}`);
    }
  }
  if (failed) process.exit(1);
}

main();
