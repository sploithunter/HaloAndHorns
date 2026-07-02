#!/usr/bin/env node
/*
  gen_layer2_pets.js — emit the configs/pets.lua entries (40 pets) + egg blocks (8) for layer 2,
  pulling resolved asset ids from scripts/pet_mesh_ids.json + scripts/egg_assets.json.
  Output is review-only Lua → /tmp/layer2_pets.lua and /tmp/layer2_eggs.lua. Insert by hand.

  Rarity ladder per origin: Common / Uncommon / Rare / Legendary / (Mythic apex | Secret dragon).
  base_power: C12 U16 R22 L33 M44 S46.  base_health: C60 U90 R130 L175 M220 S240 × role mod
  (tank ×1.4, blaster ×0.85).  egg weights: C50 U26 R6 L1.5 M0.26 S0.04.
*/
const fs = require("fs");
const path = require("path");
const root = path.resolve(__dirname, "..");
const pets = JSON.parse(fs.readFileSync(path.join(root, "scripts/pet_mesh_ids.json"), "utf8"));
const eggs = JSON.parse(fs.readFileSync(path.join(root, "scripts/egg_assets.json"), "utf8"));

const BP = { common: 12, uncommon: 16, rare: 22, legendary: 33, mythic: 44, secret: 46 };
const HP = { common: 60, uncommon: 90, rare: 130, legendary: 175, mythic: 220, secret: 240 };
const ROLE_HP = { tank: 1.4, blaster: 0.85, normal: 1.0 };
const WEIGHT = { common: 50, uncommon: 26, rare: 6, legendary: 1.5, mythic: 0.26, secret: 0.04 };

// [key, Display, rarity, role, zoom]; order = slot order (common→apex) within each origin block.
const SPEC = {
  // realm, origin, eggKey, dragon?  ->  pets[]
  "heaven/fire": { egg: "heaven2_fire_egg", pets: [
    ["coronal_cherub","Coronal Cherub","common","normal",1.5],
    ["prism_lion","Prism Lion","uncommon","normal",1.5],
    ["lance_seraph","Lance Seraph","rare","blaster",1.5],
    ["lumen_salamander","Lumen Salamander","legendary","normal",1.5],
    ["dawnfire_phoenix","Dawnfire Phoenix","mythic","blaster",1.6],
  ]},
  "heaven/ice": { egg: "heaven2_ice_egg", pets: [
    ["frostlight_doe","Frostlight Doe","common","normal",1.5],
    ["prism_fox","Prism Fox","uncommon","normal",1.5],
    ["starlight_owl","Starlight Owl","rare","blaster",1.5],
    ["glacial_bear","Glacial Bear","legendary","tank",1.6],
    ["aurora_dragon","Aurora Dragon","secret","normal",2.0],
  ]},
  "heaven/grass": { egg: "heaven2_grass_egg", pets: [
    ["bloomspirit_lamb","Bloomspirit Lamb","common","normal",1.5],
    ["lightleaf_hare","Lightleaf Hare","uncommon","normal",1.5],
    ["crystalbark_stag","Crystalbark Stag","rare","tank",1.5],
    ["radiant_sprite","Radiant Sprite","legendary","normal",1.5],
    ["worldbloom_ent","Worldbloom Ent","mythic","tank",1.6],
  ]},
  "heaven/desert": { egg: "heaven2_desert_egg", pets: [
    ["aurora_dove","Aurora Dove","common","normal",1.5],
    ["prism_scarab","Prism Scarab","uncommon","normal",1.5],
    ["mirage_meerkat","Mirage Meerkat","rare","normal",1.5],
    ["sunwell_camel","Sunwell Camel","legendary","normal",1.5],
    ["empyreal_couatl","Empyreal Couatl","mythic","normal",1.6],
  ]},
  "hell/fire": { egg: "hell2_fire_egg", pets: [
    ["frostcinder_imp","Frostcinder Imp","common","normal",1.5],
    ["rimemane_lion","Rimemane Lion","uncommon","normal",1.5],
    ["hoarfrost_phoenix","Hoarfrost Phoenix","rare","blaster",1.5],
    ["frostbrand_salamander","Frostbrand Salamander","legendary","normal",1.5],
    ["deadfire_phoenix","Deadfire Phoenix","mythic","blaster",1.6],
  ]},
  "hell/ice": { egg: "hell2_ice_egg", pets: [
    ["rimegloom_hare","Rimegloom Hare","common","normal",1.5],
    ["dread_fox","Dread Fox","uncommon","normal",1.5],
    ["gravefrost_owl","Gravefrost Owl","rare","blaster",1.5],
    ["rimeguard_bear","Rimeguard Bear","legendary","tank",1.6],
    ["rimewraith_dragon","Rimewraith Dragon","secret","normal",2.0],
  ]},
  "hell/grass": { egg: "hell2_grass_egg", pets: [
    ["frostblight_lamb","Frostblight Lamb","common","normal",1.5],
    ["gloom_hare","Gloom Hare","uncommon","normal",1.5],
    ["icerot_stag","Icerot Stag","rare","tank",1.5],
    ["rimewither_sprite","Rimewither Sprite","legendary","normal",1.5],
    ["frostgrave_ent","Frostgrave Ent","mythic","tank",1.6],
  ]},
  "hell/desert": { egg: "hell2_desert_egg", pets: [
    ["wraith_dove","Wraith Dove","common","normal",1.5],
    ["rime_scarab","Rime Scarab","uncommon","normal",1.5],
    ["gloom_jackal","Gloom Jackal","rare","normal",1.5],
    ["frostdust_camel","Frostdust Camel","legendary","normal",1.5],
    ["dread_couatl","Dread Couatl","mythic","normal",1.6],
  ]},
};

const EGG_NAME = {
  heaven2_fire_egg: "Coronal Egg", heaven2_ice_egg: "Prism Egg",
  heaven2_grass_egg: "Bloomlight Egg", heaven2_desert_egg: "Mirage Egg",
  hell2_fire_egg: "Frostcinder Egg", hell2_ice_egg: "Black-Ice Egg",
  hell2_grass_egg: "Frostblight Egg", hell2_desert_egg: "Frostcarrion Egg",
};
const A = (id) => (String(id).startsWith("rbxassetid://") ? String(id) : "rbxassetid://" + id);
function variant(stem, display) {
  const e = pets[stem];
  if (!e) throw new Error("missing registry: " + stem);
  return `mesh_asset = "${A(e.meshId)}", texture_asset = "${A(e.imageId)}", display_name = "${display}"`;
}

let petsOut = "", eggsOut = "";
for (const [ro, blk] of Object.entries(SPEC)) {
  const [realm, origin] = ro.split("/");
  petsOut += `\n        -- ===== ${realm} 2 · ${origin} =====\n`;
  for (const [key, disp, rar, role, zoom] of blk.pets) {
    const hp = Math.round(HP[rar] * ROLE_HP[role]);
    const bp = BP[rar];
    const b = pets[key + "_basic"], g = pets[key + "_gold"];
    if (!b || !g) throw new Error("missing variant: " + key);
    petsOut +=
`        ${key} = {
            display_name = "${disp}",
            category = "${realm}",
            realm = "${realm}",
            rarity = "${rar}",
            base_power = ${bp},
            base_health = ${hp},
            viewport_zoom = ${zoom},
            asset_transform = { scale = 1.6, huge_scale = 3, orientation = { x = 0, y = 0, z = 0 } },
            camera = { distance = 3.5, angle_y = 0, angle_x = 180, offset = Vector3.new(0, 0, 0), lighting = "default" },
            variants = {
                basic = { mesh_asset = "${A(b.meshId)}", texture_asset = "${A(b.imageId)}", display_name = "${disp}", abilities = {} },
                golden = { mesh_asset = "${A(g.meshId)}", texture_asset = "${A(g.imageId)}", display_name = "Golden ${disp}", abilities = {} },
                rainbow = { mesh_asset = "${A(b.meshId)}", texture_asset = "${A(b.imageId)}", display_name = "Rainbow ${disp}", abilities = {} },
            },
        },
`;
  }
  // egg block
  const eg = eggs[blk.egg];
  const dragon = blk.pets.find((p) => p[2] === "secret");
  const weights = blk.pets.map(([k, , rar]) => `                ${k} = ${WEIGHT[rar]},`).join("\n");
  const realmCoin = origin === "fire" ? "lava_coins" : origin === "ice" ? "ice_coins" : origin === "grass" ? "grass_coins" : "desert_coins";
  eggsOut +=
`        ${blk.egg} = {
            name = "${EGG_NAME[blk.egg]}",
            description = "Layer-2 ${realm} ${origin} egg.",
            world_placeable = true,
            cost = 5000,
            currency = "${realmCoin}",
            huge = { chance = 0.00002, any_pet = true },
            mesh_asset = "${A(eg.mesh_id)}",
            texture_asset = "${A(eg.mesh_image)}",
            image_id = "${A(eg.icon_image)}",
            camera = { distance = 3.5, angle_y = 0, angle_x = 180, offset = Vector3.new(0, 0, 0), lighting = "default" },
            pet_weights = {
${weights}
            },
            rarity_rates = { golden_chance = 0.05, rainbow_chance = 0.005 },
            variant_rolls = { enabled = true, allow_basic = true, allow_golden = true, allow_rainbow = true, cost_multiplier = 20 },
            modifier_support = { supports_luck_gamepass = true, supports_golden_gamepass = true, supports_rainbow_gamepass = true, max_luck_multiplier = 10.0 },
            hatching_time = 3,
            guaranteed_shiny_chance = 0,
            bonus_xp = 0,
        },
`;
}
fs.writeFileSync("/tmp/layer2_pets.lua", petsOut);
fs.writeFileSync("/tmp/layer2_eggs.lua", eggsOut);
console.log("wrote /tmp/layer2_pets.lua (" + petsOut.split("\n").length + " lines) + /tmp/layer2_eggs.lua");
