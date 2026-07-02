--[[
    PetBadge — the ONE universal icon-badge renderer. Every archetype/power icon in the game is
    this same two-layer stack: a colored DISC ImageLabel (element of origin) behind a tinted RING
    ImageLabel (plain `aura` ring for archetypes; a directional ring for powers later). No
    per-surface special path — SquadHud, InventoryPanel, hotbar, etc. all call this.

    Data lives in configs/power_icons.lua:
      - discs[element][symbol]  = the pre-baked colored disc Image (element = disc color)
      - role_symbol[roleId]     = which white symbol a role stamps (tank->armor, melee->fist_impact,
                                  ranged->arrow_right, support->star_sparkle, control->hand_stop)
      - rings[shape] + elements[elem].dark = the ring frame + its tint
      - element_alias            = canonical combat element (grass/lava/ice/desert) -> badge key
                                   (earth/fire/desert/ice)

    Two entry points:
      PetBadge.create(parent, opts) -> { holder, disc, ring }   (build once)
      PetBadge.apply(disc, ring, element, role, opts) -> bool    (re-skin existing labels each tick)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Configs = ReplicatedStorage:WaitForChild("Configs")
local POWER_ICONS = require(Configs:WaitForChild("power_icons"))

local PetBadge = {}

-- Lazily pull the petType -> origin-element map (grass/lava/ice/desert) + the disc-only
-- badge_element override (creator-egg pets) from combat_fx.
local _pettypeElement, _badgeElement
local function originMaps()
    if _pettypeElement == nil then
        local ok, cfx = pcall(function()
            return require(Configs:WaitForChild("combat_fx"))
        end)
        local origin = (ok and cfx and cfx.origin) or {}
        _pettypeElement = origin.pettype_element or {}
        _badgeElement = origin.badge_element or {}
    end
    return _pettypeElement, _badgeElement
end

-- Badge element key (earth/fire/desert/ice/creator, else "neutral") for a pet type.
-- DISPLAY ONLY (disc colors): this is the power_icons ALIAS (lava->fire, grass->earth),
-- NOT the biome id — never feed it into ElementResonance (the alias silently reads
-- neutral for lava/grass pets; ice/desert alias to themselves, which hid the bug).
-- badge_element is a disc-only override (creator-egg pets show the flag disc + white ring
-- while their combat element stays unchanged).
function PetBadge.elementForPetType(petType)
    local pet, badge = originMaps()
    local override = badge[petType or ""]
    if override then
        return POWER_ICONS.elementKey(override)
    end
    return POWER_ICONS.elementKey(pet[petType or ""])
end

-- RAW biome element (grass/lava/ice/desert) for a pet type — the combat_fx id the
-- biome-RPS math (ElementResonance.biomeMultiplier) and the server damage path use.
function PetBadge.biomeElementForPetType(petType)
    local pet = originMaps()
    return pet[petType or ""]
end

-- Lazy power/archetype configs (for power-slot badges in the hotbar).
local _powers, _archetypes, _potions
local function powersCfg()
    if _powers == nil then
        local ok, p = pcall(function()
            return require(Configs:WaitForChild("powers"))
        end)
        _powers = (ok and p) or {}
    end
    return _powers
end
local function archetypesCfg()
    if _archetypes == nil then
        local ok, a = pcall(function()
            return require(Configs:WaitForChild("archetypes"))
        end)
        _archetypes = (ok and a and a.archetypes) or {}
    end
    return _archetypes
end
local function potionsCfg()
    if _potions == nil then
        local ok, p = pcall(function()
            return require(Configs:WaitForChild("potions"))
        end)
        _potions = (ok and p) or {}
    end
    return _potions
end

-- Resolve a potion METER -> the same { element, symbol, ring } shape powers use, from the meter's
-- `badge` spec in configs/potions.lua (element + symbol + targeting `target`). So a potion buff wears
-- the unified disc + targeting ring everywhere a power does (hotbar slot, squad cards). Returns nil if
-- the meter / its badge isn't configured.
function PetBadge.forPotion(meterId)
    local meters = potionsCfg().meters
    local m = meters and meters[meterId]
    local badge = m and m.badge
    if not badge or not badge.symbol then
        return nil
    end
    local shape = POWER_ICONS.targeting_ring[badge.target or "none"] or "aura"
    return {
        element = POWER_ICONS.elementKey(badge.element),
        symbol = badge.symbol,
        ring = shape,
    }
end

-- Lazy enhancement deps (config + pure core + origin->element map for tints).
local _enhCfg, _enhCore, _archElement
local _enchantsCfg
local function enchantsCfg()
    if _enchantsCfg == nil then
        local ok, cfg = pcall(function()
            return require(game:GetService("ReplicatedStorage").Configs:WaitForChild("enchants"))
        end)
        _enchantsCfg = (ok and type(cfg) == "table") and cfg or false
    end
    return _enchantsCfg or nil
end

local function enhancementCfg()
    if _enhCfg == nil then
        local ok, c = pcall(function()
            return require(Configs:WaitForChild("enhancements"))
        end)
        _enhCfg = (ok and c) or {}
    end
    return _enhCfg
end
local function enhancementCore()
    if _enhCore == nil then
        local ok, m = pcall(function()
            return require(ReplicatedStorage.Shared.Game.Enhancements)
        end)
        _enhCore = (ok and m) or false
    end
    return _enhCore or nil
end
local function originElement(archetype)
    if _archElement == nil then
        local ok, cfx = pcall(function()
            return require(Configs:WaitForChild("combat_fx"))
        end)
        _archElement = (ok and cfx and cfx.origin and cfx.origin.archetype_element) or {}
    end
    return POWER_ICONS.elementKey(_archElement[archetype] or "neutral")
end

-- Enhancement badge: disc = FIRST origin's element color + the type's symbol; enhancement ring
-- tinted the SECOND origin's color (single = both layers one color group — Jason's grammar).
-- The one assembly path: PowerChoiceMenu's ENHANCE strip AND inventory cards both call this.
function PetBadge.createEnhancementBadge(parent, opts)
    opts = opts or {}
    local holder = Instance.new("Frame")
    holder.Name = "EnhBadge"
    holder.Size = opts.size or UDim2.fromScale(1, 1)
    holder.Position = opts.position or UDim2.fromScale(0, 0)
    if opts.anchor then
        holder.AnchorPoint = opts.anchor
    end
    holder.BackgroundTransparency = 1
    if opts.zindex then
        holder.ZIndex = opts.zindex
    end
    holder.Parent = parent
    local core = enhancementCore()
    local spec = core and core.badgeSpec(enhancementCfg(), opts.record)
    if not spec then
        return holder
    end
    local z = opts.zindex or 1
    local disc = Instance.new("ImageLabel")
    disc.BackgroundTransparency = 1
    disc.AnchorPoint = Vector2.new(0.5, 0.5)
    disc.Position = UDim2.fromScale(0.5, 0.5)
    disc.Size = UDim2.fromScale(0.8, 0.8)
    disc.ScaleType = Enum.ScaleType.Fit
    disc.Image = POWER_ICONS.discFor(originElement(spec.discOrigin), spec.symbol) or ""
    disc.ZIndex = z
    disc.Parent = holder
    local ring = Instance.new("ImageLabel")
    ring.BackgroundTransparency = 1
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.fromScale(0.5, 0.5)
    ring.Size = UDim2.fromScale(1, 1)
    ring.ScaleType = Enum.ScaleType.Fit
    ring.Image = POWER_ICONS.rings.enhancement or POWER_ICONS.rings.aura or ""
    ring.ImageColor3 = POWER_ICONS.elementColor3(originElement(spec.ringOrigin), "bright")
    ring.ZIndex = z + 1
    ring.Parent = holder
    if opts.dead then
        -- outleveled (CoH dead zone): grey + dim both layers so it reads "needs replacing"
        local GREY = Color3.fromRGB(120, 120, 128)
        disc.ImageColor3 = GREY
        disc.ImageTransparency = 0.45
        ring.ImageColor3 = GREY
        ring.ImageTransparency = 0.45
    end
    return holder
end

-- ENCHANT badge (Jason): the per-copy identity axis. NEUTRAL (white) disc carries the
-- effect symbol — same alphabet as auras/powers — and the RING METAL carries strength
-- 1-5 (copper/bronze/silver/gold/onyx, configs/enchants.lua display.ring_tiers). When
-- Jason's metal ring art lands (tier.asset) it replaces the tinted grayscale ring.
-- opts: { enchantId, strength, size?, position?, anchor?, zindex? }
function PetBadge.createEnchantBadge(parent, opts)
    opts = opts or {}
    local holder = Instance.new("Frame")
    holder.Name = "EnchantBadge"
    holder.Size = opts.size or UDim2.fromScale(1, 1)
    holder.Position = opts.position or UDim2.fromScale(0, 0)
    if opts.anchor then
        holder.AnchorPoint = opts.anchor
    end
    holder.BackgroundTransparency = 1
    if opts.zindex then
        holder.ZIndex = opts.zindex
    end
    holder.Parent = parent
    local cfg = enchantsCfg()
    local display = cfg and cfg.display or {}
    local symbol = (display.symbols and display.symbols[opts.enchantId]) or "star_sparkle"
    local discImage = POWER_ICONS.discFor("neutral", symbol)
        or POWER_ICONS.discFor("neutral", "star_sparkle")
    if not discImage then
        return holder -- no neutral disc art -> empty holder (caller may destroy)
    end
    local z = opts.zindex or 1
    local disc = Instance.new("ImageLabel")
    disc.BackgroundTransparency = 1
    disc.AnchorPoint = Vector2.new(0.5, 0.5)
    disc.Position = UDim2.fromScale(0.5, 0.5)
    disc.Size = UDim2.fromScale(0.8, 0.8)
    disc.ScaleType = Enum.ScaleType.Fit
    disc.Image = discImage
    disc.ZIndex = z
    disc.Parent = holder
    local tiers = display.ring_tiers or {}
    local strength = math.clamp(math.floor(tonumber(opts.strength) or 1), 1, math.max(#tiers, 1))
    local tier = tiers[strength]
    local ring = Instance.new("ImageLabel")
    ring.BackgroundTransparency = 1
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.fromScale(0.5, 0.5)
    ring.Size = UDim2.fromScale(1, 1)
    ring.ScaleType = Enum.ScaleType.Fit
    if tier and tier.asset then
        ring.Image = tier.asset
    else
        ring.Image = POWER_ICONS.rings.enhancement or POWER_ICONS.rings.aura or ""
        local tint = tier and tier.tint
        ring.ImageColor3 = tint and Color3.fromRGB(tint[1], tint[2], tint[3])
            or Color3.fromRGB(220, 220, 225)
    end
    ring.ZIndex = z + 1
    ring.Parent = holder
    return holder
end

-- Resolve a power id -> { element, symbol, ring } (ring = a ring SHAPE key), or nil if the power
-- or its effect/glyph has no mapped symbol. Element = the power's element, else its archetype
-- theme. Symbol + targeting come from power_icons.power_effect_badge / glyph / signature maps.
function PetBadge.forPower(powerId)
    -- Potion buffs tag their attribute with "potion_<meter>" so every surface that resolves a badge
    -- by power id (squad cards via <attr>PowerId, the hotbar slot) renders the same unified disc+ring.
    if type(powerId) == "string" and powerId:sub(1, 7) == "potion_" then
        return PetBadge.forPotion(powerId:sub(8))
    end
    local cfg = powersCfg()
    local def = cfg.powers and cfg.powers[powerId]
    if not def then
        return nil
    end
    local rawElement = def.element
    if not rawElement and def.archetype then
        local arch = archetypesCfg()[def.archetype]
        rawElement = arch and arch.theme
    end
    local element = POWER_ICONS.elementKey(rawElement)

    -- SYMBOL = what it does (effect / signature glyph). RING = who it hits (the power's target).
    local spec = (not def.signature) and POWER_ICONS.power_effect_badge[def.effect or ""] or nil
    local symbol
    if def.signature then
        symbol = (
            POWER_ICONS.power_signature_symbol and POWER_ICONS.power_signature_symbol[powerId]
        ) or POWER_ICONS.power_glyph_symbol[def.glyph or ""]
    elseif spec then
        symbol = spec.symbol
    end
    if not symbol then
        return nil
    end

    -- Ring reflects the power's REAL target, so single-pet armor shows the outward pet ring, team
    -- armor the team-AoE ring, player_field the aura -- instead of every armor power sharing one
    -- ring. Falls back to the signature/effect default for powers with no `target` (always-on
    -- neutrals -> self/aura).
    local targetKind = POWER_ICONS.power_target_ring[def.target or ""]
    if not targetKind then
        if def.signature then
            targetKind = POWER_ICONS.power_signature_ring[def.target or ""] or "single"
        elseif spec then
            targetKind = spec.target
        end
    end
    local shape = POWER_ICONS.targeting_ring[targetKind or "none"] or "aura"
    return { element = element, symbol = symbol, ring = shape }
end

-- Disc Image (rbxassetid string) for a power's badge, or nil. Shortcut for surfaces that only
-- need the disc (status badges, the floating armor icon) so a buff shows the SAME icon as its power.
function PetBadge.powerDiscImage(powerId)
    if not powerId or powerId == "" then
        return nil
    end
    local b = PetBadge.forPower(powerId)
    return b and POWER_ICONS.discFor(b.element, b.symbol) or nil
end

-- Re-skin pre-existing disc + ring ImageLabels (the reuse path; e.g. SquadHud cards persist).
-- element = canonical or badge token; role = role id; opts.symbol overrides the role symbol;
-- opts.ring = ring shape (default "aura"). Returns true if a disc image was found.
function PetBadge.apply(disc, ring, element, role, opts)
    opts = opts or {}
    local elemKey = POWER_ICONS.elementKey(element)
    local symbol = opts.symbol or POWER_ICONS.symbolForRole(role)
    local discImg = POWER_ICONS.discFor(elemKey, symbol)
    if disc then
        disc.Image = discImg or ""
        disc.Visible = discImg ~= nil
    end
    if ring then
        ring.Image = POWER_ICONS.rings[opts.ring or "aura"] or POWER_ICONS.rings.aura
        ring.ImageColor3 = POWER_ICONS.elementColor3(elemKey, "dark")
    end
    return discImg ~= nil
end

-- Build a full badge (disc inset behind a slightly larger framing ring) into `parent`, filling
-- it. opts = { element, role, symbol, ring, zIndex }. Returns { holder, disc, ring }.
function PetBadge.create(parent, opts)
    opts = opts or {}
    local z = opts.zIndex or 1

    local holder = Instance.new("Frame")
    holder.Name = "PetBadge"
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.fromScale(1, 1)
    holder.ZIndex = z
    holder.Parent = parent

    local disc = Instance.new("ImageLabel")
    disc.Name = "Disc"
    disc.BackgroundTransparency = 1
    disc.AnchorPoint = Vector2.new(0.5, 0.5)
    disc.Position = UDim2.fromScale(0.5, 0.5)
    disc.Size = UDim2.fromScale(0.80, 0.80) -- inset so the ring frames it
    disc.ScaleType = Enum.ScaleType.Fit
    disc.ZIndex = z
    disc.Parent = holder

    local ring = Instance.new("ImageLabel")
    ring.Name = "Ring"
    ring.BackgroundTransparency = 1
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    -- centred at .5,.5, plus a per-ring nudge + scale to compensate off-centre / under-sized source
    -- PNGs (config-driven; see power_icons.ring_centering).
    local off = POWER_ICONS.ringCentering(opts.ring)
    local rscale = off.scale or 1
    ring.Position = UDim2.new(0.5 + (off.x or 0), 0, 0.5 + (off.y or 0), 0)
    ring.Size = UDim2.fromScale(rscale, rscale)
    ring.ScaleType = Enum.ScaleType.Fit
    ring.ZIndex = z + 1
    ring.Parent = holder

    PetBadge.apply(disc, ring, opts.element, opts.role, opts)
    return { holder = holder, disc = disc, ring = ring }
end

return PetBadge
