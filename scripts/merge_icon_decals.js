#!/usr/bin/env node
/*
  merge_icon_decals.js — fold the per-color upload manifests (scripts/icon_ids.<color>.json,
  which hold { symbol: decalId } from upload_icons.js) into the master scripts/asset_manifest.json
  under discs[color][symbol] = { decal, image }.

  - Preserves any existing `image` id (resolved Decal->Texture). Only sets/updates `decal`.
  - Colors: white green red yellow blue. (Color == disc COLOR; the badge element key is mapped
    later in gen_power_icons.js: green->earth, red->fire, yellow->desert, blue->ice, white->neutral.)

  Usage: node scripts/merge_icon_decals.js
*/
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const MANIFEST = path.join(ROOT, "scripts", "asset_manifest.json");
const COLORS = ["white", "green", "red", "yellow", "blue", "purple"];

const manifest = JSON.parse(fs.readFileSync(MANIFEST, "utf8"));
manifest.discs = manifest.discs || {};

let added = 0,
  kept = 0;
for (const color of COLORS) {
  const p = path.join(ROOT, "scripts", `icon_ids.${color}.json`);
  if (!fs.existsSync(p)) {
    console.log(`(no icon_ids.${color}.json — skipping)`);
    continue;
  }
  const perColor = JSON.parse(fs.readFileSync(p, "utf8"));
  manifest.discs[color] = manifest.discs[color] || {};
  const bucket = manifest.discs[color];
  for (const [symbol, decal] of Object.entries(perColor)) {
    if (symbol.startsWith("_")) continue; // _note etc.
    const existing = bucket[symbol];
    if (existing && existing.image) {
      // keep resolved image; refresh decal id (should be identical)
      existing.decal = String(decal);
      kept += 1;
    } else {
      bucket[symbol] = { decal: String(decal), image: (existing && existing.image) || null };
      added += 1;
    }
  }
}

fs.writeFileSync(MANIFEST, JSON.stringify(manifest, null, 2) + "\n");

// Report how many still need Decal->Image resolution.
let unresolved = 0,
  total = 0;
for (const color of COLORS) {
  for (const [sym, rec] of Object.entries(manifest.discs[color] || {})) {
    if (sym.startsWith("_")) continue;
    total += 1;
    if (!rec.image) unresolved += 1;
  }
}
console.log(`merged decals: ${added} new, ${kept} already-resolved kept.`);
console.log(`discs total: ${total} | still need image resolution: ${unresolved}`);
