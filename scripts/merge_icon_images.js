#!/usr/bin/env node
/*
  merge_icon_images.js — fold a Decal->Image resolution map into scripts/asset_manifest.json.

  Open Cloud uploads as Decals; the Decal id does NOT render in ImageLabel.Image. The real Image
  content id is the Decal.Texture, resolved in Studio EDIT mode via InsertService:LoadAsset(decal).
  That resolution is done over the Studio MCP; this script takes the resulting JSON map and writes
  the `image` field next to each matching `decal` in the manifest (discs[color][symbol] + rings).

  Input: a JSON file mapping { "<decalId>": "<imageId>", ... } (default scripts/_resolved.json,
  or pass a path as argv[2]).

  Usage: node scripts/merge_icon_images.js [scripts/_resolved.json]
*/
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const MANIFEST = path.join(ROOT, "scripts", "asset_manifest.json");
const MAP_PATH = path.resolve(ROOT, process.argv[2] || "scripts/_resolved.json");

const manifest = JSON.parse(fs.readFileSync(MANIFEST, "utf8"));
const map = JSON.parse(fs.readFileSync(MAP_PATH, "utf8"));
// Normalize keys/values to strings.
const resolved = {};
for (const [d, img] of Object.entries(map)) resolved[String(d)] = String(img);

let set = 0,
  missing = 0;
function applyBucket(bucket) {
  for (const [sym, rec] of Object.entries(bucket || {})) {
    if (sym.startsWith("_") || !rec || typeof rec !== "object") continue;
    if (rec.image) continue; // already resolved
    const img = rec.decal && resolved[String(rec.decal)];
    if (img) {
      rec.image = img;
      set += 1;
    } else {
      missing += 1;
    }
  }
}

for (const color of Object.keys(manifest.discs || {})) {
  if (color.startsWith("_")) continue;
  applyBucket(manifest.discs[color]);
}
applyBucket(manifest.rings);

fs.writeFileSync(MANIFEST, JSON.stringify(manifest, null, 2) + "\n");
console.log(`resolved images: ${set} set, ${missing} still unresolved.`);
