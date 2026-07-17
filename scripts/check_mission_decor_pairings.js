#!/usr/bin/env node
/*
  Mission-decor PAIRING audit — answers Jason's question:

    "Is this Roblox rot, or did we map the wrong texture onto a different
     mesh generation after decimate/rebake?"

  SSOT: scripts/mission_decor_pairings.json
    - mesh_id          = MeshPart.MeshId (content id Roblox renders)
    - model_asset_id   = LoadAsset Model wrapper (NOT interchangeable with mesh_id)
    - bind_mode        = TextureID | SurfaceAppearance
    - color_map / texture_id = the albedo actually bound on that mesh
    - atlas_sha256 / fbx_sha256 = export lock for that generation

  Live dump: scripts/mission_decor_live_dump.json
    Refresh via Studio MCP / scripts/studio/dump_mission_decor_live.luau then
    save JSON here (or pipe MCP output).

  Usage:
    node scripts/check_mission_decor_pairings.js           # audit (exit 1 on issues)
    node scripts/check_mission_decor_pairings.js --json
    node scripts/check_mission_decor_pairings.js --stamp-from-live
      # rewrite pairings.props bind fields from live dump (keeps export hashes)

  Diagnosis cheatsheet when a prop looks kaleidoscoped:
    [live_mesh_drift]     MissionProps MeshId != blessed pairings mesh_id
                          → rbxm/transplant pointed at another generation
    [live_albedo_drift]   ColorMap/TextureID != blessed pair
                          → wrong atlas bound onto (possibly correct) mesh
    [cross_gen_texture]   legacy texture_ids.json id used as if it were this
                          gen's albedo (Studio-import TextureID vs SA ColorMap)
    [model_vs_mesh_confusion]
                          code/registry treated Model asset id as MeshId
    [pair_ok_still_ugly]  live matches blessed pair; grey mesh clean
                          → render/CDN class (not a pairing bug) — soak/eyes
*/

const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const PAIRINGS_PATH = path.join(ROOT, "scripts", "mission_decor_pairings.json");
const LIVE_PATH = path.join(ROOT, "scripts", "mission_decor_live_dump.json");
const MODEL_IDS_PATH = path.join(ROOT, "scripts", "mission_decor_model_ids.json");
const TEXTURE_IDS_PATH = path.join(ROOT, "scripts", "mission_decor_texture_ids.json");
const FINGERPRINTS_PATH = path.join(ROOT, "scripts", "mission_decor_fingerprints.json");

const args = new Set(process.argv.slice(2));
const jsonMode = args.has("--json");
const stampFromLive = args.has("--stamp-from-live");

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function strip(id) {
  if (id == null || id === "") return "";
  return String(id).replace(/^rbxassetid:\/\//, "");
}

function readIdMap(filePath) {
  if (!fs.existsSync(filePath)) return {};
  const raw = readJson(filePath);
  const out = {};
  for (const [k, v] of Object.entries(raw)) {
    if (k.startsWith("_")) continue;
    if (v == null || v === "") continue;
    out[k] = strip(v);
  }
  return out;
}

function albedoOf(entry) {
  if (!entry) return "";
  if (entry.bind_mode === "SurfaceAppearance") return strip(entry.color_map);
  if (entry.bind_mode === "TextureID") return strip(entry.texture_id);
  return strip(entry.color_map) || strip(entry.texture_id);
}

function liveAlbedo(livep) {
  if (!livep) return "";
  if (livep.bind_mode === "SurfaceAppearance") return strip(livep.color_map);
  if (livep.bind_mode === "TextureID") return strip(livep.texture_id);
  return strip(livep.color_map) || strip(livep.texture_id);
}

function audit() {
  const pairings = readJson(PAIRINGS_PATH);
  const live = fs.existsSync(LIVE_PATH) ? readJson(LIVE_PATH) : null;
  const modelIds = readIdMap(MODEL_IDS_PATH);
  const textureIds = readIdMap(TEXTURE_IDS_PATH);
  const fingerprints = fs.existsSync(FINGERPRINTS_PATH)
    ? readJson(FINGERPRINTS_PATH).props || {}
    : {};

  const report = [];
  const names = new Set([
    ...Object.keys(pairings.props || {}),
    ...Object.keys((live && live.props) || {}),
    ...Object.keys(modelIds),
    ...Object.keys(textureIds),
  ]);

  for (const name of [...names].sort()) {
    if (name.startsWith("_")) continue;
    const issues = [];
    const blessed = (pairings.props || {})[name];
    const livep = live && live.props && live.props[name];
    const fp = fingerprints[name];

    if (!blessed) {
      issues.push({
        code: "unblessed_prop",
        detail: "present live/registry but missing from mission_decor_pairings.json",
      });
    }

    if (blessed && livep) {
      if (strip(livep.mesh_id) !== strip(blessed.mesh_id)) {
        issues.push({
          code: "live_mesh_drift",
          detail: `live mesh ${livep.mesh_id} != blessed ${blessed.mesh_id}`,
        });
      }
      if (liveAlbedo(livep) !== albedoOf(blessed)) {
        issues.push({
          code: "live_albedo_drift",
          detail: `live albedo ${liveAlbedo(livep) || "∅"} != blessed ${albedoOf(blessed) || "∅"} (mode live=${livep.bind_mode} blessed=${blessed.bind_mode})`,
        });
      }
      if ((livep.bind_mode || "") !== (blessed.bind_mode || "")) {
        issues.push({
          code: "bind_mode_drift",
          detail: `live ${livep.bind_mode} != blessed ${blessed.bind_mode}`,
        });
      }
    } else if (blessed && !livep && live) {
      issues.push({
        code: "missing_live",
        detail: "blessed in pairings but absent from live dump",
      });
    }

    // Cross-generation traps (the multi-path bug class)
    if (blessed && blessed.bind_mode === "SurfaceAppearance" && !albedoOf(blessed)) {
      issues.push({
        code: "empty_albedo",
        detail: "SurfaceAppearance bind but color_map empty",
      });
    }
    if (blessed && textureIds[name] && textureIds[name] !== albedoOf(blessed)) {
      issues.push({
        code: "cross_gen_texture",
        detail: `texture_ids.json ${textureIds[name]} != blessed albedo ${albedoOf(blessed)} — do NOT paste that id onto this mesh_id`,
      });
    }
    if (fp && fp.roblox_mesh_id && blessed && strip(fp.roblox_mesh_id) !== strip(blessed.mesh_id)) {
      issues.push({
        code: "fingerprint_mesh_gen",
        detail: `fingerprints.json mesh ${fp.roblox_mesh_id} != blessed mesh ${blessed.mesh_id} (older export lock)`,
      });
    }
    if (fp && fp.roblox_texture_id && blessed && strip(fp.roblox_texture_id) !== albedoOf(blessed)) {
      issues.push({
        code: "fingerprint_texture_gen",
        detail: `fingerprints.json texture ${fp.roblox_texture_id} != blessed albedo ${albedoOf(blessed)}`,
      });
    }
    if (modelIds[name] && blessed && modelIds[name] === strip(blessed.mesh_id)) {
      issues.push({
        code: "model_vs_mesh_confusion",
        detail: `model_ids.json equals mesh_id (${modelIds[name]}) — Model wrapper and Mesh content id collided; verify which you mean`,
      });
    }
    if (modelIds[name] && blessed && modelIds[name] !== strip(blessed.model_asset_id || "")) {
      issues.push({
        code: "model_asset_drift",
        detail: `model_ids.json ${modelIds[name]} != pairings.model_asset_id ${blessed.model_asset_id || "∅"}`,
      });
    }

    if (issues.length) report.push({ prop: name, issues });
  }

  const HARD = new Set([
    "live_mesh_drift",
    "live_albedo_drift",
    "bind_mode_drift",
    "missing_live",
    "unblessed_prop",
    "empty_albedo",
  ]);
  const hard = [];
  const soft = [];
  for (const row of report) {
    const hardIssues = row.issues.filter((i) => HARD.has(i.code));
    const softIssues = row.issues.filter((i) => !HARD.has(i.code));
    if (hardIssues.length) hard.push({ prop: row.prop, issues: hardIssues });
    if (softIssues.length) soft.push({ prop: row.prop, issues: softIssues });
  }

  return {
    ok: hard.length === 0,
    generation: pairings.generation,
    blessed_at: pairings.blessed_at,
    live_captured_at: live && live.captured_at,
    hard_fails: hard,
    soft_warns: soft,
    drifts: report, // full (hard+soft) for --json consumers
  };
}

function stampFromLiveDump() {
  const pairings = readJson(PAIRINGS_PATH);
  const live = readJson(LIVE_PATH);
  const modelIds = readIdMap(MODEL_IDS_PATH);
  let updated = 0;
  for (const [name, livep] of Object.entries(live.props || {})) {
    const prev = pairings.props[name] || {};
    pairings.props[name] = {
      ...prev,
      mesh_id: strip(livep.mesh_id),
      model_asset_id: modelIds[name] || prev.model_asset_id || "",
      bind_mode: livep.bind_mode,
      texture_id: strip(livep.texture_id),
      color_map: strip(livep.color_map),
      normal_map: strip(livep.normal_map),
      has_skinned_mesh: livep.has_skinned_mesh,
      bone_count: livep.bone_count,
    };
    updated += 1;
  }
  pairings.blessed_at = live.captured_at || new Date().toISOString();
  pairings.blessed_source = live.source || "ReplicatedStorage.MissionProps";
  fs.writeFileSync(PAIRINGS_PATH, JSON.stringify(pairings, null, 2) + "\n");
  return updated;
}

function main() {
  if (stampFromLive) {
    const n = stampFromLiveDump();
    if (jsonMode) {
      console.log(JSON.stringify({ ok: true, stamped: n }, null, 2));
    } else {
      console.log(`stamped ${n} props from ${path.relative(ROOT, LIVE_PATH)} -> pairings`);
    }
    return;
  }

  const result = audit();
  if (jsonMode) {
    console.log(JSON.stringify(result, null, 2));
    if (!result.ok) process.exit(1);
    return;
  }

  const printBlock = (title, rows) => {
    if (!rows.length) return;
    console.log(`${title} (${rows.length} props):\n`);
    for (const row of rows) {
      console.log(`  ${row.prop}`);
      for (const issue of row.issues) {
        console.log(`    - [${issue.code}] ${issue.detail}`);
      }
    }
    console.log("");
  };

  printBlock("HARD FAIL — MissionProps vs blessed pair", result.hard_fails);
  printBlock("SOFT WARN — registry/export generation skew (multi-path trap)", result.soft_warns);

  if (result.ok && result.soft_warns.length === 0) {
    console.log(
      `mission-decor pairings OK (gen=${result.generation}; blessed ${result.blessed_at}; live ${result.live_captured_at || "no dump"})`
    );
  } else if (result.ok) {
    console.log(
      `mission-decor pairings LIVE-LOCKED (gen=${result.generation}) — ${result.soft_warns.length} soft warns (stale registries/exports)`
    );
  }

  console.log(`Cheatsheet:`);
  console.log(`  live_mesh_drift / live_albedo_drift → MissionProps no longer matches blessed pair (OUR transplant/rbxm bug)`);
  console.log(`  cross_gen_texture → texture_ids.json is a DIFFERENT generation's albedo — do not reuse`);
  console.log(`  fingerprint_*_gen → offline export lock is stale vs blessed live pair`);
  console.log(`  model_asset_drift → model_ids.json moved without re-bless / transplant`);
  console.log(`  pair matches + still ugly → render/CDN class (eyes/soak), not pairing`);
  console.log(`  Refresh live: scripts/studio/dump_mission_decor_live.luau → scripts/mission_decor_live_dump.json`);
  console.log(`  Re-bless after visual OK: node scripts/check_mission_decor_pairings.js --stamp-from-live`);

  if (!result.ok) process.exit(1);
}

main();
