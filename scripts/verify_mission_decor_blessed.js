#!/usr/bin/env node
/*
  Verify a mission-decor prop against its blessed dump under
  scripts/mission_decor_blessed/<prop>.json.

  Usage:
    node scripts/verify_mission_decor_blessed.js heaven_gilded_bookcase
    node scripts/verify_mission_decor_blessed.js heaven_gilded_bookcase --live scripts/mission_decor_live_dump.json
*/

const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const prop = process.argv[2];
if (!prop) {
  console.error("usage: node scripts/verify_mission_decor_blessed.js <prop> [--live dump.json]");
  process.exit(2);
}

const args = process.argv.slice(3);
let livePath = path.join(ROOT, "scripts", "mission_decor_live_dump.json");
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--live") livePath = path.resolve(args[++i]);
}

const blessedPath = path.join(ROOT, "scripts", "mission_decor_blessed", `${prop}.json`);
if (!fs.existsSync(blessedPath)) {
  console.error(`missing blessed dump: ${path.relative(ROOT, blessedPath)}`);
  process.exit(1);
}

const blessed = JSON.parse(fs.readFileSync(blessedPath, "utf8"));
const pairings = JSON.parse(
  fs.readFileSync(path.join(ROOT, "scripts", "mission_decor_pairings.json"), "utf8")
);
const live = fs.existsSync(livePath) ? JSON.parse(fs.readFileSync(livePath, "utf8")) : null;

function strip(id) {
  return String(id || "").replace(/^rbxassetid:\/\//, "");
}

const issues = [];
const p = (pairings.props || {})[prop];
if (!p) issues.push("missing from mission_decor_pairings.json");
else {
  if (strip(p.mesh_id) !== strip(blessed.roblox.mesh_id)) {
    issues.push(`pairings mesh_id ${p.mesh_id} != blessed ${blessed.roblox.mesh_id}`);
  }
  const alb =
    p.bind_mode === "TextureID" ? p.texture_id : p.color_map || p.texture_id;
  const belAlb =
    blessed.roblox.bind_mode === "TextureID"
      ? blessed.roblox.texture_id
      : blessed.roblox.color_map || blessed.roblox.texture_id;
  if (strip(alb) !== strip(belAlb)) {
    issues.push(`pairings albedo ${alb} != blessed ${belAlb}`);
  }
  if ((p.bind_mode || "") !== (blessed.roblox.bind_mode || "")) {
    issues.push(`pairings bind_mode ${p.bind_mode} != blessed ${blessed.roblox.bind_mode}`);
  }
}

if (live && live.props && live.props[prop]) {
  const l = live.props[prop];
  if (strip(l.mesh_id) !== strip(blessed.roblox.mesh_id)) {
    issues.push(`live dump mesh_id ${l.mesh_id} != blessed ${blessed.roblox.mesh_id}`);
  }
  const lAlb =
    l.bind_mode === "TextureID" ? l.texture_id : l.color_map || l.texture_id;
  const belAlb =
    blessed.roblox.bind_mode === "TextureID"
      ? blessed.roblox.texture_id
      : blessed.roblox.color_map || blessed.roblox.texture_id;
  if (strip(lAlb) !== strip(belAlb)) {
    issues.push(`live dump albedo ${lAlb} != blessed ${belAlb}`);
  }
} else if (live) {
  issues.push(`live dump missing prop ${prop}`);
}

if (issues.length) {
  console.log(`BLESSED VERIFY FAIL (${prop}):`);
  for (const i of issues) console.log(`  - ${i}`);
  console.log(`\nBlessed file: ${path.relative(ROOT, blessedPath)}`);
  console.log(`Diagnose steps: see diagnose_if_bad_again in that file.`);
  process.exit(1);
}

console.log(
  `blessed OK: ${prop} mesh=${blessed.roblox.mesh_id} bind=${blessed.roblox.bind_mode} ` +
    `faces=${blessed.decor_fingerprint.faces} hash=${blessed.decor_fingerprint.hash}`
);
