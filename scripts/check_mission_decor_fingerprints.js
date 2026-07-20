#!/usr/bin/env node
/*
  Mission-decor EXPORT lock — atlas/FBX hashes + claimed Roblox ids.

  Companion (LIVE pairing SSOT): scripts/check_mission_decor_pairings.js
    That tool answers "wrong-generation albedo on this mesh?" by comparing
    MissionProps MeshId + ColorMap/TextureID to scripts/mission_decor_pairings.json.
    This file only locks exports on disk + registry claims.

  NOTE: mission_decor_model_ids.json stores LoadAsset MODEL wrappers — not MeshId.
  Fingerprint field roblox_mesh_id must be the MeshPart.MeshId (from live dump /
  pairings), never the Model asset id.

  Usage:
    node scripts/check_mission_decor_fingerprints.js --stamp
    node scripts/check_mission_decor_fingerprints.js --check
    node scripts/check_mission_decor_fingerprints.js --json

  Ledger: scripts/mission_decor_fingerprints.json
*/

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const EXPORT_ROOT = path.join(ROOT, "assets", "exports", "props", "meshy_mission_decor");
const LEDGER_PATH = path.join(ROOT, "scripts", "mission_decor_fingerprints.json");
const PAIRINGS_PATH = path.join(ROOT, "scripts", "mission_decor_pairings.json");
const MODEL_IDS_PATH = path.join(ROOT, "scripts", "mission_decor_model_ids.json");
const TEXTURE_IDS_PATH = path.join(ROOT, "scripts", "mission_decor_texture_ids.json");

const args = new Set(process.argv.slice(2));
const stampMode = args.has("--stamp");
const checkMode = args.has("--check") || !stampMode;
const jsonMode = args.has("--json");

function sha256File(filePath) {
  const hash = crypto.createHash("sha256");
  hash.update(fs.readFileSync(filePath));
  return hash.digest("hex");
}

function readIdMap(filePath) {
  if (!fs.existsSync(filePath)) return {};
  const raw = JSON.parse(fs.readFileSync(filePath, "utf8"));
  const out = {};
  for (const [k, v] of Object.entries(raw)) {
    if (k.startsWith("_")) continue;
    if (v == null || v === "") continue;
    out[k] = String(v).replace(/^rbxassetid:\/\//, "");
  }
  return out;
}

function preferBakedFbx(dir, prop) {
  const names = fs.readdirSync(dir).filter((n) => n.endsWith(".fbx"));
  const baked = names
    .filter((n) => n.includes("_baked"))
    .sort()
    .reverse(); // prefer higher label like 10k over 7k when lexicographic helps
  const tenK = baked.find((n) => n.includes("_10k_"));
  if (tenK) return path.join(dir, tenK);
  if (baked[0]) return path.join(dir, baked[0]);
  const plain = names.find((n) => n.startsWith(prop));
  return plain ? path.join(dir, plain) : null;
}

function readPairingsMeshAlbedo() {
  // Prefer pairings.json (MeshId + ColorMap/TextureID).
  // model_ids.json is a LoadAsset MODEL wrapper — never treat it as MeshId.
  if (!fs.existsSync(PAIRINGS_PATH)) return { mesh: {}, albedo: {} };
  const raw = JSON.parse(fs.readFileSync(PAIRINGS_PATH, "utf8"));
  const mesh = {};
  const albedo = {};
  for (const [name, p] of Object.entries(raw.props || {})) {
    if (p.mesh_id) mesh[name] = String(p.mesh_id).replace(/^rbxassetid:\/\//, "");
    const alb = p.bind_mode === "TextureID" ? p.texture_id : p.color_map || p.texture_id;
    if (alb) albedo[name] = String(alb).replace(/^rbxassetid:\/\//, "");
  }
  return { mesh, albedo };
}

function collectProps() {
  if (!fs.existsSync(EXPORT_ROOT)) {
    throw new Error(`missing export root: ${EXPORT_ROOT}`);
  }
  const pairings = readPairingsMeshAlbedo();
  const textureIds = readIdMap(TEXTURE_IDS_PATH);
  const modelIds = readIdMap(MODEL_IDS_PATH);
  const names = new Set([
    ...Object.keys(pairings.mesh),
    ...Object.keys(textureIds),
    ...Object.keys(modelIds),
    ...fs
      .readdirSync(EXPORT_ROOT, { withFileTypes: true })
      .filter((d) => d.isDirectory() && !d.name.startsWith("_"))
      .map((d) => d.name),
  ]);

  const props = {};
  for (const name of [...names].sort()) {
    const dir = path.join(EXPORT_ROOT, name);
    const atlas = path.join(dir, `${name}.png`);
    const fbx = fs.existsSync(dir) ? preferBakedFbx(dir, name) : null;
    const entry = {
      atlas_path: fs.existsSync(atlas) ? path.relative(ROOT, atlas).split(path.sep).join("/") : null,
      atlas_sha256: fs.existsSync(atlas) ? sha256File(atlas) : null,
      fbx_path: fbx ? path.relative(ROOT, fbx).split(path.sep).join("/") : null,
      fbx_sha256: fbx ? sha256File(fbx) : null,
      roblox_mesh_id: pairings.mesh[name] || null,
      roblox_texture_id: pairings.albedo[name] || textureIds[name] || null,
      roblox_model_asset_id: modelIds[name] || null,
    };
    props[name] = entry;
  }
  return props;
}

function loadLedger() {
  if (!fs.existsSync(LEDGER_PATH)) return { _comment: "", props: {} };
  return JSON.parse(fs.readFileSync(LEDGER_PATH, "utf8"));
}

function diffProp(name, expected, actual) {
  const issues = [];
  if (!expected) {
    issues.push({ code: "new_prop", detail: "present on disk/registries but missing from ledger" });
    return issues;
  }
  const fields = [
    ["atlas_sha256", "atlas_changed"],
    ["fbx_sha256", "fbx_changed"],
    ["roblox_mesh_id", "mesh_id_changed"],
    ["roblox_texture_id", "texture_id_changed"],
  ];
  for (const [field, code] of fields) {
    if ((expected[field] || null) !== (actual[field] || null)) {
      issues.push({
        code,
        detail: `${field}: ledger=${expected[field] || "∅"} now=${actual[field] || "∅"}`,
      });
    }
  }
  if (!actual.atlas_sha256) {
    issues.push({ code: "missing_atlas", detail: `expected ${name}.png under exports` });
  }
  if (!actual.fbx_sha256) {
    issues.push({ code: "missing_fbx", detail: `expected a *_baked.fbx under exports/${name}` });
  }
  if (!actual.roblox_mesh_id || !actual.roblox_texture_id) {
    issues.push({
      code: "unpaired_registry",
      detail: `mesh=${actual.roblox_mesh_id || "∅"} texture=${actual.roblox_texture_id || "∅"}`,
    });
  }
  return issues;
}

function main() {
  const actual = collectProps();
  if (stampMode) {
    const ledger = {
      _comment:
        "Mission-decor generation lock. atlas_sha256 + fbx_sha256 + roblox mesh/texture ids must move together. Stamp after a known-good rebake/import; --check warns when any field drifts. Does NOT prove Roblox CDN content is unchanged — only that OUR exports+registries stayed locked.",
      stamped_at: new Date().toISOString(),
      props: actual,
    };
    fs.writeFileSync(LEDGER_PATH, JSON.stringify(ledger, null, 2) + "\n");
    if (!jsonMode) {
      console.log(`stamped ${Object.keys(actual).length} props -> ${path.relative(ROOT, LEDGER_PATH)}`);
    } else {
      console.log(JSON.stringify({ ok: true, stamped: Object.keys(actual).length }, null, 2));
    }
    return;
  }

  const ledger = loadLedger();
  const expectedProps = ledger.props || {};
  const report = [];
  const allNames = new Set([...Object.keys(expectedProps), ...Object.keys(actual)]);
  for (const name of [...allNames].sort()) {
    if (!actual[name]) {
      report.push({
        prop: name,
        issues: [{ code: "missing_prop", detail: "in ledger but absent from exports/registries" }],
      });
      continue;
    }
    const issues = diffProp(name, expectedProps[name], actual[name]);
    if (issues.length) report.push({ prop: name, issues });
  }

  if (jsonMode) {
    console.log(JSON.stringify({ ok: report.length === 0, drifts: report }, null, 2));
  } else if (report.length === 0) {
    console.log(
      `mission-decor fingerprints OK (${Object.keys(actual).length} props; ledger ${ledger.stamped_at || "unspecified"})`
    );
  } else {
    console.log(`mission-decor fingerprint DRIFT (${report.length} props):\n`);
    for (const row of report) {
      console.log(`  ${row.prop}`);
      for (const issue of row.issues) {
        console.log(`    - [${issue.code}] ${issue.detail}`);
      }
    }
    console.log(`\nTrace next:`);
    console.log(`  atlas_changed / fbx_changed  → rebake overwrote exports (Blender lane)`);
    console.log(`  mesh_id_changed / texture_id_changed → registry edit without matching export stamp`);
    console.log(`  unpaired_registry → model/texture id maps disagree`);
    console.log(`  Re-stamp only after verifying in-engine: node scripts/check_mission_decor_fingerprints.js --stamp`);
  }

  if (checkMode && report.length > 0) process.exit(1);
}

main();
