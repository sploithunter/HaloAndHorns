#!/usr/bin/env node
/* One-shot: add `origin` (lava/ice/grass/desert) to the 40 layer-2 pets, bump the 6 Mythic apexes
   to the Legendary↔Secret midpoint (bp 44->40, hp base 220->207), and register all 40 in
   combat_fx.lua origin.pettype_element so the RPS/stats/VFX resolve. */
const fs = require("fs");
const path = require("path");
const root = path.resolve(__dirname, "..");

const ORIGIN = {
  lava: ["coronal_cherub","prism_lion","lance_seraph","lumen_salamander","dawnfire_phoenix",
         "frostcinder_imp","rimemane_lion","hoarfrost_phoenix","frostbrand_salamander","deadfire_phoenix"],
  ice: ["frostlight_doe","prism_fox","starlight_owl","glacial_bear","aurora_dragon",
        "rimegloom_hare","dread_fox","gravefrost_owl","rimeguard_bear","rimewraith_dragon"],
  grass: ["bloomspirit_lamb","lightleaf_hare","crystalbark_stag","radiant_sprite","worldbloom_ent",
          "frostblight_lamb","gloom_hare","icerot_stag","rimewither_sprite","frostgrave_ent"],
  desert: ["aurora_dove","prism_scarab","mirage_meerkat","sunwell_camel","empyreal_couatl",
           "wraith_dove","rime_scarab","gloom_jackal","frostdust_camel","dread_couatl"],
};
const keyOrigin = {};
for (const [o, ks] of Object.entries(ORIGIN)) for (const k of ks) keyOrigin[k] = o;
// Mythic apexes: new base_health by role after base 220->207.
const MYTHIC_HP = {
  dawnfire_phoenix: 176, deadfire_phoenix: 176,        // blaster 207*0.85
  worldbloom_ent: 290, frostgrave_ent: 290,            // tank 207*1.4
  empyreal_couatl: 207, dread_couatl: 207,             // normal
};

// --- patch configs/pets.lua ---
const pf = path.join(root, "configs/pets.lua");
let s = fs.readFileSync(pf, "utf8");
let added = 0, bumped = 0;
for (const key of Object.keys(keyOrigin)) {
  const open = `        ${key} = {`;
  const i = s.indexOf(open);
  if (i < 0) throw new Error("pet not found: " + key);
  const j = s.indexOf("\n        },\n", i);
  if (j < 0) throw new Error("entry end not found: " + key);
  let entry = s.slice(i, j);
  if (!/\n            origin = /.test(entry)) {
    entry = entry.replace(/(\n            realm = "[^"]+",)/, `$1\n            origin = "${keyOrigin[key]}",`);
    added++;
  }
  if (MYTHIC_HP[key]) {
    entry = entry.replace(/base_power = 44,/, "base_power = 40,");
    entry = entry.replace(/base_health = \d+,/, `base_health = ${MYTHIC_HP[key]},`);
    bumped++;
  }
  s = s.slice(0, i) + entry + s.slice(j);
}
fs.writeFileSync(pf, s);

// --- patch configs/combat_fx.lua: register the 40 in pettype_element ---
const cf = path.join(root, "configs/combat_fx.lua");
let c = fs.readFileSync(cf, "utf8");
const anchor = "pettype_element = {\n";
const ai = c.indexOf(anchor);
if (ai < 0) throw new Error("pettype_element anchor not found");
if (c.includes("coronal_cherub =")) throw new Error("layer-2 already in pettype_element");
const lines = Object.keys(keyOrigin).map((k) => `            ${k} = "${keyOrigin[k]}",`).join("\n");
const at = ai + anchor.length;
c = c.slice(0, at) + `            -- Layer 2 (Heaven 2 / Hell 2) — origin = biome RPS element (mirrors pet config .origin).\n` + lines + "\n" + c.slice(at);
fs.writeFileSync(cf, c);

console.log(`pets.lua: +${added} origin fields, ${bumped} mythic bumps. combat_fx.lua: +40 pettype_element.`);
