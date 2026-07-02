#!/usr/bin/env node
/*
  upload_icons.js — batch-upload PNG icons to Roblox via the Open Cloud Assets API,
  poll each operation, and write the resulting asset ids to a manifest JSON.

  Usage:
    node scripts/upload_icons.js --dir assets/UI/blue_icons --creator-user <userId> [--only shield] [--prefix "pr_blue_"] [--out scripts/icon_ids.blue.json]
    node scripts/upload_icons.js --dir ... --creator-group <groupId> ...

  Reads ROBLOX_OPEN_CLOUD_KEY from the environment or .env.local. The key must have
  the "asset" (write) scope — the place-publish key may not; if so you'll get 401/403.

  Images upload as Decal assets; the returned assetId works in ImageLabel.Image as
  rbxassetid://<id>. New uploads go through moderation (id is assigned immediately,
  may render once approved).
*/

const fs = require("fs");
const path = require("path");

// ---- tiny .env.local loader (KEY=VALUE lines) ----
function loadEnvLocal() {
  const p = path.resolve(process.cwd(), ".env.local");
  if (!fs.existsSync(p)) return;
  for (const line of fs.readFileSync(p, "utf8").split("\n")) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) {
      process.env[m[1]] = m[2].replace(/^["']|["']$/g, "");
    }
  }
}
loadEnvLocal();

// ---- args ----
const args = process.argv.slice(2);
function arg(name, def) {
  const i = args.indexOf("--" + name);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
}
const DIR = arg("dir", "assets/UI/blue_icons");
const ONLY = arg("only", null);
const PREFIX = arg("prefix", "");
const OUT = arg("out", "scripts/icon_ids.json");
const CREATOR_USER = arg("creator-user", null);
// Default to the PROJECT GROUP (15872767) so an omitted creator NEVER uploads to a personal
// account — that was the recurring asset-ownership leak. Pass --creator-user <id> only to
// deliberately override (rare).
const CREATOR_GROUP = arg("creator-group", "15872767");

const KEY = process.env.ROBLOX_OPEN_CLOUD_KEY;
if (!KEY) {
  console.error("ROBLOX_OPEN_CLOUD_KEY not set (env or .env.local).");
  process.exit(1);
}
const creator = CREATOR_USER ? { userId: String(CREATOR_USER) } : { groupId: String(CREATOR_GROUP) };

const ASSETS = "https://apis.roblox.com/assets/v1/assets";
const OPS = "https://apis.roblox.com/assets/v1/operations/";

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function uploadOne(file) {
  const name = path.basename(file, ".png");
  const buf = fs.readFileSync(file);
  const request = {
    assetType: "Decal",
    displayName: (PREFIX + name).slice(0, 50),
    description: "Power/role/ring icon (auto-uploaded).",
    creationContext: { creator },
  };
  // Build multipart manually as one Buffer → fetch sets Content-Length (Roblox rejects the
  // chunked, no-length body that native fetch+FormData produces as "request body empty").
  const boundary = "----rbxIconUpload" + Date.now() + Math.floor(Math.random() * 1e6);
  const pre = Buffer.from(
    `--${boundary}\r\n` +
      `Content-Disposition: form-data; name="request"\r\n` +
      `Content-Type: application/json\r\n\r\n` +
      JSON.stringify(request) +
      `\r\n--${boundary}\r\n` +
      `Content-Disposition: form-data; name="fileContent"; filename="${name}.png"\r\n` +
      `Content-Type: image/png\r\n\r\n`,
    "utf8"
  );
  const post = Buffer.from(`\r\n--${boundary}--\r\n`, "utf8");
  const body = Buffer.concat([pre, buf, post]);

  const res = await fetch(ASSETS, {
    method: "POST",
    headers: {
      "x-api-key": KEY,
      "Content-Type": `multipart/form-data; boundary=${boundary}`,
    },
    body,
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`upload ${name}: HTTP ${res.status} ${text.slice(0, 300)}`);
  }
  const op = JSON.parse(text);
  const opId = op.operationId || (op.path && op.path.split("/").pop());
  if (!opId) throw new Error(`upload ${name}: no operationId in ${text.slice(0, 200)}`);

  // poll the operation for the assetId
  for (let i = 0; i < 30; i++) {
    await sleep(1500);
    const pr = await fetch(OPS + opId, { headers: { "x-api-key": KEY } });
    const pt = await pr.text();
    if (!pr.ok) throw new Error(`poll ${name}: HTTP ${pr.status} ${pt.slice(0, 200)}`);
    const pj = JSON.parse(pt);
    if (pj.done) {
      const assetId = pj.response && (pj.response.assetId || pj.response.id);
      if (!assetId) throw new Error(`poll ${name}: done but no assetId ${pt.slice(0, 200)}`);
      return assetId;
    }
  }
  throw new Error(`poll ${name}: timed out`);
}

(async () => {
  let files = fs
    .readdirSync(DIR)
    .filter((f) => f.endsWith(".png") && f !== "contact_sheet.png")
    .map((f) => path.join(DIR, f));
  if (ONLY) files = files.filter((f) => path.basename(f, ".png") === ONLY);
  if (files.length === 0) {
    console.error("No matching png files in " + DIR + (ONLY ? " for --only " + ONLY : ""));
    process.exit(1);
  }

  const out = fs.existsSync(OUT) ? JSON.parse(fs.readFileSync(OUT, "utf8")) : {};
  let uploaded = 0,
    skipped = 0;
  for (const file of files) {
    const name = path.basename(file, ".png");
    // Resume / no-duplicates: skip a symbol already recorded in the OUT manifest. Re-running is
    // idempotent and only uploads the missing ones (use --force or delete the key to re-upload).
    if (out[name] && !args.includes("--force")) {
      console.log(`skip ${name} (already ${out[name]})`);
      skipped += 1;
      continue;
    }
    process.stdout.write(`uploading ${name} ... `);
    try {
      const id = await uploadOne(file);
      out[name] = id;
      uploaded += 1;
      console.log(id);
      fs.writeFileSync(OUT, JSON.stringify(out, null, 2)); // write incrementally
    } catch (e) {
      console.log("FAILED");
      console.error("  " + e.message);
    }
  }
  console.log(`\nWrote ${OUT} (uploaded ${uploaded}, skipped ${skipped})`);
})();
