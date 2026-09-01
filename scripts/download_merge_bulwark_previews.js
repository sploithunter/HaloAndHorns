#!/usr/bin/env node

// Recover the transparent preview generated for each accepted Merge bulwark model.
// These are the source images for the flat UI cards. The runtime models remain independent:
// five families share one long, side-to-side presentation contract and Land Shark is the only
// special-case presentation.

const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const API_BASE = "https://api.meshy.ai/openapi/v1";
const SOURCE_MANIFEST = path.join(ROOT, "scripts", "merge_bulwark_model_ids.json");
const OUTPUT_DIR = path.join(ROOT, "assets", "ui", "merge_bulwarks");
const SOURCE_RECORD = path.join(ROOT, "scripts", "merge_bulwark_preview_sources.json");

function loadEnvLocal() {
  const envPath = path.join(ROOT, ".env.local");
  if (!fs.existsSync(envPath)) return;
  for (const rawLine of fs.readFileSync(envPath, "utf8").split(/\r?\n/)) {
    const match = rawLine.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (!match || process.env[match[1]]) continue;
    process.env[match[1]] = match[2].replace(/^["']|["']$/g, "");
  }
}

function pngDimensions(bytes) {
  if (bytes.length < 24 || bytes.toString("ascii", 1, 4) !== "PNG") return undefined;
  return [bytes.readUInt32BE(16), bytes.readUInt32BE(20)];
}

async function fetchTask(apiKey, taskId) {
  const response = await fetch(`${API_BASE}/retexture/${encodeURIComponent(taskId)}`, {
    headers: { Authorization: `Bearer ${apiKey}` },
  });
  const body = await response.text();
  if (!response.ok) throw new Error(`Meshy ${response.status}: ${body.slice(0, 240)}`);
  return JSON.parse(body);
}

async function download(url) {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Download ${response.status}: ${response.statusText}`);
  return Buffer.from(await response.arrayBuffer());
}

async function main() {
  loadEnvLocal();
  const apiKey = process.env.MESHY_API_KEY;
  if (!apiKey) throw new Error("MESHY_API_KEY is unavailable in the environment or .env.local.");

  const modelManifest = JSON.parse(fs.readFileSync(SOURCE_MANIFEST, "utf8"));
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  const records = {
    _note:
      "Transparent Meshy thumbnails recovered from the accepted retexture tasks. Five static families use the same long side-to-side UI presentation; Land Shark is the only special case.",
    sourceModelManifest: "scripts/merge_bulwark_model_ids.json",
    families: {},
  };

  const jobs = [];
  for (const [familyId, family] of Object.entries(modelManifest.families || {})) {
    records.families[familyId] = [];
    for (const tier of family.tiers || []) jobs.push({ familyId, tier });
  }

  let cursor = 0;
  const workers = Array.from({ length: Math.min(6, jobs.length) }, async () => {
    while (cursor < jobs.length) {
      const job = jobs[cursor++];
      const { familyId, tier } = job;
      const task = await fetchTask(apiKey, tier.retextureTaskId);
      if (task.status !== "SUCCEEDED" || !task.alpha_thumbnail_url) {
        throw new Error(`${familyId} tier ${tier.tier}: alpha thumbnail unavailable (${task.status})`);
      }
      const bytes = await download(task.alpha_thumbnail_url);
      const fileName = `${familyId}_tier${tier.tier}.png`;
      fs.writeFileSync(path.join(OUTPUT_DIR, fileName), bytes);
      records.families[familyId][tier.tier - 1] = {
        tier: tier.tier,
        retextureTaskId: tier.retextureTaskId,
        file: `assets/ui/merge_bulwarks/${fileName}`,
        dimensions: pngDimensions(bytes),
      };
      console.log(`${familyId} tier ${tier.tier}: ${fileName}`);
    }
  });

  await Promise.all(workers);
  fs.writeFileSync(SOURCE_RECORD, `${JSON.stringify(records, null, 2)}\n`);
  console.log(`Recovered ${jobs.length} previews into ${path.relative(ROOT, OUTPUT_DIR)}.`);
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
