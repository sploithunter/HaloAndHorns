--[[
    PetCardStyle — the SHARED pet-card chrome (rarity ring + variant ring + variant
    background gradients, with optional rotation animation), extracted from
    InventoryPanel's card builder so every pet-card surface (inventory, TRADE,
    future pickers) renders the same card from the same config
    (configs/inventory.lua buckets.pets.card_visuals + configs/pets.lua rarities).

    Jason (trade v2 review): "why not use the pet UI we had? ...radically inferior."
    Right call — this module is the reusable seam. InventoryPanel still carries its
    original inline copy (unifying it onto this module is follow-up cleanup).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PetCardStyle = {}

local _inventoryConfig, _petsConfig
local function configs()
    if not _inventoryConfig then
        pcall(function()
            _inventoryConfig = require(ReplicatedStorage.Configs:WaitForChild("inventory"))
        end)
        pcall(function()
            _petsConfig = require(ReplicatedStorage.Configs:WaitForChild("pets"))
        end)
    end
    return _inventoryConfig or {}, _petsConfig or {}
end

local function cardVisuals()
    local inv = configs()
    return (inv.buckets and inv.buckets.pets and inv.buckets.pets.card_visuals) or {}
end

-- Rarity color: explicit record rarity first, else the species family rarity.
function PetCardStyle.rarityColor(rarityId, petId)
    local _, pets = configs()
    local id = rarityId
    if not id and petId and pets.pets and pets.pets[petId] then
        id = pets.pets[petId].rarity
    end
    local def = id and pets.rarities and pets.rarities[tostring(id):lower()]
    if def and typeof(def.color) == "Color3" then
        return def.color
    end
    return Color3.fromRGB(150, 150, 150)
end

function PetCardStyle.styleFor(rarityId, variant)
    local config = cardVisuals()
    local rid = tostring(rarityId or "common"):lower()
    local vid = tostring(variant or "basic"):lower()
    return {
        ring = (config.rarity_rings and config.rarity_rings[rid]) or config.ring_default or {},
        variantRing = vid ~= "basic" and config.variant_rings and config.variant_rings[vid] or nil,
        background = (config.variant_backgrounds and config.variant_backgrounds[vid])
            or (config.variant_backgrounds and config.variant_backgrounds.basic)
            or {},
    }
end

-- public: shared by every gradient site (rings, backgrounds, icon backdrops)
function PetCardStyle.colorSequence(colors, fallback)
    local usable = {}
    if type(colors) == "table" then
        for _, c in ipairs(colors) do
            if typeof(c) == "Color3" then
                usable[#usable + 1] = c
            end
        end
    end
    if #usable == 0 then
        return ColorSequence.new(fallback or Color3.fromRGB(45, 45, 55))
    end
    if #usable == 1 then
        return ColorSequence.new(usable[1])
    end
    local keys = {}
    for i, c in ipairs(usable) do
        keys[#keys + 1] = ColorSequenceKeypoint.new((i - 1) / (#usable - 1), c)
    end
    return ColorSequence.new(keys)
end

function PetCardStyle.spin(gradient, seconds)
    TweenService:Create(
        gradient,
        TweenInfo.new(seconds or 3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
        { Rotation = 360 }
    ):Play()
end

-- Dress `frame` as a real pet card: rarity stroke (gradient ring), inner variant
-- ring for golden/rainbow, variant background gradient — animation per config.
function PetCardStyle.applyChrome(frame, rarityId, variant, petId, colorOverride)
    local style = PetCardStyle.styleFor(rarityId, variant)
    local color = (typeof(colorOverride) == "Color3" and colorOverride)
        or PetCardStyle.rarityColor(rarityId, petId)

    frame.BackgroundColor3 = Color3.fromRGB(45, 45, 55)

    local stroke = Instance.new("UIStroke")
    stroke.Name = "RarityStroke"
    stroke.Color = color
    stroke.Thickness = tonumber(style.ring.thickness) or 2
    stroke.Parent = frame
    stroke:SetAttribute("BaseThickness", stroke.Thickness) -- hover anim scales from this
    local ringGradient = Instance.new("UIGradient")
    ringGradient.Color = PetCardStyle.colorSequence(style.ring.colors, color)
    ringGradient.Rotation = tonumber(style.ring.rotation) or 0
    ringGradient.Parent = stroke
    if style.ring.animated == true then
        PetCardStyle.spin(ringGradient, tonumber(style.ring.rotation_seconds) or 3)
    end

    if style.variantRing then
        local vf = Instance.new("Frame")
        vf.Name = "VariantStrokeFrame"
        vf.BackgroundTransparency = 1
        vf.Position = UDim2.new(0, 4, 0, 4)
        vf.Size = UDim2.new(1, -8, 1, -8)
        vf.ZIndex = frame.ZIndex + 1
        vf.Parent = frame
        local vc = Instance.new("UICorner")
        vc.CornerRadius = UDim.new(0, 9)
        vc.Parent = vf
        local vs = Instance.new("UIStroke")
        vs.Color = color
        vs.Thickness = tonumber(style.variantRing.thickness) or 2
        vs.Parent = vf
        local vg = Instance.new("UIGradient")
        vg.Color = PetCardStyle.colorSequence(style.variantRing.colors, color)
        vg.Rotation = tonumber(style.variantRing.rotation) or 0
        vg.Parent = vs
        if style.variantRing.animated == true then
            PetCardStyle.spin(vg, tonumber(style.variantRing.rotation_seconds) or 3)
        end
    end

    local bg = Instance.new("UIGradient")
    bg.Name = "VariantBackgroundGradient"
    bg.Color = PetCardStyle.colorSequence(style.background.colors, Color3.fromRGB(45, 45, 55))
    bg.Rotation = tonumber(style.background.rotation) or 45
    bg.Parent = frame
    if style.background.animated == true then
        PetCardStyle.spin(bg, tonumber(style.background.rotation_seconds) or 5)
    end

    return color
end

return PetCardStyle
