#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const ROOT = path.resolve(__dirname, "..");
const OUTPUT_PATH = path.join(ROOT, "configs/merge_tier_art.lua");
const PROOF_PATH = path.join(ROOT, "scripts/merge_tier_runtime_manifest.json");
const CANNON_MANIFEST_PATH = path.join(ROOT, "scripts/merge_cannon_model_ids.json");
const CANNON_PREVIEW_PATH = path.join(ROOT, "scripts/merge_cannon_preview_ids.json");
const CANNON_PREVIEW_DECALS_PATH = path.join(ROOT, "scripts/merge_cannon_preview_decals.json");
const CANNON_PREVIEW_SOURCE_PATH = path.join(ROOT, "scripts/merge_cannon_preview_sources.json");
const BULWARK_MANIFEST_PATH = path.join(ROOT, "scripts/merge_bulwark_model_ids.json");
const BULWARK_PREVIEW_PATH = path.join(ROOT, "scripts/merge_bulwark_preview_ids.json");

const CANNON_FAMILIES = ["heal", "rage", "debuff", "gravity", "repulsor", "nullifier"];
const BULWARK_FAMILIES = [
  "impaler_palisade",
  "concertina_line",
  "land_shark",
  "saw_blade",
  "grasping_hedge",
  "wardstone_barrier",
];

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function quote(value) {
  return JSON.stringify(String(value));
}

function orderedTiers(entries, label) {
  assert(Array.isArray(entries), `${label}: tier list is missing`);
  const byTier = new Map(entries.map((entry) => [Number(entry.tier), entry]));
  const tiers = [1, 2, 3, 4].map((tier) => byTier.get(tier));
  assert(tiers.every(Boolean), `${label}: expected tiers 1 through 4`);
  return tiers;
}

function validateUnique(entries, field, label) {
  const values = entries.map((entry) => String(entry[field] || ""));
  assert(values.every(Boolean), `${label}: ${field} is missing`);
  assert(new Set(values).size === values.length, `${label}: ${field} values are not distinct`);
}

function validateCannonPreviewFiles(sourceManifest) {
  const records = Array.isArray(sourceManifest.records) ? sourceManifest.records : [];
  assert(sourceManifest.status === "COMPLETE", "cannon preview sources: status is not COMPLETE");
  assert(records.length === 24, "cannon preview sources: expected 24 records");
  const seen = new Set();
  const hashes = new Set();
  for (const record of records) {
    const key = `${record.family}:${Number(record.tier)}`;
    assert(!seen.has(key), `cannon preview sources: duplicate ${key}`);
    seen.add(key);
    const filePath = path.join(ROOT, String(record.file || ""));
    assert(fs.existsSync(filePath), `cannon preview source is missing: ${record.file}`);
    const bytes = fs.readFileSync(filePath);
    assert(bytes.length >= 26 && bytes.toString("ascii", 1, 4) === "PNG", `${record.file}: not PNG`);
    assert(bytes.readUInt32BE(16) === 256 && bytes.readUInt32BE(20) === 256, `${record.file}: not 256x256`);
    assert(bytes[25] === 6, `${record.file}: PNG is not RGBA`);
    const digest = crypto.createHash("sha256").update(bytes).digest("hex");
    assert(digest === record.sha256, `${record.file}: sha256 mismatch`);
    hashes.add(digest);
  }
  assert(hashes.size === 24, "cannon preview sources: PNG hashes are not distinct");
  for (const family of CANNON_FAMILIES) {
    for (const tier of [1, 2, 3, 4]) {
      assert(seen.has(`${family}:${tier}`), `cannon preview sources: missing ${family} tier ${tier}`);
    }
  }
}

function collect() {
  const cannonManifest = readJson(CANNON_MANIFEST_PATH);
  const cannonPreviews = readJson(CANNON_PREVIEW_PATH);
  const cannonPreviewDecals = readJson(CANNON_PREVIEW_DECALS_PATH);
  const cannonPreviewSources = readJson(CANNON_PREVIEW_SOURCE_PATH);
  const bulwarkManifest = readJson(BULWARK_MANIFEST_PATH);
  const bulwarkPreviews = readJson(BULWARK_PREVIEW_PATH);
  const cannons = {};
  const bulwarks = {};

  validateCannonPreviewFiles(cannonPreviewSources);

  for (const family of CANNON_FAMILIES) {
    const tiers = orderedTiers(cannonManifest.families?.[family]?.tiers, `cannon ${family}`);
    const previews = orderedTiers(cannonPreviews.families?.[family], `cannon preview ${family}`);
    cannons[family] = tiers.map((entry, index) => ({
      tier: Number(entry.tier),
      modelAssetId: String(entry.roblox.modelAssetId),
      meshId: String(entry.roblox.meshId),
      textureId: String(entry.roblox.textureId),
      previewDecalId: String(previews[index].decalId),
      previewImageId: String(previews[index].imageId),
      templateScale: Number(entry.runtime.templateScale),
      barrelYawDegrees: Number(entry.runtime.barrelYawDegrees || 0),
      worldScale: Number(entry.runtime.worldScale || 1),
      seatOffsetY: Number(entry.runtime.seatOffsetY || 0),
    }));
    assert(
      cannons[family].every((entry) => entry.templateScale === 1),
      `cannon ${family}: runtime template scale must be 1`,
    );
    for (const entry of cannons[family]) {
      const key = `${family}_tier${entry.tier}`;
      assert(
        String(cannonPreviewDecals[key] || "") === entry.previewDecalId,
        `cannon preview ${key}: upload Decal id does not match the resolved manifest`,
      );
    }
  }

  for (const family of BULWARK_FAMILIES) {
    const tiers = orderedTiers(bulwarkManifest.families?.[family]?.tiers, `bulwark ${family}`);
    const previews = orderedTiers(bulwarkPreviews.families?.[family], `bulwark preview ${family}`);
    bulwarks[family] = tiers.map((entry, index) => ({
      tier: Number(entry.tier),
      modelAssetId: String(entry.modelAssetId),
      meshId: String(entry.meshId),
      textureId: String(entry.textureId),
      previewDecalId: String(previews[index].decalId),
      previewImageId: String(previews[index].imageId),
    }));
  }

  const cannonEntries = CANNON_FAMILIES.flatMap((family) => cannons[family]);
  const bulwarkEntries = BULWARK_FAMILIES.flatMap((family) => bulwarks[family]);
  for (const field of ["modelAssetId", "meshId", "textureId"]) {
    validateUnique(cannonEntries, field, "all cannon tiers");
    validateUnique(bulwarkEntries, field, "all bulwark tiers");
  }
  validateUnique(cannonEntries, "previewDecalId", "all cannon tier previews");
  validateUnique(cannonEntries, "previewImageId", "all cannon tier previews");
  validateUnique(bulwarkEntries, "previewDecalId", "all bulwark tier previews");
  validateUnique(bulwarkEntries, "previewImageId", "all bulwark tier previews");

  return { cannons, bulwarks };
}

function renderRegistry(name, families, familyOrder, fields) {
  const lines = [`local ${name} = {`];
  for (const family of familyOrder) {
    lines.push(`    ${family} = {`);
    for (const entry of families[family]) {
      lines.push("        {");
      lines.push(`            tier = ${entry.tier},`);
      for (const field of fields) {
        lines.push(`            ${field} = ${quote(entry[field])},`);
      }
      if (Number.isFinite(entry.barrelYawDegrees) && Number(entry.barrelYawDegrees) !== 0) {
        lines.push(`            barrelYawDegrees = ${Number(entry.barrelYawDegrees)},`);
      }
      if (Number.isFinite(entry.worldScale)) {
        lines.push(`            worldScale = ${Number(entry.worldScale)},`);
      }
      if (Number.isFinite(entry.seatOffsetY) && Number(entry.seatOffsetY) !== 0) {
        lines.push(`            seatOffsetY = ${Number(entry.seatOffsetY)},`);
      }
      lines.push("        },");
    }
    lines.push("    },");
  }
  lines.push("}");
  return lines.join("\n");
}

function render(document) {
  return `-- @generated by scripts/sync_merge_tier_art.js; do not hand-edit asset ids.\n-- Model/Mesh/Texture and flat workshop preview ids come from the proof manifests.\n-- Cannon and bulwark menus use transparent images instead of live 3D ViewportFrames.\n\n${renderRegistry("CANNONS", document.cannons, CANNON_FAMILIES, [
    "modelAssetId",
    "meshId",
    "textureId",
    "previewDecalId",
    "previewImageId",
  ])}\n\n${renderRegistry("BULWARKS", document.bulwarks, BULWARK_FAMILIES, [
    "modelAssetId",
    "meshId",
    "textureId",
    "previewDecalId",
    "previewImageId",
  ])}\n\nreturn {\n    cannons = CANNONS,\n    bulwarks = BULWARKS,\n}\n`;
}

function renderProof(document) {
  const flatten = (families, order) =>
    order.flatMap((family) => families[family].map((entry) => ({ family, ...entry })));
  const proof = {
    schemaVersion: 1,
    status: "COMPLETE",
    sourceManifests: [
      "scripts/merge_cannon_model_ids.json",
      "scripts/merge_cannon_preview_sources.json",
      "scripts/merge_cannon_preview_decals.json",
      "scripts/merge_cannon_preview_ids.json",
      "scripts/merge_bulwark_model_ids.json",
      "scripts/merge_bulwark_preview_ids.json",
    ],
    runtimeConfig: "configs/merge_tier_art.lua",
    runtimeConsumers: [
      "src/Shared/Game/MergeTowerProgression.lua",
      "src/Shared/Game/MergeBulwarkProgression.lua",
      "src/Shared/Game/MergeTowerModels.lua",
      "src/Shared/Game/MergeBulwarkModels.lua",
    ],
    counts: {
      cannonFamilies: CANNON_FAMILIES.length,
      cannonTierMappings: CANNON_FAMILIES.length * 4,
      cannonPreviewMappings: CANNON_FAMILIES.length * 4,
      bulwarkFamilies: BULWARK_FAMILIES.length,
      bulwarkTierMappings: BULWARK_FAMILIES.length * 4,
      bulwarkPreviewMappings: BULWARK_FAMILIES.length * 4,
      distinctModelAssets: (CANNON_FAMILIES.length + BULWARK_FAMILIES.length) * 4,
    },
    cannons: flatten(document.cannons, CANNON_FAMILIES),
    bulwarks: flatten(document.bulwarks, BULWARK_FAMILIES),
  };
  return `${JSON.stringify(proof, null, 2)}\n`;
}

function main() {
  const command = process.argv[2] || "check";
  const document = collect();
  const expected = render(document);
  const expectedProof = renderProof(document);
  if (command === "write") {
    fs.writeFileSync(OUTPUT_PATH, expected);
    fs.writeFileSync(PROOF_PATH, expectedProof);
    console.log(`wrote ${path.relative(ROOT, OUTPUT_PATH)}`);
    console.log(`wrote ${path.relative(ROOT, PROOF_PATH)}`);
    return;
  }
  if (command === "check") {
    const current = fs.existsSync(OUTPUT_PATH) ? fs.readFileSync(OUTPUT_PATH, "utf8") : "";
    const currentProof = fs.existsSync(PROOF_PATH) ? fs.readFileSync(PROOF_PATH, "utf8") : "";
    if (current !== expected || currentProof !== expectedProof) {
      throw new Error(
        "Merge tier art registry or proof manifest is stale; run `node scripts/sync_merge_tier_art.js write`.",
      );
    }
    console.log("PASS: Merge tier art registry matches cannon, bulwark, and preview manifests");
    return;
  }
  throw new Error("usage: node scripts/sync_merge_tier_art.js [write|check]");
}

try {
  main();
} catch (error) {
  console.error(error.message || error);
  process.exitCode = 1;
}
