--[[
    Power / status icons — Halo & Horns [PROTOTYPE].

    Roblox Image asset ids for the hotbar slots, pet status badges, and squad action
    buttons. Imported as Images (correct for ImageLabel). Aura art = squad/AoE,
    target art = single-target. Add ids here as they're made; UI falls back to text
    labels for anything without an icon.

    SCALE: many imported icons carry a transparent margin/border baked into the
    image. Containers clip their icon, so a scale > 1 zooms the art to crop that
    border away. `default_scale` applies to every icon; `scales` overrides per asset
    id when one piece of art needs more/less zoom. Tune live, then record here.
]]

local function id(n)
    return "rbxassetid://" .. n
end

-- Disc + ring IMAGE ids are GENERATED from scripts/asset_manifest.json into power_icons_assets.lua
-- (single source of truth — never hand-edit ids). Re-run `mise run gen-icons` after uploading icons.
-- discs[element][symbol] covers all 5 colors (earth/fire/desert/ice + neutral=white generic) × 31
-- symbols; rings[shape] = the 5 targeting frames.
local Assets = require(script.Parent:WaitForChild("power_icons_assets"))

local M = {
    -- Hotbar slot icon per power id (falls back to the slot's text label if absent).
    powers = {
        stone_skin = id(120424299023186), -- shield, single target
        bulwark = id(73499491406959), -- shield aura (squad damage-reduction)
        ice_armor = id(73499491406959),
        dune_shield = id(73499491406959),
        ember_ward = id(73499491406959),
        dodge = id(120424299023186),
        mountains_strength = id(102528688168498), -- damage buff aura
    },

    -- Pet status-badge icons (keys match SquadHud PET_EFFECTS). Use the new icon set so the
    -- buff badges match the hotbar/squad badges (the old flat assets read "wrong" next to them).
    status = {
        defense = id(99602330844217), -- DEF (Bulwark) -> ice armor disc (blue armor_chest)
        shield = id(121311806877255), -- SH (absorption pool) -> white shield disc
        damage = id(111373865269609), -- DMG (damage buff) -> green chevrons_up disc
    },

    -- Squad-HUD action buttons.
    actions = {
        heal = id(109752593245713), -- heal aura
        buff = id(102528688168498), -- damage buff aura
    },

    -- Spare art ready for single-target / assist-target variants when those land.
    spare = {
        heal_target = id(124914444699157),
        damage_target = id(91449088100042),
        shield_target = id(120424299023186),
    },

    -- Ring FRAMES (the 5 grayscale rings, uploaded white; tinted per element via ImageColor3).
    -- The SHAPE conveys TARGETING; the COLOR (tint) conveys element of origin. Layer a bright
    -- disc behind a dark ring + a white symbol to build an archetype/power badge in code, so we
    -- never have to upload a colored ring per element.
    -- NB: ids below are the IMAGE content ids (resolved from the uploaded Decals via the
    -- Decal.Texture each wraps). The Decal ids themselves do NOT render in ImageLabel.Image.
    rings = Assets.rings, -- GENERATED (target_in/target_out/aoe/target_aoe/aura)

    -- Per-ring CENTERING nudge — a fraction of the badge SIZE added to the ring's Position (which
    -- stays anchored .5,.5 like all our circular UI). Compensates source ring PNGs whose visible
    -- circle isn't dead-centre in the canvas — common with AI-generated / batch-exported art. Measured
    -- from the symmetric `aura` ring (its alpha centroid IS the circle centre); the directional rings
    -- share the same canvas alignment, and their centroid is skewed by the arrow, so they reuse the
    -- default rather than being measured directly. +x nudges RIGHT, +y nudges DOWN; scale = ring Size
    -- multiplier (>1 = bigger). Tuned by eye so the ring frames / sits centred on the disc.
    ring_centering = {
        default = { x = -0.014, y = 0.018, scale = 1.08 }, -- bigger + nudged SOUTHWEST
        -- per-shape overrides (only if a specific ring's circle differs from the shared alignment):
        -- aura = { x = ..., y = ..., scale = ... },
    },

    -- Map a power's targeting kind onto a ring SHAPE (above). UI: rings[targetingRing[kind]].
    targeting_ring = {
        single = "target_in",
        ally = "target_out",
        enemy_aoe = "aoe",
        team_aoe = "target_aoe",
        self = "aura",
        none = "aura",
        -- PetTargeting scope vocabulary (damage + power targeting SSOT): same ring art, named for
        -- the pet/aura `targeting` field so PetBadge can ring straight off the scope.
        targeted_aoe = "target_aoe",
        aoe = "aoe",
        aura = "aura",
        -- contagion = a target whose effect spreads outward; reuse the targeted-AoE ring until a
        -- dedicated chain/spread ring is drawn (TODO art). Without this it silently falls back to aura.
        contagion = "target_aoe",
    },

    -- Rock-paper-scissors element tints, RECOVERED from the hand-colored reference rings
    -- (colored = white_grayscale x ImageColor3, so the bright sample IS the multiplier). `bright`
    -- tints the disc/element; `dark` (= bright x ~0.36) tints the ring frame. Element by COLOR,
    -- archetype by the white SYMBOL shape. neutral = archetype with no/mixed element.
    elements = {
        earth = { bright = { 91, 255, 81 }, dark = { 33, 92, 29 } }, -- green (grass)
        fire = { bright = { 255, 82, 89 }, dark = { 92, 30, 32 } }, -- red (lava)
        desert = { bright = { 255, 209, 79 }, dark = { 92, 75, 28 } }, -- yellow (sand)
        ice = { bright = { 81, 136, 255 }, dark = { 29, 49, 92 } }, -- blue (frost)
        neutral = { bright = { 220, 220, 225 }, dark = { 70, 70, 78 } }, -- mixed / archetype-only
        -- creator (Colorado exclusive / creator-egg origin): the disc art is the flag-themed colorado
        -- role icon; the RING is WHITE (Jason) — so both tints are near-white.
        creator = { bright = { 255, 255, 255 }, dark = { 240, 240, 245 } },
    },

    -- Canonical combat element (grass/lava/ice/desert, from CombatOrigin / combat_fx) -> the
    -- badge element key above. The badge vocabulary is earth/fire; combat uses grass/lava.
    element_alias = {
        grass = "earth",
        lava = "fire",
        desert = "desert",
        ice = "ice",
        earth = "earth",
        fire = "fire",
        creator = "creator", -- Colorado / creator-egg origin: flag disc + white ring (passes through)
    },

    -- Archetype/role id (pet_roles / PetPowerView.roleInfo .id) -> the white SYMBOL to stamp on
    -- the element disc. (melee = the IMPACT fist; control = the hand.)
    role_symbol = {
        tank = "armor_chest",
        melee = "fist_impact",
        ranged = "arrow_right",
        support = "star_sparkle",
        control = "hand_stop",
    },

    -- Power badges. A power's disc COLOUR = its element (signature `element`, else the archetype
    -- theme); SYMBOL + RING (targeting) come from these maps. `power_effect_badge` keys off the
    -- power's `effect` (configs/powers.lua); signatures use `power_glyph_symbol` + the target map.
    -- target values are targeting_ring keys (resolved to a ring shape via M.ringFor).
    power_effect_badge = {
        shield = { symbol = "shield", target = "self" }, -- absorb shields (dune_shield/ember_ward)
        armor = { symbol = "armor_chest", target = "self" }, -- hardening armor (ironclad/ice_armor) -> tank armor icon
        armor_single = { symbol = "armor_chest", target = "self" }, -- single-pet hardening armor (stone_skin) -> tank armor icon (ring from target=single_pet)
        team_shield = { symbol = "armor_chest", target = "self" }, -- Bulwark squad defense
        dodge = { symbol = "eye_hidden", target = "self" }, -- evasion (mirage_step)
        damage_buff = { symbol = "fist", target = "self" }, -- Mountain's Strength (fist = damage BUFF)
        crit_up = { symbol = "critical_hit", target = "self" }, -- Critical Strike (+crit chance, squad) -> crit reticle
        root = { symbol = "user_desk", target = "enemy_aoe" }, -- frost_bind (user_desk = ROOT)
        quicksand = { symbol = "user_desk", target = "enemy_aoe" }, -- Quicksand (desert root; generic root icon for now)
        aoe_slow = { symbol = "chevrons_down", target = "enemy_aoe" }, -- blizzard
        aoe_blind = { symbol = "sand_storm", target = "enemy_aoe" }, -- sandstorm (dedicated storm art)
        damage_over_time = { symbol = "contagion", target = "single" }, -- mark_of_flame
        aoe_damage = { symbol = "ranged_impact", target = "enemy_aoe" }, -- eruption (ranged AoE)
        -- Generic / farming / luck / utility roster (white disc unless the power sets an element):
        heal = { symbol = "plus", target = "self" }, -- restore endurance
        coin_yield = { symbol = "coins_up", target = "self" }, -- Prospector
        windfall = { symbol = "gift_up", target = "self" }, -- Windfall
        magnet = { symbol = "magnet", target = "self" }, -- Magnet (drop pull)
        resonance = { symbol = "chevrons_up", target = "self" }, -- Resonance (innate AoE crystal-boost)
        luck = { symbol = "clover_lucky", target = "self" }, -- Fortune
        luck_huge = { symbol = "clover_huge", target = "self" }, -- Huge Fortune
        move_speed = { symbol = "arrow_right", target = "self" }, -- Swift
        recharge = { symbol = "history", target = "self" }, -- Hasten
        revive = { symbol = "revive", target = "self" }, -- Revive (instant re-summon)
        recall = { symbol = "pet_transfer", target = "self" }, -- Recall (to saved/egg spot)
        world_travel = { symbol = "portal", target = "self" }, -- World Travel
        xp_boost = { symbol = "xp_up", target = "self" }, -- XP boost
        -- Attack fill (origin-coloured):
        sunder = { symbol = "shield_broken", target = "enemy_aoe" }, -- armor break
        disarm = { symbol = "fist_broken", target = "single" }, -- weaken enemy attack
        focus_fire = { symbol = "target", target = "single" }, -- designate priority target
        expose = { symbol = "eye", target = "single" }, -- reveal + accuracy/crit
        cripple = { symbol = "target_down", target = "single" }, -- slow + weaken
        strike = { symbol = "ranged_impact", target = "single" }, -- basic ranged hit (fist_impact stays for true melee)
        -- New origin powers (2026-06-08 art batch). player_field -> self ring (centred on caster).
        taunt = { symbol = "taunt", target = "enemy_aoe" }, -- AoE aggro pull
        rage = { symbol = "rage", target = "ally" }, -- HP-inverse pet damage buff
        armor_field = { symbol = "armor_chest", target = "self" }, -- player_field team armor
        restoring_sands = { symbol = "plus", target = "ally" }, -- single-pet instant heal
        healing_field = { symbol = "plus", target = "self" }, -- player_field heal-over-time
        fear = { symbol = "fear", target = "single" }, -- flee control
        ice_shard = { symbol = "ice_shard", target = "single" }, -- targeted frost damage
        deep_freeze = { symbol = "capacitor", target = "single" }, -- full hold (Capacitor)
        frost_field = { symbol = "ice_storm", target = "self" }, -- player_field slow/freeze
        scorch = { symbol = "scorch", target = "single" }, -- -def debuff
        fire_nova = { symbol = "nuke", target = "self" }, -- player_field burn AoE
    },

    -- Support PET aura kind (configs/pet_roles.lua support_auras) -> the white SYMBOL for its badge.
    -- The disc COLOUR is the pet's biome element; this picks the symbol (heal=plus, yield=coins_up…).
    support_symbol = {
        heal = "plus",
        defense = "armor_chest",
        offense = "chevrons_up",
        yield = "coins_up",
        luck = "clover_lucky", -- bunny (Grass) — lucky-rabbit hatch-luck aura
        hold = "capacitor", -- controller HOLD glyph (capacitor IS the hold art; see discs map above)
        empower = "chevrons_up", -- single-target damage buffer: SAME damage-up glyph as offense; the
        -- single-target ring (SUPPORT_META.ring = "single") is what reads it apart from team offense
        haste = "history", -- team attack-speed aura (efficiency-as-aura); reuse the clock/recharge glyph
    },
    power_glyph_symbol = {
        debuff = "contagion",
        burst = "ranged_impact", -- ranged AoE bursts (cataclysm/shatter); not melee -> ranged_impact. firestorm overrides to its own art below.
        buff = "chevrons_up",
        -- origin-signature glyphs (docs/PET_REALM_SIGNATURE_POWERS.md)
        shield = "armor_chest", -- Bastion / Living Mountain / Mirage Veil
        hold = "capacitor", -- Permafrost / Seismic Hold / Absolute Zero / Eternal Winter (capacitor = HOLD)
        heal = "plus", -- Oasis / Simoom
        summon = "pet", -- Gaia's Colossus / Genie of the Dunes (call a guardian) -> paw glyph
        brand = "contagion", -- Inferno Brand (ramping mark)
    },
    -- Per-id symbol override for a signature with dedicated art (beats its generic glyph symbol).
    power_signature_symbol = {
        firestorm = "fire_storm", -- team-cleave Firestorm gets its own storm art (not the burst glyph)
        seismic_hold = "knockback", -- "Seismic Event" is now a knockback-DoT, not a hold
        cataclysm = "nuke", -- the meteor capstone (≠ Eruption's ranged_impact)
        -- The three AoE holds were all `capacitor` -> give two of them dedicated ice art so the
        -- trio reads distinct (Permafrost keeps the plain capacitor hold).
        absolute_zero = "ice_hold",
        eternal_winter = "winter_hold",
    },
    power_signature_ring = {
        single = "single",
        single_spread = "single",
        targeted_aoe = "enemy_aoe",
        team_aoe = "team_aoe",
        friendly = "ally",
    },
    -- A power's `target` (who it hits) -> targeting-ring KIND, used for EVERY power so the ring is
    -- honest: single_pet armor reads as one pet (outward), team armor as the squad, player_field as
    -- aura -- instead of all armor sharing the effect's generic ring. PetBadge.forPower keys off this
    -- first, falling back to the signature/effect default for powers with no `target`.
    power_target_ring = {
        single = "single", -- one enemy -> inward ring
        single_pet = "ally", -- one of your pets -> outward ring
        team_aoe = "team_aoe", -- the whole squad
        targeted_aoe = "enemy_aoe", -- enemies around a target
        player_field = "self", -- centred on the player -> aura
        self = "self",
    },

    -- Pre-baked colored disc-icons: discs[element][symbol] = Image id. The element is the disc
    -- COLOR (the pet's origin); the symbol is the archetype/power glyph baked onto it. Jason's
    -- recolor script renders these per element; uploaded as Decals, ids here are the resolved
    -- IMAGE content ids (see scripts/icon_ids.discs.json). The aura ring (rings.aura) tinted
    -- elements[elem].dark frames it -> the universal two-layer badge (src/Client/UI/PetBadge).
    discs = Assets.discs, -- GENERATED: discs[element][symbol], 5 colors (incl. neutral) × 31 symbols

    -- Zoom applied inside the (clipping) container to crop a transparent border.
    -- 1 = fit exactly; >1 = zoom in. Per-asset overrides win over default_scale.
    default_scale = 1.25,
    scales = {
        -- e.g. [id(73499491406959)] = 1.4,
        -- (Full-bleed disc icons are auto-registered at a slight inset below, after M is built.)
        [id(121311806877255)] = 0.9, -- white shield disc (status fallback; not in M.discs loop)
    },
}

-- Zoom factor for a given image string ("" / nil -> 1, i.e. no icon present).
function M.scaleFor(image)
    if not image or image == "" then
        return 1
    end
    return M.scales[image] or M.default_scale
end

-- Raw RGB triple {r,g,b} for an element badge layer. shade = "bright" (disc) | "dark" (ring).
-- Pure (no Color3) so headless specs can read it; UI wraps it via M.elementColor3.
function M.elementRGB(element, shade)
    local e = M.elements[element] or M.elements.neutral
    return e[shade] or e.bright
end

-- Color3 for an element badge layer (client UI only — touches the Color3 global).
function M.elementColor3(element, shade)
    local t = M.elementRGB(element, shade)
    return Color3.fromRGB(t[1], t[2], t[3])
end

-- Ring image (rbxassetid string) for a TARGETING kind; falls back to the plain archetype ring.
function M.ringFor(targetingKind)
    local shape = M.targeting_ring[targetingKind or "none"] or "aura"
    return M.rings[shape] or M.rings.aura
end

-- Centering nudge { x, y } (scale fractions of the badge) for a ring SHAPE, so an off-centre source
-- PNG visually centres while the ImageLabel stays anchored/positioned at .5,.5. Per-shape override →
-- `default` → {0,0}.
function M.ringCentering(shape)
    local c = M.ring_centering or {}
    return c[shape] or c.default or { x = 0, y = 0 }
end

-- Normalize any element token (canonical grass/lava or badge earth/fire) to a badge key.
function M.elementKey(element)
    return M.element_alias[element or ""] or "neutral"
end

-- White symbol id for a role/archetype id ("" if none).
function M.symbolForRole(role)
    return M.role_symbol[role or ""]
end

-- Disc Image (rbxassetid string) for an element + symbol; nil if that combo wasn't uploaded.
function M.discFor(element, symbol)
    local e = M.discs[M.elementKey(element)]
    return e and symbol and e[symbol] or nil
end

-- Auto-register every colored disc at a slight inset: they're full-bleed (no transparent border
-- to crop), so the 1.25 border-zoom would overflow a clipping frame (status badges) and cut their
-- edges. Any scaleFor() consumer gets ~0.92 for a disc unless explicitly overridden above.
for _, byElement in pairs(M.discs) do
    for _, image in pairs(byElement) do
        if M.scales[image] == nil then
            M.scales[image] = 0.92
        end
    end
end

return M
