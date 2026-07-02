#!/usr/bin/env node
/*
  upload_audio.js — batch-upload local SFX (.mp3) to Roblox as Audio assets via the Open Cloud
  Assets API, poll each operation, and write the resulting asset ids to a manifest JSON.

  Usage:
    node scripts/upload_audio.js --dir assets/audio/sfx --creator-user 3200870803 [--only fireball_launch] [--out scripts/audio_ids.json]

  Reads ROBLOX_OPEN_CLOUD_KEY from the environment or .env.local (key needs the "asset" write
  scope). Audio uploads as type Audio; the returned assetId works as rbxassetid://<id> on a Sound.
  New uploads go through moderation (id assigned immediately; plays once approved). Idempotent —
  re-running skips ids already in the OUT manifest (use --force to re-upload).
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

const args = process.argv.slice(2);
function arg(name, def) {
  const i = args.indexOf("--" + name);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
}
const DIR = arg("dir", "assets/audio/sfx");
const ONLY = arg("only", null);
const OUT = arg("out", "scripts/audio_ids.json");
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
  const name = path.basename(file, ".mp3");
  const buf = fs.readFileSync(file);
  const request = {
    assetType: "Audio",
    displayName: name.slice(0, 50),
    description: "Power/combat SFX (auto-uploaded).",
    creationContext: { creator },
  };
  // Build multipart manually as one Buffer so fetch sets Content-Length (Roblox rejects the
  // chunked, no-length body that native fetch+FormData produces).
  const boundary = "----rbxAudioUpload" + Date.now() + Math.floor(Math.random() * 1e6);
  const pre = Buffer.from(
    `--${boundary}\r\n` +
      `Content-Disposition: form-data; name="request"\r\n` +
      `Content-Type: application/json\r\n\r\n` +
      JSON.stringify(request) +
      `\r\n--${boundary}\r\n` +
      `Content-Disposition: form-data; name="fileContent"; filename="${name}.mp3"\r\n` +
      `Content-Type: audio/mpeg\r\n\r\n`,
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
  if (!res.ok) {
    throw new Error(`upload ${name}: HTTP ${res.status} ${text.slice(0, 400)}`);
  }
  const op = JSON.parse(text);
  const opId = op.operationId || (op.path && op.path.split("/").pop());
  if (!opId) throw new Error(`upload ${name}: no operationId in ${text.slice(0, 200)}`);

  for (let i = 0; i < 40; i++) {
    await sleep(1500);
    const pr = await fetch(OPS + opId, { headers: { "x-api-key": KEY } });
    const pt = await pr.text();
    if (!pr.ok) throw new Error(`poll ${name}: HTTP ${pr.status} ${pt.slice(0, 200)}`);
    const pj = JSON.parse(pt);
    if (pj.done) {
      const assetId = pj.response && (pj.response.assetId || pj.response.id);
      if (!assetId) throw new Error(`poll ${name}: done but no assetId ${pt.slice(0, 300)}`);
      return assetId;
    }
  }
  throw new Error(`poll ${name}: timed out`);
}

(async () => {
  let files = fs
    .readdirSync(DIR)
    .filter((f) => f.endsWith(".mp3"))
    .map((f) => path.join(DIR, f));
  if (ONLY) files = files.filter((f) => path.basename(f, ".mp3") === ONLY);
  if (files.length === 0) {
    console.error("No matching mp3 files in " + DIR + (ONLY ? " for --only " + ONLY : ""));
    process.exit(1);
  }

  const out = fs.existsSync(OUT) ? JSON.parse(fs.readFileSync(OUT, "utf8")) : {};
  let uploaded = 0,
    skipped = 0;
  for (const file of files) {
    const name = path.basename(file, ".mp3");
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
      fs.writeFileSync(OUT, JSON.stringify(out, null, 2)); // incremental
    } catch (e) {
      console.log("FAILED");
      console.error("  " + e.message);
    }
  }
  console.log(`\nWrote ${OUT} (uploaded ${uploaded}, skipped ${skipped})`);
})();
