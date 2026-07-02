--[[
    InventoryPanel - Professional Pet Simulator Style Inventory
    
    Features:
    - Grid layout with item cards
    - Search functionality
    - Category filtering
    - Professional visual design with gradients and shadows
    - Hover effects and animations
    - Item rarity indicators
    - Responsive design
    
    Usage:
    local InventoryPanel = require(script.InventoryPanel)
    local inventory = InventoryPanel.new()
    MenuManager:RegisterPanel("Inventory", inventory)
]]

local Players = game:GetService("Players")
local AssetFetch = require(game:GetService("ReplicatedStorage").Shared.Utils.AssetFetch)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

-- #179 down-lockout: pill ring assets (white = available, red = locked) for the equipped view.
local PILL_UI = require(ReplicatedStorage.Configs:WaitForChild("pill_ui"))
-- Shared panel exterior (outer pill) + the currency-HUD capsule treatment for header/action buttons.
local PanelChrome = require(script.Parent.Parent.Components.PanelChrome)

-- Capsule treatment on an existing button: full pill corner + the game pill BORDER (neon 9-slice
-- ring, area-themed). The fill keeps its state color and the intrinsic text stays untinted — the
-- earlier gradient was bleeding through the text. Idempotent (safe to re-call after a recolor).
local function pillify(btn)
    for _, c in ipairs(btn:GetChildren()) do
        if
            c:IsA("UICorner")
            or c:IsA("UIGradient")
            or c:IsA("UIStroke")
            or c.Name == "PillBorder"
        then
            c:Destroy()
        end
    end
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn
    PanelChrome.pillBorder(btn, PanelChrome.areaPill(), (btn.ZIndex or 1) + 4, 0, 0.18)
    return btn
end

-- Player-facing pet-card grid sizes (persisted setting; small = the dense default).
-- Card internals are cardSize-derived (fromScale or math.floor(cardSize * k) pixel math),
-- so multiplying cardSize rescales the whole card.
local CARD_SCALE_FACTORS = { small = 1, medium = 1.5, large = 2 }
local CARD_SCALE_NEXT = { small = "medium", medium = "large", large = "small" }
local CARD_SCALE_LABEL = { small = "Cards: S", medium = "Cards: M", large = "Cards: L" }

-- delete-mode chrome: the 🗑 header pill is muted when idle, red when armed; the
-- selection highlight + bulk-confirm reuse this same red (matches the existing
-- delete-confirm stroke at 231/76/60).
local DELETE_PILL_IDLE = Color3.fromRGB(120, 72, 78)
local DELETE_RED = Color3.fromRGB(231, 76, 60)
-- rarities the SERVER refuses to delete (configs/pets.lua deletion.denied_rarities)
-- plus the specials surfaced on stack cards (secret/huge ride the item.special flag).
-- This is the client-side visual gate; InventoryService:_isDeletionDenied is the backstop.
local DELETE_DENIED_RARITIES = { exclusive = true, creator = true, secret = true, huge = true }

local function lockoutFormatTime(sec)
    sec = math.max(0, math.ceil(sec))
    if sec >= 60 then
        return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
    end
    return sec .. "s"
end

-- Silence verbose raw debug prints (right-click / card-size / context-menu chatter that
-- fired on every interaction). Real logging goes through self.logger (gated by the
-- "InventoryPanel" level in configs/logging.lua); warn()/error() still surface. Toggle for
-- local debugging.
local __RAW_PRINT = print
local __PRINT_ENABLED = false
local function print(...)
    if __PRINT_ENABLED then
        __RAW_PRINT(...)
    end
end

-- Get shared modules
local Locations = require(ReplicatedStorage.Shared.Locations)
local ConfigLoader = require(ReplicatedStorage.Shared.ConfigLoader)
-- Single source of truth for configured base power (huge-aware), shared with the
-- server so the displayed power matches the power that mines/fights.
local PetPower = require(ReplicatedStorage.Shared.Game.PetPower)
local PetTargeting = require(ReplicatedStorage.Shared.Game.PetTargeting) -- damage/power scope → badge ring
local PetBadge = require(script.Parent.Parent.PetBadge)
-- Two-number card display (⛏ mining / ⚔ combat) — assembles the PetPower profile from config.
local petPowerViewOk, PetPowerView = pcall(function()
    return require(ReplicatedStorage.Shared.Game.PetPowerView)
end)
if not petPowerViewOk then
    PetPowerView = nil
end
-- Universal archetype badge (element disc + tinted ring). Optional: falls back to the text chip.
local petBadgeOk, PetBadge = pcall(function()
    return require(script.Parent.Parent.PetBadge)
end)
if not petBadgeOk then
    PetBadge = nil
end
-- Icon registry + support-aura config, for the "this pet provides X" badge on the card.
local powerIconsOk, POWER_ICONS = pcall(function()
    return require(ReplicatedStorage.Configs:WaitForChild("power_icons"))
end)
if not powerIconsOk then
    POWER_ICONS = nil
end
local petRolesOk, PET_ROLES = pcall(function()
    return require(ReplicatedStorage.Configs:WaitForChild("pet_roles"))
end)
if not petRolesOk then
    PET_ROLES = nil
end
-- Biome RPS (zone resonance) — the card recalculates as the player crosses zones.
local elementsOk, ELEMENTS_CONFIG = pcall(function()
    return require(ReplicatedStorage.Configs:WaitForChild("elements"))
end)
if not elementsOk then
    ELEMENTS_CONFIG = nil
end
local areasOk, AREAS_CONFIG = pcall(function()
    return require(ReplicatedStorage.Configs:WaitForChild("areas"))
end)
if not areasOk then
    AREAS_CONFIG = nil
end
local ElementResonance = require(ReplicatedStorage.Shared.Game.ElementResonance)
-- Pet defs (for the species realm -> light/shadow alignment used by the cross-realm resonance).
local petsCfgOk, PETS_CONFIG = pcall(function()
    return require(ReplicatedStorage.Configs:WaitForChild("pets"))
end)
if not petsCfgOk then
    PETS_CONFIG = nil
end
-- Pre-uploaded pet/egg card THUMBNAILS (flat image asset ids), GENERATED by
-- scripts/gen_pet_thumbnails.js into configs/pet_thumbnail_assets.lua. When an id exists the card
-- shows a flat ImageLabel (a texture — replicated, CDN-cached, zero per-frame cost) instead of
-- cloning the baked ViewportFrame (a live 3D scene rendered every frame). Same ONE card path:
-- _getPetImageFromAssets prefers this, then falls back to the viewport. Empty/missing registry =
-- every card falls back to the viewport exactly as before (zero regression). See the resolver below.
local petThumbsOk, PET_THUMBNAILS = pcall(function()
    return require(ReplicatedStorage.Configs:WaitForChild("pet_thumbnail_assets"))
end)
if not petThumbsOk then
    PET_THUMBNAILS = nil
end

-- Cross-realm resonance for a pet right now: its species realm (heaven->light / hell->shadow /
-- else neutral) vs the realm the player is standing in. Uses the SAME shared function as the server
-- damage path, so the card's number == the damage actually dealt (display = dealt, first principle).
local function realmResonanceFor(petType)
    if not ELEMENTS_CONFIG then
        return 1
    end
    local def = PETS_CONFIG and PETS_CONFIG.pets and PETS_CONFIG.pets[petType]
    local player = Players.LocalPlayer
    local playerRealm = player and player:GetAttribute("CurrentRealm")
    return ElementResonance.petRealmMultiplier(def and def.realm, playerRealm, ELEMENTS_CONFIG)
end

-- Current zone resonance multiplier for a pet type (1.0 when neutral/unknown).
local function zoneResonanceFor(petType)
    if not (ELEMENTS_CONFIG and PetBadge) then
        return 1
    end
    local zones = AREAS_CONFIG and AREAS_CONFIG.zones
    local player = Players.LocalPlayer
    local zone = zones and player and zones[tostring(player:GetAttribute("CurrentArea"))]
    local zoneElement = zone and zone.element
    -- RAW biome id, NOT the badge-color alias: elementForPetType returns the disc key
    -- (lava->"fire", grass->"earth"), which the biome cycle doesn't contain — lava and
    -- grass pets silently read NEUTRAL on cards/sort/tooltips while ice/desert (alias =
    -- identity) worked. Jason's catch: Ember Lion card 63 in Spawn while it dealt 83.
    local petElement = PetBadge.biomeElementForPetType(petType)
    return ElementResonance.biomeMultiplier(petElement, zoneElement, ELEMENTS_CONFIG)
end

-- SORT KEY = the displayed number, exactly: full profile chain (element x variant x
-- aptitude x zone resonance). Sorting raw power missed aptitude — buffer pets (0.35)
-- displayed 15 but sorted as ~43, landing between 45s and 42s (Jason's catch).
-- SINGLE source of truth for a pet's resolved power on a card. Builds the full LIVE context (biome
-- RPS + cross-realm light/shadow resonance) and resolves through PetPowerView — exactly as the
-- server resolves dealt damage. The displayed ⛏/⚔ text AND the sort key both call this, so they can
-- never diverge (Jason: "they should have a single source of truth"). Returns the profile, or nil if
-- PetPowerView is unavailable.
local function resolvePetProfile(power, petType, variant, isCreator)
    if not (petPowerViewOk and PetPowerView) then
        return nil
    end
    local ok, profile = pcall(function()
        return PetPowerView.profile({
            base = power,
            petType = petType,
            variant = variant,
            creator = isCreator == true,
            context = {
                zone = zoneResonanceFor(petType), -- biome RPS (pet element vs zone)
                realm = realmResonanceFor(petType), -- cross-realm light/shadow vs current realm
            },
        })
    end)
    return ok and profile or nil
end

local function displaySortPower(power, petType, variant, isCreator)
    local profile = resolvePetProfile(power, petType, variant, isCreator)
    if profile then
        return math.max(profile.miningEffective or 0, profile.combatEffective or 0)
    end
    -- Fallback (PetPowerView missing): raw power x both context multipliers.
    return (tonumber(power) or 0) * zoneResonanceFor(petType) * realmResonanceFor(petType)
end

-- Enchant display (metal ring tiers + per-effect %) for badges + readable tooltips.
local enchantsOk, ENCHANTS_CONFIG = pcall(function()
    return require(ReplicatedStorage.Configs:WaitForChild("enchants"))
end)
if not enchantsOk then
    ENCHANTS_CONFIG = nil
end
-- Support-aura kind -> { biome element for the disc colour, human label }.
local PetCardStyle = require(script.Parent.Parent.PetCardStyle)
-- shared amount-picker popover (delete: how many of a stack; same widget trade uses)
local QuantitySelector = require(script.Parent.Parent.Components.QuantitySelector)

local SUPPORT_META = {
    heal = { element = "earth", label = "Heal" },
    defense = { element = "ice", label = "Defense" },
    offense = { element = "fire", label = "War-Cry" }, -- team damage aura (renamed from "Offense")
    yield = { element = "desert", label = "Crystal Yield" },
    luck = { element = "earth", label = "Luck" }, -- bunny's lucky-rabbit aura (Grass)
    hold = { element = "ice", label = "Hold" }, -- single-target CC; ring derived via PetTargeting.auraScope
    empower = { element = "fire", label = "Empower" }, -- single-target buffer; ring derived via PetTargeting.auraScope
    haste = { element = "fire", label = "Haste" }, -- team attack-speed aura (efficiency-as-aura)
}
-- Hatcher display: the pet stores the hatcher's STABLE UserId (hatcher_user_id) as the SSOT —
-- players rename, so we resolve the id to the CURRENT username for display (Jason). Cached +
-- async (GetNameFromUserIdAsync yields); false = in-flight sentinel so we never double-request.
local _hatcherNameCache = {}
local function requestHatcherName(userId, onResolved)
    userId = tonumber(userId)
    if not userId or userId <= 0 then
        return
    end
    local cached = _hatcherNameCache[userId]
    if cached ~= nil then
        if type(cached) == "string" and onResolved then
            onResolved(cached)
        end
        return
    end
    _hatcherNameCache[userId] = false
    task.spawn(function()
        local ok, name = pcall(function()
            return Players:GetNameFromUserIdAsync(userId)
        end)
        _hatcherNameCache[userId] = (ok and type(name) == "string" and name) or nil
        if ok and type(name) == "string" and onResolved then
            onResolved(name)
        end
    end)
end

local petVisualsOk, PetVariantVisuals = pcall(function()
    return require(ReplicatedStorage.Shared.Services.PetVariantVisuals)
end)

local function getAssetTransform(petData)
    if type(petData and petData.asset_transform) ~= "table" then
        return {}
    end

    local transform = petData.asset_transform
    local orientation = type(transform.orientation) == "table" and transform.orientation or {}
    return {
        scale = tonumber(transform.scale) or 1,
        hugeScale = tonumber(transform.huge_scale or transform.hugeScale) or 1,
        orientation = {
            x = tonumber(orientation.x) or 0,
            y = tonumber(orientation.y) or 0,
            z = tonumber(orientation.z) or 0,
        },
    }
end

local function applyUnbakedAssetTransform(model, transform)
    if not model or not model:IsA("Model") or type(transform) ~= "table" then
        return
    end

    if model:GetAttribute("AssetScale") ~= nil then
        return
    end

    if transform.scale and transform.scale > 0 and math.abs(transform.scale - 1) > 0.001 then
        pcall(function()
            model:ScaleTo(transform.scale)
        end)
    end

    local orientation = transform.orientation or {}
    local orientationCF = CFrame.Angles(
        math.rad(orientation.x or 0),
        math.rad(orientation.y or 0),
        math.rad(orientation.z or 0)
    )
    if orientationCF ~= CFrame.identity then
        pcall(function()
            model:PivotTo(orientationCF)
        end)
    end
end

local function getCameraDirection(cameraConfig)
    local angleY = math.rad(tonumber(cameraConfig and cameraConfig.angle_y) or 0)
    local angleX = math.rad(tonumber(cameraConfig and cameraConfig.angle_x) or 180)
    return Vector3.new(
        math.sin(angleY) * math.cos(angleX),
        math.sin(angleX),
        math.cos(angleY) * math.cos(angleX)
    )
end

-- Load Logger with wrapper
local LoggerWrapper
local loggerSuccess, loggerResult = pcall(function()
    return require(Locations.Logger)
end)

if loggerSuccess and loggerResult then
    LoggerWrapper = {
        new = function(name)
            return {
                info = function(self, ...)
                    loggerResult:Info("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                warn = function(self, ...)
                    loggerResult:Warn("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                error = function(self, ...)
                    loggerResult:Error("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
                debug = function(self, ...)
                    loggerResult:Debug("[" .. name .. "] " .. tostring((...)), { context = name })
                end,
            }
        end,
    }
else
    LoggerWrapper = {
        new = function(name)
            return {
                info = function(self, ...)
                    print("[" .. name .. "] INFO:", ...)
                end,
                warn = function(self, ...)
                    warn("[" .. name .. "] WARN:", ...)
                end,
                error = function(self, ...)
                    warn("[" .. name .. "] ERROR:", ...)
                end,
                debug = function(self, ...)
                    print("[" .. name .. "] DEBUG:", ...)
                end,
            }
        end,
    }
end

-- Load UI config
local uiConfig
local configSuccess, configResult = pcall(function()
    return Locations.getConfig("ui")
end)

if configSuccess and configResult then
    uiConfig = configResult
else
    -- Enhanced fallback config
    uiConfig = {
        active_theme = "dark",
        themes = {
            dark = {
                primary = {
                    background = Color3.fromRGB(25, 25, 30),
                    surface = Color3.fromRGB(35, 35, 45),
                    accent = Color3.fromRGB(52, 152, 219),
                },
                text = {
                    primary = Color3.fromRGB(255, 255, 255),
                    secondary = Color3.fromRGB(200, 200, 210),
                },
            },
        },
        helpers = {
            get_theme = function(config)
                return config.themes.dark
            end,
        },
        defaults = {
            panel = {
                header = {
                    close_button = {
                        icon = "89257673063270",
                        size = { width = 30, height = 30 },
                        offset = { x = 10, y = -10 },
                        background_color = Color3.fromRGB(220, 60, 60),
                        hover_color = Color3.fromRGB(180, 40, 40),
                        corner_radius = 8,
                    },
                },
            },
        },
    }
end

local InventoryPanel = {}
InventoryPanel.__index = InventoryPanel

function InventoryPanel.new()
    local self = setmetatable({}, InventoryPanel)

    self.logger = LoggerWrapper.new("InventoryPanel")

    -- Load inventory configuration
    local success, result = pcall(function()
        return ConfigLoader:LoadConfig("inventory")
    end)

    if success then
        self.inventoryConfig = result
        self.logger:info("📁 INVENTORY CONFIG LOADED", {
            hasDisplayCategories = self.inventoryConfig.display_categories ~= nil,
            categoryCount = self.inventoryConfig.display_categories
                    and #self.inventoryConfig.display_categories
                or 0,
            hasCategorySettings = self.inventoryConfig.category_settings ~= nil,
        })
    else
        self.logger:error("❌ FAILED TO LOAD INVENTORY CONFIG", { error = result })
        self.inventoryConfig = nil
    end

    -- Configurable card sizing (with safe defaults)
    self.cardSize = Vector2.new(45, 45)
    self.cardPadding = Vector2.new(8, 8)

    -- Prefer UI.lua settings if present (hot-reload in Studio for live tuning)
    pcall(function()
        if game:GetService("RunService"):IsStudio() then
            ConfigLoader:ReloadConfig("ui")
        end
    end)
    local okUI, uiConfig = pcall(function()
        return ConfigLoader:LoadConfig("ui")
    end)
    local uiAppliedSize = false
    local uiAppliedPadding = false
    if
        okUI
        and uiConfig
        and uiConfig.panel_configs
        and uiConfig.panel_configs.inventory_panel
        and uiConfig.panel_configs.inventory_panel.grid
    then
        local invGrid = uiConfig.panel_configs.inventory_panel.grid
        if invGrid.card_size and typeof(invGrid.card_size) == "Vector2" then
            self.cardSize = invGrid.card_size
            uiAppliedSize = true
        end
        if invGrid.card_padding and typeof(invGrid.card_padding) == "Vector2" then
            self.cardPadding = invGrid.card_padding
            uiAppliedPadding = true
        end
    end

    -- Fallback to inventory.lua overrides
    local invUi = self.inventoryConfig and self.inventoryConfig.ui
    if invUi and typeof(invUi) == "table" then
        if (not uiAppliedSize) and invUi.card_size and typeof(invUi.card_size) == "Vector2" then
            self.cardSize = invUi.card_size
        end
        if
            not uiAppliedPadding
            and invUi.card_padding
            and typeof(invUi.card_padding) == "Vector2"
        then
            self.cardPadding = invUi.card_padding
        end
    end

    -- Load context menu configuration
    local contextSuccess, contextResult = pcall(function()
        return ConfigLoader:LoadConfig("context_menus")
    end)

    if contextSuccess then
        self.contextMenuConfig = contextResult
        self.logger:info("🖱️ CONTEXT MENU CONFIG LOADED", {
            hasItemTypes = self.contextMenuConfig.item_types ~= nil,
            itemTypeCount = self.contextMenuConfig.item_types
                    and #self.contextMenuConfig.item_types
                or 0,
        })
    else
        self.logger:error("❌ FAILED TO LOAD CONTEXT MENU CONFIG", { error = contextResult })
        self.contextMenuConfig = nil
    end

    -- Panel state
    self.isVisible = false
    self.frame = nil
    self.searchBox = nil
    self.itemsGrid = nil
    self.itemFrames = {}
    self.selectedCategory = "All"
    self.searchTerm = ""

    -- Delete mode (header 🗑 toggle + multi-select): off by default. _deleteSelection
    -- is keyed by bucket+uid -> item; _deleteSelectedFrames mirrors it with the live
    -- card frame so a re-render (folder replication) can re-paint the highlight.
    self._deleteMode = false
    self._deleteSelection = {}
    self._deleteSelectedFrames = {}
    self._deleteSelectionCount = 0

    -- Initialize with empty data - will be populated from real inventory
    self.inventoryData = {}

    -- Get reference to player for inventory access
    self.player = Players.LocalPlayer

    -- Initialize networking
    self.signals = nil
    self:_initializeNetworking()

    -- Player-facing card scale (persisted: SettingsService → InventoryCardScale attribute).
    -- The config sizes above stay the SMALL baseline (the dense "lay of the land" default);
    -- medium/large multiply it for players who find 45px cards squinty.
    self.baseCardSize = self.cardSize
    self.baseCardPadding = self.cardPadding
    self._cardScale = nil
    self:_applyCardScale(self:_getCardScaleName())
    -- the attribute lands a beat after join (and echoes our own sets) — re-apply on change;
    -- _applyCardScale dedupes, so the echo after an optimistic local apply is a no-op
    self.player:GetAttributeChangedSignal("InventoryCardScale"):Connect(function()
        self:_applyCardScale(self:_getCardScaleName())
    end)

    return self
end

-- Current persisted scale name ("small"/"medium"/"large") from the replicated attribute.
function InventoryPanel:_getCardScaleName()
    local value = self.player:GetAttribute("InventoryCardScale")
    if type(value) == "string" and CARD_SCALE_FACTORS[value] then
        return value
    end
    return "small"
end

-- Apply a card scale: multiply the config baseline into self.cardSize/cardPadding and,
-- if the panel is open, resize both UIGridLayouts and rebuild the cards (card internals
-- are cardSize-derived, so the rebuild rescales badges/chips too).
function InventoryPanel:_applyCardScale(scaleName)
    if not CARD_SCALE_FACTORS[scaleName] then
        scaleName = "small"
    end
    if self._cardScale == scaleName then
        return
    end
    self._cardScale = scaleName

    local factor = CARD_SCALE_FACTORS[scaleName]
    self.cardSize = Vector2.new(
        math.floor(self.baseCardSize.X * factor + 0.5),
        math.floor(self.baseCardSize.Y * factor + 0.5)
    )
    self.cardPadding = Vector2.new(
        math.floor(self.baseCardPadding.X * factor + 0.5),
        math.floor(self.baseCardPadding.Y * factor + 0.5)
    )

    if self.isVisible and self.equippedGrid and self.inventoryGrid then
        for _, container in ipairs({ self.equippedGrid, self.inventoryGrid }) do
            local grid = container:FindFirstChildOfClass("UIGridLayout")
            if grid then
                grid.CellSize = UDim2.new(0, self.cardSize.X, 0, self.cardSize.Y)
                grid.CellPadding = UDim2.new(0, self.cardPadding.X, 0, self.cardPadding.Y)
            end
        end
        self:_updateItemsDisplay()
    end

    if self._cardScaleButton then
        self._cardScaleButton.Text = CARD_SCALE_LABEL[scaleName]
    end
end

function InventoryPanel:Show(parent)
    if self.isVisible then
        return
    end

    self:_createUI(parent)
    self:_loadRealInventoryData() -- Load real data first
    self:_updateItemsDisplay() -- Update items display with real data
    self:_refreshCategoryTabs() -- Update category tabs with real counts (after data is loaded)

    -- BIOME RPS: crossing a zone border re-prices every pet card (the zone event we
    -- already capture — Jason: "recalculate the pets in the inventory"). The power
    -- sort re-runs with the new numbers, so the grid reorders to this zone's truth.
    if not self._zoneListener then
        self._zoneListener = Players.LocalPlayer
            :GetAttributeChangedSignal("CurrentArea")
            :Connect(function()
                if self.isVisible then
                    self:_loadRealInventoryData()
                    self:_updateItemsDisplay()
                end
            end)
    end
    self:_setupEquippedFolderListeners() -- Listen for equipped changes
    self:SetupRealTimeUpdates() -- Listen for inventory changes (pets)
    self:_setupBucketListeners() -- Live-update the open non-pet bucket (enhancements/etc.)

    self.isVisible = true
    -- #179: tick the availability rings / red counts while the window is open (timers count down).
    task.spawn(function()
        while self.isVisible do
            pcall(function()
                self:_refreshLockoutVisuals()
            end)
            task.wait(0.5)
        end
    end)
    self.logger:info("Professional inventory panel shown")
end

-- Decode the lockout pool replicated by EnemyService (a JSON player attribute), or nil.
function InventoryPanel:_decodeLockouts()
    local raw = self.player and self.player:GetAttribute("PetLockouts")
    if type(raw) ~= "string" or raw == "" then
        return nil
    end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    return ok and type(decoded) == "table" and decoded or nil
end

-- Paint a pill RING on an equipped card: white = available, red = locked/recovering (+ timer).
-- The availability ring is a BORDER (transparent center), not a filled overlay — so the PET stays
-- visible inside it. White stroke = available, red = locked/recovering; a small timer chip sits at
-- the BOTTOM (never over the pet's face). (Earlier this drew a filled pill on top of the card, which
-- covered the pet with a solid block — a pure layering bug.)
function InventoryPanel:_applyAvailabilityRing(frame, lockUntil, now)
    local ring = frame:FindFirstChild("AvailRing")
    local timer = frame:FindFirstChild("AvailTimer")
    if not ring then
        -- Jason's pill_frame art is a hollow ring (transparent center). Sit it BEHIND the card (low
        -- ZIndex) and slightly oversized, so only the ring's border frames the card from behind — the
        -- pet/card content draws on top and is never clipped or covered by the ring.
        ring = Instance.new("ImageLabel")
        ring.Name = "AvailRing"
        ring.BackgroundTransparency = 1
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.Position = UDim2.fromScale(0.5, 0.5)
        ring.Size = UDim2.fromScale(1.2, 1.2)
        ring.ScaleType = Enum.ScaleType.Stretch
        ring.ZIndex = 0
        ring.Parent = frame
        timer = Instance.new("TextLabel")
        timer.Name = "AvailTimer"
        timer.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
        timer.BackgroundTransparency = 0.15
        timer.AnchorPoint = Vector2.new(0.5, 1)
        timer.Position = UDim2.fromScale(0.5, 0.97) -- bottom edge, clear of the pet
        timer.Size = UDim2.fromOffset(46, 18)
        timer.Font = Enum.Font.GothamBlack
        timer.TextSize = 12
        timer.TextColor3 = Color3.fromRGB(255, 255, 255)
        timer.ZIndex = 122
        local tc = Instance.new("UICorner")
        tc.CornerRadius = UDim.new(0, 6)
        tc.Parent = timer
        timer.Parent = frame
    end
    local locked = lockUntil ~= nil
    ring.Visible = true
    ring.Image = locked and PILL_UI.slot_locked or PILL_UI.slot_available -- ruby ring / neutral ring
    timer.Visible = locked
    timer.Text = locked and lockoutFormatTime(lockUntil - now) or ""
end

-- Draw a blank ring for every UNLOCKED-but-empty equip slot, so the row always shows how many slots
-- you have (filled cards + blank rings = total slots). Count comes from the replicated PetEquipSlots.
-- Rings start neutral; _refreshLockoutVisuals repaints them every tick from the lockout pool, so a
-- slot freed by unequipping a downed pet stays RED (with its timer) until it's actually available.
function InventoryPanel:_renderEmptySlotRings(filledCount)
    self._emptySlotRings = {}
    local total = tonumber(self.player and self.player:GetAttribute("PetEquipSlots")) or 0
    if total <= filledCount then
        return
    end
    for i = filledCount + 1, total do
        -- The open slot IS the neutral pill_frame (hollow ring) over a faint dark canvas, so it
        -- reads as an empty version of a filled slot.
        local ring = Instance.new("ImageLabel")
        ring.Name = "EmptySlotRing"
        ring.Size = UDim2.new(0, self.cardSize.X, 0, self.cardSize.Y)
        ring.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
        ring.BackgroundTransparency = 0.35 -- faint canvas inside the hole
        ring.BorderSizePixel = 0
        ring.Image = PILL_UI.slot_available -- neutral (white) ring = an open, available slot
        ring.ImageTransparency = 0.25
        ring.ScaleType = Enum.ScaleType.Stretch
        ring.LayoutOrder = i
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 10)
        rc.Parent = ring
        ring.Parent = self.equippedGrid
        table.insert(self._emptySlotRings, ring)
    end
end

-- Repaint one EMPTY slot ring from the lockout pool: red + timer while its slot lock is still
-- recovering, neutral once it's genuinely open. Same lazy timer chip as _applyAvailabilityRing.
function InventoryPanel:_applyEmptySlotRing(ring, lockUntil, now)
    local locked = lockUntil ~= nil
    ring.Image = locked and PILL_UI.slot_locked or PILL_UI.slot_available
    ring.ImageTransparency = locked and 0 or 0.25
    local timer = ring:FindFirstChild("AvailTimer")
    if locked and not timer then
        timer = Instance.new("TextLabel")
        timer.Name = "AvailTimer"
        timer.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
        timer.BackgroundTransparency = 0.15
        timer.AnchorPoint = Vector2.new(0.5, 1)
        timer.Position = UDim2.fromScale(0.5, 0.97)
        timer.Size = UDim2.fromOffset(46, 18)
        timer.Font = Enum.Font.GothamBlack
        timer.TextSize = 12
        timer.TextColor3 = Color3.fromRGB(255, 255, 255)
        timer.ZIndex = 122
        local tc = Instance.new("UICorner")
        tc.CornerRadius = UDim.new(0, 6)
        tc.Parent = timer
        timer.Parent = ring
    end
    if timer then
        timer.Visible = locked
        timer.Text = locked and lockoutFormatTime(lockUntil - now) or ""
    end
end

-- Hide any ring/timer on a card (an inventory pet that's fully available stays clean).
function InventoryPanel:_clearAvailabilityRing(frame)
    local ring = frame:FindFirstChild("AvailRing")
    local timer = frame:FindFirstChild("AvailTimer")
    if ring then
        ring.Visible = false
    end
    if timer then
        timer.Visible = false
    end
end

-- Read the LIVE deployed pet models (same source the squad HUD reads) so an EQUIPPED card reflects
-- whether its pet can actually be SUMMONED right now. _enforceLockouts stamps SlotLockUntil (the
-- 1-min slot hold) and CooldownUntil (down / 5-min identity) on every live pet — so a re-equipped pet
-- sitting in a still-recovering slot carries SlotLockUntil > now and its card stays RED until it's
-- summonable, instead of going white the moment it's re-slotted.
function InventoryPanel:_deployedLocks(now)
    local byUid, byKey, claimedSlots = {}, {}, {}
    local pp = Workspace:FindFirstChild("PlayerPets")
    local folder = pp and self.player and pp:FindFirstChild(self.player.Name)
    if not folder then
        return byUid, byKey, claimedSlots
    end
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") then
            -- Every live pet CLAIMS its squad position: a slot lock with a live occupant is shown
            -- on that pet's card, so only occupant-less locks belong to the empty slot rings.
            local pn = m:FindFirstChild("PositionNumber")
            local pos = (pn and pn.Value) or m:GetAttribute("PositionNumber")
            if pos then
                claimedSlots["slot_" .. tostring(pos)] = true
            end
            local until_ = math.max(
                tonumber(m:GetAttribute("SlotLockUntil")) or 0,
                tonumber(m:GetAttribute("CooldownUntil")) or 0
            )
            if until_ > now then
                local uid = m:GetAttribute("LockoutUid")
                local key = m:GetAttribute("LockoutKey")
                if uid then
                    byUid[uid] = math.max(byUid[uid] or 0, until_)
                end
                if key then
                    byKey[key] = byKey[key] or {}
                    table.insert(byKey[key], until_)
                end
            end
        end
    end
    for _, list in pairs(byKey) do
        table.sort(list, function(a, b)
            return a > b
        end)
    end
    return byUid, byKey, claimedSlots
end

-- Repaint every card's lockout overlay from the decoded pool. Equipped cards get the ring; an
-- inventory STACK whose available count is reduced shows its count in RED.
function InventoryPanel:_refreshLockoutVisuals()
    local frames = self.itemFrames
    if type(frames) ~= "table" then
        return
    end
    local map = self:_decodeLockouts()
    local now = os.time()
    -- active recovering count per stack key (consumed greedily by equipped ghosts of that key)
    local stackActive = {}
    if map and type(map.stacks) == "table" then
        for key, list in pairs(map.stacks) do
            local active = {}
            if type(list) == "table" then
                for _, t in ipairs(list) do
                    if t > now then
                        active[#active + 1] = t
                    end
                end
            end
            table.sort(active, function(a, b)
                return a > b
            end)
            if #active > 0 then
                stackActive[key] = active
            end
        end
    end
    local depUid, depKey, claimedSlots = self:_deployedLocks(now)
    local depKeyUsed = {}
    local stackUsed = {}
    for _, frame in ipairs(frames) do
        if frame and frame.Parent then
            local kind = frame:GetAttribute("LockKind")
            local lid = frame:GetAttribute("LockId")
            local equipped = frame:GetAttribute("LockEquipped") == true
            local lockUntil
            local recovering = 0
            if kind == "special" and lid and map and type(map.pets) == "table" then
                local u = map.pets[lid]
                if type(u) == "number" and u > now then
                    lockUntil = u
                end
            elseif kind == "stack" and lid then
                local active = stackActive[lid]
                recovering = active and #active or 0
                if equipped and active then
                    local used = stackUsed[lid] or 0
                    if used < #active then
                        lockUntil = active[used + 1]
                        stackUsed[lid] = used + 1
                    end
                end
            end
            if equipped and kind then
                -- An equipped pet's REAL state is on its live model (slot + identity holds). Prefer
                -- that over the replicated pool so a re-equipped pet stays red until summonable; fall
                -- back to the pool value if the model isn't found.
                local depUntil
                if kind == "special" and lid then
                    depUntil = depUid[lid]
                elseif kind == "stack" and lid and depKey[lid] then
                    local used = depKeyUsed[lid] or 0
                    if used < #depKey[lid] then
                        depUntil = depKey[lid][used + 1]
                        depKeyUsed[lid] = used + 1
                    end
                end
                lockUntil = depUntil or lockUntil
                -- equipped slot: always ring it (white = available, red = recovering + timer)
                self:_applyAvailabilityRing(frame, lockUntil, now)
            elseif kind == "special" then
                -- inventory HUGE: a unique pet on its 5-min uid lockout is NOT deployable even though
                -- the slot is free — show the red ring + timer so you don't try to re-deploy it; an
                -- available huge stays clean.
                if lockUntil then
                    self:_applyAvailabilityRing(frame, lockUntil, now)
                else
                    self:_clearAvailabilityRing(frame)
                end
            elseif kind == "stack" then
                -- inventory stack: red the count label when some are recovering (reduced availability)
                local countLbl = frame:FindFirstChild("QtyLabel")
                if countLbl and countLbl:IsA("TextLabel") then
                    countLbl.TextColor3 = recovering > 0 and Color3.fromRGB(235, 70, 70)
                        or Color3.fromRGB(255, 255, 255)
                end
            end
        end
    end
    -- EMPTY slot rings: a slot lock with NO live occupant (its downed pet was unequipped) is a
    -- recovering OPEN slot — ring it red with the remaining time. Truth is the persisted lockout
    -- pool (replicated PetLockouts.slots); locks claimed by a live pet already paint that card.
    local rings = self._emptySlotRings
    if rings and #rings > 0 then
        local freed = {}
        if map and type(map.slots) == "table" then
            for slotName, t in pairs(map.slots) do
                if type(t) == "number" and t > now and not claimedSlots[slotName] then
                    freed[#freed + 1] = t
                end
            end
            table.sort(freed, function(a, b)
                return a > b
            end)
        end
        for i, ring in ipairs(rings) do
            if ring.Parent then
                self:_applyEmptySlotRing(ring, freed[i], now)
            end
        end
    end
end

function InventoryPanel:Hide()
    if not self.isVisible then
        return
    end

    -- per-card right-click listeners are GLOBAL UIS connections — without this they
    -- outlive the panel and right-click steering spawns orphan context menus
    if self._rightClickConnections then
        for _, connection in pairs(self._rightClickConnections) do
            if connection then
                connection:Disconnect()
            end
        end
        self._rightClickConnections = {}
    end
    -- bucket folder listeners are live ChildAdded/Removed connections — drop them with the panel
    self:_teardownBucketListeners()
    local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
    for _, gui in ipairs(pg and pg:GetChildren() or {}) do
        if gui.Name == "ContextMenuGui" then
            gui:Destroy()
        end
    end

    if self.frame then
        self.frame:Destroy()
        self.frame = nil
    end
    self._cardScaleButton = nil -- lived in the destroyed header

    -- delete-mode chrome lived in the destroyed frame/header; reset to idle so a
    -- re-open starts clean (no stale selection or armed pill)
    self._deletePill = nil
    self._deleteActionButton = nil
    self._deleteMode = false
    self._deleteSelection = {}
    self._deleteSelectedFrames = {}
    self._deleteSelectionCount = 0

    self.itemFrames = {}
    self.isVisible = false
    self.logger:info("Inventory panel hidden")
end

function InventoryPanel:_createUI(parent)
    local theme = uiConfig.helpers.get_theme(uiConfig)

    -- Create image-based panel using BaseUI system (like Settings panel)
    local BaseUI = require(script.Parent.Parent.BaseUI)
    local baseUI = BaseUI.new()

    -- Create professional image-based inventory panel
    -- Near-fullscreen, centered (Jason tuned live): 0.94 wide, full height minus 56px. The MenuOverlay
    -- uses the full viewport (IgnoreGuiInset) + a dim scrim, so this reads as a modal. Header/content
    -- below are RELATIVE to this frame, so they scale on every device.
    local panelResult = baseUI:CreateImagePanel("inventory_panel", {
        size = UDim2.new(0.94, 0, 0.92, 0),
        position = UDim2.new(0.5, 0, 0.5, 0),
        anchor_point = Vector2.new(0.5, 0.5),
    }, parent)

    self.frame = panelResult.panel
    self.frame.Name = "InventoryPanel"
    self.frame.Size = UDim2.new(0.94, 0, 0.92, 0)
    self.frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    self.frame.AnchorPoint = Vector2.new(0.5, 0.5)

    -- Standard area-themed game pill around the whole menu (Jason: "a pill around the menu as a
    -- whole"), same style as the other panels.
    PanelChrome.pillBorder(self.frame, PanelChrome.areaPill(), 130, 0, 0.07) -- match the shared shell

    -- Store references
    self.header = panelResult.header
    self.content = panelResult.content
    self.baseUI = baseUI

    -- RELATIVE header + content (Jason, tuned live): header = top 15%, content = bottom 85% docked
    -- right under it. This makes everything scale on mobile AND closes the dead "blue bar" gap the
    -- fixed-px header used to leave between itself and the content.
    if self.header then
        self.header.Size = UDim2.new(1, 0, 0.12, 0)
        self.header.Position = UDim2.new(0, 0, 0.03, 0)
        self.header.AnchorPoint = Vector2.new(0, 0)
        -- The panel background is an opaque ImageLabel whose source art has a blue band at the very
        -- top. The header sits 0.03 down (it can't go higher — the pill ring covers it when the panel
        -- scales down), so that blue band peeks through as a thin strip above the header. The header
        -- and content cover the rest of the image, so tinting the whole image to the header colour
        -- (the SSOT) recolours ONLY that exposed strip to match — no extra fill element needed.
        -- BackgroundColor3 must match too: the UICorner below rounds the frame by revealing the
        -- background at the corners, so a light background would show as gray corner wedges (Jason).
        if self.header:IsA("Frame") then
            self.frame.ImageColor3 = self.header.BackgroundColor3
            self.frame.BackgroundColor3 = self.header.BackgroundColor3
            self.frame.BackgroundTransparency = 0
        end
    end
    if self.content then
        self.content.Size = UDim2.new(1, 0, 0.85, 0)
        self.content.Position = UDim2.new(0.5, 0, 0.15, 0)
        self.content.AnchorPoint = Vector2.new(0.5, 0)
    end

    -- Header LEFT sub-container (Jason): 30% width, full height, upper-left — holds the bag icon +
    -- "Inventory" title. Relative so it scales; the action buttons get a 70% RIGHT container below.
    if self.header then
        local leftBox = Instance.new("Frame")
        leftBox.Name = "HeaderLeft"
        leftBox.AnchorPoint = Vector2.new(0, 0)
        leftBox.Position = UDim2.new(0, 0, 0, 0)
        leftBox.Size = UDim2.new(0.3, 0, 1, 0)
        leftBox.BackgroundTransparency = 1
        leftBox.ZIndex = 16
        leftBox.Parent = self.header
        local bagIcon = self.header:FindFirstChild("HeaderIcon")
        if bagIcon then
            bagIcon.AnchorPoint = Vector2.new(0, 0.5)
            bagIcon.Position = UDim2.new(0, 6, 0.5, 0)
            bagIcon.Size = UDim2.new(1, 0, 1, 0) -- full height; aspect constraint keeps it square (Jason)
            bagIcon.Parent = leftBox
        end
        local titleLbl = self.header:FindFirstChild("HeaderTitle")
        if titleLbl then
            titleLbl.AnchorPoint = Vector2.new(0, 0.5)
            titleLbl.Position = UDim2.new(0.25, 0, 0.5, 0)
            titleLbl.Size = UDim2.new(0.5, 0, 0.9, 0)
            titleLbl.TextScaled = true
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left
            titleLbl.Parent = leftBox
        end
    end
    local fcorner = self.frame:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
    fcorner.CornerRadius = UDim.new(0, 22)
    fcorner.Parent = self.frame

    -- Add close button to header if it exists (same as Settings panel)
    if self.header then
        -- Get close button config from global defaults with safety checks
        local config = nil
        if
            uiConfig
            and uiConfig.defaults
            and uiConfig.defaults.panel
            and uiConfig.defaults.panel.header
            and uiConfig.defaults.panel.header.close_button
        then
            config = uiConfig.defaults.panel.header.close_button
        else
            -- Fallback configuration if config not found
            config = {
                icon = "89257673063270",
                size = { width = 30, height = 30 },
                offset = { x = 10, y = -10 },
                background_color = Color3.fromRGB(220, 60, 60),
                hover_color = Color3.fromRGB(180, 40, 40),
                corner_radius = 8,
            }
            self.logger:warn("Close button config not found, using fallback")
        end

        -- Header RIGHT sub-container (Jason): ~70% width, full height, upper-right — a flex row of the
        -- FIVE action buttons, each 1/5 width (RELATIVE, no fixed pixels). Small px gap on the right
        -- for the close-X (which hangs outside the header). LayoutOrder L→R: Delete,Cards,Auto,Eggs,Trade.
        local btnRow = Instance.new("Frame")
        btnRow.Name = "HeaderButtons"
        btnRow.AnchorPoint = Vector2.new(1, 0)
        btnRow.Position = UDim2.new(0.97, 0, 0, 0) -- relative gap on the right for the close-X (Jason)
        btnRow.Size = UDim2.new(0.7, 0, 1, 0)
        btnRow.BackgroundTransparency = 1
        btnRow.ZIndex = 250
        btnRow.Parent = self.header
        local btnLayout = Instance.new("UIListLayout")
        btnLayout.FillDirection = Enum.FillDirection.Horizontal
        btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        btnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        btnLayout.SortOrder = Enum.SortOrder.LayoutOrder
        btnLayout.Padding = UDim.new(0, 4)
        btnLayout.Parent = btnRow

        -- Trade lives INSIDE the inventory now (tray consolidation): rightmost button in the row.
        do
            local tradeBtn = Instance.new("TextButton")
            tradeBtn.Name = "TradeButton"
            tradeBtn.Size = UDim2.new(1 / 5, -4, 0.74, 0) -- relative 1/5 of the button row
            tradeBtn.LayoutOrder = 5
            tradeBtn.BackgroundColor3 = Color3.fromRGB(70, 140, 90)
            tradeBtn.Text = "🤝 Trade"
            tradeBtn.TextColor3 = Color3.fromRGB(240, 255, 245)
            tradeBtn.TextScaled = true
            tradeBtn.Font = Enum.Font.GothamBold
            tradeBtn.ZIndex = 250
            tradeBtn.Parent = btnRow
            pillify(tradeBtn)
            local tradeTc = Instance.new("UITextSizeConstraint")
            tradeTc.MaxTextSize = 28 -- Jason: match the other header pills
            tradeTc.Parent = tradeBtn
            tradeBtn.Activated:Connect(function()
                local mm = _G.MenuManager
                if mm and mm.OpenPanel then
                    -- guard an un-deployed draft before leaving for the Trade panel
                    self:_requestClose(function()
                        self:Hide()
                        mm:OpenPanel("Trade", "slide_in_right")
                    end)
                end
            end)
        end

        -- Shared header-pill builder (hatch settings + card-size settings below).
        -- offset = distance from the close-X slot to the pill's RIGHT edge (right-to-left chain).
        local function pill(text, layoutOrder, color)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1 / 5, -4, 0.74, 0) -- relative 1/5 of the button row
            b.LayoutOrder = layoutOrder
            b.BackgroundColor3 = color
            b.TextColor3 = Color3.fromRGB(240, 248, 255)
            b.Text = text
            b.TextScaled = true
            b.Font = Enum.Font.GothamBold
            b.ZIndex = 250
            b.Parent = btnRow
            pillify(b) -- currency-pill capsule (Eggs / AUTO / Cards / Delete header pills)
            local tc2 = Instance.new("UITextSizeConstraint")
            tc2.MaxTextSize = 28 -- Jason
            tc2.Parent = b
            return b
        end

        -- HATCH CONTROLS (Jason: "our inventory and pets menu are the same thing") —
        -- three header pills left of Trade driving the REAL egg system
        -- (EggInteractionService): Auto/Manual, count cycle 1/Half/Max, and HATCH
        -- (fires at the current-target egg; the service nags "move near an egg").
        do
            local okEgg, EggSvc = pcall(function()
                return require(ReplicatedStorage.Shared.Services.EggInteractionService)
            end)
            if okEgg and EggSvc then
                -- right-to-left after Trade: TWO settings pills only (Jason: "not sure
                -- why we have a hatch button" — hatching happens AT the egg; these
                -- configure how the E-key/auto hatch behaves)
                local countBtn = pill("Eggs: 1", 4, Color3.fromRGB(70, 100, 160))
                local autoBtn = pill("Manual", 3, Color3.fromRGB(90, 90, 110))

                local countMode = "one" -- one | half | max (display follows the service truth)
                local function refresh()
                    local st = EggSvc:GetHatchUiState()
                    -- the pill reflects the persisted ACTION MODE (a setting, not the
                    -- running loop — Jason: "it should just turn ON auto hatch so when
                    -- I'm near an egg and hatch, it auto hatches")
                    local isAuto = st.mode == "auto"
                    autoBtn.Text = isAuto and "AUTO" or "Manual"
                    autoBtn.BackgroundColor3 = isAuto and Color3.fromRGB(220, 82, 95)
                        or Color3.fromRGB(90, 90, 110)
                    pillify(autoBtn) -- re-tint the capsule to the new state color
                    countBtn.Text = ("Eggs: %d"):format(st.count)
                end
                local function flash(text)
                    autoBtn.Text = text
                    task.delay(1.4, refresh)
                end
                autoBtn.Activated:Connect(function()
                    local st = EggSvc:GetHatchUiState()
                    if st.mode ~= "auto" and not st.autoOwned then
                        flash("🔒 Locked")
                        return
                    end
                    -- SetHatchActionMode persists (the E-key behavior at any egg) and
                    -- never starts anything from here
                    EggSvc:SetHatchActionMode(st.mode == "auto" and "single" or "auto")
                    refresh()
                end)
                countBtn.Activated:Connect(function()
                    local st = EggSvc:GetHatchUiState()
                    if countMode == "one" then
                        countMode = "half"
                        EggSvc:SetSelectedHatchCount(math.max(1, math.floor(st.max / 2)))
                    elseif countMode == "half" then
                        countMode = "max"
                        EggSvc:SetSelectedHatchCount(st.max)
                    else
                        countMode = "one"
                        EggSvc:SetSelectedHatchCount(1)
                    end
                    refresh()
                end)
                refresh()
            end
        end

        -- CARD SIZE pill — cycles the pet-card grid scale S/M/L (persisted player setting:
        -- SettingsService → InventoryCardScale attribute). Small stays the dense default;
        -- M/L are for players who find the 45px cards squinty.
        do
            local scaleBtn = pill(
                CARD_SCALE_LABEL[self._cardScale or "small"],
                2, -- Cards pill (left of Auto)
                Color3.fromRGB(90, 90, 110)
            )
            self._cardScaleButton = scaleBtn
            scaleBtn.Activated:Connect(function()
                local nextScale = CARD_SCALE_NEXT[self._cardScale] or "medium"
                -- optimistic local apply (instant re-layout); the server echo via the
                -- replicated attribute is deduped in _applyCardScale
                self:_applyCardScale(nextScale)
                if self.signals and self.signals.Settings_SetInventoryCardScale then
                    self.signals.Settings_SetInventoryCardScale:FireServer({ scale = nextScale })
                end
            end)
        end

        -- DELETE pill — a TOGGLE (Jason: "a DELETE button that is a TOGGLE"). Armed,
        -- it turns card clicks into multi-select of deletable STACKS (uniques refuse);
        -- the actual delete runs from the floating "Delete (N)" button -> confirm.
        -- Sits left of the card-size pill in the same right-to-left chain.
        do
            local delPill = pill(
                "🗑 Delete",
                1, -- Delete pill (leftmost of the button row)
                DELETE_PILL_IDLE
            )
            self._deletePill = delPill
            delPill.Activated:Connect(function()
                self:_setDeleteMode(not self._deleteMode)
            end)
            self:_restyleDeletePill()
        end

        -- DELETE action button — floats bottom-center, only visible while armed.
        -- Disabled (no-op) at zero selection; otherwise opens the bulk-confirm dialog.
        do
            local del = Instance.new("TextButton")
            del.Name = "DeleteActionButton"
            del.Size = UDim2.new(0.4, 0, 0.09, 0) -- relative (Jason)
            del.AnchorPoint = Vector2.new(0.5, 1)
            del.Position = UDim2.new(0.5, 0, 1, -14)
            del.BackgroundColor3 = DELETE_PILL_IDLE
            del.Text = "🗑 Delete (0)"
            del.TextColor3 = Color3.fromRGB(255, 245, 245)
            del.TextScaled = true
            del.Font = Enum.Font.GothamBold
            del.ZIndex = 260
            del.Visible = false
            local dc = Instance.new("UICorner")
            dc.CornerRadius = UDim.new(0, 10)
            dc.Parent = del
            local dcon = Instance.new("UITextSizeConstraint")
            dcon.MaxTextSize = 18
            dcon.Parent = del
            del.Parent = self.frame
            pillify(del)
            self._deleteActionButton = del
            del.Activated:Connect(function()
                if not self._deleteMode or (self._deleteSelectionCount or 0) <= 0 then
                    return
                end
                self:_showBulkDeleteConfirmation()
            end)
            self:_updateDeleteActionButton()
        end

        -- SELL / SALVAGE entry button — floats bottom-center, ONLY visible while the
        -- Enhancements category is selected. Opens the dedicated EnhancementSellPanel
        -- (registered on MenuManager); the manager switches panels inside the overlay.
        do
            local sell = Instance.new("TextButton")
            sell.Name = "EnhancementSellButton"
            sell.Size = UDim2.new(0.4, 0, 0.09, 0) -- relative (Jason)
            sell.AnchorPoint = Vector2.new(0.5, 1)
            sell.Position = UDim2.new(0.5, 0, 1, -14)
            sell.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
            sell.Text = "💎 Sell / Salvage"
            sell.TextColor3 = Color3.fromRGB(245, 255, 248)
            sell.TextScaled = true
            sell.Font = Enum.Font.GothamBold
            sell.ZIndex = 260
            sell.Visible = false
            local sc = Instance.new("UICorner")
            sc.CornerRadius = UDim.new(0, 10)
            sc.Parent = sell
            local scon = Instance.new("UITextSizeConstraint")
            scon.MaxTextSize = 18
            scon.Parent = sell
            sell.Parent = self.frame
            pillify(sell)
            self._enhancementSellButton = sell
            sell.Activated:Connect(function()
                if _G.MenuManager then
                    _G.MenuManager:OpenPanel("EnhancementSell", "bounce_in")
                end
            end)
            self:_updateEnhancementSellButton()
        end

        local closeButton = Instance.new("ImageButton")
        closeButton.Name = "CloseButton"
        closeButton.Size = UDim2.new(0, config.size.width, 0, config.size.height)

        -- Position in top-right-corner with offset (extends outside bounds)
        closeButton.Position = UDim2.new(1, config.offset.x, 0, config.offset.y)
        closeButton.AnchorPoint = Vector2.new(1, 0) -- Anchor to top-right

        closeButton.BackgroundColor3 = config.background_color
        closeButton.BorderSizePixel = 0
        closeButton.Image = "rbxassetid://" .. config.icon
        closeButton.ScaleType = Enum.ScaleType.Fit
        -- Parent to the PANEL frame (sibling of the 130 pill border) at Z146 so the X sits ABOVE the
        -- outer pill, not under it (Jason). Same top-right corner position.
        closeButton.ZIndex = 146
        closeButton.Parent = self.frame

        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, config.corner_radius)
        closeCorner.Parent = closeButton

        -- Add hover effect
        closeButton.MouseEnter:Connect(function()
            closeButton.BackgroundColor3 = config.hover_color
        end)

        closeButton.MouseLeave:Connect(function()
            closeButton.BackgroundColor3 = config.background_color
        end)

        -- Connect close functionality (guards an un-deployed squad draft before closing)
        closeButton.MouseButton1Click:Connect(function()
            self:_requestClose()
        end)
    end

    -- Category tabs
    self:_createCategoryTabs()

    -- Search section
    self:_createSearchSection()

    -- Items grid
    self:_createItemsGrid()

    -- Add entrance animation
    self:_animateEntrance()
end

function InventoryPanel:_createCategoryTabs()
    local theme = uiConfig.helpers.get_theme(uiConfig)

    -- Category container
    local categoryContainer = Instance.new("Frame")
    categoryContainer.Name = "CategoryContainer"
    categoryContainer.Size = UDim2.new(0.95, 0, 0.1, 0) -- 95% width, 10% height (relative — Jason)
    categoryContainer.Position = UDim2.new(0.025, 0, 0.02, 0) -- 2.5% from left, 2% from top (scales with screen)
    categoryContainer.BackgroundTransparency = 1
    categoryContainer.ZIndex = 101
    categoryContainer.Parent = self.content

    -- Layout
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 3) -- small gap so the 1/6-width tabs fit across the row
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Parent = categoryContainer

    -- Get categories from configuration
    local categories = self:_getConfiguredCategories()

    for i, category in ipairs(categories) do
        self:_createCategoryTab(category, categoryContainer, i)
    end
end

function InventoryPanel:_refreshCategoryTabs()
    -- Find the category container and update the counts
    local categoryContainer = self.content and self.content:FindFirstChild("CategoryContainer")
        or self.frame:FindFirstChild("CategoryContainer")
    if not categoryContainer then
        return
    end

    -- Get configured categories with updated counts
    local categories = self:_getConfiguredCategories()

    -- Update each category tab's count display
    for _, category in ipairs(categories) do
        local tab = categoryContainer:FindFirstChild(category.name .. "Tab")
        if tab then
            local content = tab:FindFirstChild("Frame") -- Content frame name might be different
            if not content then
                -- Try to find by class
                for _, child in pairs(tab:GetChildren()) do
                    if child:IsA("Frame") and child.BackgroundTransparency == 1 then
                        content = child
                        break
                    end
                end
            end

            if content then
                local countLabel = content:FindFirstChild("CountLabel")
                if countLabel then
                    countLabel.Text = category.count .. " items"
                end
            end
        end
    end

    self.logger:info("🔄 CONFIGURED CATEGORY TABS REFRESHED", {
        categoriesUpdated = #categories,
    })
end

function InventoryPanel:_createCategoryTab(category, parent, layoutOrder)
    local isSelected = (category.name == self.selectedCategory)

    -- Tab button — RELATIVE width 1/7 (Jason: seven tabs); the fixed 120px broke the layout on narrow
    -- screens. Small px gap (layout Padding 3) eats a hair, so subtract it back here.
    local tab = Instance.new("TextButton")
    tab.Name = category.name .. "Tab"
    tab.Size = UDim2.new(1 / 7, -3, 1, 0)
    tab.BackgroundColor3 = isSelected and Color3.fromRGB(52, 152, 219) or Color3.fromRGB(40, 40, 50)
    tab.BorderSizePixel = 0
    tab.Text = ""
    tab.LayoutOrder = layoutOrder
    tab.ZIndex = 102
    tab.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0) -- full capsule to match the pill ring
    corner.Parent = tab

    -- The game pill BORDER ring (area-themed) so the tabs read as pills like the other panels — the
    -- fill color still conveys selection (blue selected / dark idle). (Jason: "they're not pilled".)
    PanelChrome.pillBorder(tab, PanelChrome.areaPill(), 102, 0, 0.18)

    -- Tab content
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -10, 1, -10)
    content.Position = UDim2.new(0, 5, 0, 5)
    content.BackgroundTransparency = 1
    content.ZIndex = 103
    content.Parent = tab

    -- Icon — RELATIVE (Jason: all tab internals relative like the All tab): 15% width, full height.
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0.15, 0, 1, 0)
    icon.Position = UDim2.new(0, 0, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Text = category.icon
    icon.TextScaled = true
    icon.Font = Enum.Font.GothamBold
    icon.ZIndex = 104
    icon.Parent = content

    -- Name — RELATIVE: right of the icon, top half.
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0.75, 0, 0.5, 0)
    nameLabel.Position = UDim2.new(0.15, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = category.name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.ZIndex = 104
    nameLabel.Parent = content

    -- Count — RELATIVE: right of the icon, bottom half.
    local countLabel = Instance.new("TextLabel")
    countLabel.Name = "CountLabel"
    countLabel.Size = UDim2.new(0.75, 0, 0.5, 0)
    countLabel.Position = UDim2.new(0.15, 0, 0.5, 0)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = category.count .. " items"
    countLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    countLabel.TextScaled = true
    countLabel.Font = Enum.Font.Gotham
    countLabel.TextXAlignment = Enum.TextXAlignment.Left
    countLabel.ZIndex = 104
    countLabel.Parent = content

    -- Click handling
    tab.Activated:Connect(function()
        self:_selectCategory(category.name)
    end)

    -- Selection-aware hover: the tab rests at the SELECTED blue while it's the active category,
    -- gray otherwise. (The old generic hover captured a static gray and its MouseLeave reset the
    -- selected tab back to gray on mouse-out — Jason: returning to a category didn't re-highlight
    -- its tab, "in a lot of places".)
    local SELECTED_BG = Color3.fromRGB(52, 152, 219)
    local UNSELECTED_BG = Color3.fromRGB(40, 40, 50)
    local function tabRestColor()
        return (category.name == self.selectedCategory) and SELECTED_BG or UNSELECTED_BG
    end
    tab.MouseEnter:Connect(function()
        local c = tabRestColor()
        TweenService:Create(tab, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundColor3 = Color3.new(
                math.min(1, c.R + 0.1),
                math.min(1, c.G + 0.1),
                math.min(1, c.B + 0.1)
            ),
        }):Play()
    end)
    tab.MouseLeave:Connect(function()
        TweenService:Create(tab, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundColor3 = tabRestColor(),
        }):Play()
    end)
end

function InventoryPanel:_createSearchSection()
    local theme = uiConfig.helpers.get_theme(uiConfig)

    -- Search container
    local searchContainer = Instance.new("Frame")
    searchContainer.Name = "SearchContainer"
    searchContainer.Size = UDim2.new(0.95, 0, 0.1, 0) -- 95% width, 10% height (relative — Jason)
    searchContainer.Position = UDim2.new(0.025, 0, 0.11, 0) -- 2.5% from left, 11% from top (scales with screen)
    searchContainer.BackgroundTransparency = 1
    searchContainer.ZIndex = 101
    searchContainer.Parent = self.content

    -- Search box background — RELATIVE 70% width (Jason); the Reset/Activate block takes the right 30%.
    local searchBG = Instance.new("Frame")
    searchBG.Size = UDim2.new(0.7, 0, 1, 0)
    searchBG.Position = UDim2.new(0, 0, 0, 5)
    searchBG.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    searchBG.BorderSizePixel = 0
    searchBG.ZIndex = 102
    searchBG.Parent = searchContainer
    pillify(searchBG) -- the search bar reads as a pill capsule too

    local searchCorner = Instance.new("UICorner")
    searchCorner.CornerRadius = UDim.new(0, 10)
    searchCorner.Parent = searchBG

    -- Search icon — RELATIVE (Jason): ~10% width, full height, kept square via an aspect-ratio
    -- constraint so it scales cleanly with the search bar.
    local searchIcon = Instance.new("TextLabel")
    searchIcon.Size = UDim2.new(0.1, 0, 1, 0)
    searchIcon.Position = UDim2.new(0, 0, 0.5, 0)
    searchIcon.AnchorPoint = Vector2.new(0, 0.5)
    searchIcon.BackgroundTransparency = 1
    searchIcon.Text = "🔍"
    searchIcon.TextScaled = true
    searchIcon.Font = Enum.Font.GothamBold
    searchIcon.ZIndex = 104
    searchIcon.Parent = searchBG
    local iconAspect = Instance.new("UIAspectRatioConstraint")
    iconAspect.AspectRatio = 1
    iconAspect.Parent = searchIcon

    -- Search text box
    self.searchBox = Instance.new("TextBox")
    self.searchBox.Name = "SearchBox"
    self.searchBox.Size = UDim2.new(0.9, 0, 1, 0)
    self.searchBox.Position = UDim2.new(0.1, 0, 0.5, 0)
    self.searchBox.AnchorPoint = Vector2.new(0, 0.5)
    self.searchBox.BackgroundTransparency = 1
    self.searchBox.Text = ""
    self.searchBox.PlaceholderText = "Search items..."
    self.searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.searchBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 160)
    self.searchBox.TextScaled = true
    self.searchBox.Font = Enum.Font.Gotham
    self.searchBox.TextXAlignment = Enum.TextXAlignment.Left
    self.searchBox.ClearTextOnFocus = false
    self.searchBox.ZIndex = 103
    self.searchBox.Parent = searchBG

    -- Search functionality
    self.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        self.searchTerm = self.searchBox.Text:lower()
        self:_updateItemsDisplay()
    end)

    -- Team loadout bar (Team 1-4 + Activate), to the right of the search box. Surfaces the existing
    -- Rosters backend: build a team here (draft, persisted via roster.create, NOT deployed); Activate
    -- = roster.invoke swaps the live squad. Draft editing on the Equipped strip is Stage 2. (task #240)
    self:_createTeamBar(searchContainer)
end

local SQUAD_CAP = 10 -- active squad slots (the server enforces the real max)

-- Style a draft-bar TextButton: rounded, themed.
local function styleTeamButton(btn, baseColor)
    btn.BackgroundColor3 = baseColor
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = true
    btn.Font = Enum.Font.GothamBold
    btn.TextScaled = true
    btn.TextColor3 = Color3.fromRGB(235, 238, 245)
    btn.ZIndex = 103
    pillify(btn) -- capsule treatment (Reset / Activate draft buttons)
    local sizeCap = Instance.new("UITextSizeConstraint")
    sizeCap.MaxTextSize = 28 -- Jason (draft bar Reset/Activate)
    sizeCap.Parent = btn
    return btn
end

-- Draft-squad bar (Reset + Activate). The Equipped strip IS the draft; clicking pets edits it
-- locally with NO deploy. Reset reverts the draft to the deployed squad; Activate commits it via one
-- atomic server call (SetEquippedPets). This is the deploy model — there is no click-to-equip-live.
function InventoryPanel:_createTeamBar(searchContainer)
    local bar = Instance.new("Frame")
    bar.Name = "DraftBar"
    -- RELATIVE 30% width, right-anchored (Jason); search box takes the left 70%. Reset/Activate inside
    -- are relative too, so the whole row scales.
    bar.Size = UDim2.new(0.3, 0, 1, 0)
    bar.Position = UDim2.new(1, 0, 0, 5)
    bar.AnchorPoint = Vector2.new(1, 0)
    bar.BackgroundTransparency = 1
    bar.ZIndex = 102
    bar.Parent = searchContainer

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0.002, 0) -- relative gap (Jason)
    layout.Parent = bar

    local reset = Instance.new("TextButton")
    reset.Name = "ResetDraft"
    reset.Size = UDim2.new(0.498, 0, 1, -2) -- relative half of the draft bar (Jason)
    reset.LayoutOrder = 1
    reset.Text = "↺ Reset"
    styleTeamButton(reset, Color3.fromRGB(56, 56, 68))
    reset.Parent = bar
    reset.Activated:Connect(function()
        self:_seedDraftFromEquipped()
        self:_updateItemsDisplay()
    end)

    local activate = Instance.new("TextButton")
    activate.Name = "ActivateDraft"
    activate.Size = UDim2.new(0.498, 0, 1, -2) -- relative half of the draft bar (Jason)
    activate.LayoutOrder = 2
    activate.Text = "✓ Activate"
    styleTeamButton(activate, Color3.fromRGB(46, 160, 87))
    activate.Parent = bar
    self._activateButton = activate
    activate.Activated:Connect(function()
        self:_commitDraft()
    end)
end

-- Seed the working draft from the currently-deployed squad (player.Equipped.pets, in slot order).
-- Refs are "stack|<stackKey>" (common copies) or a unique uid — the format the server stores/expects.
-- Equipped.pets stores commons as "stack|<stackKey>|<slot>" (trailing slot index); the draft uses the
-- slot-less "stack|<stackKey>" that _draftRefForItem produces. Strip the slot so the seed matches the
-- rendered cards (otherwise the strip shows phantom-empty and the cap locks the panel).
function InventoryPanel:_normalizeEquippedRef(value)
    if type(value) ~= "string" then
        return nil
    end
    if string.sub(value, 1, 6) == "stack|" then
        return (string.gsub(value, "|%d+$", ""))
    end
    return value
end

-- The area-insensitive identity of a stack ref: "stack|pet:enchant:area" -> "pet:enchant". Lets a
-- deployed pet match its inventory card even when the Equipped value's area segment has drifted.
function InventoryPanel:_stackPrefix(ref)
    if type(ref) ~= "string" or string.sub(ref, 1, 6) ~= "stack|" then
        return nil
    end
    local key = string.sub(ref, 7)
    local a, b = string.match(key, "^([^:]*):([^:]*)")
    if a and a ~= "" and b then
        return a .. ":" .. b
    end
    return nil
end

-- Cached display data for a deployed stack ref, EVEN at quantity 0. A fully-deployed stack (every copy
-- equipped → 0 un-equipped remaining) has NO draftable inventory card, so byRef/byPrefix (built from
-- inventoryData, which excludes qty-0 stacks) can't resolve it — the deployed pet would vanish from
-- the squad strip and the count would read short. _stackDataByKey is cached for every stack regardless
-- of quantity (see the stack-build pass), so it's the fallback. Exact key first, then pet:enchant
-- prefix (area drift). nil for uid/non-stack refs or genuinely-unknown stacks (traded/gone).
function InventoryPanel:_stackDataForRef(ref)
    if type(ref) ~= "string" or string.sub(ref, 1, 6) ~= "stack|" or not self._stackDataByKey then
        return nil
    end
    local hit = self._stackDataByKey[string.sub(ref, 7)]
    if hit then
        return hit
    end
    local pref = self:_stackPrefix(ref)
    if pref then
        for k, data in pairs(self._stackDataByKey) do
            if self:_stackPrefix("stack|" .. k) == pref then
                return data
            end
        end
    end
    return nil
end

function InventoryPanel:_seedDraftFromEquipped()
    local refs = {}
    local player = self.player or Players.LocalPlayer
    local eq = player and player:FindFirstChild("Equipped")
    local pets = eq and eq:FindFirstChild("pets")

    -- Resolve each deployed ref to the inventory's OWN draft ref so the strip can render it and the cap
    -- stays honest. Equipped values drift from the inventory key (slot suffix + area), so match exactly
    -- first, then by the area-insensitive pet:enchant prefix. Only a ref that matches NEITHER (a
    -- traded/stale pet) is dropped — never a pet you still own (that was the "5 deployed, 3 shown" bug).
    local byExact, byPrefix = {}, {}
    local haveInventory = false
    for _, item in ipairs(self.inventoryData or {}) do
        if item.folder_source == "pets" then
            haveInventory = true
            local r = self:_draftRefForItem(item)
            if r then
                byExact[r] = r
                local p = self:_stackPrefix(r)
                if p and byPrefix[p] == nil then
                    byPrefix[p] = r
                end
            end
        end
    end

    if pets then
        local bySlot = {}
        for _, sv in ipairs(pets:GetChildren()) do
            if sv:IsA("StringValue") and sv.Value ~= "" then
                local n = tonumber(string.match(sv.Name, "slot_(%d+)"))
                if n then
                    bySlot[#bySlot + 1] = { n = n, ref = self:_normalizeEquippedRef(sv.Value) }
                end
            end
        end
        table.sort(bySlot, function(a, b)
            return a.n < b.n
        end)
        for _, e in ipairs(bySlot) do
            local resolved = e.ref and (byExact[e.ref] or byPrefix[self:_stackPrefix(e.ref)])
            if resolved then
                table.insert(refs, resolved)
            elseif e.ref and (not haveInventory or self:_stackDataForRef(e.ref)) then
                -- Keep the deployed ref when it has no draftable card but is still REAL: either inventory
                -- hasn't loaded yet (don't lose the squad), OR the stack is fully equipped (0 un-equipped
                -- → no card, but cached in _stackDataByKey; the render draws it from that stack data).
                -- Only a ref with no card AND no stack data (truly traded/gone) is dropped.
                table.insert(refs, e.ref)
            end
        end
    end
    self._draftRefs = refs
    self._draftDirty = false -- a fresh seed matches what's deployed
end

-- The equipped-layer ref for an inventory pet item ("stack|<stackKey>" or a unique uid).
function InventoryPanel:_draftRefForItem(item)
    local stackKey = self:_getPetStackKey(item)
    if stackKey then
        return "stack|" .. stackKey
    end
    if typeof(item.uid) == "string" then
        return item.uid
    end
    return nil
end

-- True if this pet item is currently in the working draft.
function InventoryPanel:_isItemInDraft(item)
    if type(self._draftRefs) ~= "table" then
        return false
    end
    local ref = self:_draftRefForItem(item)
    if not ref then
        return false
    end
    for _, v in ipairs(self._draftRefs) do
        if v == ref then
            return true
        end
    end
    return false
end

-- How many pets the squad can actually field — the SAME PetEquipSlots the equipped strip pads its
-- empty rings to, so the draft can never overflow past the visible slots. SQUAD_CAP is only a fallback.
function InventoryPanel:_squadSlotCount()
    return tonumber(self.player and self.player:GetAttribute("PetEquipSlots")) or SQUAD_CAP
end

-- Edit the working draft. PURE UI — no server, nothing deploys until Activate. Clicking an inventory
-- pet ADDS one (commons up to the owned quantity, uniques once); clicking a draft slot REMOVES one.
function InventoryPanel:_toggleDraftMember(item, isDraftCard)
    if self._draftRefs == nil then
        self:_seedDraftFromEquipped()
    end
    local ref = self:_draftRefForItem(item)
    if not ref then
        return
    end
    local list = self._draftRefs
    local isStack = string.sub(ref, 1, 6) == "stack|"

    if isDraftCard then
        -- Clicking a draft slot pulls ONE copy back out.
        for i = #list, 1, -1 do
            if list[i] == ref then
                table.remove(list, i)
                self._draftDirty = true -- diverges from deployed until Activate
                break
            end
        end
        self:_updateItemsDisplay()
        return
    end

    -- Clicking an inventory pet adds one.
    if #list >= self:_squadSlotCount() then
        self:_flashActivateFull()
        return
    end
    local drafted = 0
    for _, v in ipairs(list) do
        if v == ref then
            drafted += 1
        end
    end
    if isStack then
        -- _ownedTotal survives the count-reduced inventory clone; fall back to the live count.
        local owned = tonumber(item._ownedTotal)
            or tonumber(item.count)
            or tonumber(item.quantity)
            or 1
        if drafted >= owned then
            self:_flashActivateFull() -- none of this stack left to draft
            return
        end
        table.insert(list, ref)
        self._draftDirty = true
    elseif drafted == 0 then
        table.insert(list, ref) -- a unique can be drafted once (remove via its draft slot)
        self._draftDirty = true
    end
    self:_updateItemsDisplay()
end

-- Brief red flash on Activate when the draft is at the squad cap.
function InventoryPanel:_flashActivateFull()
    local btn = self._activateButton
    if not btn then
        return
    end
    btn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    task.delay(0.25, function()
        if btn and btn.Parent then
            btn.BackgroundColor3 = Color3.fromRGB(46, 160, 87)
        end
    end)
end

-- Pulse (or stop pulsing) the Activate button. ON while the draft has un-deployed edits — a looping
-- brighten/scale tween that reads "press me". Idempotent: re-calling with the same state is a no-op,
-- so the per-render driver in _updateItemsDisplay can call it freely.
function InventoryPanel:_setActivatePulse(on)
    local btn = self._activateButton
    if not btn then
        return
    end
    if on == self._activatePulsing then
        return
    end
    self._activatePulsing = on
    if self._activatePulseTween then
        self._activatePulseTween:Cancel()
        self._activatePulseTween = nil
    end
    if on then
        local tween = TweenService:Create(
            btn,
            TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { BackgroundColor3 = Color3.fromRGB(120, 235, 150) } -- brighten from the resting green
        )
        self._activatePulseTween = tween
        tween:Play()
    else
        btn.BackgroundColor3 = Color3.fromRGB(46, 160, 87) -- back to the resting green
    end
end

-- Commit the working draft to the field: one atomic server call (clear + set Equipped.pets).
function InventoryPanel:_commitDraft()
    if self.signals and self.signals.SetEquippedPets then
        self.signals.SetEquippedPets:FireServer({ refs = self._draftRefs or {} })
    end
    -- The draft now matches what's being deployed — flip the label to "deployed/live".
    self._draftDirty = false
    self:_updateItemsDisplay()
end

-- Close request from a user-facing close control. If the squad draft has un-deployed edits, confirm
-- first (clicking a pet only STAGES it — Activate commits); otherwise close immediately. `after` does
-- the actual close (Hide, or Hide + open another panel). (Jason: remind before losing a staged squad.)
function InventoryPanel:_requestClose(after)
    after = after or function()
        self:Hide()
    end
    if self._draftDirty then
        self:_showDeployGuard(after)
    else
        after()
    end
end

-- Modal shown when closing with an un-deployed draft. Three outcomes: Activate-and-close (commit then
-- close — the good path), close without deploying (discard the edits; the draft re-seeds from the live
-- squad next open), or keep editing. Reuses the in-file confirm shape (no shared confirm component).
function InventoryPanel:_showDeployGuard(after)
    if self._deployGuard then
        return
    end
    local frame = Instance.new("Frame")
    frame.Name = "DeployGuard"
    frame.Size = UDim2.new(0, 320, 0, 226)
    frame.Position = UDim2.new(0.5, -160, 0.5, -113)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    frame.BorderSizePixel = 0
    frame.ZIndex = 300
    frame.Parent = self.frame
    self._deployGuard = frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(120, 235, 150) -- the Activate green
    stroke.Thickness = 2
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 28)
    title.Position = UDim2.new(0, 10, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = "Deploy your squad?"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.ZIndex = 301
    title.Parent = frame

    local msg = Instance.new("TextLabel")
    msg.Size = UDim2.new(1, -24, 0, 36)
    msg.Position = UDim2.new(0, 12, 0, 44)
    msg.BackgroundTransparency = 1
    msg.Text = "Your squad changes aren't live yet — Activate to send them out."
    msg.TextColor3 = Color3.fromRGB(200, 200, 200)
    msg.TextSize = 14
    msg.Font = Enum.Font.Gotham
    msg.TextWrapped = true
    msg.ZIndex = 301
    msg.Parent = frame

    local btns = Instance.new("Frame")
    btns.Size = UDim2.new(1, -24, 0, 118)
    btns.Position = UDim2.new(0, 12, 0, 96)
    btns.BackgroundTransparency = 1
    btns.ZIndex = 301
    btns.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = btns

    local function dismiss()
        if self._deployGuard then
            self._deployGuard:Destroy()
            self._deployGuard = nil
        end
    end

    local function mkBtn(text, color, order)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 34)
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextSize = 14
        b.Font = Enum.Font.GothamBold
        b.LayoutOrder = order
        b.ZIndex = 302
        b.Parent = btns
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = b
        return b
    end

    local activateBtn = mkBtn("✓ Activate & Close", Color3.fromRGB(46, 160, 87), 1)
    local closeBtn = mkBtn("Close without deploying", Color3.fromRGB(120, 70, 70), 2)
    local keepBtn = mkBtn("Keep editing", Color3.fromRGB(70, 70, 80), 3)

    activateBtn.Activated:Connect(function()
        dismiss()
        self:_commitDraft()
        if after then
            after()
        end
    end)
    closeBtn.Activated:Connect(function()
        dismiss()
        if after then
            after()
        end
    end)
    keepBtn.Activated:Connect(function()
        dismiss()
    end)
end

function InventoryPanel:_createItemsGrid()
    local theme = uiConfig.helpers.get_theme(uiConfig)

    -- Items scroll frame
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ItemsScroll"
    scrollFrame.Size = UDim2.new(0.95, 0, 0.75, 0) -- 95% width, 75% height (accounts for later start position)
    scrollFrame.Position = UDim2.new(0.025, 0, 0.25, 0) -- 2.5% from left, 25% from top (after search row — Jason)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(52, 152, 219)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.ZIndex = 101
    scrollFrame.Parent = self.content

    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 15)
    scrollCorner.Parent = scrollFrame

    -- Vertical list layout for sections
    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 10)
    listLayout.Parent = scrollFrame

    -- Padding
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 15)
    padding.PaddingBottom = UDim.new(0, 15)
    padding.PaddingLeft = UDim.new(0, 15)
    padding.PaddingRight = UDim.new(0, 15)
    padding.Parent = scrollFrame

    -- Equipped section
    local eqLabel = Instance.new("TextLabel")
    eqLabel.Name = "EquippedLabel"
    eqLabel.Size = UDim2.new(1, -20, 0, 20)
    eqLabel.BackgroundTransparency = 1
    eqLabel.Text = "Equipped"
    eqLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    eqLabel.Font = Enum.Font.GothamBold
    eqLabel.TextScaled = true
    eqLabel.LayoutOrder = 1
    eqLabel.Parent = scrollFrame
    self.equippedLabel = eqLabel -- retitled to "Team N (draft)" while editing a team (task #240)

    local eqGridContainer = Instance.new("Frame")
    eqGridContainer.Name = "EquippedContainer"
    eqGridContainer.Size = UDim2.new(1, -20, 0, 0)
    eqGridContainer.BackgroundTransparency = 1
    eqGridContainer.LayoutOrder = 2
    eqGridContainer.Parent = scrollFrame

    local eqGrid = Instance.new("UIGridLayout")
    eqGrid.CellSize = UDim2.new(0, self.cardSize.X, 0, self.cardSize.Y)
    print("card size in eqgrid", self.cardSize)
    eqGrid.CellPadding = UDim2.new(0, self.cardPadding.X, 0, self.cardPadding.Y)
    eqGrid.SortOrder = Enum.SortOrder.LayoutOrder
    eqGrid.Parent = eqGridContainer

    -- Unequipped section
    local invLabel = Instance.new("TextLabel")
    invLabel.Name = "InventoryLabel"
    invLabel.Size = UDim2.new(1, -20, 0, 20)
    invLabel.BackgroundTransparency = 1
    invLabel.Text = "Inventory"
    invLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
    invLabel.Font = Enum.Font.GothamBold
    invLabel.TextScaled = true
    invLabel.LayoutOrder = 3
    invLabel.Parent = scrollFrame

    local invGridContainer = Instance.new("Frame")
    invGridContainer.Name = "InventoryContainer"
    invGridContainer.Size = UDim2.new(1, -20, 0, 0)
    invGridContainer.BackgroundTransparency = 1
    invGridContainer.LayoutOrder = 4
    invGridContainer.Parent = scrollFrame

    local invGrid = Instance.new("UIGridLayout")
    invGrid.CellSize = UDim2.new(0, self.cardSize.X, 0, self.cardSize.Y)
    print("card size in grid", self.cardSize)
    invGrid.CellPadding = UDim2.new(0, self.cardPadding.X, 0, self.cardPadding.Y)
    invGrid.SortOrder = Enum.SortOrder.LayoutOrder
    invGrid.Parent = invGridContainer

    local function updateSectionHeights()
        -- Expand containers to fit all grid rows
        local eqH = eqGrid.AbsoluteContentSize.Y
        local invH = invGrid.AbsoluteContentSize.Y
        eqGridContainer.Size = UDim2.new(1, -20, 0, eqH)
        invGridContainer.Size = UDim2.new(1, -20, 0, invH)

        -- Recompute scroll canvas
        local total = eqH + invH + eqLabel.AbsoluteSize.Y + invLabel.AbsoluteSize.Y + 60
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(0, total))

        -- Layout settled (card AbsolutePositions are now valid) — re-cull off-screen viewports.
        self:_requestCull()
    end

    local function recomputeCanvas()
        updateSectionHeights()
    end

    eqGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateSectionHeights)
    invGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateSectionHeights)
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(recomputeCanvas)

    -- Initial sizing
    task.defer(updateSectionHeights)

    -- Store references
    self.scrollFrame = scrollFrame
    self.equippedGrid = eqGridContainer
    self.inventoryGrid = invGridContainer
    self.itemsGrid = invGridContainer -- backward compat for any code referencing itemsGrid

    -- Pause off-screen card ViewportFrames (perf): re-cull whenever the user scrolls or the visible
    -- window resizes. A big inventory otherwise renders every card's live 3D thumbnail every frame.
    if self._cullConn then
        self._cullConn:Disconnect()
    end
    self._cullConn = scrollFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        self:_requestCull()
    end)
    if self._cullSizeConn then
        self._cullSizeConn:Disconnect()
    end
    self._cullSizeConn = scrollFrame
        :GetPropertyChangedSignal("AbsoluteWindowSize")
        :Connect(function()
            self:_requestCull()
        end)
end

-- Pause off-screen card ViewportFrames so a big inventory isn't rendering N live 3D scenes at once.
-- Each pet card's 3D thumbnail (named "PetImage"/"PetViewport") is a ViewportFrame that re-renders
-- every frame WHILE VISIBLE; toggling its .Visible off while the card sits outside the scroll window
-- (plus a margin so it's already drawn by the time it scrolls in) drops the cost to ~the on-screen
-- cards. We gate the VIEWPORT, never the card frame — UIGridLayout skips Visible=false children and
-- would reflow the grid. Flat ImageLabel thumbnails (the texture path) are cheap, so only viewports
-- are gated; cards whose thumbnail is already a texture are left untouched.
function InventoryPanel:_cullCardViewports()
    local scroll = self.scrollFrame
    if not scroll or not scroll.Parent then
        return
    end
    local winTop = scroll.AbsolutePosition.Y
    local winH = scroll.AbsoluteWindowSize.Y
    if winH <= 0 then
        winH = scroll.AbsoluteSize.Y
    end
    local margin = (self.cardSize and self.cardSize.Y or 120) * 2 -- ~two rows of look-ahead
    local lo, hi = winTop - margin, winTop + winH + margin
    for _, container in ipairs({ self.equippedGrid, self.inventoryGrid }) do
        if container then
            for _, card in ipairs(container:GetChildren()) do
                if card:IsA("GuiObject") then
                    local vp = card:FindFirstChild("PetImage", true)
                        or card:FindFirstChild("PetViewport", true)
                    if vp and vp:IsA("ViewportFrame") then
                        local top = card.AbsolutePosition.Y
                        local bottom = top + card.AbsoluteSize.Y
                        vp.Visible = (bottom >= lo) and (top <= hi)
                    end
                end
            end
        end
    end
end

-- Debounce CanvasPosition spam (it fires many times per scroll): mark dirty, cull once next frame.
function InventoryPanel:_requestCull()
    if self._cullScheduled then
        return
    end
    self._cullScheduled = true
    task.defer(function()
        self._cullScheduled = false
        self:_cullCardViewports()
    end)
end

function InventoryPanel:_generateSampleData()
    local rarityColors = {
        Common = Color3.fromRGB(150, 150, 150),
        Uncommon = Color3.fromRGB(30, 255, 0),
        Rare = Color3.fromRGB(0, 112, 255),
        Epic = Color3.fromRGB(163, 53, 238),
        Legendary = Color3.fromRGB(255, 128, 0),
        Mythical = Color3.fromRGB(255, 0, 0),
    }

    local items = {}
    local petIcons =
        { "🐶", "🐱", "🐼", "🦊", "🐯", "🐸", "🐷", "🐨", "🐵", "🦁" }
    local rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical" }

    -- Generate random pets
    for i = 1, 60 do
        local rarity = rarities[math.random(1, #rarities)]
        table.insert(items, {
            id = "pet_" .. i,
            name = "Pet " .. i,
            icon = petIcons[math.random(1, #petIcons)],
            rarity = rarity,
            color = rarityColors[rarity],
            category = "Pets",
            count = 1,
            power = math.random(100, 999),
        })
    end

    return items
end

-- 🔧 CONFIGURATION-DRIVEN CATEGORIES
function InventoryPanel:_getConfiguredCategories()
    local categories = {}

    if not self.inventoryConfig or not self.inventoryConfig.display_categories then
        self.logger:warn("No inventory config found, using fallback categories")
        return self:_getFallbackCategories()
    end

    -- Get category counts by folder mapping
    local folderCounts = self:_calculateFolderCounts()

    -- Process each configured category
    for _, categoryConfig in ipairs(self.inventoryConfig.display_categories) do
        local totalCount = 0

        -- Sum counts for all folders in this category
        for _, folderName in ipairs(categoryConfig.folders) do
            totalCount = totalCount + (folderCounts[folderName] or 0)
        end

        -- Check if category should be visible
        local shouldShow = categoryConfig.always_visible or totalCount > 0
        local hideEmptyCategories = self.inventoryConfig.category_settings
            and self.inventoryConfig.category_settings.hide_empty_categories
        if not hideEmptyCategories then
            shouldShow = true -- Show all categories if hiding is disabled
        end

        -- TEMPORARY: Force show all categories for debugging
        shouldShow = true

        self.logger:info("🔍 CATEGORY VISIBILITY", {
            categoryName = categoryConfig.name,
            totalCount = totalCount,
            always_visible = categoryConfig.always_visible,
            shouldShow = shouldShow,
            folders = categoryConfig.folders,
        })

        if shouldShow then
            local categoryData = {
                name = categoryConfig.name,
                icon = categoryConfig.icon,
                description = categoryConfig.description,
                folders = categoryConfig.folders,
                count = totalCount,
                order = categoryConfig.display_order,
            }

            table.insert(categories, categoryData)
        end
    end

    -- Sort by display_order
    table.sort(categories, function(a, b)
        return a.order < b.order
    end)

    -- Create category summary for logging
    local categorySummary = {}
    for _, cat in ipairs(categories) do
        table.insert(categorySummary, cat.name .. " (" .. cat.count .. " items)")
    end

    self.logger:info("📁 CONFIGURED CATEGORIES", {
        count = #categories,
        categoryNames = categorySummary,
        fullCategories = categories,
    })

    return categories
end

function InventoryPanel:_getFallbackCategories()
    -- Fallback categories if config fails to load
    local categoryCounts = self:_calculateCategoryCounts()
    return {
        {
            name = "All",
            icon = "📦",
            count = categoryCounts.total,
            folders = { "pets", "consumables", "tools", "eggs" },
        },
        { name = "Pets", icon = "🐾", count = categoryCounts.pets, folders = { "pets" } },
        { name = "Items", icon = "⚡", count = categoryCounts.items, folders = { "consumables" } },
        { name = "Eggs", icon = "🥚", count = categoryCounts.eggs, folders = { "eggs" } },
        { name = "Tools", icon = "🔧", count = categoryCounts.tools, folders = { "tools" } },
    }
end

function InventoryPanel:_calculateFolderCounts()
    local folderCounts = {}
    local settings = self.inventoryConfig and self.inventoryConfig.category_settings or {}
    local countStacksAsSingle = settings.count_stacks_as_single ~= false -- default true

    for _, item in ipairs(self.inventoryData) do
        local folderName = item.folder_source or "unknown"
        local increment = 1
        if item.category == "Pets" and not countStacksAsSingle then
            increment = item.count or 1
        end
        folderCounts[folderName] = (folderCounts[folderName] or 0) + increment
    end

    -- Equipped stack pets sit at quantity 0 (the equipped one is taken out of the
    -- available stack), so they're not in inventoryData — but they DO render as
    -- equipped "ghost" cards. Count them so the tab total matches the visible cards.
    -- Mirror the exact ghost-render condition (stack slot with a backing stack entry).
    local equippedFolder = self.player and self.player:FindFirstChild("Equipped")
    local equippedPets = equippedFolder and equippedFolder:FindFirstChild("pets")
    if equippedPets and self._stackDataByKey then
        for _, slot in ipairs(equippedPets:GetChildren()) do
            if slot:IsA("StringValue") and typeof(slot.Value) == "string" then
                local parts = string.split(slot.Value, "|")
                if #parts >= 2 and parts[1] == "stack" and self._stackDataByKey[parts[2]] then
                    folderCounts["pets"] = (folderCounts["pets"] or 0) + 1
                end
            end
        end
    end

    self.logger:info("📊 FOLDER COUNTS DEBUG", folderCounts)
    return folderCounts
end

-- 📊 CATEGORY COUNTING (Legacy - now used for fallback)
function InventoryPanel:_calculateCategoryCounts()
    local counts = {
        total = 0,
        pets = 0,
        items = 0, -- Consumables/potions
        eggs = 0,
        tools = 0,
    }

    -- Count from real inventory data
    for _, item in ipairs(self.inventoryData) do
        counts.total = counts.total + 1

        -- Categorize based on item category
        if item.category == "Pets" then
            counts.pets = counts.pets + 1
        elseif item.category == "Items" or item.category == "Consumables" then
            counts.items = counts.items + 1
        elseif item.category == "Eggs" then
            counts.eggs = counts.eggs + 1
        elseif item.category == "Tools" then
            counts.tools = counts.tools + 1
        end
    end

    self.logger:info("📊 CATEGORY COUNTS", {
        total = counts.total,
        pets = counts.pets,
        items = counts.items,
        eggs = counts.eggs,
        tools = counts.tools,
    })

    return counts
end

-- 🔄 REAL DATA LOADING
function InventoryPanel:_loadRealInventoryData()
    self.inventoryData = {}
    -- Rebuild the stack-display cache from scratch each load so traded/removed stacks
    -- don't linger as stale ghost cards (or stale counts).
    self._stackDataByKey = {}

    -- Try to find inventory folder in player
    local inventoryFolder = self.player:FindFirstChild("Inventory")
    if not inventoryFolder then
        self.logger:warn("No inventory folder found for player")
        -- Fallback to sample data for testing
        self.inventoryData = self:_generateSampleData()
        return
    end

    local inventoryChildren = {}
    for _, child in pairs(inventoryFolder:GetChildren()) do
        table.insert(inventoryChildren, child.Name)
    end

    self.logger:info("🔍 INVENTORY DEBUG - Found inventory folder", {
        children = inventoryChildren,
    })

    -- Load pets from pets folder
    local petsFolder = inventoryFolder:FindFirstChild("pets")
    if petsFolder then
        local petsChildren = {}
        for _, child in pairs(petsFolder:GetChildren()) do
            table.insert(petsChildren, child.Name)
        end

        self.logger:info("🐾 PETS DEBUG - Found pets folder", {
            childCount = #petsFolder:GetChildren(),
            children = petsChildren,
        })

        self:_loadPetsFromFolder(petsFolder)
    else
        self.logger:warn("🚫 PETS DEBUG - No pets folder found")
    end

    -- Load enhancements from the enhancements bucket (E7)
    local enhFolder = inventoryFolder:FindFirstChild("enhancements")
    if enhFolder then
        self:_loadEnhancementsFromFolder(enhFolder)
    end

    -- Load consumables from consumables folder
    local consumablesFolder = inventoryFolder:FindFirstChild("consumables")
    if consumablesFolder then
        self:_loadConsumablesFromFolder(consumablesFolder)
    else
        self.logger:info("📦 CONSUMABLES DEBUG - No consumables folder found")
    end

    -- Load brew-charge potions (shown in the Items tab; trade-ready stackable bucket)
    local potionsFolder = inventoryFolder:FindFirstChild("potions")
    if potionsFolder then
        self:_loadPotionsFromFolder(potionsFolder)
    end

    -- Load tools from tools folder
    local toolsFolder = inventoryFolder:FindFirstChild("tools")
    if toolsFolder then
        self:_loadToolsFromFolder(toolsFolder)
    else
        self.logger:info("🔧 TOOLS DEBUG - No tools folder found")
    end

    -- Load eggs from eggs folder
    local eggsFolder = inventoryFolder:FindFirstChild("eggs")
    if eggsFolder then
        self:_loadEggsFromFolder(eggsFolder)
    else
        self.logger:info("🥚 EGGS DEBUG - No eggs folder found")
    end

    self.logger:info("✅ INVENTORY DEBUG - Loaded real inventory data", {
        totalItems = #self.inventoryData,
        hasInventoryFolder = inventoryFolder ~= nil,
        hasPetsFolder = petsFolder ~= nil,
        sampleItems = self.inventoryData[1] and {
            name = self.inventoryData[1].name,
            folder_source = self.inventoryData[1].folder_source,
            category = self.inventoryData[1].category,
        } or "no items",
    })
end

function InventoryPanel:_loadPetsFromFolder(petsFolder)
    -- Mixed storage support: prefer Stacks/Special structure if present
    local stacksFolder = petsFolder:FindFirstChild("Stacks")
    local specialFolder = petsFolder:FindFirstChild("Special")
    if stacksFolder or specialFolder then
        return self:_loadPetsFromMixedFolders(stacksFolder, specialFolder)
    end
    -- Get rarity colors for display
    local rarityColors = {
        basic = Color3.fromRGB(150, 150, 150), -- Gray
        golden = Color3.fromRGB(255, 215, 0), -- Gold
        rainbow = Color3.fromRGB(255, 0, 255), -- Magenta
    }

    -- Get pet emoji mapping
    local petIcons = {
        bear = "🐻",
        bunny = "🐰",
        doggy = "🐶",
        kitty = "🐱",
        dragon = "🐉",
    }
    local petConfigModule = ReplicatedStorage:FindFirstChild("Configs")
        and ReplicatedStorage.Configs:FindFirstChild("pets")
    local petConfig = nil
    if petConfigModule then
        local ok, mod = pcall(function()
            return require(petConfigModule)
        end)
        if ok then
            petConfig = mod
        end
    end

    -- Iterate through all pet folders
    for _, petFolder in pairs(petsFolder:GetChildren()) do
        if petFolder:IsA("Folder") and petFolder.Name ~= "Info" then
            -- Extract pet data from folder structure
            local petData = self:_extractPetDataFromFolder(petFolder)
            if petData then
                -- Convert to inventory display format
                local displayData = {
                    id = petFolder.Name, -- UID
                    name = petData.id:gsub("^%l", string.upper), -- Capitalize pet name
                    icon = petIcons[petData.id] or "🐾", -- Emoji fallback
                    rarity = petData.variant:gsub("^%l", string.upper), -- Capitalize variant
                    color = rarityColors[petData.variant] or rarityColors.basic,
                    category = "Pets",
                    count = 1, -- Pets don't stack
                    power = petConfig and petConfig.getPet and petConfig.getPet(
                        petData.id,
                        petData.variant
                    ) and petConfig.getPet(petData.id, petData.variant).power or 0,
                    level = petData.level or 1,
                    uid = petFolder.Name, -- Store UID for future operations
                    folder_source = "pets", -- Track which folder this came from

                    -- 3D Model data for viewport display
                    petType = petData.id, -- Pet type for model loading
                    variant = petData.variant, -- Variant for model loading
                    use3DModel = true, -- Flag to use 3D model instead of emoji
                }

                table.insert(self.inventoryData, displayData)
                self.logger:info("🐾 LOADED PET", {
                    name = displayData.name,
                    folder_source = displayData.folder_source,
                    category = displayData.category,
                    petType = displayData.petType,
                })
            end
        end
    end
end

-- Mixed storage loader (Stacks + Special)
function InventoryPanel:_loadPetsFromMixedFolders(stacksFolder, specialFolder)
    local rarityColors = {
        basic = Color3.fromRGB(150, 150, 150),
        golden = Color3.fromRGB(255, 215, 0),
        rainbow = Color3.fromRGB(255, 0, 255),
        common = Color3.fromRGB(150, 150, 150),
        uncommon = Color3.fromRGB(0, 255, 0),
        rare = Color3.fromRGB(0, 100, 255),
        epic = Color3.fromRGB(128, 0, 128),
        legendary = Color3.fromRGB(255, 215, 0),
        mythic = Color3.fromRGB(255, 0, 255),
        secret = Color3.fromRGB(255, 140, 0),
        exclusive = Color3.fromRGB(0, 255, 255),
        huge = Color3.fromRGB(255, 90, 210),
    }

    local petIcons = {
        bear = "🐻",
        bunny = "🐰",
        doggy = "🐶",
        kitty = "🐱",
        dragon = "🐉",
        colorado = "👤",
    }

    -- Load pet config for power lookup
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local petConfigModule = ReplicatedStorage:FindFirstChild("Configs")
        and ReplicatedStorage.Configs:FindFirstChild("pets")
    local petConfig = nil
    if petConfigModule then
        local ok, mod = pcall(function()
            return require(petConfigModule)
        end)
        if ok then
            petConfig = mod
        end
    end
    local petProgressionConfigModule = ReplicatedStorage:FindFirstChild("Configs")
        and ReplicatedStorage.Configs:FindFirstChild("pet_progression")
    local petProgressionConfig = nil
    if petProgressionConfigModule then
        local ok, mod = pcall(function()
            return require(petProgressionConfigModule)
        end)
        if ok then
            petProgressionConfig = mod
        end
    end
    local inventoryConfigModule = ReplicatedStorage:FindFirstChild("Configs")
        and ReplicatedStorage.Configs:FindFirstChild("inventory")
    local inventoryConfig = nil
    if inventoryConfigModule then
        local ok, mod = pcall(function()
            return require(inventoryConfigModule)
        end)
        if ok then
            inventoryConfig = mod
        end
    end
    self._petTooltipFieldsConfig = (
        inventoryConfig
        and inventoryConfig.buckets
        and inventoryConfig.buckets.pets
        and inventoryConfig.buckets.pets.tooltip_fields
    ) or nil

    local function getPetConfigData(petType, variant)
        if petConfig and petConfig.getPet then
            return petConfig.getPet(petType, variant)
        end
        return nil
    end

    local function readNumberValue(folder, names)
        if not folder then
            return nil
        end
        for _, name in ipairs(names) do
            local value = folder:FindFirstChild(name)
            if value and (value:IsA("NumberValue") or value:IsA("IntValue")) then
                return tonumber(value.Value)
            end
        end
        return nil
    end

    local function readStringValue(folder, names)
        if not folder then
            return nil
        end
        for _, name in ipairs(names) do
            local value = folder:FindFirstChild(name)
            if value and value:IsA("StringValue") then
                return value.Value
            end
        end
        return nil
    end

    local function readBoolValue(folder, names)
        if not folder then
            return nil
        end
        for _, name in ipairs(names) do
            local value = folder:FindFirstChild(name)
            if value and value:IsA("BoolValue") then
                return value.Value
            end
        end
        return nil
    end

    -- Mirror the SERVER eternal resolution (PetHandler) for the card display, so
    -- shown power == fought power: huge/creator pin > species block > rarity
    -- default, then the variant effect scale (one law: x1 / x1.25 / x1.5).
    local function applyVariantEternalScale(percent, variantName)
        if not percent or percent <= 0 then
            return percent or 0
        end
        local mults = PET_ROLES and PET_ROLES.variant_effect_multipliers
        local m = mults and tonumber(mults[string.lower(tostring(variantName or "basic"))])
        return percent * (m or 1)
    end

    local function getConfiguredEternalPercent(pdata, isHuge, variantName)
        local eternalCfg = (petConfig and petConfig.eternal) or {}
        local pct = 0
        if isHuge then
            if pdata and pdata.category == "creator" then
                pct = tonumber(eternalCfg.creator_power_percent) or 130
            else
                pct = tonumber(eternalCfg.huge_power_percent) or 120
            end
        elseif type(pdata and pdata.eternal) == "table" and pdata.eternal.enabled == true then
            pct = tonumber(pdata.eternal.power_percent) or 0
        else
            local defaults = eternalCfg.default_percent_by_rarity
            local rarity = pdata and pdata.rarity_id
            if type(defaults) == "table" and rarity then
                pct = tonumber(defaults[rarity]) or 0
            end
        end
        return applyVariantEternalScale(pct, variantName)
    end

    -- Eternal level bonus (pets.lua eternal.level_bonus_max), normalized by the
    -- rarity max level — same formula as the server.
    local function getEternalLevelScaleForDisplay(rarityId, level)
        local cap = petConfig and petConfig.eternal and tonumber(petConfig.eternal.level_bonus_max)
        if not cap or cap <= 0 then
            return 1
        end
        local maxLevel = PetPower.maxLevelForRarity(rarityId, petProgressionConfig)
        level = math.max(1, math.floor(tonumber(level) or 1))
        if maxLevel <= 1 or level <= 1 then
            return 1
        end
        return 1 + cap * math.clamp((level - 1) / (maxLevel - 1), 0, 1)
    end

    local function getConfiguredPowerForLevel(pdata, level, isHuge)
        -- Shared source of truth: huge pets use huge_base_power, then the
        -- normalized-cap level scaling (rarity max level derived inside).
        local base = PetPower.configuredBasePower(pdata, isHuge == true)
        if base <= 0 then
            return 0
        end
        return PetPower.basePowerForLevel(pdata, isHuge == true, level, petProgressionConfig)
    end

    local function getConfiguredMaxEnchantments(rarityId)
        local enchanting = petConfig and petConfig.enchanting
        if type(rarityId) ~= "string" or type(enchanting) ~= "table" then
            return 0
        end
        local byRarity = enchanting.max_enchantments_by_rarity
        local maxEnchantments = type(byRarity) == "table" and byRarity[rarityId]
        if maxEnchantments == nil then
            maxEnchantments = enchanting.default_max_enchantments
        end
        return tonumber(maxEnchantments) or 0
    end

    local function getRarityData(rarityId, pdata)
        if type(pdata and pdata.rarity) == "table" then
            return pdata.rarity
        end
        if petConfig and petConfig.rarities and type(rarityId) == "string" then
            return petConfig.rarities[rarityId]
        end
        return nil
    end

    local function getRarityDisplayName(rarityId, pdata)
        local rarityData = getRarityData(rarityId, pdata)
        if type(rarityData) == "table" and type(rarityData.name) == "string" then
            return rarityData.name
        end
        return tostring(rarityId or "basic"):gsub("^%l", string.upper)
    end

    local function getRarityColor(rarityId, variant, pdata)
        local rarityData = getRarityData(rarityId, pdata)
        if type(rarityData) == "table" and typeof(rarityData.color) == "Color3" then
            return rarityData.color
        end
        return rarityColors[rarityId] or rarityColors[variant] or rarityColors.basic
    end

    local function countFolderChildren(folder, names)
        if not folder then
            return 0
        end
        for _, name in ipairs(names) do
            local child = folder:FindFirstChild(name)
            if child and child:IsA("Folder") then
                return #child:GetChildren()
            end
        end
        return 0
    end

    local function readEnchantSummaries(folder)
        local summaries = {}
        if not folder then
            return summaries
        end

        local enchantFolder = folder:FindFirstChild("enchantments")
            or folder:FindFirstChild("Enchantments")
        if not enchantFolder or not enchantFolder:IsA("Folder") then
            return summaries
        end

        local children = enchantFolder:GetChildren()
        table.sort(children, function(a, b)
            return tostring(a.Name) < tostring(b.Name)
        end)
        for _, child in ipairs(children) do
            if child:IsA("Folder") then
                local id = readStringValue(child, { "id", "Id" })
                local displayName = readStringValue(child, { "display_name", "DisplayName" })
                    or id
                    or child.Name
                local strength =
                    readNumberValue(child, { "strength", "Strength", "value", "Value" })
                local profile = readStringValue(child, { "roll_profile", "RollProfile" })
                table.insert(summaries, {
                    id = id,
                    displayName = displayName,
                    strength = strength,
                    profile = profile,
                })
            end
        end

        return summaries
    end

    local function readPrimitiveValues(folder)
        local values = {}
        if not folder then
            return values
        end
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("StringValue") or child:IsA("BoolValue") then
                values[child.Name] = child.Value
            elseif child:IsA("NumberValue") or child:IsA("IntValue") then
                values[child.Name] = tonumber(child.Value)
            end
        end
        return values
    end

    -- Stacks
    if stacksFolder then
        for _, stackFolder in ipairs(stacksFolder:GetChildren()) do
            if stackFolder:IsA("Folder") then
                local itemId = stackFolder:FindFirstChild("ItemId")
                local variantValue = stackFolder:FindFirstChild("Variant")
                local qtyValue = stackFolder:FindFirstChild("Quantity")
                local enchantValue = stackFolder:FindFirstChild("Enchant")
                if itemId and variantValue and qtyValue then
                    local petType = itemId.Value
                    local variant = variantValue.Value
                    local stackEnchant = enchantValue and enchantValue.Value or nil
                    local eternalPercent = 0
                    local pdata = getPetConfigData(petType, variant)
                    local power = getConfiguredPowerForLevel(pdata, 1)
                    local rarityId = variant
                    local displayName = variant:gsub("^%l", string.upper)
                        .. " "
                        .. petType:gsub("^%l", string.upper)
                    if pdata then
                        eternalPercent = getConfiguredEternalPercent(pdata, false, variant)
                        rarityId = pdata.rarity_id or variant
                        displayName = pdata.name or displayName
                    end
                    -- Always cache stack display data so ghost cards can render even at quantity 0
                    self._stackDataByKey = self._stackDataByKey or {}
                    self._stackDataByKey[stackFolder.Name] = {
                        id = "stack|" .. stackFolder.Name,
                        name = displayName,
                        icon = petIcons[petType] or "🐾",
                        rarity = getRarityDisplayName(rarityId, pdata),
                        rarityId = rarityId,
                        color = getRarityColor(rarityId, variant, pdata),
                        category = "Pets",
                        count = qtyValue.Value,
                        power = power,
                        -- zone-aware SORT key = the displayed number (full profile chain)
                        zonePower = displaySortPower(power, petType, variant),
                        basePower = power,
                        effectivePower = power,
                        eternalPercent = eternalPercent,
                        special = rarityId == "exclusive"
                            or rarityId == "secret"
                            or rarityId == "huge",
                        enchantable = false,
                        maxEnchantments = 0,
                        source = "Stack",
                        uid = stackFolder.Name,
                        folder_source = "pets",
                        petType = petType,
                        variant = variant,
                        -- Storage v2: enchant-keyed stack -> card badge (flat strength)
                        enchant = stackEnchant,
                        use3DModel = true,
                    }
                    -- Only create a visible inventory card when count > 0
                    if (qtyValue.Value or 0) > 0 then
                        table.insert(self.inventoryData, self._stackDataByKey[stackFolder.Name])
                    end
                end
            end
        end
    end

    -- Special (unique)
    if specialFolder then
        for _, uidFolder in ipairs(specialFolder:GetChildren()) do
            if uidFolder:IsA("Folder") then
                local itemId = uidFolder:FindFirstChild("ItemId")
                if itemId then
                    local petType = itemId.Value
                    -- Try to read Variant if present in unique folder
                    local variant = "basic"
                    local variantVal = uidFolder:FindFirstChild("Variant")
                        or uidFolder:FindFirstChild("variant")
                    if variantVal and variantVal:IsA("StringValue") then
                        variant = variantVal.Value
                    end
                    local hugeValue = uidFolder:FindFirstChild("huge")
                        or uidFolder:FindFirstChild("Huge")
                    local isHuge = hugeValue
                        and hugeValue:IsA("BoolValue")
                        and hugeValue.Value == true
                    local serialValue = uidFolder:FindFirstChild("serial")
                        or uidFolder:FindFirstChild("Serial")
                    local serial = serialValue and serialValue.Value or nil
                    local serialSource =
                        readStringValue(uidFolder, { "serial_source", "SerialSource" })
                    local grantSource =
                        readStringValue(uidFolder, { "grant_source", "GrantSource" })
                    local hatcherName = readStringValue(
                        uidFolder,
                        { "hatcher_name", "HatcherName" }
                    ) or readStringValue(uidFolder, { "source", "Source" })
                    local tooltipFields = readPrimitiveValues(uidFolder)
                    if hatcherName then
                        tooltipFields.hatcher_name = hatcherName
                    end
                    local locked = readBoolValue(uidFolder, { "locked", "Locked" })
                    local pdata = getPetConfigData(petType, variant)
                    local rarityValue = uidFolder:FindFirstChild("rarity_id")
                        or uidFolder:FindFirstChild("rarity_override")
                    local storedRarityId = rarityValue
                        and rarityValue:IsA("StringValue")
                        and rarityValue.Value
                    local rarityId = isHuge and "huge"
                        or (pdata and pdata.rarity_id)
                        or storedRarityId
                        or variant
                    local storedEnchantable =
                        readBoolValue(uidFolder, { "enchantable", "Enchantable" })
                    local storedMaxEnchantments = readNumberValue(
                        uidFolder,
                        { "max_enchantments", "MaxEnchantments", "MaxEnchants" }
                    )
                    local unlockedEnchantSlots = readNumberValue(
                        uidFolder,
                        { "unlocked_enchant_slots", "UnlockedEnchantSlots" }
                    )
                    local configuredMaxEnchantments = getConfiguredMaxEnchantments(rarityId)
                    local maxEnchantments = configuredMaxEnchantments
                    if configuredMaxEnchantments <= 0 and storedRarityId == rarityId then
                        maxEnchantments = storedMaxEnchantments or 0
                    end
                    if maxEnchantments > 0 then
                        unlockedEnchantSlots = math.clamp(
                            math.floor(tonumber(unlockedEnchantSlots) or 1),
                            0,
                            maxEnchantments
                        )
                    else
                        unlockedEnchantSlots = 0
                    end
                    local enchantmentCount =
                        countFolderChildren(uidFolder, { "enchantments", "Enchantments" })
                    local enchantments = readEnchantSummaries(uidFolder)
                    local enchantable = maxEnchantments > 0
                        or (storedEnchantable == true and storedRarityId == rarityId)
                    local level = readNumberValue(uidFolder, { "level", "Level" }) or 1
                    local power = getConfiguredPowerForLevel(pdata, level, isHuge)
                    local basePower = power
                    -- ETERNAL display (Jason: the card showed the config floor while the
                    -- pet fought at baseline x percent — shown must equal fought):
                    -- stored record percent wins (pre-variant, like the server), else
                    -- the configured resolution; then baseline x pct x level bonus.
                    -- SERVER precedence (PetHandler): the huge/creator PIN overrides any
                    -- stored record percent (pre-pin reissues carry stale eternal_percent
                    -- values, e.g. the apex's 120); stored only applies to non-huge records.
                    local eternalPercent
                    if isHuge then
                        eternalPercent = getConfiguredEternalPercent(pdata, true, variant)
                    else
                        local stored = readNumberValue(
                            uidFolder,
                            { "EternalPercent", "eternal_percent", "Eternal" }
                        ) or 0
                        if stored > 0 then
                            eternalPercent = applyVariantEternalScale(stored, variant)
                        else
                            eternalPercent = getConfiguredEternalPercent(pdata, false, variant)
                        end
                    end
                    local eternalBaselinePower = tonumber(
                        Players.LocalPlayer and Players.LocalPlayer:GetAttribute("EternalPowerBase")
                    )
                    local effectivePower = power
                    if eternalPercent > 0 and eternalBaselinePower and eternalBaselinePower > 0 then
                        local eternalPower = math.floor(
                            eternalBaselinePower
                                    * (eternalPercent / 100)
                                    * getEternalLevelScaleForDisplay(rarityId, level)
                                + 0.5
                        )
                        effectivePower = math.max(power, eternalPower)
                    end
                    power = effectivePower
                    local petName = (pdata and (pdata.family_display_name or pdata.name))
                        or petType:gsub("^%l", string.upper)
                    local item = {
                        id = "special|" .. uidFolder.Name,
                        name = (isHuge and "Huge " or "")
                            .. petName
                            .. (serial and (" #" .. tostring(serial)) or ""),
                        icon = petIcons[petType] or "🐾",
                        rarity = getRarityDisplayName(rarityId, pdata),
                        rarityId = rarityId,
                        color = getRarityColor(rarityId, variant, pdata),
                        category = "Pets",
                        count = 1,
                        power = power,
                        zonePower = displaySortPower(power, petType, variant),
                        basePower = basePower,
                        effectivePower = effectivePower,
                        eternalBaselinePower = eternalBaselinePower,
                        eternalPercent = eternalPercent,
                        level = level,
                        huge = isHuge,
                        serial = serial,
                        serialSource = serialSource,
                        grantSource = grantSource,
                        hatcherName = hatcherName,
                        tooltipFields = tooltipFields,
                        locked = locked,
                        special = true,
                        enchantable = enchantable,
                        maxEnchantments = maxEnchantments,
                        unlockedEnchantSlots = unlockedEnchantSlots,
                        enchantmentCount = enchantmentCount,
                        enchantments = enchantments,
                        uid = uidFolder.Name,
                        folder_source = "pets",
                        petType = petType,
                        variant = variant,
                        use3DModel = true,
                    }
                    table.insert(self.inventoryData, item)
                end
            end
        end
    end
end

function InventoryPanel:_loadConsumablesFromFolder(consumablesFolder)
    -- Map item IDs to appropriate icons
    local itemIcons = {
        health_potion = "❤️",
        speed_potion = "⚡",
        trader_scroll = "📜",
        premium_boost = "💎",
        test_item = "🧪",
    }

    -- Iterate through all consumable items
    for _, itemFolder in pairs(consumablesFolder:GetChildren()) do
        if itemFolder:IsA("Folder") and itemFolder.Name ~= "Info" then
            local itemData = self:_extractConsumableDataFromFolder(itemFolder)
            if itemData then
                local displayData = {
                    id = itemFolder.Name,
                    name = itemData.id:gsub("_", " "):gsub("^%l", string.upper),
                    icon = itemIcons[itemData.id] or "🧪", -- Item-specific icon or fallback
                    rarity = "Common",
                    color = Color3.fromRGB(150, 150, 150),
                    category = "Items",
                    count = itemData.quantity or 1,
                    uid = itemFolder.Name,
                    folder_source = "consumables", -- Track which folder this came from
                }
                table.insert(self.inventoryData, displayData)
                self.logger:info("🧪 LOADED CONSUMABLE", {
                    name = displayData.name,
                    folder_source = displayData.folder_source,
                    category = displayData.category,
                    count = displayData.count,
                })
            end
        end
    end
end

-- Brew-charge potions (PotionService's "potions" bucket). Stack folder NAME is the potion id
-- (the `id` Value isn't always set); quantity Value holds the count. Pretty name from
-- configs/potions.lua when available. Shown in the Items tab; folder_source = "potions".
function InventoryPanel:_loadPotionsFromFolder(potionsFolder)
    local potionsCfg
    pcall(function()
        local c = require(ReplicatedStorage.Configs:WaitForChild("potions"))
        potionsCfg = c and c.potions
    end)
    for _, itemFolder in pairs(potionsFolder:GetChildren()) do
        if itemFolder:IsA("Folder") and itemFolder.Name ~= "Info" then
            local potionId = itemFolder.Name
            local qtyVal = itemFolder:FindFirstChild("quantity")
                or itemFolder:FindFirstChild("Quantity")
            local count = (qtyVal and tonumber(qtyVal.Value)) or 1
            if count > 0 then
                local def = potionsCfg and potionsCfg[potionId]
                -- Real per-potion icon: the SAME disc the hotbar uses, via meter -> badge
                -- (PetBadge.forPotion + POWER_ICONS.discFor). item.image routes to the flat-image
                -- card path; the 🧪 emoji stays only as the fallback if the disc can't resolve.
                local discImage
                if PetBadge and POWER_ICONS and def and def.meter then
                    local badge = PetBadge.forPotion(def.meter)
                    if badge then
                        discImage = POWER_ICONS.discFor(badge.element, badge.symbol)
                    end
                end
                table.insert(self.inventoryData, {
                    id = potionId,
                    name = (def and (def.display_name or def.name))
                        or (potionId:gsub("_", " "):gsub("^%l", string.upper)),
                    icon = "🧪",
                    image = discImage,
                    rarity = "Potion",
                    color = Color3.fromRGB(160, 110, 220),
                    category = "Items",
                    count = count,
                    uid = potionId,
                    folder_source = "potions",
                })
            end
        end
    end
end

-- Enhancements bucket (E7): each uid folder mirrors { id="enhancement", type, origins_csv,
-- name } via InventoryService value objects. Cards show the display name, a gear icon, and
-- the ORIGIN color (single = its origin's color, dual = chaotic purple) with Single/Dual as
-- the rarity line — same grammar as the ENHANCE strip in PowerChoiceMenu.
function InventoryPanel:_loadEnhancementsFromFolder(enhFolder)
    self._enhStacks = {} -- fresh grouping per load (stale keys would double-count)
    local ORIGIN_COLOR = {
        geomancer = Color3.fromRGB(150, 230, 150),
        pyromancer = Color3.fromRGB(255, 150, 120),
        cryomancer = Color3.fromRGB(140, 200, 255),
        sandwalker = Color3.fromRGB(240, 215, 130),
    }
    local DUAL_COLOR = Color3.fromRGB(196, 156, 255)
    local NATURAL_COLOR = Color3.fromRGB(205, 205, 215) -- generic tier: neutral, junk-grade
    for _, itemFolder in pairs(enhFolder:GetChildren()) do
        if itemFolder:IsA("Folder") and itemFolder.Name ~= "Info" then
            local nameV = itemFolder:FindFirstChild("name")
            local csvV = itemFolder:FindFirstChild("origins_csv")
            local typeV = itemFolder:FindFirstChild("type")
            local origins = {}
            if csvV and csvV:IsA("StringValue") then
                for o in string.gmatch(csvV.Value, "[^,]+") do
                    origins[#origins + 1] = o
                end
            end
            local single = #origins == 1
            local typeName = (typeV and typeV:IsA("StringValue") and typeV.Value) or nil
            -- LEVEL is part of the IDENTITY, encoded in the stack id ("..._L8"), so read
            -- it from there (SSOT) — fixes records whose separate `level` value drifted or
            -- was never stored (origin cogs showed "Level: ?"). Fall back to the value.
            local level = tonumber(itemFolder.Name:match("_L(%d+)$"))
            if not level then
                local levelV = itemFolder:FindFirstChild("level")
                level = (levelV and (levelV:IsA("NumberValue") or levelV:IsA("IntValue")))
                        and math.floor(levelV.Value)
                    or nil
            end
            local qtyV = itemFolder:FindFirstChild("Quantity")
                or itemFolder:FindFirstChild("quantity")
            local quantity = (qtyV and (qtyV:IsA("NumberValue") or qtyV:IsA("IntValue")))
                    and math.max(1, math.floor(qtyV.Value))
                or 1
            -- short labels read BIG on the card (TextScaled): name = the TYPE ("Health"),
            -- second line = the origin pair ("Geo/Cryo") in the rarity color; the badge
            -- (colored disc + symbol + ring) carries the identity
            local shorts = {}
            for _, o in ipairs(origins) do
                shorts[#shorts + 1] = o:sub(1, 1):upper() .. o:sub(2, 3)
            end
            -- STACK identical enhancements for display (Jason: "two L3 accuracies...
            -- not stacking"): records are uid-keyed server-side, but identical
            -- (type, origins, level) read as one card with a count, like pets.
            local stackKey = "enh:"
                .. tostring(typeName)
                .. "|"
                .. table.concat(origins, "+")
                .. "|"
                .. tostring(level)
            self._enhStacks = self._enhStacks or {}
            local existing = self._enhStacks[stackKey]
            if existing then
                existing.count += quantity
            else
                local displayData = {
                    id = itemFolder.Name,
                    name = typeName and (typeName:sub(1, 1):upper() .. typeName:sub(2))
                        or ((nameV and nameV:IsA("StringValue") and nameV.Value) or "Enhancement"),
                    icon = "⚙️", -- fallback only; cards render the PetBadge enhancement badge
                    rarity = (#origins == 0 and "Natural") or (single and "Single") or "Dual",
                    color = (#origins == 0 and NATURAL_COLOR)
                        or (single and ORIGIN_COLOR[origins[1]])
                        or DUAL_COLOR,
                    category = "Enhancements",
                    count = quantity,
                    uid = itemFolder.Name,
                    enhancement_type = typeName,
                    level = level,
                    origins = origins,
                    origins_label = table.concat(shorts, "/"),
                    folder_source = "enhancements",
                }
                self._enhStacks[stackKey] = displayData
                table.insert(self.inventoryData, displayData)
            end
        end
    end
end

function InventoryPanel:_loadToolsFromFolder(toolsFolder)
    -- Map tool IDs to appropriate icons
    local toolIcons = {
        basic_pickaxe = "⛏️",
        iron_pickaxe = "⛏️",
        diamond_pickaxe = "💎",
        wooden_sword = "🗡️",
        iron_sword = "⚔️",
        diamond_sword = "💎",
        crystal_staff = "🔮",
    }

    -- Iterate through all tool items
    for _, itemFolder in pairs(toolsFolder:GetChildren()) do
        if itemFolder:IsA("Folder") and itemFolder.Name ~= "Info" then
            local itemData = self:_extractToolDataFromFolder(itemFolder)
            if itemData then
                local displayData = {
                    id = itemFolder.Name,
                    name = itemData.id:gsub("_", " "):gsub("^%l", string.upper),
                    icon = toolIcons[itemData.id] or "🔧", -- Tool-specific icon or fallback
                    rarity = "Common",
                    color = Color3.fromRGB(150, 150, 150),
                    category = "Tools",
                    count = 1,
                    uid = itemFolder.Name,
                    folder_source = "tools", -- Track which folder this came from
                }
                table.insert(self.inventoryData, displayData)
            end
        end
    end
end

function InventoryPanel:_loadEggsFromFolder(eggsFolder)
    -- INVENTORY eggs (Meet-The-Creator etc.). The egg id keys a REAL egg definition
    -- in configs/pets.lua (image, name, STATED odds — fixed_odds eggs hatch at
    -- exactly these numbers, so the tooltip is honest by construction).
    local okPets, petsConfig = pcall(function()
        return require(game:GetService("ReplicatedStorage").Configs:WaitForChild("pets"))
    end)
    for _, itemFolder in pairs(eggsFolder:GetChildren()) do
        if itemFolder:IsA("Folder") and itemFolder.Name ~= "Info" then
            local itemData = self:_extractEggDataFromFolder(itemFolder)
            if itemData then
                local eggDef = okPets
                    and petsConfig.egg_sources
                    and petsConfig.egg_sources[itemData.id]
                local displayData = {
                    id = itemFolder.Name,
                    name = (eggDef and eggDef.name)
                        or itemData.id:gsub("_", " "):gsub("^%l", string.upper),
                    icon = "🥚",
                    image = eggDef and eggDef.image_id, -- real egg art (group-owned)
                    rarity = "Exclusive",
                    color = Color3.fromRGB(255, 215, 0),
                    category = "Eggs",
                    count = itemData.quantity or 1,
                    uid = itemFolder.Name,
                    egg_def = eggDef, -- odds tooltip + hatch button read this
                    folder_source = "eggs",
                }
                table.insert(self.inventoryData, displayData)
            end
        end
    end
end

-- STATED odds lines for an egg's hover tooltip. The huge row is the hidden chase:
-- shown as "???" (Jason: "the huge would be a triple question mark").
function InventoryPanel:_eggOddsLines(eggDef)
    if not eggDef then
        return { "Odds unknown" }
    end

    -- Mirror the egg billboard's display rules (EggPetPreviewService): SECRET pets are
    -- never advertised — no line at all, not even "??" — while non-secret rares below
    -- min_chance_to_show (1 in 10,000 by config) get the "??" marking instead of a rate.
    -- Secret weight still counts in the total so the shown odds stay truthful.
    local okPets, petsConfig = pcall(function()
        return ConfigLoader:LoadConfig("pets")
    end)
    local okEggSys, eggSysConfig = pcall(function()
        return ConfigLoader:LoadConfig("egg_system")
    end)
    local minShow = (
        okEggSys
        and eggSysConfig
        and eggSysConfig.pet_preview
        and tonumber(eggSysConfig.pet_preview.min_chance_to_show)
    ) or 0.0001

    local hugeChance = (eggDef.huge and tonumber(eggDef.huge.chance)) or 0
    local lines = {}
    local total = 0
    for _, w in pairs(eggDef.pet_weights or {}) do
        total = total + w
    end
    for petName, w in pairs(eggDef.pet_weights or {}) do
        local family = okPets and petsConfig and petsConfig.pets and petsConfig.pets[petName]
        local isSecret = family and family.rarity == "secret"
        if not isSecret then
            local frac = (w / math.max(total, 1)) * (1 - hugeChance)
            local displayName = petName:gsub("_", " "):gsub("^%l", string.upper)
            if frac < minShow then
                lines[#lines + 1] = ("%s — ??"):format(displayName)
            else
                lines[#lines + 1] = ("%s — %.2f%%"):format(displayName, frac * 100)
            end
        end
    end
    if hugeChance > 0 then
        lines[#lines + 1] = ("??? — %.2f%%"):format(hugeChance * 100)
    end
    if eggDef.fixed_odds then
        lines[#lines + 1] = "Stated odds are exact (no luck applies)"
    end
    return lines
end

function InventoryPanel:_extractConsumableDataFromFolder(itemFolder)
    local itemData = {}

    local itemId = itemFolder:FindFirstChild("ItemId")
    local quantity = itemFolder:FindFirstChild("Quantity")

    if not itemId then
        return nil
    end

    itemData.id = itemId.Value
    itemData.quantity = quantity and quantity.Value or 1

    return itemData
end

function InventoryPanel:_extractToolDataFromFolder(itemFolder)
    local itemData = {}

    local itemId = itemFolder:FindFirstChild("ItemId")
    if not itemId then
        return nil
    end

    itemData.id = itemId.Value

    return itemData
end

function InventoryPanel:_extractEggDataFromFolder(itemFolder)
    local itemData = {}

    local itemId = itemFolder:FindFirstChild("ItemId")
    local quantity = itemFolder:FindFirstChild("Quantity")

    if not itemId then
        return nil
    end

    itemData.id = itemId.Value
    itemData.quantity = quantity and quantity.Value or 1

    return itemData
end

-- 🖼️ PET IMAGE ICON CREATION (Using Pre-generated Images)
function InventoryPanel:_createPetImageIcon(parent, item)
    self.logger:info(
        "🖼️ CREATING PET IMAGE",
        { itemId = item.id, petType = item.petType, variant = item.variant }
    )

    -- Huge pets are ONLY a resized base pet (same petType/variant), so they take the exact SAME
    -- pre-baked image path as every other pet — no special live-ViewportFrame card. That one-off
    -- (_create3DPetIcon) is what swallowed the mouse and broke tooltip hover; it now survives only
    -- behind the config-gated "viewports" display method, not as a per-pet branch. (Jason: one
    -- elegant card path — a huge is just a resize, the Creator Colorado is huge-sized and frames
    -- fine through this same path.)

    -- Try to get pre-generated image from AssetPreloadService (huge pets get the up-close baked shot)
    local imageViewport =
        self:_getPetImageFromAssets(item.petType, item.variant, false, item.huge == true)

    if imageViewport then
        -- Use the pre-generated ViewportFrame
        imageViewport.Name = "PetImage"
        imageViewport.Size = UDim2.new(1, 0, 1, 0) -- Fill the iconBG
        imageViewport.Position = UDim2.new(0, 0, 0, 0)
        imageViewport.BackgroundTransparency = 1
        imageViewport.ZIndex = 104
        imageViewport.Parent = parent

        self.logger:info("✅ PET IMAGE LOADED", {
            itemId = item.id,
            petType = item.petType,
            variant = item.variant,
            source = "pre-generated",
        })

        return imageViewport
    else
        -- Fallback to emoji if image not available
        self.logger:warn("❌ PET IMAGE NOT FOUND, using emoji fallback", {
            itemId = item.id,
            petType = item.petType,
            variant = item.variant,
        })

        local fallbackIcon = Instance.new("TextLabel")
        fallbackIcon.Name = "PetEmojiFallback"
        fallbackIcon.Size = UDim2.new(0.8, 0, 0.8, 0)
        fallbackIcon.Position = UDim2.new(0.1, 0, 0.1, 0)
        fallbackIcon.BackgroundTransparency = 1
        fallbackIcon.Text = item.icon or "🐾"
        fallbackIcon.TextScaled = true
        fallbackIcon.Font = Enum.Font.GothamBold
        fallbackIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
        fallbackIcon.ZIndex = 104
        fallbackIcon.Parent = parent

        task.spawn(function()
            for _ = 1, 20 do
                task.wait(0.25)
                if not parent.Parent then
                    return
                end
                if parent:FindFirstChild("PetImage") then
                    return
                end

                local retryViewport = self:_getPetImageFromAssets(item.petType, item.variant, true)
                if retryViewport then
                    if fallbackIcon.Parent then
                        fallbackIcon:Destroy()
                    end

                    retryViewport.Name = "PetImage"
                    retryViewport.Size = UDim2.new(1, 0, 1, 0)
                    retryViewport.Position = UDim2.new(0, 0, 0, 0)
                    retryViewport.BackgroundTransparency = 1
                    retryViewport.ZIndex = 104
                    retryViewport.Parent = parent

                    self.logger:info("✅ PET IMAGE LOADED AFTER RETRY", {
                        itemId = item.id,
                        petType = item.petType,
                        variant = item.variant,
                    })
                    return
                end
            end
        end)

        return fallbackIcon
    end
end

-- 🎛️ GET UI DISPLAY METHOD (User preference + Configuration-based)
function InventoryPanel:_getDisplayMethod(context)
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer

    if not player then
        return "images" -- Safe fallback
    end

    -- Use simplified DisplayPreferences utility
    local DisplayPreferences = require(script.Parent.Parent.Parent.Utils.DisplayPreferences)
    local result = DisplayPreferences.GetDisplayMethod(context)

    self.logger:info("Using display preference", {
        context = context,
        method = result,
        source = "SettingsService",
    })

    return result
end

-- 🔎 PET CARD THUMBNAIL ID (pure registry lookup; huge prefers the up-close shot, falls back to base)
-- Returns "rbxassetid://N" or nil. Same huge-then-base fallback as the ViewportFrame path below so a
-- pet with no baked huge thumbnail still resolves to its normal one through the one card path.
local function resolveThumbnailId(petType, variant, huge)
    if not PET_THUMBNAILS or not PET_THUMBNAILS.pets then
        return nil
    end
    local byVariant = PET_THUMBNAILS.pets[petType]
    if not byVariant then
        return nil
    end
    return (huge and byVariant[variant .. "__huge"]) or byVariant[variant]
end

-- Dedupe the "no flat thumbnail → using viewport" warning to once per petType/variant/huge, so a new
-- pet (or one greyed out by an asset-ownership mismatch) surfaces ONE clear dev warning instead of
-- spamming per card. Everything still works (the card renders its baked ViewportFrame); the warning
-- just means "this pet has no uploaded flat texture yet" so nobody is surprised it's a live viewport.
local warnedNoFlatThumb = {}

-- 🔍 GET PET IMAGE FROM ASSETS (Helper function)
-- ONE card path: returns a flat ImageLabel when a pre-uploaded thumbnail exists (a texture, no
-- per-frame render), otherwise a clone of the baked ViewportFrame (the live 3D fallback). The caller
-- (_createPetImageIcon) styles whatever GuiObject comes back identically — it never branches per-pet.
function InventoryPanel:_getPetImageFromAssets(petType, variant, quiet, huge)
    -- Try to get image from ReplicatedStorage.Assets.Images.Pets
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    -- FAST PATH: a pre-uploaded flat thumbnail. An ImageLabel is a plain texture (replicated +
    -- CDN-cached, zero per-frame cost) and accepts the exact Name/Size/Position/ZIndex the caller
    -- sets, so it drops into the card in place of the ViewportFrame with no other changes.
    local thumbId = resolveThumbnailId(petType, variant, huge)
    if thumbId then
        local label = Instance.new("ImageLabel")
        label.BackgroundTransparency = 1
        label.Image = thumbId
        label.ScaleType = Enum.ScaleType.Fit -- preserve the baked framing's aspect (square canvas)
        label.Size = UDim2.new(1, 0, 1, 0)
        self.logger:info("🎯 PET THUMBNAIL (flat image)", {
            petType = petType,
            variant = variant,
            huge = huge == true,
            image = thumbId,
        })
        if not huge then
            return label
        end
        -- HUGE: an up-close shot of the face, mirroring the viewport "__huge" framing. There's no
        -- separate huge texture, so we zoom the flat one: scale it up inside a clipped frame and lift
        -- it so the face fills the card. Scale-based, so it's resolution-independent and needs no extra
        -- asset. (HUGE_RAISE shifts the image DOWN so the upper-body/face rises to the card centre.)
        local HUGE_ZOOM, HUGE_RAISE = 1.4, 0.1
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.Size = UDim2.fromScale(HUGE_ZOOM, HUGE_ZOOM)
        label.Position = UDim2.new(0.5, 0, 0.5 + HUGE_RAISE, 0)
        label.ZIndex = 104
        local clip = Instance.new("Frame")
        clip.BackgroundTransparency = 1
        clip.ClipsDescendants = true
        clip.Size = UDim2.new(1, 0, 1, 0)
        label.Parent = clip
        return clip
    end

    local success, imageViewport = pcall(function()
        local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
        if not assetsFolder then
            return nil
        end

        local imagesFolder = assetsFolder:FindFirstChild("Images")
        if not imagesFolder then
            return nil
        end

        local petsImagesFolder = imagesFolder:FindFirstChild("Pets")
        if not petsImagesFolder then
            return nil
        end

        local petTypeFolder = petsImagesFolder:FindFirstChild(petType)
        if not petTypeFolder then
            return nil
        end

        -- HUGE pets prefer the up-close "<variant>__huge" thumbnail (baked with the huge_face camera);
        -- fall back to the normal one if it isn't generated yet (same one card path either way).
        local petImageViewport = (huge and petTypeFolder:FindFirstChild(variant .. "__huge"))
            or petTypeFolder:FindFirstChild(variant)
        if not petImageViewport then
            return nil
        end

        -- Clone the ViewportFrame to avoid "Parent property is locked" errors
        return petImageViewport:Clone()
    end)

    if success and imageViewport then
        -- We're here because resolveThumbnailId returned nil (no uploaded flat texture for this
        -- pet/variant) — so the card uses the live baked ViewportFrame. Warn ONCE per pet/variant so
        -- a missing/greyed-out (ownership mismatch) thumbnail is visible to devs, never silent.
        local warnKey = petType .. "/" .. tostring(variant) .. (huge and "/huge" or "")
        if not quiet and not warnedNoFlatThumb[warnKey] then
            warnedNoFlatThumb[warnKey] = true
            self.logger:warn(
                "🖼️ No flat thumbnail — using live viewport (upload/register a texture)",
                {
                    petType = petType,
                    variant = variant,
                    huge = huge == true,
                }
            )
        end
        self.logger:info("🎯 PET IMAGE FOUND", {
            petType = petType,
            variant = variant,
            path = "ReplicatedStorage.Assets.Images.Pets." .. petType .. "." .. variant,
        })
        return imageViewport
    elseif not quiet then
        self.logger:warn("🚫 PET IMAGE NOT FOUND", {
            petType = petType,
            variant = variant,
            error = success and "Image not found" or imageViewport,
        })
    end
    return nil
end

-- 🎮 3D VIEWPORT CREATION (For ViewportFrame display mode)
function InventoryPanel:_create3DPetIcon(parent, item)
    self.logger:info(
        "🎮 CREATING 3D VIEWPORT",
        { itemId = item.id, petType = item.petType, variant = item.variant }
    )

    -- Create ViewportFrame for 3D model
    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "PetViewport"
    viewport.Size = UDim2.new(1, 0, 1, 0) -- Fill the iconBG
    viewport.Position = UDim2.new(0, 0, 0, 0)
    viewport.BackgroundTransparency = 1
    viewport.ZIndex = 104
    viewport.Parent = parent

    -- Create camera
    local camera = Instance.new("Camera")
    camera.Parent = viewport
    viewport.CurrentCamera = camera

    -- Load the 3D model
    self:_load3DPetModel(viewport, camera, item)

    return viewport
end

function InventoryPanel:_createEmojiFallback(viewport, item)
    -- Create emoji icon as fallback when 3D model fails
    local fallbackIcon = Instance.new("TextLabel")
    fallbackIcon.Size = UDim2.new(0.8, 0, 0.8, 0)
    fallbackIcon.Position = UDim2.new(0.1, 0, 0.1, 0)
    fallbackIcon.BackgroundTransparency = 1
    fallbackIcon.Text = item.icon
    fallbackIcon.TextScaled = true
    fallbackIcon.Font = Enum.Font.GothamBold
    fallbackIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
    fallbackIcon.ZIndex = 105
    fallbackIcon.Parent = viewport
end

-- 🎮 3D PET MODEL LOADING (For ViewportFrame display mode)
function InventoryPanel:_load3DPetModel(viewport, camera, item)
    local InsertService = game:GetService("InsertService")
    local Locations = require(game:GetService("ReplicatedStorage").Shared.Locations)
    local petConfig = Locations.getConfig("pets")

    task.spawn(function()
        local success, result = pcall(function()
            -- Get pet data from config
            local petData = petConfig.getPet(item.petType, item.variant)
            if not petData or not petData.asset_id then
                self.logger:warn("No pet data or asset ID found", {
                    petType = item.petType,
                    variant = item.variant,
                })
                return
            end

            -- Try to load from ReplicatedStorage.Assets first (like egg system)
            local modelClone = nil
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")

            if assetsFolder then
                local modelsFolder = assetsFolder:FindFirstChild("Models")
                if modelsFolder then
                    local petsFolder = modelsFolder:FindFirstChild("Pets")
                    if petsFolder then
                        local petTypeFolder = petsFolder:FindFirstChild(item.petType)
                        if petTypeFolder then
                            local petModel = petTypeFolder:FindFirstChild(item.variant)
                            if petModel then
                                modelClone = petModel:Clone()
                                self.logger:debug(
                                    "Loaded pet model from ReplicatedStorage.Assets",
                                    {
                                        petType = item.petType,
                                        variant = item.variant,
                                        path = petModel:GetFullName(),
                                    }
                                )
                            end
                        end
                    end
                end
            end

            -- Fallback to InsertService loading
            if not modelClone then
                local assetId = petData.asset_id
                if assetId and assetId ~= "rbxassetid://0" then
                    local assetNumber = tonumber(assetId:match("%d+"))
                    if assetNumber then
                        local asset = AssetFetch.load(assetNumber)
                        modelClone = asset:FindFirstChildOfClass("Model")
                        if modelClone then
                            modelClone = modelClone:Clone()
                            self.logger:debug("Loaded pet model from InsertService", {
                                assetId = assetId,
                                petType = item.petType,
                                variant = item.variant,
                            })
                        end
                        asset:Destroy()
                    end
                end
            end

            if not modelClone then
                self.logger:warn("Failed to load pet model, creating emoji fallback", {
                    petType = item.petType,
                    variant = item.variant,
                    assetId = petData.asset_id,
                })

                -- Create emoji fallback in the viewport
                self:_createEmojiFallback(viewport, item)
                return
            end

            if petVisualsOk and PetVariantVisuals then
                PetVariantVisuals.ApplyServerMetadata(modelClone, item.petType, item.variant)
                PetVariantVisuals.ApplyStaticVisuals(modelClone)
            end

            local transform = getAssetTransform(petData)
            applyUnbakedAssetTransform(modelClone, transform)

            if item.huge == true then
                local assetScale = tonumber(modelClone:GetAttribute("AssetScale"))
                    or transform.scale
                    or 1
                local hugeScale = tonumber(modelClone:GetAttribute("HugeScale"))
                    or transform.hugeScale
                    or 1
                if hugeScale and hugeScale > 0 then
                    modelClone:ScaleTo(assetScale * hugeScale)
                end
            end

            -- Position model in viewport
            local modelCFrame = CFrame.new(0, 0, 0)
            if modelClone.PrimaryPart then
                modelClone:SetPrimaryPartCFrame(modelCFrame)
            else
                modelClone:MoveTo(modelCFrame.Position)
            end

            modelClone.Parent = viewport

            -- Calculate camera position
            local modelSize = modelClone:GetExtentsSize()
            local zoomMultiplier = petData.viewport_zoom or 1.5
            local baseDistance = math.max(modelSize.X, modelSize.Y, modelSize.Z) * 1.45 -- card framing margin (Jason: 1.2 crowded beefy pets)
            local distance = baseDistance / zoomMultiplier

            -- Safety clamp
            if distance < 1 then
                distance = 1
            end

            local modelPosition = modelClone:GetBoundingBox().Position

            if item.huge == true then
                local _, boundingSize = modelClone:GetBoundingBox()
                -- huge_face: per-pet aim/zoom for the up-close huge shot. Defaults reproduce the old
                -- framing (y 0.22, dist 0.7, fov 58 = aimed mid-body, fine for humanoids like Colorado).
                -- Quadrupeds (bears) carry the face higher/forward, so they set y (and optionally x/z)
                -- to raise the look-at onto the face instead of the belly. All fractions of the model's
                -- bounding extent; offset added relative to the bounding-box CENTER.
                local face = petData.huge_face or {}
                local target = modelPosition
                    + Vector3.new(
                        boundingSize.X * (face.x or 0),
                        boundingSize.Y * (face.y or 0.22),
                        boundingSize.Z * (face.z or 0)
                    )
                local closeDistance =
                    math.max(0.8, math.max(boundingSize.X, boundingSize.Z) * (face.dist or 0.7))
                local cameraDirection = getCameraDirection(petData.camera)
                camera.FieldOfView = face.fov or 58
                camera.CFrame = CFrame.new(target + cameraDirection * closeDistance, target)

                self.logger:info("Huge pet close-up loaded in inventory", {
                    petType = item.petType,
                    variant = item.variant,
                    modelSize = boundingSize,
                    distance = closeDistance,
                    camera = petData.camera,
                })
                return
            end

            -- Set up rotating camera (like egg system)
            local cameraAngle = 0
            local rotationSpeed = 2 -- degrees per frame
            local connection

            connection = game:GetService("RunService").Heartbeat:Connect(function()
                if viewport.Parent and modelClone.Parent then
                    -- Rotate camera around the model
                    camera.CFrame = CFrame.Angles(0, math.rad(cameraAngle), 0)
                        * CFrame.new(modelPosition + Vector3.new(0, 0, distance), modelPosition)
                    cameraAngle = cameraAngle + rotationSpeed
                    if cameraAngle >= 360 then
                        cameraAngle = 0
                    end
                else
                    -- Clean up if viewport or model is destroyed
                    connection:Disconnect()
                end
            end)

            self.logger:info("3D pet model loaded in inventory", {
                petType = item.petType,
                variant = item.variant,
                modelSize = modelSize,
                distance = distance,
            })
        end)

        if not success then
            self.logger:warn("Failed to load 3D pet model, creating emoji fallback", {
                error = result,
                petType = item.petType,
                variant = item.variant,
            })

            -- Create emoji fallback on error
            self:_createEmojiFallback(viewport, item)
        end
    end)
end

function InventoryPanel:_extractPetDataFromFolder(petFolder)
    local petData = {}

    -- Required fields (match what InventoryService actually creates)
    local itemId = petFolder:FindFirstChild("ItemId") -- Changed from "PetType"
    local variant = petFolder:FindFirstChild("variant") -- Changed from "Variant" (case)

    if not itemId or not variant then
        self.logger:warn("Invalid pet folder structure", {
            folderName = petFolder.Name,
            hasItemId = itemId ~= nil,
            hasVariant = variant ~= nil,
            children = {},
        })

        -- Debug: List all children to see what's actually there
        local actualChildren = {}
        for _, child in pairs(petFolder:GetChildren()) do
            table.insert(actualChildren, child.Name .. " (" .. child.ClassName .. ")")
        end

        self.logger:warn("🔍 PET FOLDER DEBUG - Available children", {
            folderName = petFolder.Name,
            children = actualChildren,
        })

        return nil
    end

    petData.id = itemId.Value
    petData.variant = variant.Value

    -- Optional fields
    local level = petFolder:FindFirstChild("level") -- Changed case
    if level then
        petData.level = level.Value
    end

    -- Stats are in a folder structure
    local statsFolder = petFolder:FindFirstChild("stats")
    if statsFolder and statsFolder:IsA("Folder") then
        petData.stats = {}

        local health = statsFolder:FindFirstChild("health")
        if health then
            petData.stats.health = health.Value
        end

        local speed = statsFolder:FindFirstChild("speed")
        if speed then
            petData.stats.speed = speed.Value
        end
    else
        -- Fallback: try direct children (in case structure is different)
        local health = petFolder:FindFirstChild("health")
        local speed = petFolder:FindFirstChild("speed")

        if health or speed then
            petData.stats = {
                health = health and health.Value or 100,
                speed = speed and speed.Value or 1.0,
            }
        end
    end

    local nickname = petFolder:FindFirstChild("nickname") -- Changed case
    if nickname then
        petData.nickname = nickname.Value
    end

    return petData
end

-- Origin "pair key" so identical origin pairs cluster regardless of order: the origins
-- sorted + joined, e.g. {pyromancer, sandwalker} and {sandwalker, pyromancer} both ->
-- "pyromancer+sandwalker". Empty (naturals) -> "".
local function enhancementPairKey(item)
    local origins = item.origins
    if type(origins) ~= "table" or #origins == 0 then
        return ""
    end
    local copy = table.clone(origins)
    table.sort(copy)
    return table.concat(copy, "+")
end

-- natural (#origins 0) / dual (>=2) / single (1) -> the configured class rank.
local function enhancementClassRank(item, classOrder)
    local n = (type(item.origins) == "table" and #item.origins) or 0
    local key = (n == 0 and "natural") or (n >= 2 and "dual") or "single"
    return classOrder[key] or 99
end

-- Cached inventory-sort config (configs/inventory.lua `sorting`). Falls back to the
-- built-in pets→enhancements→eggs order + natural→dual→single if the block is absent.
function InventoryPanel:_sortConfig()
    if self._sortCfg == nil then
        local cfg = {
            section_order = { pets = 0, enhancements = 1, eggs = 2 },
            enhancement_class_order = { natural = 0, dual = 1, single = 2 },
        }
        pcall(function()
            local inv = require(ReplicatedStorage.Configs:WaitForChild("inventory"))
            if inv and inv.sorting then
                cfg.section_order = inv.sorting.section_order or cfg.section_order
                cfg.enhancement_class_order = inv.sorting.enhancement_class_order
                    or cfg.enhancement_class_order
            end
        end)
        self._sortCfg = cfg
    end
    return self._sortCfg
end

-- Inventory grid comparator. Order: equipped first → bucket section (pets, then
-- enhancements, then eggs, then the rest) → a per-section rule:
--   • enhancements: class (natural→dual→single) → origin PAIR → type (A–Z) → level desc
--   • eggs: by name
--   • pets / other: power desc → count desc → name (the original rule)
function InventoryPanel:_compareInventoryItems(a, b)
    -- NO equipped-first rule: deployment now lives in the draft strip, and the inventory grid renders
    -- EVERY pet (deployed included). The old "equipped before non-equipped" sort was harmless when
    -- equipped pets siphoned off to the separate equipped strip — but with the always-on draft they
    -- render in the grid, so it shoved deployed pets ahead of higher-power ones (Huge Bears above the
    -- Creator Colorado). The grid is pure section + power again. (task #240)
    local cfg = self:_sortConfig()
    local as = cfg.section_order[a.folder_source] or 50
    local bs = cfg.section_order[b.folder_source] or 50
    if as ~= bs then
        return as < bs
    end

    if a.folder_source == "enhancements" and b.folder_source == "enhancements" then
        local ac = enhancementClassRank(a, cfg.enhancement_class_order)
        local bc = enhancementClassRank(b, cfg.enhancement_class_order)
        if ac ~= bc then
            return ac < bc
        end
        local ak, bk = enhancementPairKey(a), enhancementPairKey(b)
        if ak ~= bk then
            return ak < bk
        end
        local at = tostring(a.enhancement_type or a.name)
        local bt = tostring(b.enhancement_type or b.name)
        if at ~= bt then
            return at < bt
        end
        local al = tonumber(a.level) or 0
        local bl = tonumber(b.level) or 0
        if al ~= bl then
            return al > bl -- higher level first
        end
        return tostring(a.name) < tostring(b.name)
    elseif a.folder_source == "eggs" and b.folder_source == "eggs" then
        return tostring(a.name) < tostring(b.name)
    end

    -- pets / other: power desc, count desc, name (unchanged behavior)
    local ap = tonumber(a.zonePower or a.power) or 0
    local bp = tonumber(b.zonePower or b.power) or 0
    if ap ~= bp then
        return ap > bp
    end
    local acn = tonumber(a.count) or 1
    local bcn = tonumber(b.count) or 1
    if acn ~= bcn then
        return acn > bcn
    end
    return tostring(a.name) < tostring(b.name)
end

-- Build a lowercased, cached search haystack so the inventory search matches more than the display
-- name (Jason: search "luck" -> luck pets, "tank" -> tanks). Includes name/type/rarity/variant and,
-- for pets, Role / Element / support-Aura — from the same sources the card + tooltip use. Cached on
-- the item (each inventory reload makes fresh item tables, so the cache never goes stale).
function InventoryPanel:_itemSearchText(item)
    if item._searchText then
        return item._searchText
    end
    local parts = {}
    local function add(v)
        if v ~= nil and v ~= "" then
            parts[#parts + 1] = tostring(v)
        end
    end
    add(item.name)
    add(item.petType)
    add(item.rarity)
    add(item.variant)
    if item.category == "Pets" and item.petType then
        if PetPowerView then
            local ok, role = pcall(function()
                return PetPowerView.roleInfo(item.petType, item.role)
            end)
            if ok and role then
                add(role.label)
                add(role.id)
            end
        end
        if PetBadge then
            add(item.creator and "creator" or PetBadge.biomeElementForPetType(item.petType))
        end
        if PET_ROLES and PET_ROLES.support_auras then
            local entry = PET_ROLES.support_auras[item.petType]
            local auras = (type(entry) == "table") and (entry.kind and { entry } or entry) or nil
            for _, a in ipairs(auras or {}) do
                add(a.kind)
                local meta = SUPPORT_META[a.kind]
                if meta then
                    add(meta.label)
                end
            end
        end
    end
    add(item.enhancement_type)
    add(item.origins_label)
    item._searchText = string.lower(table.concat(parts, " "))
    return item._searchText
end

function InventoryPanel:_updateItemsDisplay()
    -- Cards get destroyed + rebuilt here; hide any open tooltip first so a card destroyed under the
    -- cursor (its MouseLeave never fires) can't leave the popup stuck on screen (Jason: intermittent).
    self:_hideItemTooltip()
    -- Cleanup old right-click connections to prevent memory leaks
    if self._rightClickConnections then
        for itemId, connection in pairs(self._rightClickConnections) do
            if connection then
                connection:Disconnect()
            end
        end
        self._rightClickConnections = {}
    end

    -- Clear existing items in both grids
    local function clearChildren(container)
        if container then
            for _, child in ipairs(container:GetChildren()) do
                -- item cards are Frames; the empty-slot rings are ImageLabels named EmptySlotRing.
                -- Clear BOTH each rebuild, else stale empty rings leak in and pile up (the layout
                -- helpers UIGridLayout/UIPadding are neither, so they survive).
                if child:IsA("Frame") or child.Name == "EmptySlotRing" then
                    child:Destroy()
                end
            end
        end
    end
    clearChildren(self.equippedGrid)
    clearChildren(self.inventoryGrid)
    self.itemFrames = {}

    -- Draft mode is ALWAYS on: the Equipped strip is the working draft squad (deploy is draft +
    -- Activate, there is no live equip). Seed it from the deployed squad on first render. (task #240)
    if self._draftRefs == nil then
        self:_seedDraftFromEquipped()
    end
    local teamMode = true
    local draftRefs = self._draftRefs
    if self.equippedLabel then
        -- Clean (matches what's deployed) reads "deployed" in green; an edited draft reads "draft" in
        -- purple until Activate commits it. self._draftDirty is set on every draft edit. (task #240)
        local deployed = not self._draftDirty
        self.equippedLabel.Text = (deployed and "Squad (deployed)  —  " or "Squad (draft)  —  ")
            .. #draftRefs
            .. "/"
            .. self:_squadSlotCount()
        self.equippedLabel.TextColor3 = deployed and Color3.fromRGB(120, 230, 140)
            or Color3.fromRGB(185, 150, 255)
    end
    -- Pulse Activate while the draft is un-deployed: clicking a pet only EDITS the draft (nothing
    -- deploys until Activate), so a new player can stage a squad and stall. The pulse says "you're
    -- not done — press this". Stops the instant the draft matches the field. (Jason: don't-get-stuck)
    self:_setActivatePulse(self._draftDirty == true)

    -- Get current category folders for filtering
    local categoryFolders = self:_getCategoryFolders(self.selectedCategory)

    -- Filter items
    local filteredItems = {}
    for _, item in ipairs(self.inventoryData) do
        local isStackItem = typeof(item.id) == "string" and string.sub(item.id, 1, 6) == "stack|"
        local matchesCategory =
            self:_itemMatchesCategory(item, self.selectedCategory, categoryFolders)
        -- Equipped pets are your active squad — show them in the Equipped row on EVERY category
        -- tab, not just Pets/All (Jason: equipped pets vanished on Enhancements). Stack-equipped
        -- pets already show on every tab via the ghost-card pass below, so this just makes the
        -- non-stack (unique) equipped pets consistent with them. Routes to the equipped grid.
        local equippedBypass = (not isStackItem) and self:_isItemEquipped(item)
        local matchesSearch = (
            self.searchTerm == "" or self:_itemSearchText(item):find(self.searchTerm, 1, true)
        )

        if (matchesCategory or equippedBypass) and matchesSearch then
            table.insert(filteredItems, item)
        end
    end

    -- Sort: equipped first, then by bucket section (pets → enhancements → eggs → rest),
    -- with a per-section rule (pets by power, enhancements grouped, eggs by name).
    table.sort(filteredItems, function(a, b)
        return self:_compareInventoryItems(a, b)
    end)

    -- Create item frames into equipped or inventory sections
    local eqIndex, invIndex = 1, 1
    for _, item in ipairs(filteredItems) do
        local isStack = typeof(item.id) == "string" and string.sub(item.id, 1, 6) == "stack|"
        local isEquipped = self:_isItemEquipped(item)
        if isStack then
            isEquipped = false
        end -- keep the stack in inventory
        if teamMode then
            isEquipped = false -- in team mode the strip shows the DRAFT (rendered below), not live
        end
        local container = isEquipped and self.equippedGrid or self.inventoryGrid
        -- In draft mode, an inventory stack shows REMAINING availability (owned − drafted) so you can
        -- see how many of a common you can still field. Clone for display, but stamp _ownedTotal so the
        -- add-cap still uses the true owned count.
        local renderItem = item
        if teamMode and item.folder_source == "pets" then
            local ref = self:_draftRefForItem(item)
            if ref and string.sub(ref, 1, 6) == "stack|" then
                local owned = tonumber(item.count) or tonumber(item.quantity) or 0
                local drafted = 0
                for _, v in ipairs(draftRefs or {}) do
                    if v == ref then
                        drafted += 1
                    end
                end
                if drafted > 0 then
                    local remaining = math.max(0, owned - drafted)
                    if remaining <= 0 then
                        -- The whole stack is in the draft: drop it from inventory so it isn't a
                        -- phantom "+1" card that looks like another copy you can still add.
                        continue
                    end
                    renderItem = table.clone(item)
                    renderItem._ownedTotal = owned
                    renderItem.count = remaining
                    renderItem.quantity = remaining
                end
            elseif ref then
                -- A unique is one-of: if it's in the draft it's fully deployed, so drop it from the
                -- inventory grid (else the deployed unique shows in BOTH the strip and inventory and
                -- looks like you own two). Mirrors the stack remaining==0 case above.
                local inDraft = false
                for _, v in ipairs(draftRefs or {}) do
                    if v == ref then
                        inDraft = true
                        break
                    end
                end
                if inDraft then
                    continue
                end
            end
        end
        self:_createItemFrameInto(renderItem, isEquipped and eqIndex or invIndex, container)
        if isEquipped then
            eqIndex += 1
        else
            invIndex += 1
        end
    end

    -- Render the working DRAFT into the Equipped strip (one card per ref, in order). Clicking a draft
    -- card toggles it back out (the draft hijack). Nothing here touches the live field until Activate.
    if teamMode and draftRefs then
        -- Resolve each draft ref to its inventory card the SAME way _seedDraftFromEquipped does: exact
        -- ref first, then the area-insensitive "pet:enchant" prefix. A deployed ref can carry a drifted
        -- or empty area segment (e.g. "stack|bunny:rainbow:") that never exactly equals the card's key —
        -- without the prefix fallback the slot rendered EMPTY while the count still read the ref (the
        -- "1/3 deployed but no card in the slot" bug). Render must match the seed or they disagree.
        local byRef, byPrefix = {}, {}
        for _, item in ipairs(self.inventoryData) do
            if item.folder_source == "pets" then
                local ref = self:_draftRefForItem(item)
                if type(ref) == "string" and byRef[ref] == nil then
                    byRef[ref] = item
                    local p = self:_stackPrefix(ref)
                    if p and byPrefix[p] == nil then
                        byPrefix[p] = item
                    end
                end
            end
        end
        -- Use eqIndex (not a local) so _renderEmptySlotRings(eqIndex - 1) below pads the RIGHT number
        -- of empty slots — otherwise it padded a full 10 on top of the draft cards and they piled up.
        for _, ref in ipairs(draftRefs) do
            -- exact → prefix (un-equipped card) → cached stack data (fully-deployed stack, no card)
            local item = byRef[ref]
                or byPrefix[self:_stackPrefix(ref)]
                or self:_stackDataForRef(ref)
            if item then
                -- A draft SLOT is one pet, not the whole stack: clone + count 1 so the card shows a
                -- single pet (no "x5" stack badge), like the live equipped ghost cards do.
                local card = item
                if string.sub(ref, 1, 6) == "stack|" then
                    card = table.clone(item)
                    card.count = 1
                    card.quantity = 1
                end
                self:_createItemFrameInto(card, eqIndex, self.equippedGrid)
                eqIndex += 1
            end
        end
    end

    -- Add ghost cards for equipped instances drawn from stacks (one per equipped UID)
    if not teamMode and self.equippedItems and self.equippedItems.pets then
        for equippedUid, _ in pairs(self.equippedItems.pets) do
            if typeof(equippedUid) == "string" then
                local parts = string.split(equippedUid, "|")
                if #parts >= 2 and parts[1] == "stack" then
                    local stackKey = parts[2]
                    local stackData = self._stackDataByKey and self._stackDataByKey[stackKey]
                    if stackData then
                        local ghost = table.clone(stackData)
                        ghost.id = "equipped_instance|" .. equippedUid
                        ghost.uid = equippedUid
                        ghost.count = 1
                        self:_createItemFrameInto(ghost, eqIndex, self.equippedGrid)
                        eqIndex += 1
                    end
                end
            end
        end
    end

    -- Pad the equipped row with blank rings for the remaining open slots (eqIndex-1 = # filled).
    self:_renderEmptySlotRings(eqIndex - 1)

    -- Grid just (re)built — pause every off-screen card's viewport. Deferred so card AbsolutePositions
    -- are laid out first; the scroll/resize signals keep it current after that.
    self:_requestCull()
end

function InventoryPanel:_getCategoryFolders(categoryName)
    -- Get folders that belong to the selected category
    if not self.inventoryConfig or not self.inventoryConfig.display_categories then
        -- Fallback mapping for legacy categories
        local fallbackMapping = {
            All = { "pets", "consumables", "tools", "eggs", "resources" },
            Pets = { "pets" },
            Items = { "consumables" },
            Eggs = { "eggs" },
            Tools = { "tools" },
            Resources = { "resources" },
        }
        return fallbackMapping[categoryName] or {}
    end

    -- Find the category in configuration
    for _, categoryConfig in ipairs(self.inventoryConfig.display_categories) do
        if categoryConfig.name == categoryName then
            return categoryConfig.folders
        end
    end

    return {}
end

function InventoryPanel:_itemMatchesCategory(item, categoryName, categoryFolders)
    -- "All" category shows everything
    if categoryName == "All" then
        return true
    end

    -- Check if item's folder source is in the category's folder list
    if item.folder_source then
        for _, folderName in ipairs(categoryFolders) do
            if item.folder_source == folderName then
                self.logger:debug("✅ FILTER MATCH", {
                    item = item.name,
                    category = categoryName,
                    folder_source = item.folder_source,
                    matched_folder = folderName,
                })
                return true
            end
        end
        self.logger:debug("❌ FILTER NO MATCH", {
            item = item.name,
            category = categoryName,
            folder_source = item.folder_source,
            available_folders = categoryFolders,
        })
        return false -- Don't fall back to legacy if folder_source exists
    end

    -- Fallback: check legacy category field (only if no folder_source)
    local legacyMatch = item.category == categoryName
    self.logger:debug("🔄 FILTER LEGACY", {
        item = item.name,
        category = categoryName,
        item_category = item.category,
        matched = legacyMatch,
    })
    return legacyMatch
end

function InventoryPanel:_createItemFrameInto(item, layoutOrder, parentContainer)
    -- Item frame
    local itemFrame = Instance.new("Frame")
    itemFrame.Name = item.id
    local cardStyle = PetCardStyle.styleFor(item.rarityId, item.variant)
    itemFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    itemFrame.BorderSizePixel = 0
    itemFrame.LayoutOrder = layoutOrder
    itemFrame.ZIndex = 102
    itemFrame.Size = UDim2.new(0, self.cardSize.X, 0, self.cardSize.Y)
    print("cardSize", self.cardSize)
    itemFrame.Parent = parentContainer or self.itemsGrid

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = itemFrame

    -- card chrome (rarity ring + variant ring + background gradients) via the
    -- SHARED PetCardStyle — the same renderer the trade window uses (Jason: "the
    -- whole point of this game is to make reusable components")
    PetCardStyle.applyChrome(itemFrame, item.rarityId, item.variant, item.petType, item.color)

    -- Item icon background
    local iconBG = Instance.new("Frame")
    local configuredIconSize: Vector2? = nil
    local configuredIconScale: number? = nil
    do
        -- Load UI config via Locations to avoid scope issues with ConfigLoader
        local okUI, uiCfg = pcall(function()
            return Locations.getConfig("ui")
        end)
        if
            okUI
            and uiCfg
            and uiCfg.panel_configs
            and uiCfg.panel_configs.inventory_panel
            and uiCfg.panel_configs.inventory_panel.grid
        then
            local g = uiCfg.panel_configs.inventory_panel.grid
            if g.icon_size and typeof(g.icon_size) == "Vector2" then
                configuredIconSize = g.icon_size
            end
            if typeof(g.icon_scale) == "number" then
                configuredIconScale = g.icon_scale
            end
        end
    end
    local iconSize = configuredIconSize and configuredIconSize.X
        or (configuredIconScale and math.floor(
            self.cardSize.X * math.clamp(configuredIconScale, 0.1, 1.2)
        ))
        or math.floor(self.cardSize.X * 0.5)
    iconBG.Size = UDim2.new(0, iconSize, 0, iconSize)
    iconBG.Position =
        UDim2.new(0.5, -math.floor(iconSize / 2), 0, math.floor(self.cardSize.Y * 0.08))
    iconBG.BackgroundColor3 = item.color
    iconBG.BackgroundTransparency = 0.8
    iconBG.BorderSizePixel = 0
    iconBG.ZIndex = 103
    iconBG.Parent = itemFrame

    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, math.floor(self.cardSize.X * 0.3))
    iconCorner.Parent = iconBG

    if cardStyle.variantRing then
        iconBG.BackgroundTransparency = 0.35
        local iconGradient = Instance.new("UIGradient")
        iconGradient.Name = "VariantIconGradient"
        iconGradient.Color = PetCardStyle.colorSequence(cardStyle.variantRing.colors, item.color)
        iconGradient.Rotation = tonumber(cardStyle.variantRing.rotation) or 0
        iconGradient.Parent = iconBG
        if cardStyle.variantRing.animated == true then
            PetCardStyle.spin(iconGradient, tonumber(cardStyle.variantRing.rotation_seconds) or 3)
        end
    end

    -- Item icon (3D model or emoji fallback)
    self.logger:info("🎨 CREATING ICON", {
        itemId = item.id,
        use3DModel = item.use3DModel,
        petType = item.petType,
        variant = item.variant,
        icon = item.icon,
    })

    if item.use3DModel then
        -- Check configuration to determine display method
        local displayMethod = self:_getDisplayMethod("inventory")

        if displayMethod == "images" then
            -- Use pre-generated pet image
            self.logger:info(
                "🖼️ USING PET IMAGE",
                { itemId = item.id, petType = item.petType, config = "images" }
            )
            local imageIcon = self:_createPetImageIcon(iconBG, item)
        elseif displayMethod == "viewports" then
            -- Use 3D ViewportFrame
            self.logger:info(
                "🎮 USING 3D VIEWPORT",
                { itemId = item.id, petType = item.petType, config = "viewports" }
            )
            local viewport = self:_create3DPetIcon(iconBG, item)
        else
            -- Unknown config, default to images
            self.logger:warn("🚨 UNKNOWN DISPLAY METHOD, defaulting to images", {
                displayMethod = displayMethod,
                itemId = item.id,
            })
            local imageIcon = self:_createPetImageIcon(iconBG, item)
        end
    elseif item.folder_source == "enhancements" and item.enhancement_type and item.origins then
        -- the SAME two-layer badge as the PowerChoiceMenu ENHANCE strip (one assembly path):
        -- disc = first origin's color + type symbol, ring tinted the second origin's color
        PetBadge.createEnhancementBadge(iconBG, {
            size = UDim2.fromScale(0.92, 0.92),
            position = UDim2.fromScale(0.5, 0.5),
            anchor = Vector2.new(0.5, 0.5),
            record = { type = item.enhancement_type, origins = item.origins },
            zindex = 104,
        })
        if item.level then
            -- level chip, top-left (pets use that spot for the equipped check — free here)
            local lvl = Instance.new("TextLabel")
            lvl.Name = "EnhLevel"
            local lW = math.max(16, math.floor(self.cardSize.X * 0.3))
            local lH = math.max(12, math.floor(self.cardSize.Y * 0.2))
            local lM = math.max(2, math.floor(self.cardSize.X * 0.05))
            lvl.Size = UDim2.fromOffset(lW, lH)
            lvl.Position = UDim2.fromOffset(lM, lM)
            lvl.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            lvl.BackgroundTransparency = 0.25
            lvl.Text = "L" .. tostring(item.level)
            lvl.TextColor3 = item.color or Color3.fromRGB(255, 255, 255)
            lvl.TextScaled = true
            lvl.Font = Enum.Font.GothamBold
            lvl.ZIndex = 105
            lvl.Parent = itemFrame
            local lc = Instance.new("UICorner")
            lc.CornerRadius = UDim.new(0, 5)
            lc.Parent = lvl
        end
    elseif item.image then
        -- flat image icon (egg items: real uploaded art instead of the emoji)
        local img = Instance.new("ImageLabel")
        img.Size = UDim2.fromScale(0.92, 0.92)
        img.AnchorPoint = Vector2.new(0.5, 0.5)
        img.Position = UDim2.fromScale(0.5, 0.5)
        img.BackgroundTransparency = 1
        img.ScaleType = Enum.ScaleType.Fit
        img.Image = item.image
        img.ZIndex = 104
        img.Parent = iconBG
    else
        -- Use emoji fallback
        self.logger:info("🎭 USING EMOJI FALLBACK", { itemId = item.id, icon = item.icon })
        local icon = Instance.new("TextLabel")
        local calcBase = iconSize
        if configuredIconSize then
            calcBase = configuredIconSize.Y
        elseif configuredIconScale then
            calcBase = math.floor(self.cardSize.Y * math.clamp(configuredIconScale, 0.1, 1.2))
        end
        local ti = math.max(8, math.floor(calcBase * 0.8))
        icon.Size = UDim2.new(0, ti, 0, ti)
        icon.Position = UDim2.new(0.5, -math.floor(ti / 2), 0.5, -math.floor(ti / 2))
        icon.BackgroundTransparency = 1
        icon.Text = item.icon
        icon.TextScaled = true
        icon.Font = Enum.Font.GothamBold
        icon.ZIndex = 104
        icon.Parent = iconBG
    end

    -- Quantity badge (top-right)
    local qty = tonumber(item.count) or 1
    if qty > 1 then
        local qtyLabel = Instance.new("TextLabel")
        qtyLabel.Name = "QtyLabel"
        local qW = math.max(12, math.floor(self.cardSize.X * 0.28))
        local qH = math.max(10, math.floor(self.cardSize.Y * 0.22))
        local qM = math.max(2, math.floor(self.cardSize.X * 0.06))
        qtyLabel.Size = UDim2.new(0, qW, 0, qH)
        qtyLabel.Position = UDim2.new(1, -qW - qM, 0, qM)
        qtyLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        qtyLabel.BorderSizePixel = 0
        qtyLabel.Text = "×" .. tostring(qty)
        qtyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        qtyLabel.TextScaled = true
        qtyLabel.Font = Enum.Font.GothamBold
        qtyLabel.ZIndex = 105
        qtyLabel.Parent = itemFrame
        local qc = Instance.new("UICorner")
        qc.CornerRadius = UDim.new(0, 6)
        qc.Parent = qtyLabel
    end

    -- Equipped icon (top-left)
    local equippedIcon = Instance.new("TextLabel")
    equippedIcon.Name = "EquippedIcon"
    local eW = math.max(12, math.floor(self.cardSize.X * 0.28))
    local eH = math.max(10, math.floor(self.cardSize.Y * 0.22))
    local eM = math.max(2, math.floor(self.cardSize.X * 0.06))
    equippedIcon.Size = UDim2.new(0, eW, 0, eH)
    equippedIcon.Position = UDim2.new(0, eM, 0, eM)
    equippedIcon.BackgroundTransparency = 1
    equippedIcon.Text = self:_isItemEquipped(item) and "✓" or ""
    equippedIcon.TextColor3 = Color3.fromRGB(255, 215, 0)
    equippedIcon.TextScaled = true
    equippedIcon.Font = Enum.Font.GothamBold
    equippedIcon.ZIndex = 105
    equippedIcon.Parent = itemFrame

    -- Name (center bottom) and strength below it (configurable spacing)
    local nameLabel = Instance.new("TextLabel")
    local powerLabel = Instance.new("TextLabel")

    local nameHeightScale = 0.17
    local nameBottomOffsetScale = 0.31
    local powerHeightScale = 0.14
    local powerBottomOffsetScale = 0.17
    local nameFont = Enum.Font.GothamBold
    local nameColor = Color3.fromRGB(255, 255, 255)
    local powerFont = Enum.Font.Gotham
    local powerPrefix = "⚡ "
    local powerColorOverride: Color3? = nil
    local useRarityColorForPower = true

    do
        local okUI, uiCfg = pcall(function()
            return ConfigLoader:LoadConfig("ui")
        end)
        if
            okUI
            and uiCfg
            and uiCfg.panel_configs
            and uiCfg.panel_configs.inventory_panel
            and uiCfg.panel_configs.inventory_panel.grid
        then
            local g = uiCfg.panel_configs.inventory_panel.grid
            if typeof(g.name_label) == "table" then
                nameHeightScale = typeof(g.name_label.height_scale) == "number"
                        and g.name_label.height_scale
                    or nameHeightScale
                nameBottomOffsetScale = typeof(g.name_label.bottom_offset_scale) == "number"
                        and g.name_label.bottom_offset_scale
                    or nameBottomOffsetScale
                if typeof(g.name_label.font) == "EnumItem" then
                    nameFont = g.name_label.font
                end
                if typeof(g.name_label.color) == "Color3" then
                    nameColor = g.name_label.color
                end
            end
            if typeof(g.power_label) == "table" then
                powerHeightScale = typeof(g.power_label.height_scale) == "number"
                        and g.power_label.height_scale
                    or powerHeightScale
                powerBottomOffsetScale = typeof(g.power_label.bottom_offset_scale) == "number"
                        and g.power_label.bottom_offset_scale
                    or powerBottomOffsetScale
                if typeof(g.power_label.font) == "EnumItem" then
                    powerFont = g.power_label.font
                end
                if typeof(g.power_label.prefix) == "string" then
                    powerPrefix = g.power_label.prefix
                end
                if typeof(g.power_label.color) == "Color3" then
                    powerColorOverride = g.power_label.color
                end
                if typeof(g.power_label.color_from_rarity) == "boolean" then
                    useRarityColorForPower = g.power_label.color_from_rarity
                end
            end
        end
    end

    nameLabel.Size = UDim2.new(1, -8, 0, math.max(8, math.floor(self.cardSize.Y * nameHeightScale)))
    nameLabel.Position =
        UDim2.new(0, 4, 1, -math.max(12, math.floor(self.cardSize.Y * nameBottomOffsetScale)))
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = item.name
    nameLabel.TextColor3 = nameColor
    nameLabel.TextScaled = true
    nameLabel.Font = nameFont
    nameLabel.ZIndex = 103
    nameLabel.Parent = itemFrame

    powerLabel.Name = "PowerLabel"
    powerLabel.Size =
        UDim2.new(1, -8, 0, math.max(6, math.floor(self.cardSize.Y * powerHeightScale)))
    powerLabel.Position =
        UDim2.new(0, 4, 1, -math.max(8, math.floor(self.cardSize.Y * powerBottomOffsetScale)))
    powerLabel.BackgroundTransparency = 1
    -- Pet cards show ⚔ POWER + ❤ EFFECTIVE HP — the TRUE numbers the pet ACTUALLY has (Jason's
    -- first principle). Mining and attack are one unified power now, so the old ⛏/⚔ pair printed the
    -- same number twice; the second slot becomes survivability instead, the one stat that varies by
    -- archetype. ⚔ resolves through resolvePetProfile (the sort key's SSOT) with the full live
    -- context (biome RPS + cross-realm resonance) — a light pet reads ⚔63 in Hell, 34 in Heaven, 42
    -- at home. ❤ = power * pet_down_threshold_factor * (1 + defense/k) via PetPowerView.survivability
    -- — the SAME endurance ceiling + armor curve the server downs the pet with. ❤ uses the BASE power
    -- (not the contextual ⚔), because cross-realm resonance scales offense only, never toughness:
    -- a blaster reads ❤ = 10x power, a tank ❤ = 20x power (defense is the multiplier).
    local powerText = (item.power and (powerPrefix .. tostring(item.power))) or ""
    if item.folder_source == "enhancements" and item.origins_label then
        powerText = item.origins_label -- "Geo/Cryo" under the type name, in the rarity color
    end
    if PetPowerView and item.category == "Pets" and item.petType and item.power then
        local profile = resolvePetProfile(item.power, item.petType, item.variant, item.creator)
        if profile then
            local okEhp, ehp = pcall(function()
                return PetPowerView.survivability(item.power, item.petType, item.role)
            end)
            -- ⚔ = the FULL hit the focus takes (Jason's first principle). An aura pet SPLITS its hit
            -- ("hit = hit - aura"): the swing deals (1-f) and the field returns f to the focus, so the
            -- focus still nets the full combatEffective — that's the number to show. (Neighbors take
            -- the f as bonus AoE; the aura ring on the badge signals the field.)
            powerText = string.format(
                "⚔ %d  ❤ %d",
                PetPowerView.displayRound(profile.combatEffective),
                PetPowerView.displayRound((okEhp and ehp) or 0)
            )
        end
    end
    powerLabel.Text = powerText
    powerLabel.TextColor3 = (useRarityColorForPower and item.color)
        or powerColorOverride
        or item.color
    powerLabel.TextScaled = true
    powerLabel.Font = powerFont
    powerLabel.ZIndex = 103
    powerLabel.Parent = itemFrame
    -- Thin dark outline: the number is painted in the rarity color, so on a same-colored card
    -- (purple-on-purple is the worst) or on white pet art it blends out. A very thin black stroke
    -- gives every glyph a luminance edge without fattening the small text (Jason: keep it very thin).
    local powerStroke = Instance.new("UIStroke")
    powerStroke.Name = "PowerOutline"
    powerStroke.Color = Color3.fromRGB(0, 0, 0)
    powerStroke.Thickness = 1
    powerStroke.Transparency = 0.1
    powerStroke.LineJoinMode = Enum.LineJoinMode.Round
    powerStroke.Parent = powerLabel

    -- Archetype chip (top-left): identifies the pet's role at a glance — Tank / Melee /
    -- Blaster / Buffer / Control — so buffers (the per-zone support pets) are easy to spot.
    if PetPowerView and item.category == "Pets" and item.petType then
        local okRole, role = pcall(function()
            return PetPowerView.roleInfo(item.petType, item.role)
        end)
        if okRole and role and role.label then
            -- Preferred: the universal element-disc + tinted-ring BADGE (top-left, square).
            local built = false
            if PetBadge then
                local element = PetBadge.elementForPetType(item.petType)
                -- Relative: a square badge sized to ~half the card's HEIGHT (aspect-ratio
                -- constraint), poking off the top-left corner by a fraction of the card. No
                -- pixel math — it scales with cardSize automatically.
                local holder = Instance.new("Frame")
                holder.Name = "RoleBadge"
                holder.Size = UDim2.new(1, 0, 0.5, 0) -- full width box, half-height -> square fits to height
                holder.Position = UDim2.fromScale(-0.1, -0.1)
                holder.BackgroundTransparency = 1
                holder.ZIndex = 106
                holder.Parent = itemFrame
                local hAspect = Instance.new("UIAspectRatioConstraint")
                hAspect.AspectRatio = 1
                hAspect.AspectType = Enum.AspectType.FitWithinMaxSize
                hAspect.Parent = holder
                -- DAMAGE-targeting ring: the archetype badge wears the ring for HOW its attack hits
                -- (PetTargeting.attackScope → power_icons.targeting_ring). Resolve the per-pet
                -- override from the PETS CONFIG (pets.lua attack_targeting) — the SAME source spawn
                -- reads onto the live pet's AttackTargeting attribute (which the squad HUD reads), so
                -- the inventory card and the squad badge always agree. NOT item.attack_targeting
                -- (unpopulated → wrongly fell back to single, diverging from the HUD — Jason's catch).
                local petDef = PETS_CONFIG and PETS_CONFIG.pets and PETS_CONFIG.pets[item.petType]
                -- Huge-only scope override (pets.lua huge_attack_targeting): the huge bear's earth
                -- AURA is huge-exclusive, so a HUGE card shows the aura ring while a normal bear
                -- shows single — mirrors the huge-aware AttackTargeting the spawn path stamps, so
                -- card ↔ squad HUD stay in agreement.
                local cfgTargeting = petDef and petDef.attack_targeting
                if item.huge == true and petDef and petDef.huge_attack_targeting then
                    cfgTargeting = petDef.huge_attack_targeting
                end
                local atkScope = PetTargeting.attackScope(cfgTargeting, role.id, PET_ROLES)
                local b = PetBadge.create(holder, {
                    element = element,
                    role = role.id,
                    ring = POWER_ICONS.targeting_ring[atkScope],
                    zIndex = 106,
                })
                built = b and b.disc and b.disc.Visible == true
                if not built then
                    holder:Destroy() -- no disc art for this (element, role) -> fall back to text chip
                elseif
                    PetTargeting.isContagious(
                        petDef and petDef.attack_dot,
                        petDef and petDef.attack_targeting
                    )
                then
                    -- SPREAD MARKER (SSOT): the geometry ring alone can't tell AoE-contagion from a
                    -- plain AoE, so a contagious burn wears a small contagion glyph on the badge — the
                    -- card reads "this attack's burn spreads". Element-tinted to match. Same isContagious
                    -- truth the combat loop arms from (attack_dot.spread / legacy "contagion").
                    local spreadDisc = POWER_ICONS.discFor
                        and POWER_ICONS.discFor(element, "contagion")
                    if spreadDisc then
                        local mk = Instance.new("ImageLabel")
                        mk.Name = "SpreadMarker"
                        mk.Size = UDim2.fromScale(0.52, 0.52)
                        mk.AnchorPoint = Vector2.new(1, 0)
                        mk.Position = UDim2.fromScale(1.08, -0.08) -- top-right nub on the badge
                        mk.BackgroundTransparency = 1
                        mk.Image = spreadDisc
                        mk.ScaleType = Enum.ScaleType.Fit
                        mk.ZIndex = 108
                        mk.Parent = holder
                        local mkAspect = Instance.new("UIAspectRatioConstraint")
                        mkAspect.AspectRatio = 1
                        mkAspect.Parent = mk
                    end
                end
            end
            -- Fallback: the original coloured text chip (Tank / Melee / ...).
            if not built then
                local tint = role.color and Color3.fromRGB(role.color.r, role.color.g, role.color.b)
                    or Color3.fromRGB(70, 70, 90)
                local chip = Instance.new("TextLabel")
                chip.Name = "RoleChip"
                chip.Size = UDim2.new(
                    0,
                    math.max(28, math.floor(self.cardSize.X * 0.5)),
                    0,
                    math.max(10, math.floor(self.cardSize.Y * 0.16))
                )
                chip.Position = UDim2.new(0, 3, 0, 3)
                chip.BackgroundColor3 = tint
                chip.BackgroundTransparency = 0.15
                chip.Text = " " .. tostring(role.label) .. " "
                chip.TextColor3 = Color3.fromRGB(255, 255, 255)
                chip.TextScaled = true
                chip.Font = Enum.Font.GothamBold
                chip.ZIndex = 104
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 4)
                corner.Parent = chip
                chip.Parent = itemFrame
            end
        end
    end

    -- Support buff this pet PROVIDES (bottom-right): the per-zone buffer pets (bunny=Heal,
    -- penguin=Defense, emberimp=Offense, meerkat=Coin Yield) emit a team aura — surface it so
    -- "what does a meerkat do?" reads at a glance. Element-disc (biome colour) + short label.
    if POWER_ICONS and PET_ROLES and item.category == "Pets" and item.petType then
        -- entry may be a single aura or a LIST (creator pets carry every buffer); fan the
        -- badges across the corner and label "ALL" when there are several.
        local entry = PET_ROLES.support_auras and PET_ROLES.support_auras[item.petType]
        local auras = nil
        if type(entry) == "table" then
            auras = entry.kind and { entry } or entry
        end
        local shown = 0
        for _, aura in ipairs(auras or {}) do
            local meta = SUPPORT_META[aura.kind]
            local symbol = POWER_ICONS.support_symbol and POWER_ICONS.support_symbol[aura.kind]
            local disc = meta and symbol and POWER_ICONS.discFor(meta.element, symbol)
            if disc then
                local holder = Instance.new("Frame")
                holder.Name = "SupportBadge" .. (shown > 0 and tostring(shown + 1) or "")
                holder.Size = UDim2.new(0.4, 0, 0.4, 0) -- square (aspect), ~40% of card
                -- first badge in the lower-right corner; extras fan LEFT at half-overlap
                holder.Position =
                    UDim2.new(0.66, -shown * math.floor(self.cardSize.X * 0.14), 0.5, 0)
                holder.BackgroundTransparency = 1
                holder.ZIndex = 107 + (#auras - shown) -- earlier badges sit in front
                holder.Parent = itemFrame
                local aspect = Instance.new("UIAspectRatioConstraint")
                aspect.AspectRatio = 1
                aspect.AspectType = Enum.AspectType.FitWithinMaxSize
                aspect.Parent = holder
                local img = Instance.new("ImageLabel")
                img.Name = "Icon"
                img.Size = UDim2.fromScale(1, 1)
                img.BackgroundTransparency = 1
                img.Image = disc
                img.ScaleType = Enum.ScaleType.Fit
                img.ZIndex = holder.ZIndex
                img.Parent = holder
                -- TARGETING RING (POWER targeting SSOT): the ring frames the disc with the aura's
                -- SCOPE — single-target (empower/hold → inward ring) vs team (offense/yield → aura
                -- ring) — derived from PetTargeting.auraScope, not hand-set. Disc shrinks to sit
                -- inside; ring tints to the aura's element (bright).
                local auraScope = PetTargeting.auraScope(aura, PET_ROLES)
                local ringShape = POWER_ICONS.targeting_ring
                    and POWER_ICONS.targeting_ring[auraScope]
                local ringImg = ringShape and POWER_ICONS.rings and POWER_ICONS.rings[ringShape]
                if ringImg then
                    img.AnchorPoint = Vector2.new(0.5, 0.5)
                    img.Position = UDim2.fromScale(0.5, 0.5)
                    img.Size = UDim2.fromScale(0.78, 0.78)
                    local ring = Instance.new("ImageLabel")
                    ring.Name = "Ring"
                    ring.AnchorPoint = Vector2.new(0.5, 0.5)
                    ring.Position = UDim2.fromScale(0.5, 0.5)
                    ring.Size = UDim2.fromScale(1, 1)
                    ring.BackgroundTransparency = 1
                    ring.Image = ringImg
                    ring.ScaleType = Enum.ScaleType.Fit
                    ring.ImageColor3 = POWER_ICONS.elementColor3
                            and POWER_ICONS.elementColor3(meta.element, "bright")
                        or Color3.fromRGB(245, 120, 90)
                    ring.ZIndex = holder.ZIndex + 1
                    ring.Parent = holder
                end
                shown += 1
            end
        end
        if shown > 0 then
            local first = SUPPORT_META[auras[1].kind]
            local lbl = Instance.new("TextLabel")
            lbl.Name = "SupportLabel"
            lbl.Size = UDim2.new(1, -4, 0, math.max(8, math.floor(self.cardSize.Y * 0.15)))
            lbl.Position = UDim2.new(0, 2, 1, -math.max(8, math.floor(self.cardSize.Y * 0.15)))
            lbl.BackgroundTransparency = 1
            local second = shown == 2 and SUPPORT_META[auras[2].kind]
            lbl.Text = (shown > 2 and "ALL")
                or (shown == 2 and ((first and first.label or "?") .. "+" .. (second and second.label or "?")))
                or (first and first.label or "")
            lbl.TextColor3 = Color3.fromRGB(255, 230, 140)
            lbl.TextStrokeTransparency = 0.3
            lbl.TextScaled = true
            lbl.Font = Enum.Font.GothamBold
            lbl.TextXAlignment = Enum.TextXAlignment.Right
            lbl.ZIndex = 107
            lbl.Parent = itemFrame
        end
    end

    -- ENCHANT badges (lower-LEFT — Jason: per-copy IDENTITY, vs auras lower-right =
    -- species role): white disc carries the effect symbol, ring metal carries
    -- strength 1-5 (copper/bronze/silver/gold/onyx). Extras fan RIGHT, mirroring
    -- the aura pile. Same PetBadge alphabet as every other badge surface.
    -- Storage v2: an enchant-keyed STACK shows its one effect as a badge at the flat
    -- "Mythic Strength" (resolved from config at render — never stored on the stack).
    if
        PetBadge
        and item.category == "Pets"
        and item.enchant
        and type(item.enchantments) ~= "table"
    then
        local stackStrength = (
            ENCHANTS_CONFIG
            and ENCHANTS_CONFIG.stack_enchants
            and tonumber(ENCHANTS_CONFIG.stack_enchants.strength)
        ) or 1
        item.enchantments = { { id = item.enchant, strength = stackStrength } }
    end
    if PetBadge and item.category == "Pets" and type(item.enchantments) == "table" then
        local shownEnch = 0
        for _, enchant in ipairs(item.enchantments) do
            if enchant.id and shownEnch < 3 then
                local holder = PetBadge.createEnchantBadge(itemFrame, {
                    enchantId = enchant.id,
                    strength = enchant.strength,
                    size = UDim2.new(0.4, 0, 0.4, 0),
                    position = UDim2.new(
                        -0.06,
                        shownEnch * math.floor(self.cardSize.X * 0.14),
                        0.5,
                        0
                    ),
                    zindex = 107 + shownEnch,
                })
                local aspect = Instance.new("UIAspectRatioConstraint")
                aspect.AspectRatio = 1
                aspect.AspectType = Enum.AspectType.FitWithinMaxSize
                aspect.Parent = holder
                shownEnch += 1
            end
        end
    end

    -- Add interaction system (includes hover effects)
    -- DEBUG SPAM SUPPRESSED
    self:_addItemInteractions(itemFrame, item)
    -- DEBUG SPAM SUPPRESSED

    -- Apply equipped styling if item is equipped
    local isEquipped = self:_isItemEquipped(item)
    self:_applyEquippedStyling(itemFrame, isEquipped, item.color)

    -- #179 down-lockout identity (read by _refreshLockoutVisuals for the availability ring / red
    -- count). Equipped = lives in the equipped grid. Stacks MUST key by the model's 2-field
    -- LockoutKey (<petType:variant>) — the live pets and the replicated pool both use it — NOT the
    -- 3-field storage stack key (<id:variant:enchant>), which matches neither. Build the key from
    -- the item's own petType/variant so the ring reads the pet's CombatDowned/CooldownUntil truth
    -- instead of guessing at string formats.
    do
        local isStackCard = (type(item.id) == "string" and item.id:sub(1, 6) == "stack|")
            or (type(item.uid) == "string" and item.uid:sub(1, 6) == "stack|")
        if isStackCard then
            local key
            if item.petType then
                key = tostring(item.petType) .. ":" .. tostring(item.variant or "basic")
            else
                -- no petType on the item (shouldn't happen): first two fields of the stack key
                local raw = (type(item.uid) == "string" and item.uid:sub(1, 6) == "stack|")
                        and (string.split(item.uid, "|"))[2]
                    or item.uid
                    or ""
                local f = string.split(tostring(raw), ":")
                key = tostring(f[1] or "") .. ":" .. tostring(f[2] or "")
            end
            itemFrame:SetAttribute("LockKind", "stack")
            itemFrame:SetAttribute("LockId", key)
        elseif type(item.uid) == "string" and item.uid ~= "" then
            itemFrame:SetAttribute("LockKind", "special")
            itemFrame:SetAttribute("LockId", item.uid)
        end
        itemFrame:SetAttribute("LockEquipped", itemFrame.Parent == self.equippedGrid)
    end
    -- Store reference
    table.insert(self.itemFrames, itemFrame)
    -- Index by stack key for live count updates
    if item.id:sub(1, 6) == "stack|" then
        self._stackFrames = self._stackFrames or {}
        self._stackDataByKey = self._stackDataByKey or {}
        local key = item.uid or item.id:sub(7)
        self._stackFrames[key] = itemFrame
        self._stackDataByKey[key] = item
    end
end

function InventoryPanel:_selectCategory(categoryName)
    self.selectedCategory = categoryName

    -- Update category tabs visual state
    local categoryContainer = self.frame:FindFirstChild("CategoryContainer")
    if categoryContainer then
        for _, tab in ipairs(categoryContainer:GetChildren()) do
            if tab:IsA("TextButton") then
                -- exact match (tabs are named "<category>Tab") — substring :find was fragile
                local isSelected = (tab.Name == categoryName .. "Tab")
                tab.BackgroundColor3 = isSelected and Color3.fromRGB(52, 152, 219)
                    or Color3.fromRGB(40, 40, 50)
            end
        end
    end

    -- Update items display
    self:_updateItemsDisplay()

    -- Show the Sell/Salvage entry button only on the Enhancements category.
    self:_updateEnhancementSellButton()

    -- Re-scope the live bucket listeners to the newly-selected category's folders
    self:_setupBucketListeners()
end

-- The "💎 Sell / Salvage" entry button is visible ONLY while the Enhancements category
-- is selected; clicking it opens the dedicated EnhancementSellPanel.
function InventoryPanel:_updateEnhancementSellButton()
    if self._enhancementSellButton then
        self._enhancementSellButton.Visible = (self.selectedCategory == "Enhancements")
    end
end

function InventoryPanel:_addButtonHoverEffect(button, originalColor)
    button.MouseEnter:Connect(function()
        local tween = TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundColor3 = Color3.new(
                math.min(1, originalColor.R + 0.1),
                math.min(1, originalColor.G + 0.1),
                math.min(1, originalColor.B + 0.1)
            ),
        })
        tween:Play()
    end)

    button.MouseLeave:Connect(function()
        local tween = TweenService:Create(
            button,
            TweenInfo.new(0.15, Enum.EasingStyle.Quad),
            { BackgroundColor3 = originalColor }
        )
        tween:Play()
    end)
end

function InventoryPanel:_addItemHoverEffect(itemFrame)
    local originalSize = itemFrame.Size
    local stroke = itemFrame:FindFirstChild("UIStroke")

    itemFrame.MouseEnter:Connect(function()
        local sizeTween =
            TweenService:Create(itemFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                Size = UDim2.new(
                    originalSize.X.Scale,
                    originalSize.X.Offset + 5,
                    originalSize.Y.Scale,
                    originalSize.Y.Offset + 5
                ),
            })
        sizeTween:Play()

        if stroke then
            local strokeTween = TweenService:Create(
                stroke,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad),
                { Transparency = 0, Thickness = 3 }
            )
            strokeTween:Play()
        end
    end)

    itemFrame.MouseLeave:Connect(function()
        local sizeTween = TweenService:Create(
            itemFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad),
            { Size = originalSize }
        )
        sizeTween:Play()

        if stroke then
            local strokeTween = TweenService:Create(
                stroke,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad),
                { Transparency = 0.3, Thickness = 2 }
            )
            strokeTween:Play()
        end
    end)
end

function InventoryPanel:_animateEntrance()
    -- Start slightly off-screen and transparent
    self.frame.Position = UDim2.new(0.5, 0, 0.5, 50)
    self.frame.BackgroundTransparency = 1

    -- Animate to final position
    local tween = TweenService:Create(
        self.frame,
        TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {
            Position = UDim2.new(0.5, 0, 0.5, 0),
            BackgroundTransparency = 0,
        }
    )
    tween:Play()
end

-- Public interface methods
function InventoryPanel:IsVisible()
    return self.isVisible
end

function InventoryPanel:GetFrame()
    return self.frame
end

function InventoryPanel:UpdateInventory(newData)
    if newData then
        self.inventoryData = newData
        if self.isVisible then
            self:_updateItemsDisplay()
        end
    end
end

-- 🔄 REAL-TIME INVENTORY UPDATES
function InventoryPanel:RefreshFromRealData()
    if self.isVisible then
        self:_loadRealInventoryData()
        self:_refreshCategoryTabs() -- Update category counts too
        self:_updateItemsDisplay()
        self.logger:info("Inventory refreshed from real data")
    end
end

function InventoryPanel:_formatNumber(value)
    local numberValue = tonumber(value)
    if not numberValue then
        return "-"
    end
    if math.abs(numberValue - math.floor(numberValue)) < 0.001 then
        return tostring(math.floor(numberValue))
    end
    return string.format("%.1f", numberValue)
end

function InventoryPanel:_hideItemTooltip()
    if self._tooltipHoverGuard then
        self._tooltipHoverGuard:Disconnect()
        self._tooltipHoverGuard = nil
    end
    -- SINGLE-INSTANCE INVARIANT: sweep EVERY ItemTooltip under the panel, not just the tracked
    -- self.itemTooltip ref. Multiple re-entrant paths build a tooltip — the two per-card hover
    -- handlers (leftClickDetection + itemFrame MouseEnter) AND the async "Hatched By" re-render
    -- (task.spawn'd, huge/special-only) — and the single ref only remembers the LAST frame, so an
    -- earlier one gets orphaned with no hide ever destroying it. That was the "huge card sticks,
    -- only ever a Huge" bug (huge/special pets are the only ones with hatcher_user_id → the only
    -- ones that hit the async re-entry). Sweeping the whole class makes a leaked second frame
    -- impossible. See the matching sweep in _renderItemTooltip.
    self.itemTooltip = nil
    if self.frame then
        for _, child in ipairs(self.frame:GetChildren()) do
            if child.Name == "ItemTooltip" then
                child:Destroy()
            end
        end
    end
    self._tooltipItem = nil -- stop any pending hatcher-name re-render from firing
    self._tooltipSourceFrame = nil
end

function InventoryPanel:_formatTooltipFieldLabel(fieldName)
    local labels = self._petTooltipFieldsConfig and self._petTooltipFieldsConfig.labels
    if type(labels) == "table" and labels[fieldName] then
        return tostring(labels[fieldName])
    end

    local words = {}
    for word in tostring(fieldName):gmatch("[^_]+") do
        table.insert(words, word:sub(1, 1):upper() .. word:sub(2))
    end
    return table.concat(words, " ")
end

function InventoryPanel:_formatTooltipFieldValue(value)
    if type(value) == "boolean" then
        return value and "Yes" or "No"
    end
    if type(value) == "number" then
        return self:_formatNumber(value)
    end
    return tostring(value)
end

function InventoryPanel:_readNumberValue(folder, names)
    if not folder then
        return nil
    end
    for _, name in ipairs(names) do
        local value = folder:FindFirstChild(name)
        if value and (value:IsA("NumberValue") or value:IsA("IntValue")) then
            return tonumber(value.Value)
        end
    end
    return nil
end

function InventoryPanel:_readStringValue(folder, names)
    if not folder then
        return nil
    end
    for _, name in ipairs(names) do
        local value = folder:FindFirstChild(name)
        if value and value:IsA("StringValue") then
            return value.Value
        end
    end
    return nil
end

function InventoryPanel:_readBoolValue(folder, names)
    if not folder then
        return nil
    end
    for _, name in ipairs(names) do
        local value = folder:FindFirstChild(name)
        if value and value:IsA("BoolValue") then
            return value.Value
        end
    end
    return nil
end

function InventoryPanel:_readPrimitiveValues(folder)
    local values = {}
    if not folder then
        return values
    end
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("StringValue") or child:IsA("BoolValue") then
            values[child.Name] = child.Value
        elseif child:IsA("NumberValue") or child:IsA("IntValue") then
            values[child.Name] = tonumber(child.Value)
        end
    end
    return values
end

function InventoryPanel:_countFolderChildren(folder, names)
    if not folder then
        return 0
    end
    for _, name in ipairs(names) do
        local child = folder:FindFirstChild(name)
        if child and child:IsA("Folder") then
            return #child:GetChildren()
        end
    end
    return 0
end

function InventoryPanel:_readEnchantSummaries(folder)
    local summaries = {}
    if not folder then
        return summaries
    end

    local enchantFolder = folder:FindFirstChild("enchantments")
        or folder:FindFirstChild("Enchantments")
    if not enchantFolder or not enchantFolder:IsA("Folder") then
        return summaries
    end

    local children = enchantFolder:GetChildren()
    table.sort(children, function(a, b)
        return tostring(a.Name) < tostring(b.Name)
    end)
    for _, child in ipairs(children) do
        if child:IsA("Folder") then
            local id = self:_readStringValue(child, { "id", "Id" })
            local displayName = self:_readStringValue(child, { "display_name", "DisplayName" })
                or id
                or child.Name
            local strength =
                self:_readNumberValue(child, { "strength", "Strength", "value", "Value" })
            local profile = self:_readStringValue(child, { "roll_profile", "RollProfile" })
            table.insert(summaries, {
                id = id,
                displayName = displayName,
                strength = strength,
                profile = profile,
            })
        end
    end

    return summaries
end

function InventoryPanel:_getReplicatedSpecialPetFolder(uid)
    if type(uid) ~= "string" or uid == "" or not self.player then
        return nil
    end

    local inventoryFolder = self.player:FindFirstChild("Inventory")
    local petsFolder = inventoryFolder and inventoryFolder:FindFirstChild("pets")
    local specialFolder = petsFolder and petsFolder:FindFirstChild("Special")
    return specialFolder and specialFolder:FindFirstChild(uid) or nil
end

function InventoryPanel:_getConfiguredPetPower(petType, variant, level, isHuge)
    local okPets, petsConfig = pcall(function()
        return ConfigLoader:LoadConfig("pets")
    end)
    if not okPets or not petsConfig or not petsConfig.getPet then
        return nil
    end

    local pdata = petsConfig.getPet(petType, variant)
    -- Shared source of truth (huge-aware): huge pets use huge_base_power.
    local base = PetPower.configuredBasePower(pdata, isHuge == true)
    if base <= 0 then
        return nil
    end

    local progressionConfig = select(
        2,
        pcall(function()
            return ConfigLoader:LoadConfig("pet_progression")
        end)
    )
    return PetPower.withLevel(base, level, progressionConfig)
end

function InventoryPanel:_refreshPetTooltipFromReplicatedState(item)
    if not item or item.category ~= "Pets" or not item.special or type(item.uid) ~= "string" then
        return item
    end

    local petFolder = self:_getReplicatedSpecialPetFolder(item.uid)
    if not petFolder then
        return item
    end

    local level = self:_readNumberValue(petFolder, { "level", "Level" }) or item.level or 1
    local exp = self:_readNumberValue(petFolder, { "exp", "Exp", "xp", "XP" }) or item.exp or 0
    local maxLevel = self:_readNumberValue(petFolder, { "max_level", "MaxLevel" }) or item.maxLevel
    local xpToNext = self:_readNumberValue(
        petFolder,
        { "xp_to_next_level", "XpToNextLevel", "XPToNextLevel" }
    ) or item.xpToNextLevel

    item.level = math.max(1, math.floor(tonumber(level) or 1))
    item.exp = math.max(0, math.floor(tonumber(exp) or 0))
    item.maxLevel = maxLevel and math.max(1, math.floor(tonumber(maxLevel) or 1)) or nil
    item.xpToNextLevel = xpToNext and math.max(0, math.floor(tonumber(xpToNext) or 0)) or nil
    item.unlockedEnchantSlots = self:_readNumberValue(
        petFolder,
        { "unlocked_enchant_slots", "UnlockedEnchantSlots" }
    ) or item.unlockedEnchantSlots
    item.maxEnchantments = self:_readNumberValue(
        petFolder,
        { "max_enchantments", "MaxEnchantments", "MaxEnchants" }
    ) or item.maxEnchantments
    item.enchantmentCount = self:_countFolderChildren(petFolder, { "enchantments", "Enchantments" })
    item.enchantments = self:_readEnchantSummaries(petFolder)
    item.locked = self:_readBoolValue(petFolder, { "locked", "Locked" })

    local tooltipFields = self:_readPrimitiveValues(petFolder)
    local hatcherName = self:_readStringValue(petFolder, { "hatcher_name", "HatcherName" })
        or self:_readStringValue(petFolder, { "source", "Source" })
    if hatcherName then
        tooltipFields.hatcher_name = hatcherName
    end
    item.tooltipFields = tooltipFields

    local isHuge = self:_readBoolValue(petFolder, { "huge", "Huge" }) == true or item.huge == true
    local basePower = self:_getConfiguredPetPower(item.petType, item.variant, 1, isHuge)
    local leveledPower = self:_getConfiguredPetPower(item.petType, item.variant, item.level, isHuge)
    if basePower then
        item.basePower = basePower
    end
    if leveledPower then
        item.power = leveledPower
        item.effectivePower = math.max(tonumber(item.effectivePower) or 0, leveledPower)
    end

    return item
end

function InventoryPanel:_appendConfiguredTooltipFields(lines, item)
    local fields = item and item.tooltipFields
    if type(fields) ~= "table" then
        return
    end

    local config = self._petTooltipFieldsConfig or {}
    local hidden = {}
    for _, fieldName in ipairs(config.hidden or {}) do
        hidden[fieldName] = true
    end
    for _, fieldName in ipairs({
        "level",
        "Level",
        "exp",
        "Exp",
        "xp",
        "XP",
        "max_level",
        "MaxLevel",
        "xp_to_next_level",
        "XpToNextLevel",
        "XPToNextLevel",
    }) do
        hidden[fieldName] = true
    end

    local appended = {}
    local function appendField(fieldName)
        if appended[fieldName] or hidden[fieldName] then
            return
        end
        local value = fields[fieldName]
        if value == nil or value == "" or type(value) == "table" then
            return
        end

        appended[fieldName] = true
        table.insert(lines, {
            label = self:_formatTooltipFieldLabel(fieldName),
            value = self:_formatTooltipFieldValue(value),
        })
    end

    for _, fieldName in ipairs(config.order or {}) do
        appendField(fieldName)
    end

    local fieldNames = {}
    for fieldName in pairs(fields) do
        table.insert(fieldNames, fieldName)
    end
    table.sort(fieldNames)

    for _, fieldName in ipairs(fieldNames) do
        appendField(fieldName)
    end
end

function InventoryPanel:_showItemTooltip(item, sourceFrame)
    if not self.frame or not item then
        return
    end

    self:_hideItemTooltip()
    if sourceFrame then
        self._tooltipSourceFrame = sourceFrame -- the hovered card; popup flips to its opposite side
    end
    item = self:_refreshPetTooltipFromReplicatedState(item)
    self._tooltipItem = item -- tracked so an async hatcher-name resolve can re-render this same card

    -- Enhancements get their OWN tooltip — the pet fields (Type/Variant/Power/Enchants)
    -- are meaningless for them (Jason: "it's not distinguishing... we need to give
    -- different information").
    if item.folder_source == "eggs" then
        local lines = {}
        for i, line in ipairs(self:_eggOddsLines(item.egg_def)) do
            lines[#lines + 1] = { label = i == 1 and "Hatches" or "", value = line }
        end
        lines[#lines + 1] = { label = "Action", value = "Click to hatch · tradeable" }
        item.tooltip_title = tostring(item.name or "Egg")
        self:_renderItemTooltip(item, lines)
        return
    end

    if item.folder_source == "enhancements" then
        local okCfg, enhCfg = pcall(function()
            return require(ReplicatedStorage.Configs:WaitForChild("enhancements"))
        end)
        local values = (okCfg and enhCfg and enhCfg.values) or {}
        local single = item.rarity == "Single"
        local natural = item.rarity == "Natural"
        local value = (natural and values.natural) or (single and values.single) or values.dual
        local originNames = {}
        for _, o in ipairs(item.origins or {}) do
            originNames[#originNames + 1] = o:sub(1, 1):upper() .. o:sub(2)
        end
        local lines = {
            {
                label = "Boosts",
                value = tostring(item.enhancement_type or "?"):gsub("^%l", string.upper),
            },
            { label = "Level", value = tostring(item.level or "?") },
            {
                label = "Grade",
                value = (item.rarity or "?")
                    .. (value and (" (+" .. math.floor(value * 100 + 0.5) .. "%)") or ""),
            },
            {
                label = single and "Origin" or "Origins",
                value = #originNames > 0 and table.concat(originNames, " + ")
                    or (natural and "None — generic" or "Unknown"),
            },
            {
                label = "Usable by",
                value = #originNames > 0 and table.concat(originNames, " or ")
                    or (natural and "Anyone" or "—"),
            },
            { label = "Slot via", value = "Level-up menu → ENHANCE" },
        }
        item.tooltip_title = (#originNames > 0 and (item.origins_label .. " ") or "")
            .. tostring(item.name or "Enhancement")
        self:_renderItemTooltip(item, lines)
        return
    end

    local lines = {
        { label = "Rarity", value = item.rarity or "-" },
        { label = "Type", value = item.petType or "-" },
        { label = "Variant", value = item.variant or "-" },
        { label = "Power", value = self:_formatNumber(item.effectivePower or item.power) },
    }

    -- Consistent identity baseline for EVERY pet (Jason: thin cards need Role + Element + the two
    -- stats). All derived client-side from the same sources the card uses — single source of truth.
    if item.category == "Pets" and item.petType then
        if PetPowerView then
            local okRole, role = pcall(function()
                return PetPowerView.roleInfo(item.petType, item.role)
            end)
            if okRole and role and role.label then
                table.insert(lines, { label = "Role", value = role.label })
            end
        end
        if PetBadge then
            local elem = item.creator and "creator" or PetBadge.biomeElementForPetType(item.petType)
            if elem and elem ~= "" then
                table.insert(
                    lines,
                    { label = "Element", value = (tostring(elem):gsub("^%l", string.upper)) }
                )
            end
        end
        -- Damage (⚔ zone-calculated attack) + Endurance (❤ toughness) — the two stats the card shows.
        -- Use item.effectivePower FIRST: for eternal pets (huge/secret/exclusive) the eternal pin is
        -- the pet's real power, but _refreshPetTooltipFromReplicatedState overwrites item.power with
        -- the raw config-leveled power (e.g. a huge hare's base 16). Reading effectivePower keeps the
        -- tooltip's ⚔/❤ equal to the card's (which uses the pinned power). Non-eternal pets set
        -- effectivePower == power, so nothing changes for them.
        local basePower = item.effectivePower or item.power or item.basePower
        if PetPowerView and basePower then
            local profile = resolvePetProfile(basePower, item.petType, item.variant, item.creator)
            if profile then
                table.insert(lines, {
                    label = "Damage",
                    value = "⚔ "
                        .. self:_formatNumber(
                            PetPowerView.displayRound(profile.combatEffective or 0)
                        ),
                })
                local okEhp, ehp = pcall(function()
                    return PetPowerView.survivability(basePower, item.petType, item.role)
                end)
                if okEhp and ehp then
                    table.insert(lines, {
                        label = "Endurance",
                        value = "❤ " .. self:_formatNumber(PetPowerView.displayRound(ehp)),
                    })
                end
            end
        end
    end

    if item.basePower and item.effectivePower and item.basePower ~= item.effectivePower then
        table.insert(lines, { label = "Base", value = self:_formatNumber(item.basePower) })
    end
    if item.special and item.maxLevel and item.maxLevel > 1 then
        table.insert(lines, {
            label = "Level",
            value = tostring(item.level or 1) .. "/" .. tostring(item.maxLevel),
        })
        local xpToNext = tonumber(item.xpToNextLevel) or 0
        if xpToNext > 0 then
            table.insert(lines, {
                label = "XP",
                value = self:_formatNumber(item.exp or 0) .. "/" .. self:_formatNumber(xpToNext),
            })
        else
            table.insert(lines, { label = "XP", value = "Max" })
        end
    end
    if tonumber(item.eternalPercent) and tonumber(item.eternalPercent) > 0 then
        table.insert(lines, {
            label = "Eternal",
            value = self:_formatNumber(item.eternalPercent) .. "% of top-team average",
        })
    end
    if item.eternalBaselinePower then
        table.insert(lines, {
            label = "Baseline",
            value = self:_formatNumber(item.eternalBaselinePower),
        })
    end
    if item.huge then
        table.insert(lines, {
            label = "Huge",
            value = item.serial and ("#" .. tostring(item.serial)) or "Yes",
        })
    elseif item.serial then
        table.insert(lines, { label = "Serial", value = "#" .. tostring(item.serial) })
    end
    if item.enchantable then
        local maxEnchantments = tonumber(item.maxEnchantments) or 0
        local unlockedEnchantSlots = tonumber(item.unlockedEnchantSlots) or maxEnchantments
        local enchantmentCount = tonumber(item.enchantmentCount) or 0
        local value = tostring(enchantmentCount)
        if unlockedEnchantSlots > 0 then
            value = value .. "/" .. tostring(unlockedEnchantSlots)
            if maxEnchantments > unlockedEnchantSlots then
                value = value .. " (max " .. tostring(maxEnchantments) .. ")"
            end
        elseif maxEnchantments > 0 then
            value = value .. "/0 (max " .. tostring(maxEnchantments) .. ")"
        end
        table.insert(lines, { label = "Enchants", value = value })
        for index, enchant in ipairs(item.enchantments or {}) do
            -- readable identity line (Jason: players can't price a trade on opaque
            -- integers): "Coin Finder · Silver (+4.5%)" — metal from display.ring_tiers,
            -- percent from the effect's amount_per_strength
            local strength = tonumber(enchant.strength)
            local value = tostring(enchant.displayName or enchant.id or "-")
            local enchCfg = ENCHANTS_CONFIG
            if strength and enchCfg then
                local tiers = enchCfg.display and enchCfg.display.ring_tiers
                local tier = tiers and tiers[math.clamp(strength, 1, #tiers)]
                if tier and tier.name then
                    value = value .. " · " .. tier.name
                end
                local effect = enchCfg.effects and enchant.id and enchCfg.effects[enchant.id]
                local per = effect
                    and effect.modifier
                    and tonumber(effect.modifier.amount_per_strength)
                if per then
                    value = value .. (" (+%.1f%%)"):format(strength * per * 100)
                else
                    value = value .. " +" .. self:_formatNumber(strength)
                end
            elseif strength then
                value = value .. " +" .. self:_formatNumber(strength)
            end
            table.insert(lines, { label = "Enchant " .. tostring(index), value = value })
        end
    elseif item.enchantmentCount and item.enchantmentCount > 0 then
        table.insert(lines, { label = "Enchants", value = tostring(item.enchantmentCount) })
    else
        table.insert(lines, { label = "Enchants", value = "None" })
    end
    if item.category == "Pets" and item.petType then
        -- Zone ALWAYS shows now (Jason: it blinked in/out before) — Neutral when no resonance.
        local mult = zoneResonanceFor(item.petType)
        local zoneVal
        if mult > 1.001 then
            zoneVal = ("Strong here (+%d%%)"):format((mult - 1) * 100 + 0.5)
        elseif mult < 0.999 then
            zoneVal = ("Weak here (-%d%%)"):format((1 - mult) * 100 + 0.5)
        else
            zoneVal = "Neutral here"
        end
        table.insert(lines, { label = "Zone", value = zoneVal })

        -- Support pets: surface the team aura they provide (Jason). Reuse SUPPORT_META labels +
        -- a readable magnitude; fall back to the capitalized kind for combat debuffs not in the map.
        local aura = PET_ROLES and PET_ROLES.support_auras and PET_ROLES.support_auras[item.petType]
        if aura and aura.kind then
            local meta = SUPPORT_META[aura.kind]
            local label = (meta and meta.label) or (tostring(aura.kind):gsub("^%l", string.upper))
            local mag = ""
            if aura.mult then
                mag = (" +%d%%"):format((aura.mult - 1) * 100 + 0.5)
            elseif aura.amount then
                mag = (" +%d"):format(aura.amount + 0.5)
            elseif aura.fraction then
                mag = (" %d%%/%ds"):format(aura.fraction * 100 + 0.5, aura.interval or 2)
            elseif aura.duration then
                mag = (" %ds"):format(aura.duration)
            end
            table.insert(lines, { label = "Aura", value = label .. mag })
        end
    end
    if item.locked ~= nil then
        table.insert(lines, { label = "Locked", value = item.locked and "Yes" or "No" })
    end
    if item.serialSource and item.serialSource ~= "" then
        table.insert(lines, { label = "Serial Source", value = tostring(item.serialSource) })
    end
    -- Hatched By: resolve the stable UserId -> the CURRENT username (Jason: keep the id since
    -- players rename, but show a name). Falls back to the name-at-hatch, then "Player <id>".
    local tf = item.tooltipFields
    if type(tf) == "table" then
        local rawName = tf.hatcher_name
        local uid = tonumber(tf.hatcher_user_id)
        if not uid and type(rawName) == "string" and rawName:match("^%d+$") then
            uid = tonumber(rawName) -- legacy: an id ended up in the name field
        end
        if uid then
            local resolved = _hatcherNameCache[uid]
            local display = (type(resolved) == "string" and resolved)
                or (type(rawName) == "string" and not rawName:match("^%d+$") and rawName)
                or ("Player " .. tostring(uid))
            table.insert(lines, { label = "Hatched By", value = display })
            tf.hatcher_name = nil -- claimed; keep the configured path from re-adding it
            if type(resolved) ~= "string" then
                requestHatcherName(uid, function()
                    if self._tooltipItem == item then
                        -- re-render once the username resolves (keep the same side via the source)
                        self:_showItemTooltip(item, self._tooltipSourceFrame)
                    end
                end)
            end
        end
    end
    self:_appendConfiguredTooltipFields(lines, item)
    if item.count and item.count > 1 then
        table.insert(lines, { label = "Owned", value = tostring(item.count) })
    end

    self:_renderItemTooltip(item, lines)
end

-- Shared tooltip frame renderer (pet + enhancement paths both feed it their lines).
function InventoryPanel:_renderItemTooltip(item, lines)
    -- SINGLE-INSTANCE INVARIANT (see _hideItemTooltip): destroy any stray ItemTooltip before
    -- building the new one, so a re-entrant caller (the async "Hatched By" re-render, or the two
    -- per-card hover handlers firing together) can never leave two frames stacked. This is what
    -- fixed the "huge pet card sticks open" bug.
    if self.frame then
        for _, child in ipairs(self.frame:GetChildren()) do
            if child.Name == "ItemTooltip" then
                child:Destroy()
            end
        end
    end
    self.itemTooltip = nil

    local tooltip = Instance.new("Frame")
    tooltip.Name = "ItemTooltip"
    local tooltipHeight = 52 + (#lines * 22)
    tooltip.Size = UDim2.new(0, 250, 0, tooltipHeight)
    -- Flip to the OPPOSITE side of the hovered card so the popup never covers it (Jason): card on
    -- the right half -> popup on the LEFT, card on the left -> popup on the RIGHT. Y tracks the card,
    -- clamped inside the panel. Falls back to the old top-right anchor if the source is unknown.
    local src = self._tooltipSourceFrame
    if src and src.Parent and self.frame then
        local cardCenterX = src.AbsolutePosition.X + src.AbsoluteSize.X * 0.5
        local panelMidX = self.frame.AbsolutePosition.X + self.frame.AbsoluteSize.X * 0.5
        local relY = src.AbsolutePosition.Y - self.frame.AbsolutePosition.Y
        local posY = math.clamp(relY, 8, math.max(8, self.frame.AbsoluteSize.Y - tooltipHeight - 8))
        tooltip.Position = (cardCenterX > panelMidX) and UDim2.new(0, 16, 0, posY)
            or UDim2.new(1, -270, 0, posY)
    else
        tooltip.Position = UDim2.new(1, -270, 0, 72)
    end
    tooltip.BackgroundColor3 = Color3.fromRGB(24, 25, 32)
    tooltip.BorderSizePixel = 0
    tooltip.ZIndex = 300
    tooltip.Parent = self.frame
    self.itemTooltip = tooltip

    -- Hover guard: MouseLeave is unreliable when a child element swallows the hover — a HUGE pet's
    -- card is a full-size 3D ViewportFrame, so leaving it never fires the card's MouseLeave and the
    -- popup sticks (Jason: "still sticks, and only ever a Huge"). Card-destroyed-under-cursor has the
    -- same effect. Rather than chase the quirk, poll while the tooltip is up: if the source card is
    -- gone or no longer actually under the cursor, hide. Only runs while a tooltip is shown.
    if self._tooltipHoverGuard then
        self._tooltipHoverGuard:Disconnect()
        self._tooltipHoverGuard = nil
    end
    -- Every card is a static baked image now (no live ViewportFrame to swallow the hover), so the
    -- card's native MouseEnter/MouseLeave drive show/hide — same as every non-huge card already does.
    -- The only case native hover misses is a card destroyed under the cursor during a re-render (no
    -- MouseLeave fires), so hide on that one event. No per-frame polling, no mouse-position math.
    if self._tooltipHoverGuard then
        self._tooltipHoverGuard:Disconnect()
        self._tooltipHoverGuard = nil
    end
    if self._tooltipSourceFrame then
        self._tooltipHoverGuard = self._tooltipSourceFrame.Destroying:Connect(function()
            self:_hideItemTooltip()
        end)
    end

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = tooltip

    local stroke = Instance.new("UIStroke")
    stroke.Color = item.color or Color3.fromRGB(120, 130, 150)
    stroke.Thickness = 2
    stroke.Transparency = 0.15
    stroke.Parent = tooltip

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -20, 0, 28)
    title.Position = UDim2.new(0, 10, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = item.tooltip_title or item.name or "Pet"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.ZIndex = 301
    title.Parent = tooltip

    for index, line in ipairs(lines) do
        local row = Instance.new("TextLabel")
        row.Name = "Line" .. tostring(index)
        row.Size = UDim2.new(1, -20, 0, 20)
        row.Position = UDim2.new(0, 10, 0, 34 + ((index - 1) * 22))
        row.BackgroundTransparency = 1
        row.Text = tostring(line.label) .. ": " .. tostring(line.value)
        row.TextColor3 = Color3.fromRGB(215, 220, 230)
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.TextScaled = true
        row.Font = Enum.Font.Gotham
        row.ZIndex = 301
        row.Parent = tooltip
    end
end

-- 🖱️ ITEM INTERACTION SYSTEM
function InventoryPanel:_addItemInteractions(itemFrame, item)
    -- DEBUG SPAM SUPPRESSED
    self.logger:info("🔧 ADDING INTERACTIONS", {
        itemId = item.id,
        itemName = item.name,
        hasSignals = self.signals ~= nil,
    })

    -- Left-click: Primary action (consume/equip)
    local leftClickDetection = Instance.new("TextButton")
    leftClickDetection.Size = UDim2.new(1, 0, 1, 0)
    leftClickDetection.BackgroundTransparency = 1
    leftClickDetection.Text = ""
    leftClickDetection.ZIndex = 105
    leftClickDetection.Parent = itemFrame

    leftClickDetection.Activated:Connect(function()
        -- DEBUG SPAM SUPPRESSED
        -- Delete mode hijacks the primary action: a click toggles selection instead
        -- of equipping/consuming/hatching (uniques refuse + flash a "protected" tell).
        if self._deleteMode then
            self:_toggleDeleteSelection(item, itemFrame)
            return
        end
        -- Deploy is draft-based: a pet click only edits the working draft (no live equip). A click on a
        -- draft slot (in the equipped grid) removes one; a click in the inventory grid adds one.
        -- Non-pets (eggs etc.) keep their normal primary action. Activate commits the draft. (task #240)
        if item.folder_source == "pets" then
            self:_toggleDraftMember(item, itemFrame.Parent == self.equippedGrid)
            return
        end
        self:_handlePrimaryAction(item)
    end)

    -- Re-paint the selection highlight after a re-render: folder replication rebuilds
    -- the cards while delete mode is still armed, so the new frame must reclaim its
    -- highlight + refresh the stored frame ref (keyed by bucket+uid).
    if self._deleteMode and self._deleteSelection then
        local key = self:_deleteSelectionKey(item)
        local entry = self._deleteSelection[key]
        if entry then
            self._deleteSelectedFrames = self._deleteSelectedFrames or {}
            self._deleteSelectedFrames[key] = itemFrame
            self:_applyDeleteHighlight(itemFrame, true, entry.quantity)
        end
    end

    -- Right-click: Context menu (using UserInputService with frame detection)
    local isMouseOverFrame = false

    leftClickDetection.MouseEnter:Connect(function()
        isMouseOverFrame = true
        self:_showItemTooltip(item, itemFrame)
    end)

    leftClickDetection.MouseLeave:Connect(function()
        isMouseOverFrame = false
        self:_hideItemTooltip()
    end)

    -- Global right-click detection (but only act if over this frame)
    local userInputService = game:GetService("UserInputService")

    local AssetFetch = require(ReplicatedStorage.Shared.Utils.AssetFetch)
    local rightClickConnection = userInputService.InputBegan:Connect(function(input, gameProcessed)
        -- print("🔍 RIGHT CLICK INPUT:", input.UserInputType, "gameProcessed:", gameProcessed, "isMouseOver:", isMouseOverFrame, "for item:", item.id)

        -- For right-clicks, we ignore gameProcessed because we want to handle custom context menus
        -- For left-clicks, we still respect gameProcessed to avoid conflicts with normal UI
        if input.UserInputType ~= Enum.UserInputType.MouseButton2 then
            return -- Only handle right-clicks in this listener
        end

        -- right-click debug removed (noisy)
        -- self.isVisible guard: closing the panel UNDER the cursor (the hatch-confirm
        -- flow does exactly this) leaves isMouseOverFrame stuck true with this UIS
        -- connection alive — every steering right-click then spawned orphan menus.
        if isMouseOverFrame and self.isVisible and itemFrame.Parent then
            print("🖱️ RIGHT CLICK DETECTED ON:", item.id)
            local mouse = Players.LocalPlayer:GetMouse()
            self.logger:info(
                "🖱️ RIGHT CLICK ON ITEM",
                { itemId = item.id, x = mouse.X, y = mouse.Y }
            )
            self:_showAdvancedContextMenu(item, mouse.X, mouse.Y)
        else
            -- skip noisy spam
        end
    end)

    -- Store connection for cleanup (prevent memory leaks)
    if not self._rightClickConnections then
        self._rightClickConnections = {}
    end
    self._rightClickConnections[item.id] = rightClickConnection

    -- DEBUG SPAM SUPPRESSED

    -- CONSOLIDATED: Enhanced hover effects for visual feedback
    local originalSize = itemFrame.Size
    local stroke = itemFrame:FindFirstChild("UIStroke")
    -- DEBUG SPAM SUPPRESSED

    -- UPDATED MouseEnter to include BOTH tracking AND hover effects
    itemFrame.MouseEnter:Connect(function()
        isMouseOverFrame = true
        self:_showItemTooltip(item, itemFrame)
        -- DEBUG SPAM SUPPRESSED

        -- Background color change
        local bgTween = TweenService:Create(
            itemFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad),
            { BackgroundColor3 = Color3.fromRGB(55, 55, 65) }
        )
        bgTween:Play()

        -- Size increase
        local sizeTween =
            TweenService:Create(itemFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                Size = UDim2.new(
                    originalSize.X.Scale,
                    originalSize.X.Offset + 5,
                    originalSize.Y.Scale,
                    originalSize.Y.Offset + 5
                ),
            })
        sizeTween:Play()

        -- Stroke enhancement
        if stroke then
            local strokeTween = TweenService:Create(
                stroke,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad),
                { Transparency = 0, Thickness = 3 }
            )
            strokeTween:Play()
        end
    end)

    -- UPDATED MouseLeave to include BOTH tracking AND hover effects
    itemFrame.MouseLeave:Connect(function()
        isMouseOverFrame = false
        self:_hideItemTooltip()
        -- DEBUG SPAM SUPPRESSED

        -- Background color reset
        local bgTween = TweenService:Create(
            itemFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad),
            { BackgroundColor3 = Color3.fromRGB(45, 45, 55) }
        )
        bgTween:Play()

        -- Size reset
        local sizeTween = TweenService:Create(
            itemFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad),
            { Size = originalSize }
        )
        sizeTween:Play()

        -- Stroke reset
        if stroke then
            local strokeTween = TweenService:Create(
                stroke,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad),
                { Transparency = 0.3, Thickness = 2 }
            )
            strokeTween:Play()
        end
    end)
end

-- Click egg -> the inventory CLOSES and a standalone confirm menu appears (Jason:
-- "you click the egg, it closes the window, brings up the separate hatch menu; yes ->
-- menu goes away, run the animation and hatch"). Own ScreenGui because the panel is gone.
function InventoryPanel:_showHatchConfirmation(item)
    self:Hide()

    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local old = playerGui:FindFirstChild("HatchConfirm")
    if old then
        old:Destroy()
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "HatchConfirm"
    gui.DisplayOrder = 150
    gui.IgnoreGuiInset = true
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 340, 0, 230)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 215, 0) -- creator gold (it's an exclusive egg)
    stroke.Thickness = 2
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 32)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "Hatch " .. tostring(item.name or "this egg") .. "?"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 19
    title.Font = Enum.Font.GothamBold
    title.ZIndex = 2
    title.Parent = frame

    -- the egg art, so it reads as THIS egg
    if item.image then
        local img = Instance.new("ImageLabel")
        img.Size = UDim2.new(0, 64, 0, 64)
        img.Position = UDim2.new(0, 14, 0, 50)
        img.BackgroundTransparency = 1
        img.ScaleType = Enum.ScaleType.Fit
        img.Image = item.image
        img.ZIndex = 2
        img.Parent = frame
    end

    local message = Instance.new("TextLabel")
    message.Size = UDim2.new(1, -98, 0, 110)
    message.Position = UDim2.new(0, 88, 0, 46)
    message.BackgroundTransparency = 1
    message.Text = table.concat(self:_eggOddsLines(item.egg_def), "\n")
    message.TextColor3 = Color3.fromRGB(200, 200, 200)
    message.TextSize = 14
    message.Font = Enum.Font.Gotham
    message.TextWrapped = true
    message.TextXAlignment = Enum.TextXAlignment.Left
    message.TextYAlignment = Enum.TextYAlignment.Top
    message.ZIndex = 2
    message.Parent = frame

    local buttons = Instance.new("Frame")
    buttons.Size = UDim2.new(1, -20, 0, 38)
    buttons.Position = UDim2.new(0, 10, 1, -48)
    buttons.BackgroundTransparency = 1
    buttons.ZIndex = 2
    buttons.Parent = frame
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.Padding = UDim.new(0, 10)
    layout.Parent = buttons

    local function mkButton(text, color, order)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 110, 1, 0)
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextSize = 16
        b.Font = Enum.Font.GothamBold
        b.LayoutOrder = order
        b.ZIndex = 3
        b.Parent = buttons
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = b
        return b
    end
    local noBtn = mkButton("No", Color3.fromRGB(70, 70, 80), 1)
    local yesBtn = mkButton("HATCH", Color3.fromRGB(46, 160, 67), 2)

    noBtn.Activated:Connect(function()
        gui:Destroy()
    end)
    yesBtn.Activated:Connect(function()
        gui:Destroy()
        self:_hatchEggItem(item)
    end)
end

-- Bus hatch + the SAME reveal animation world eggs use (one presentation path).
function InventoryPanel:_hatchEggItem(item)
    task.spawn(function()
        local remote = ReplicatedStorage:WaitForChild("GameAPICommand", 5)
        if not remote then
            return
        end
        local okInvoke, res = pcall(function()
            return remote:InvokeServer("egg_item.hatch", { egg = item.id })
        end)
        local r = okInvoke and type(res) == "table" and (res.result or res) or {}
        self.logger:info("🥚 HATCH", { egg = item.id, ok = r.ok, pet = r.pet, huge = r.huge })
        if r.ok ~= true then
            return
        end
        local okAnim, hatchingService = pcall(function()
            return require(ReplicatedStorage.Shared.Services.EggHatchingService)
        end)
        if not (okAnim and hatchingService) then
            return
        end
        -- generated viewport image when one exists for this pet/variant, else the flag
        -- falls through to the animation's own fallbacks
        local petImageId = "generated_image"
        local petsConfig = nil
        pcall(function()
            petsConfig = require(ReplicatedStorage.Configs:WaitForChild("pets"))
        end)
        local pdata = petsConfig and petsConfig.getPet and petsConfig.getPet(r.pet, r.variant)
        hatchingService:StartHatchingAnimation({
            {
                petType = r.pet,
                variant = r.variant,
                power = pdata and pdata.power,
                eggType = item.id,
                imageId = item.image, -- the real uploaded egg art
                petImageId = petImageId,
                rarityId = r.huge and "huge" or (pdata and pdata.rarity_id),
                specialHatch = r.huge == true,
            },
        })
    end)
end

-- 🗑 DELETE MODE — toggle + multi-select + bulk confirm.
-- Mirrors InventoryService:_isDeletionDenied so the UI never offers a delete the
-- server would refuse: per-uid uniques (special pets) and protected classes
-- (huge/creator/exclusive/secret) are NOT deletable; everything else is a stack.
function InventoryPanel:_isItemDeletable(item)
    if not item then
        return false
    end
    -- per-uid unique records live one-folder-per-uid (id "special|<uid>") — never a stack
    if type(item.id) == "string" and item.id:sub(1, 8) == "special|" then
        return false
    end
    if item.special == true or item.huge == true or item.creator == true then
        return false
    end
    local rarity = item.rarityId
    if rarity and DELETE_DENIED_RARITIES[rarity] then
        return false
    end
    return true
end

-- Stable per-card selection key (a card's uid is unique within its bucket).
function InventoryPanel:_deleteSelectionKey(item)
    return tostring(item.folder_source or "?") .. "::" .. tostring(item.uid or item.id)
end

-- Red border + count badge on a selected card (removed on deselect). The badge reads
-- "×N" = how many of the stack are marked (the picker's chosen amount). Named children
-- so re-render / deselect can find and clear them without disturbing the rarity chrome.
function InventoryPanel:_applyDeleteHighlight(itemFrame, on, quantity)
    if not itemFrame then
        return
    end
    local existing = itemFrame:FindFirstChild("DeleteSelectStroke")
    local badge = itemFrame:FindFirstChild("DeleteSelectBadge")
    if on then
        if not existing then
            local s = Instance.new("UIStroke")
            s.Name = "DeleteSelectStroke"
            s.Color = DELETE_RED
            s.Thickness = 3
            s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            s.Parent = itemFrame
        end
        if not badge then
            badge = Instance.new("TextLabel")
            badge.Name = "DeleteSelectBadge"
            badge.Size = UDim2.new(0, 30, 0, 22)
            badge.AnchorPoint = Vector2.new(1, 0)
            badge.Position = UDim2.new(1, -4, 0, 4)
            badge.BackgroundColor3 = DELETE_RED
            badge.TextColor3 = Color3.fromRGB(255, 255, 255)
            badge.TextScaled = true
            badge.Font = Enum.Font.GothamBold
            badge.ZIndex = 130
            local bc = Instance.new("UICorner")
            bc.CornerRadius = UDim.new(0, 8)
            bc.Parent = badge
            local bcon = Instance.new("UITextSizeConstraint")
            bcon.MaxTextSize = 14
            bcon.Parent = badge
            badge.Parent = itemFrame
        end
        badge.Text = quantity and ("×%d"):format(quantity) or "✓"
    else
        if existing then
            existing:Destroy()
        end
        if badge then
            badge:Destroy()
        end
    end
end

-- "Give the user a tell, don't silently ignore" (Jason): a brief 🔒 Protected tag
-- when they click a unique in delete mode.
function InventoryPanel:_flashUndeletable(itemFrame)
    if not itemFrame or not itemFrame.Parent or itemFrame:FindFirstChild("UndeletableTell") then
        return
    end
    local tag = Instance.new("TextLabel")
    tag.Name = "UndeletableTell"
    tag.Size = UDim2.new(1, -6, 0, 16)
    tag.AnchorPoint = Vector2.new(0.5, 1)
    tag.Position = UDim2.new(0.5, 0, 1, -4)
    tag.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    tag.BackgroundTransparency = 0.15
    tag.Text = "🔒 Protected"
    tag.TextColor3 = Color3.fromRGB(255, 175, 95)
    tag.TextScaled = true
    tag.Font = Enum.Font.GothamBold
    tag.ZIndex = 131
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = tag
    local con = Instance.new("UITextSizeConstraint")
    con.MaxTextSize = 12
    con.Parent = tag
    tag.Parent = itemFrame
    task.delay(0.9, function()
        if tag and tag.Parent then
            tag:Destroy()
        end
    end)
end

-- The header pill reflects armed/idle: muted when off, red "Cancel" when on (the
-- floating action button is the actual delete trigger).
function InventoryPanel:_restyleDeletePill()
    local b = self._deletePill
    if not b then
        return
    end
    if self._deleteMode then
        b.BackgroundColor3 = DELETE_RED
        b.Text = "🗑 Cancel"
    else
        b.BackgroundColor3 = DELETE_PILL_IDLE
        b.Text = "🗑 Delete"
    end
    pillify(b) -- re-tint the capsule (armed red ↔ idle) in place
end

-- Recount selection -> drives the floating button's label + enabled state + visibility.
-- The button names total UNITS to be destroyed (sum of per-stack picks), since that's
-- the number the player actually cares about; the confirm dialog adds the stack count.
function InventoryPanel:_updateDeleteActionButton()
    local stacks, units = 0, 0
    if self._deleteSelection then
        for _, entry in pairs(self._deleteSelection) do
            stacks += 1
            units += (entry.quantity or 0)
        end
    end
    self._deleteSelectionCount = stacks
    self._deleteUnitCount = units
    local btn = self._deleteActionButton
    if not btn then
        return
    end
    btn.Visible = self._deleteMode == true
    btn.Text = ("🗑 Delete (%d)"):format(units)
    if stacks > 0 then
        btn.BackgroundColor3 = DELETE_RED
        btn.AutoButtonColor = true
        btn.TextTransparency = 0
    else
        btn.BackgroundColor3 = DELETE_PILL_IDLE
        btn.AutoButtonColor = false
        btn.TextTransparency = 0.35
    end
end

-- Drop every highlight + reset the selection maps.
function InventoryPanel:_clearDeleteSelection()
    if self._deleteSelectedFrames then
        for _, frame in pairs(self._deleteSelectedFrames) do
            if frame and frame.Parent then
                self:_applyDeleteHighlight(frame, false)
            end
        end
    end
    self._deleteSelection = {}
    self._deleteSelectedFrames = {}
    self:_updateDeleteActionButton()
end

-- Arm / disarm delete mode. Disarming always clears the current selection.
function InventoryPanel:_setDeleteMode(on)
    on = on and true or false
    if self._deleteMode == on then
        return
    end
    self._deleteMode = on
    if not on then
        self:_clearDeleteSelection()
    end
    self:_restyleDeletePill()
    self:_updateDeleteActionButton()
end

-- Low-level: set or clear one stack's selection entry ({ item, quantity }) + repaint.
function InventoryPanel:_setDeleteSelection(key, entry, itemFrame)
    self._deleteSelection = self._deleteSelection or {}
    self._deleteSelectedFrames = self._deleteSelectedFrames or {}
    if entry then
        self._deleteSelection[key] = entry
        self._deleteSelectedFrames[key] = itemFrame
        self:_applyDeleteHighlight(itemFrame, true, entry.quantity)
    else
        self._deleteSelection[key] = nil
        self._deleteSelectedFrames[key] = nil
        self:_applyDeleteHighlight(itemFrame, false)
    end
    self:_updateDeleteActionButton()
end

-- The starting amount on the delete slider: configurable (configs/inventory.lua
-- ui.delete_picker_default = "min" | "max"), defaulting to "min" (1) so a misclick
-- can't pre-arm deleting the whole stack. Cached after first read.
function InventoryPanel:_deletePickerDefault(total)
    if self._deletePickerMode == nil then
        local mode = "min"
        pcall(function()
            local cfg = require(ReplicatedStorage.Configs:WaitForChild("inventory"))
            if cfg and cfg.ui and cfg.ui.delete_picker_default then
                mode = cfg.ui.delete_picker_default
            end
        end)
        self._deletePickerMode = mode
    end
    return self._deletePickerMode == "max" and total or 1
end

-- The shared amount-picker popover for "how many of THIS stack to delete". The
-- starting amount comes from config (see _deletePickerDefault). count==1 stacks skip it.
function InventoryPanel:_promptDeleteQuantity(item, itemFrame, default)
    local total = math.max(1, math.floor(tonumber(item.count) or 1))
    local key = self:_deleteSelectionKey(item)
    QuantitySelector.prompt({
        parent = self.frame,
        title = "Delete how many?",
        subtitle = (item.name or "Stack") .. ("  •  have %d"):format(total),
        iconText = type(item.icon) == "string" and #item.icon <= 6 and item.icon or "🗑",
        accent = DELETE_RED,
        min = 1,
        max = total,
        default = default or self:_deletePickerDefault(total),
        confirmText = "Select",
        onConfirm = function(amount)
            self:_setDeleteSelection(key, { item = item, quantity = amount }, itemFrame)
        end,
    })
end

-- A card click in delete mode. Deletable stacks only (uniques flash a tell). A stack
-- with >1 opens the amount picker; a single-unit stack toggles directly. Re-tapping a
-- selected stack re-opens the picker to adjust (or toggles off for single-unit stacks).
function InventoryPanel:_toggleDeleteSelection(item, itemFrame)
    self._deleteSelection = self._deleteSelection or {}
    self._deleteSelectedFrames = self._deleteSelectedFrames or {}
    if not self:_isItemDeletable(item) then
        self:_flashUndeletable(itemFrame)
        return
    end
    local key = self:_deleteSelectionKey(item)
    local total = math.max(1, math.floor(tonumber(item.count) or 1))
    local existing = self._deleteSelection[key]
    if total <= 1 then
        -- single-unit stack: plain toggle, no picker needed
        self:_setDeleteSelection(key, existing and nil or { item = item, quantity = 1 }, itemFrame)
        return
    end
    -- multi-unit: pick the amount. Re-editing pre-fills the current pick; a fresh
    -- selection passes nil so _promptDeleteQuantity uses the configured starting amount.
    self:_promptDeleteQuantity(item, itemFrame, existing and existing.quantity or nil)
end

-- "Give the user every chance to not do it" (Jason): the bulk confirm. Cancel is the
-- default/left button; Delete is the red commit. Reuses the delete-confirm visual
-- vocabulary (red stroke, gotham, corner) from _showDeleteConfirmation.
function InventoryPanel:_showBulkDeleteConfirmation()
    local entries = {}
    local stacks, units = 0, 0
    if self._deleteSelection then
        for _, entry in pairs(self._deleteSelection) do
            entries[#entries + 1] = entry
            stacks += 1
            units += (entry.quantity or 0)
        end
    end
    if stacks == 0 or units == 0 or not self.frame then
        return
    end

    local prior = self.frame:FindFirstChild("DeleteConfirmation")
    if prior then
        prior:Destroy()
    end

    local confirmFrame = Instance.new("Frame")
    confirmFrame.Name = "DeleteConfirmation"
    confirmFrame.Size = UDim2.new(0, 320, 0, 160)
    confirmFrame.Position = UDim2.new(0.5, -160, 0.5, -80)
    confirmFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    confirmFrame.BorderSizePixel = 0
    confirmFrame.ZIndex = 300
    confirmFrame.Parent = self.frame

    local confirmCorner = Instance.new("UICorner")
    confirmCorner.CornerRadius = UDim.new(0, 12)
    confirmCorner.Parent = confirmFrame

    local confirmStroke = Instance.new("UIStroke")
    confirmStroke.Color = DELETE_RED
    confirmStroke.Thickness = 2
    confirmStroke.Parent = confirmFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 0, 30)
    titleLabel.Position = UDim2.new(0, 10, 0, 12)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = ("Delete %d %s?"):format(units, units == 1 and "item" or "items")
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 18
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.ZIndex = 301
    titleLabel.Parent = confirmFrame

    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, -20, 0, 46)
    messageLabel.Position = UDim2.new(0, 10, 0, 48)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = ("This destroys %d %s across %d %s and cannot be undone."):format(
        units,
        units == 1 and "item" or "items",
        stacks,
        stacks == 1 and "stack" or "stacks"
    )
    messageLabel.TextColor3 = Color3.fromRGB(255, 180, 120)
    messageLabel.TextSize = 14
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.TextWrapped = true
    messageLabel.ZIndex = 301
    messageLabel.Parent = confirmFrame

    local buttonContainer = Instance.new("Frame")
    buttonContainer.Size = UDim2.new(1, -20, 0, 35)
    buttonContainer.Position = UDim2.new(0, 10, 1, -45)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.ZIndex = 301
    buttonContainer.Parent = confirmFrame

    local buttonLayout = Instance.new("UIListLayout")
    buttonLayout.FillDirection = Enum.FillDirection.Horizontal
    buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
    buttonLayout.Padding = UDim.new(0, 10)
    buttonLayout.Parent = buttonContainer

    -- Cancel is the default (left, neutral) — the easy way out.
    local cancelButton = Instance.new("TextButton")
    cancelButton.Size = UDim2.new(0, 100, 1, 0)
    cancelButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
    cancelButton.BorderSizePixel = 0
    cancelButton.Text = "Cancel"
    cancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    cancelButton.TextSize = 14
    cancelButton.Font = Enum.Font.GothamBold
    cancelButton.LayoutOrder = 1
    cancelButton.ZIndex = 302
    cancelButton.Parent = buttonContainer
    local cancelCorner = Instance.new("UICorner")
    cancelCorner.CornerRadius = UDim.new(0, 6)
    cancelCorner.Parent = cancelButton

    local deleteButton = Instance.new("TextButton")
    deleteButton.Size = UDim2.new(0, 100, 1, 0)
    deleteButton.BackgroundColor3 = DELETE_RED
    deleteButton.BorderSizePixel = 0
    deleteButton.Text = ("Delete %d"):format(units)
    deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    deleteButton.TextSize = 14
    deleteButton.Font = Enum.Font.GothamBold
    deleteButton.LayoutOrder = 2
    deleteButton.ZIndex = 302
    deleteButton.Parent = buttonContainer
    local deleteCorner = Instance.new("UICorner")
    deleteCorner.CornerRadius = UDim.new(0, 6)
    deleteCorner.Parent = deleteButton

    cancelButton.Activated:Connect(function()
        confirmFrame:Destroy()
    end)
    deleteButton.Activated:Connect(function()
        confirmFrame:Destroy()
        self:_performBulkDelete(entries)
    end)

    -- Entrance animation (same back-ease pop as the single-item confirm).
    confirmFrame.BackgroundTransparency = 1
    confirmFrame.Size = UDim2.new(0, 0, 0, 0)
    confirmFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    TweenService
        :Create(confirmFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0,
            Size = UDim2.new(0, 320, 0, 160),
            Position = UDim2.new(0.5, -160, 0.5, -80),
        })
        :Play()
end

-- Fire one DeleteInventoryItem per selected stack at its CHOSEN quantity (the picker's
-- amount, clamped to the stack count), then disarm (clears selection + highlights +
-- hides the button) and let folder replication refresh the grid (the egg/quantity
-- delete paths do the same nudge). entries = { { item = <card>, quantity = N }, ... }.
function InventoryPanel:_performBulkDelete(entries)
    if not self.signals or not self.signals.DeleteInventoryItem then
        self.logger:warn("❌ Signals not available for deletion")
        self:_setDeleteMode(false)
        return
    end
    local fired = 0
    for _, entry in ipairs(entries) do
        local item = entry.item
        -- re-check the gate (server is the backstop, but never even ask for a unique)
        if item and self:_isItemDeletable(item) then
            local itemUid = item.uid or item.uniqueId
            -- clamp the pick to the stack count (the picker already does, but defend it)
            local total = math.max(1, math.floor(tonumber(item.count) or 1))
            local qty = math.clamp(math.floor(tonumber(entry.quantity) or total), 1, total)
            if item.folder_source and itemUid then
                self.signals.DeleteInventoryItem:FireServer({
                    bucket = item.folder_source,
                    itemUid = itemUid,
                    itemId = item.id,
                    quantity = qty,
                    reason = "player_deleted",
                })
                fired += 1
            else
                self.logger:warn("❌ Skipped delete - missing source or UID", {
                    itemId = item.id,
                    hasSource = item.folder_source ~= nil,
                })
            end
        end
    end
    self.logger:info("🗑️ BULK DELETE", { requested = #entries, fired = fired })
    self:_setDeleteMode(false)
    task.wait(0.1)
    self:RefreshFromRealData()
end

function InventoryPanel:_showDeleteConfirmation(item)
    self.logger:info("🗑️ ITEM DELETE REQUESTED", { itemId = item.id, itemName = item.name })

    -- Create confirmation dialog
    local confirmFrame = Instance.new("Frame")
    confirmFrame.Name = "DeleteConfirmation"
    confirmFrame.Size = UDim2.new(0, 300, 0, 150)
    confirmFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
    confirmFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    confirmFrame.BorderSizePixel = 0
    confirmFrame.ZIndex = 200
    confirmFrame.Parent = self.frame

    local confirmCorner = Instance.new("UICorner")
    confirmCorner.CornerRadius = UDim.new(0, 12)
    confirmCorner.Parent = confirmFrame

    local confirmStroke = Instance.new("UIStroke")
    confirmStroke.Color = Color3.fromRGB(231, 76, 60)
    confirmStroke.Thickness = 2
    confirmStroke.Parent = confirmFrame

    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 0, 30)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Delete Item?"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 18
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.ZIndex = 201
    titleLabel.Parent = confirmFrame

    -- Message
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, -20, 0, 40)
    messageLabel.Position = UDim2.new(0, 10, 0, 45)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = "Are you sure you want to delete:\n" .. item.name .. "?"
    messageLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    messageLabel.TextSize = 14
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.ZIndex = 201
    messageLabel.TextWrapped = true
    messageLabel.Parent = confirmFrame

    -- Warning for valuable items
    if item.power and item.power > 10 then
        local warningLabel = Instance.new("TextLabel")
        warningLabel.Size = UDim2.new(1, -20, 0, 20)
        warningLabel.Position = UDim2.new(0, 10, 0, 85)
        warningLabel.BackgroundTransparency = 1
        warningLabel.Text = "⚠️ This item cannot be recovered!"
        warningLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
        warningLabel.TextSize = 12
        warningLabel.Font = Enum.Font.GothamBold
        warningLabel.ZIndex = 201
        warningLabel.Parent = confirmFrame
    end

    -- Buttons
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Size = UDim2.new(1, -20, 0, 35)
    buttonContainer.Position = UDim2.new(0, 10, 1, -45)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.ZIndex = 201
    buttonContainer.Parent = confirmFrame

    local buttonLayout = Instance.new("UIListLayout")
    buttonLayout.FillDirection = Enum.FillDirection.Horizontal
    buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
    buttonLayout.Padding = UDim.new(0, 10)
    buttonLayout.Parent = buttonContainer

    -- Cancel button
    local cancelButton = Instance.new("TextButton")
    cancelButton.Size = UDim2.new(0, 80, 1, 0)
    cancelButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
    cancelButton.BorderSizePixel = 0
    cancelButton.Text = "Cancel"
    cancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    cancelButton.TextSize = 14
    cancelButton.Font = Enum.Font.Gotham
    cancelButton.LayoutOrder = 1
    cancelButton.ZIndex = 202
    cancelButton.Parent = buttonContainer

    local cancelCorner = Instance.new("UICorner")
    cancelCorner.CornerRadius = UDim.new(0, 6)
    cancelCorner.Parent = cancelButton

    -- Delete button
    local deleteButton = Instance.new("TextButton")
    deleteButton.Size = UDim2.new(0, 80, 1, 0)
    deleteButton.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
    deleteButton.BorderSizePixel = 0
    deleteButton.Text = "Delete"
    deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    deleteButton.TextSize = 14
    deleteButton.Font = Enum.Font.GothamBold
    deleteButton.LayoutOrder = 2
    deleteButton.ZIndex = 202
    deleteButton.Parent = buttonContainer

    local deleteCorner = Instance.new("UICorner")
    deleteCorner.CornerRadius = UDim.new(0, 6)
    deleteCorner.Parent = deleteButton

    -- Button actions
    cancelButton.Activated:Connect(function()
        confirmFrame:Destroy()
    end)

    deleteButton.Activated:Connect(function()
        confirmFrame:Destroy()
        self:_deleteItem(item)
    end)

    -- Entrance animation
    confirmFrame.BackgroundTransparency = 1
    confirmFrame.Size = UDim2.new(0, 0, 0, 0)
    confirmFrame.Position = UDim2.new(0.5, 0, 0.5, 0)

    local tween = TweenService:Create(
        confirmFrame,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {
            BackgroundTransparency = 0,
            Size = UDim2.new(0, 300, 0, 150),
            Position = UDim2.new(0.5, -150, 0.5, -75),
        }
    )
    tween:Play()
end

-- 🎮 PRIMARY ACTIONS (Left-click)
function InventoryPanel:_handlePrimaryAction(item)
    -- DEBUG SPAM SUPPRESSED
    self.logger:info("🖱️ PRIMARY ACTION", {
        itemId = item.id,
        itemName = item.name,
        folder_source = item.folder_source,
        count = item.count,
    })

    if item.folder_source == "eggs" then
        -- explicit hatch (NEVER automatic — Jason): close the inventory, ask, and only
        -- then hatch — with the real reveal animation. Misclicks cost nothing.
        self:_showHatchConfirmation(item)
        return
    end

    if item.folder_source == "consumables" then
        -- Consume the item
        self:_consumeItem(item)
    elseif item.folder_source == "pets" then
        -- Equip/unequip pet
        self:_togglePetEquipped(item)
    elseif item.folder_source == "tools" then
        -- Equip/unequip tool
        self:_toggleToolEquipped(item)
    else
        -- Default: Show info
        self:_showItemInfo(item)
    end
end

function InventoryPanel:_consumeItem(item)
    self.logger:info("🍎 CONSUMING ITEM", { itemId = item.id, itemName = item.name })

    if self.signals then
        self.signals.ConsumeItem:FireServer({
            bucket = item.folder_source,
            itemUid = item.uid,
            itemId = item.id,
            quantity = 1,
        })
        self.logger:info("✅ Consume request sent to server")
    else
        self.logger:warn("❌ Signals not available for consumption")
    end
end

function InventoryPanel:_togglePetEquipped(item)
    self.logger:info("🐾 TOGGLING PET EQUIPPED", { itemId = item.id, itemName = item.name })

    if self.signals then
        local payload = { bucket = item.folder_source, itemId = item.id }
        local equippedUid = self:_getEquippedUidForPetItem(item)
        if equippedUid then
            payload.itemUid = equippedUid
        elseif typeof(item.id) == "string" and string.sub(item.id, 1, 6) == "stack|" then
            local stackKey = string.sub(item.id, 7)
            payload.itemUid = "stack|"
                .. stackKey
                .. "|"
                .. game:GetService("HttpService"):GenerateGUID(false)
            payload.isStackEquip = true
        elseif typeof(item.uid) == "string" and string.sub(item.uid, 1, 6) == "stack|" then
            -- Only generate a new instance if this is NOT a ghost equipped instance
            if
                not (
                    typeof(item.id) == "string"
                    and string.sub(item.id, 1, 18) == "equipped_instance|"
                )
            then
                local stackKey = string.sub(item.uid, 7)
                payload.itemUid = "stack|"
                    .. stackKey
                    .. "|"
                    .. game:GetService("HttpService"):GenerateGUID(false)
                payload.isStackEquip = true
            else
                payload.itemUid = item.uid -- toggle existing equipped instance
            end
        elseif typeof(item.uid) == "string" and string.find(item.uid, ":", 1, true) then
            -- Legacy stack key (id:variant)
            payload.itemUid = "stack|"
                .. item.uid
                .. "|"
                .. game:GetService("HttpService"):GenerateGUID(false)
            payload.isStackEquip = true
        elseif typeof(item.id) == "string" and string.find(item.id, ":", 1, true) then
            payload.itemUid = "stack|"
                .. item.id
                .. "|"
                .. game:GetService("HttpService"):GenerateGUID(false)
            payload.isStackEquip = true
        else
            -- Unique/special: use exact UID
            payload.itemUid = item.uid
        end
        self.signals.TogglePetEquipped:FireServer(payload)
        self.logger:info("✅ Toggle pet request sent to server")
    else
        self.logger:warn("❌ Signals not available for pet equipping")
    end
end

function InventoryPanel:_getPetStackKey(item)
    if typeof(item.uid) == "string" then
        if string.sub(item.uid, 1, 6) == "stack|" then
            return string.sub(item.uid, 7)
        end
        if string.find(item.uid, ":", 1, true) then
            return item.uid
        end
    end

    if typeof(item.id) == "string" then
        if string.sub(item.id, 1, 6) == "stack|" then
            return string.sub(item.id, 7)
        end
        if string.find(item.id, ":", 1, true) then
            return item.id
        end
    end

    return nil
end

function InventoryPanel:_getEquippedUidForPetItem(item)
    if not (self.equippedItems and self.equippedItems.pets) then
        return nil
    end

    if typeof(item.id) == "string" and string.sub(item.id, 1, 18) == "equipped_instance|" then
        return item.uid
    end

    if typeof(item.id) == "string" and string.sub(item.id, 1, 6) == "stack|" then
        return nil
    end

    local rawUid = item.uid
    if typeof(rawUid) == "string" then
        if string.sub(rawUid, 1, 6) == "stack|" then
            return nil
        end

        if self.equippedItems.pets[rawUid] then
            return rawUid
        end

        local specialUid = "special|" .. rawUid
        if self.equippedItems.pets[specialUid] then
            return specialUid
        end
    end

    return nil
end

function InventoryPanel:_toggleToolEquipped(item)
    self.logger:info("🔧 TOGGLING TOOL EQUIPPED", { itemId = item.id, itemName = item.name })

    if self.signals then
        self.signals.ToggleToolEquipped:FireServer({
            bucket = item.folder_source,
            itemUid = item.uid,
            itemId = item.id,
        })
        self.logger:info("✅ Toggle tool request sent to server")
    else
        self.logger:warn("❌ Signals not available for tool equipping")
    end
end

-- 🖱️ ADVANCED CONTEXT MENU (Right-click)
function InventoryPanel:_showAdvancedContextMenu(item, x, y)
    print("🖱️ SHOWING CONTEXT MENU FOR:", item.id, "at", x, y)
    self.logger:info("🖱️ ADVANCED CONTEXT MENU", { itemId = item.id, x = x, y = y })

    -- Calculate menu size based on available options
    local menuOptions = self:_getContextMenuOptions(item)
    local menuHeight = #menuOptions * 35 + 10

    -- Clamp menu position to screen bounds
    local screenSize = workspace.CurrentCamera.ViewportSize
    local clampedX = math.min(x, screenSize.X - 160) -- Leave 10px margin
    local clampedY = math.min(y, screenSize.Y - menuHeight - 10)
    clampedX = math.max(clampedX, 10) -- Minimum 10px from left edge
    clampedY = math.max(clampedY, 10) -- Minimum 10px from top edge

    print(
        "📍 CLAMPED POSITION: x="
            .. clampedX
            .. " y="
            .. clampedY
            .. " (screen: "
            .. screenSize.X
            .. "x"
            .. screenSize.Y
            .. ")"
    )

    -- Create ScreenGui container (required for visibility)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ContextMenuGui"
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = Players.LocalPlayer.PlayerGui

    -- Create context menu
    local contextMenu = Instance.new("Frame")
    contextMenu.Name = "AdvancedContextMenu"
    contextMenu.Size = UDim2.new(0, 150, 0, menuHeight)
    contextMenu.Position = UDim2.new(0, clampedX, 0, clampedY)
    contextMenu.BackgroundColor3 = Color3.fromRGB(255, 100, 100) -- BRIGHT RED for testing
    contextMenu.BackgroundTransparency = 0 -- Make it fully opaque
    contextMenu.BorderSizePixel = 2 -- Add visible border
    contextMenu.BorderColor3 = Color3.fromRGB(255, 255, 0) -- YELLOW border
    contextMenu.ZIndex = 1000 -- Much higher ZIndex
    -- Parent to ScreenGui (this makes it visible!)
    contextMenu.Parent = screenGui

    -- Debug: Print the exact path
    local fullPath = contextMenu:GetFullName()
    print("🔍 CONTEXT MENU FULL PATH:", fullPath)
    print("🔍 PLAYER GUI CHILDREN COUNT:", #Players.LocalPlayer.PlayerGui:GetChildren())

    local menuCorner = Instance.new("UICorner")
    menuCorner.CornerRadius = UDim.new(0, 8)
    menuCorner.Parent = contextMenu

    local menuStroke = Instance.new("UIStroke")
    menuStroke.Color = Color3.fromRGB(100, 100, 110)
    menuStroke.Thickness = 1
    menuStroke.Parent = contextMenu

    local menuLayout = Instance.new("UIListLayout")
    menuLayout.FillDirection = Enum.FillDirection.Vertical
    menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
    menuLayout.Padding = UDim.new(0, 2)
    menuLayout.Parent = contextMenu

    local menuPadding = Instance.new("UIPadding")
    menuPadding.PaddingTop = UDim.new(0, 5)
    menuPadding.PaddingBottom = UDim.new(0, 5)
    menuPadding.PaddingLeft = UDim.new(0, 5)
    menuPadding.PaddingRight = UDim.new(0, 5)
    menuPadding.Parent = contextMenu

    -- Create menu options
    print("📋 CREATING", #menuOptions, "MENU OPTIONS")
    for i, option in ipairs(menuOptions) do
        print("🔧 CREATING OPTION:", option.text, "action:", option.action)
        self:_createContextMenuOption(contextMenu, option, i, item)
    end

    local parentName = contextMenu.Parent and contextMenu.Parent.Name or "nil"
    print(
        "✅ CONTEXT MENU CREATED - Parent:",
        parentName,
        "Position:",
        contextMenu.Position,
        "Size:",
        contextMenu.Size
    )

    -- Auto-close functionality (pass ScreenGui to destroy the whole thing)
    self:_setupContextMenuAutoClose(screenGui)
end

function InventoryPanel:_getContextMenuOptions(item)
    local options = {}

    -- Get configuration for this item type
    local itemType = item.folder_source or "unknown"
    local config = self.contextMenuConfig

    if not config then
        -- Fallback if no config loaded
        return self:_getFallbackContextMenuOptions(item)
    end

    -- Get item type configuration
    local typeConfig = config.item_types[itemType] or config.fallback
    if not typeConfig or not typeConfig.actions then
        return self:_getFallbackContextMenuOptions(item)
    end

    print("🎯 USING CONFIG FOR ITEM TYPE:", itemType, "actions:", #typeConfig.actions)

    -- Process base actions for this item type
    for _, actionConfig in ipairs(typeConfig.actions) do
        self:_addConfiguredAction(options, actionConfig, item)
    end

    -- Add item-specific overrides if they exist
    if typeConfig.item_overrides and typeConfig.item_overrides[item.id] then
        local overrides = typeConfig.item_overrides[item.id]
        if overrides.additional_actions then
            print("🔧 ADDING ITEM-SPECIFIC ACTIONS FOR:", item.id)
            for _, actionConfig in ipairs(overrides.additional_actions) do
                self:_addConfiguredAction(options, actionConfig, item)
            end
        end
    end

    -- Sort by order
    table.sort(options, function(a, b)
        return (a.order or 999) < (b.order or 999)
    end)

    print("📋 FINAL OPTIONS COUNT:", #options)

    return options
end

function InventoryPanel:_addConfiguredAction(options, actionConfig, item)
    local itemCount = item.count or 1

    if actionConfig.enabled == false then
        return
    end
    if
        actionConfig.enabled_check
        and not self:_passesActionEnabledCheck(actionConfig.enabled_check, item)
    then
        return
    end

    -- Check if action should be enabled
    if actionConfig.min_count and itemCount < actionConfig.min_count then
        print(
            "❌ SKIPPING ACTION:",
            actionConfig.action,
            "- not enough items (need",
            actionConfig.min_count,
            "have",
            itemCount,
            ")"
        )
        return -- Skip if not enough items
    end

    -- Handle quantity-based actions (delete, consume, etc.)
    if actionConfig.quantities then
        print(
            "🔢 PROCESSING QUANTITY ACTION:",
            actionConfig.action,
            "with quantities:",
            table.concat(actionConfig.quantities, ", ")
        )
        for _, quantity in ipairs(actionConfig.quantities) do
            local actualQuantity = quantity
            if quantity == "all" then
                actualQuantity = itemCount
            elseif type(quantity) == "number" and quantity > itemCount then
                print("⏭️ SKIPPING QUANTITY:", quantity, "- not enough items")
                -- Skip if we don't have enough items
            else
                -- Get color for this quantity
                local color = actionConfig.color
                if actionConfig.quantity_colors and actionConfig.quantity_colors[quantity] then
                    color = actionConfig.quantity_colors[quantity]
                end

                -- Format text with quantity
                local text = actionConfig.text
                if quantity == "all" then
                    text = string.format(text:gsub("%%d", "All (%d)"), itemCount)
                else
                    text = string.format(text, quantity)
                end

                table.insert(options, {
                    text = text,
                    action = actionConfig.action,
                    quantity = actualQuantity,
                    color = Color3.fromRGB(color[1], color[2], color[3]),
                    order = actionConfig.order,
                    confirmation = actionConfig.confirmation,
                })
            end
        end
    else
        -- Single action (info, equip, etc.)
        print("➡️ ADDING SINGLE ACTION:", actionConfig.action, actionConfig.text)
        table.insert(options, {
            text = actionConfig.text,
            action = actionConfig.action,
            color = Color3.fromRGB(
                actionConfig.color[1],
                actionConfig.color[2],
                actionConfig.color[3]
            ),
            order = actionConfig.order,
            confirmation = actionConfig.confirmation,
        })
    end
end

function InventoryPanel:_passesActionEnabledCheck(checkName, item)
    if checkName == "can_enchant" then
        if item.folder_source ~= "pets" or item.enchantable ~= true then
            return false
        end
        if type(item.uid) ~= "string" or item.uid == "" then
            return false
        end
        return (tonumber(item.unlockedEnchantSlots) or tonumber(item.maxEnchantments) or 0) > 0
    end

    return true
end

function InventoryPanel:_getFallbackContextMenuOptions(item)
    -- Basic fallback when config fails to load
    print("🔄 USING FALLBACK OPTIONS FOR:", item.id)
    local options = {}
    local itemCount = item.count or 1

    table.insert(options, {
        text = "ℹ️ Info",
        action = "info",
        color = Color3.fromRGB(100, 150, 255),
        order = 1,
    })

    if itemCount > 1 then
        table.insert(options, {
            text = "🗑️ Delete 1",
            action = "delete",
            quantity = 1,
            color = Color3.fromRGB(255, 200, 100),
            order = 2,
        })
        table.insert(options, {
            text = "🗑️ Delete All (" .. itemCount .. ")",
            action = "delete",
            quantity = itemCount,
            color = Color3.fromRGB(230, 76, 60),
            order = 3,
        })
    else
        table.insert(options, {
            text = "🗑️ Delete",
            action = "delete",
            quantity = 1,
            color = Color3.fromRGB(230, 76, 60),
            order = 2,
        })
    end

    return options
end

function InventoryPanel:_createContextMenuOption(parent, option, layoutOrder, item)
    print("🔧 CREATING BUTTON:", option.text, "color:", option.color)
    local optionButton = Instance.new("TextButton")
    optionButton.Size = UDim2.new(1, 0, 0, 30)
    optionButton.BackgroundColor3 = option.color or Color3.fromRGB(60, 60, 70) -- Fallback color
    optionButton.BackgroundTransparency = 0.8
    optionButton.BorderSizePixel = 0
    optionButton.Text = option.text
    optionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    optionButton.TextSize = 12
    optionButton.Font = Enum.Font.Gotham
    optionButton.LayoutOrder = layoutOrder
    optionButton.ZIndex = 1001 -- Higher than context menu
    optionButton.Parent = parent

    local optionCorner = Instance.new("UICorner")
    optionCorner.CornerRadius = UDim.new(0, 4)
    optionCorner.Parent = optionButton

    -- Hover effect
    optionButton.MouseEnter:Connect(function()
        local tween = TweenService:Create(
            optionButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad),
            { BackgroundTransparency = 0.3 }
        )
        tween:Play()
    end)

    optionButton.MouseLeave:Connect(function()
        local tween = TweenService:Create(
            optionButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad),
            { BackgroundTransparency = 0.8 }
        )
        tween:Play()
    end)

    -- Action
    optionButton.Activated:Connect(function()
        print("🖱️ CONTEXT MENU OPTION CLICKED:", option.text)
        self.logger:info(
            "🖱️ CONTEXT MENU ACTION",
            { action = option.action, text = option.text, quantity = option.quantity }
        )

        -- Find and destroy the ScreenGui (parent of parent)
        local screenGui = parent.Parent
        if screenGui and screenGui:IsA("ScreenGui") then
            screenGui:Destroy()
        else
            parent:Destroy() -- Fallback
        end
        self:_executeContextMenuAction(option, item)
    end)

    -- Also add debug for mouse events on the button
    optionButton.MouseButton1Click:Connect(function()
        print("🔘 BUTTON MouseButton1Click DETECTED:", option.text)
    end)

    optionButton.MouseButton1Down:Connect(function()
        print("🔽 BUTTON MouseButton1Down DETECTED:", option.text)
    end)

    print("✅ BUTTON CREATED AND ADDED TO PARENT:", optionButton.Text, "Parent:", parent.Name)
end

function InventoryPanel:_executeContextMenuAction(option, item)
    print(
        "🎬 EXECUTING ACTION:",
        option.action,
        "quantity:",
        option.quantity,
        "for item:",
        item.id
    )

    if option.action == "info" then
        self:_showItemInfo(item)
    elseif option.action == "delete" then
        self:_deleteItemQuantity(item, option.quantity)
    elseif option.action == "consume" then
        self:_consumeItemQuantity(item, option.quantity)
    elseif option.action == "equip" then
        self:_toggleItemEquipped(item)
    elseif option.action == "rename" then
        self:_renameItem(item)
    elseif option.action == "sell" then
        self:_sellItem(item)
    elseif option.action == "upgrade" then
        self:_upgradeItem(item)
    elseif option.action == "hatch" then
        self:_hatchEgg(item, option.quantity or 1)
    elseif option.action == "hatch_multiple" then
        self:_hatchEgg(item, option.quantity)
    else
        self.logger:warn("❓ UNKNOWN ACTION", { action = option.action, itemId = item.id })
        print("❓ UNKNOWN ACTION:", option.action)
    end
end

-- 🍎 CONSUME ACTIONS
function InventoryPanel:_consumeItemQuantity(item, quantity)
    print("🍎 CONSUMING ITEM:", item.id, "quantity:", quantity)
    self.logger:info("🍎 CONSUME ITEM", {
        itemId = item.id,
        itemName = item.name,
        quantity = quantity,
        folder_source = item.folder_source,
    })

    if self.signals and self.signals.ConsumeItem then
        self.signals.ConsumeItem:FireServer({
            bucket = item.folder_source,
            itemUid = item.uid,
            itemId = item.id,
            quantity = quantity,
        })
        self.logger:info("✅ Consume request sent to server")
    else
        self.logger:warn("❌ Signals not available for consuming")
    end
end

-- 🐾 EQUIP ACTIONS
function InventoryPanel:_toggleItemEquipped(item)
    print("🐾 TOGGLING EQUIPPED:", item.id)
    if item.folder_source == "pets" then
        self:_togglePetEquipped(item)
    elseif item.folder_source == "tools" then
        self:_toggleToolEquipped(item)
    else
        self.logger:warn("❓ Cannot equip item type", { folder_source = item.folder_source })
    end
end

-- ✏️ RENAME ACTIONS
function InventoryPanel:_renameItem(item)
    print("✏️ RENAME ITEM:", item.id)
    -- TODO: Show text input dialog for renaming
    self.logger:info("✏️ RENAME REQUESTED", { itemId = item.id })
    print("🚧 RENAME NOT IMPLEMENTED YET")
end

-- 💰 SELL ACTIONS
function InventoryPanel:_sellItem(item)
    print("💰 SELL ITEM:", item.id)
    -- TODO: Implement selling to shop
    self.logger:info("💰 SELL REQUESTED", { itemId = item.id })
    print("🚧 SELL NOT IMPLEMENTED YET")
end

-- ⬆️ UPGRADE ACTIONS
function InventoryPanel:_upgradeItem(item)
    print("⬆️ UPGRADE ITEM:", item.id)
    -- TODO: Implement item upgrading
    self.logger:info("⬆️ UPGRADE REQUESTED", { itemId = item.id })
    print("🚧 UPGRADE NOT IMPLEMENTED YET")
end

-- 🥚 HATCH ACTIONS
function InventoryPanel:_hatchEgg(item, quantity)
    print("🥚 HATCH EGG:", item.id, "quantity:", quantity)
    -- TODO: Implement egg hatching from inventory
    self.logger:info("🥚 HATCH REQUESTED", { itemId = item.id, quantity = quantity })
    print("🚧 HATCH NOT IMPLEMENTED YET - Use egg interaction in world")
end

function InventoryPanel:_deleteItemQuantity(item, quantity)
    self.logger:info("🗑️ DELETING ITEM QUANTITY", {
        itemId = item.id,
        itemName = item.name,
        quantity = quantity,
        totalCount = item.count,
    })

    local itemUid = item.uid or item.uniqueId
    if item.folder_source and itemUid then
        if self.signals then
            self.signals.DeleteInventoryItem:FireServer({
                bucket = item.folder_source,
                itemUid = itemUid,
                itemId = item.id,
                quantity = quantity,
                reason = "player_deleted",
            })
            self.logger:info("✅ Delete quantity request sent to server")
        else
            self.logger:warn("❌ Signals not available for deletion")
        end
    else
        self.logger:warn("❌ Cannot delete item - missing source or UID")
    end

    -- Immediate UI feedback
    task.wait(0.1)
    self:RefreshFromRealData()
end

function InventoryPanel:_setupContextMenuAutoClose(contextMenu)
    -- SIMPLE SOLUTION: Just auto-close after 5 seconds, no click detection
    -- Let the button events handle themselves without interference
    task.spawn(function()
        task.wait(5)
        if contextMenu.Parent then
            print("🕒 AUTO-CLOSING CONTEXT MENU AFTER 5 SECONDS")
            contextMenu:Destroy()
        end
    end)
end

function InventoryPanel:_showItemContextMenu(item, x, y)
    self.logger:info("🖱️ ITEM CONTEXT MENU", { itemId = item.id, x = x, y = y })

    -- Create context menu
    local contextMenu = Instance.new("Frame")
    contextMenu.Name = "ItemContextMenu"
    contextMenu.Size = UDim2.new(0, 120, 0, 80)
    contextMenu.Position = UDim2.new(0, x, 0, y)
    contextMenu.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    contextMenu.BorderSizePixel = 0
    contextMenu.ZIndex = 150
    contextMenu.Parent = Players.LocalPlayer.PlayerGui

    local menuCorner = Instance.new("UICorner")
    menuCorner.CornerRadius = UDim.new(0, 6)
    menuCorner.Parent = contextMenu

    local menuStroke = Instance.new("UIStroke")
    menuStroke.Color = Color3.fromRGB(100, 100, 110)
    menuStroke.Thickness = 1
    menuStroke.Parent = contextMenu

    local menuLayout = Instance.new("UIListLayout")
    menuLayout.FillDirection = Enum.FillDirection.Vertical
    menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
    menuLayout.Parent = contextMenu

    -- Delete option
    local deleteOption = Instance.new("TextButton")
    deleteOption.Size = UDim2.new(1, 0, 0, 40)
    deleteOption.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
    deleteOption.BackgroundTransparency = 0.2
    deleteOption.BorderSizePixel = 0
    deleteOption.Text = "🗑️ Delete"
    deleteOption.TextColor3 = Color3.fromRGB(255, 255, 255)
    deleteOption.TextSize = 12
    deleteOption.Font = Enum.Font.Gotham
    deleteOption.LayoutOrder = 1
    deleteOption.ZIndex = 151
    deleteOption.Parent = contextMenu

    -- Info option
    local infoOption = Instance.new("TextButton")
    infoOption.Size = UDim2.new(1, 0, 0, 40)
    infoOption.BackgroundTransparency = 1
    infoOption.BorderSizePixel = 0
    infoOption.Text = "ℹ️ Info"
    infoOption.TextColor3 = Color3.fromRGB(255, 255, 255)
    infoOption.TextSize = 12
    infoOption.Font = Enum.Font.Gotham
    infoOption.LayoutOrder = 2
    infoOption.ZIndex = 151
    infoOption.Parent = contextMenu

    -- Actions
    deleteOption.Activated:Connect(function()
        contextMenu:Destroy()
        self:_showDeleteConfirmation(item)
    end)

    infoOption.Activated:Connect(function()
        contextMenu:Destroy()
        self:_showItemInfo(item)
    end)

    -- Auto-close after 3 seconds or on click outside
    local closeConnection
    local closeTimer = task.wait(3)

    closeConnection = game:GetService("UserInputService").InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            contextMenu:Destroy()
            closeConnection:Disconnect()
        end
    end)

    task.spawn(function()
        task.wait(3)
        if contextMenu.Parent then
            contextMenu:Destroy()
        end
        if closeConnection then
            closeConnection:Disconnect()
        end
    end)
end

function InventoryPanel:_deleteItem(item)
    self.logger:info("🗑️ DELETING ITEM", {
        itemId = item.id,
        itemName = item.name,
        folder_source = item.folder_source,
        uniqueId = item.uniqueId,
        uid = item.uid,
        hasSignals = self.signals ~= nil,
        signalsType = typeof(self.signals),
    })

    -- Debug: Check if DeleteInventoryItem signal exists
    if self.signals then
        self.logger:info("🔍 SIGNALS DEBUG", {
            hasDeleteSignal = self.signals.DeleteInventoryItem ~= nil,
            deleteSignalType = typeof(self.signals.DeleteInventoryItem),
            hasFireServerMethod = self.signals.DeleteInventoryItem
                and typeof(self.signals.DeleteInventoryItem.FireServer) == "function",
        })
    end

    -- Determine which network call to make based on source
    local itemUid = item.uid or item.uniqueId -- Check both field names
    if item.folder_source and itemUid then
        -- Real inventory item - call server to delete from ProfileStore
        if self.signals then
            self.signals.DeleteInventoryItem:FireServer({
                bucket = item.folder_source,
                itemUid = itemUid,
                itemId = item.id,
                reason = "player_deleted",
            })
            self.logger:info("✅ Delete request sent to server via Signals")
        else
            self.logger:warn("❌ Signals not available for deletion")
        end
    else
        self.logger:warn("❌ Cannot delete item - missing source or UID", {
            hasSource = item.folder_source ~= nil,
            hasUid = itemUid ~= nil,
            itemUid = itemUid,
            hasOldUid = item.uniqueId ~= nil,
            hasNewUid = item.uid ~= nil,
        })
    end

    -- Immediate UI feedback - remove from display
    task.wait(0.1)
    self:RefreshFromRealData()
end

function InventoryPanel:_showItemInfo(item)
    self.logger:info("ℹ️ SHOWING ITEM INFO", { itemId = item.id })
    -- This would show detailed item information
    -- For now, just log the item data
    print("=== ITEM INFO ===")
    for key, value in pairs(item) do
        print(key .. ":", value)
    end
    print("================")
end

-- 🌐 NETWORK INITIALIZATION
function InventoryPanel:_initializeNetworking()
    local success, signals = pcall(function()
        return require(ReplicatedStorage.Shared.Network.Signals)
    end)

    if success and signals then
        self.signals = signals
        self.logger:info("✅ Signals initialized for inventory")
    else
        self.logger:warn("❌ Failed to get Signals module:", signals)
    end
end

function InventoryPanel:SetupRealTimeUpdates()
    -- Watch for changes to the inventory folder
    local inventoryFolder = self.player:FindFirstChild("Inventory")
    if inventoryFolder then
        local petsFolder = inventoryFolder:FindFirstChild("pets")
        if petsFolder then
            -- Listen for new pets being added
            -- Mixed structure incremental listeners
            local stacks = petsFolder:FindFirstChild("Stacks")
            local special = petsFolder:FindFirstChild("Special")

            if stacks then
                stacks.ChildAdded:Connect(function(stackFolder)
                    if stackFolder:IsA("Folder") then
                        task.wait(0.05)
                        self:RefreshFromRealData()
                    end
                end)
                stacks.ChildRemoved:Connect(function()
                    self:RefreshFromRealData()
                end)
                -- Quantity change listener per existing stack
                for _, sf in ipairs(stacks:GetChildren()) do
                    local qty = sf:FindFirstChild("Quantity")
                    if qty then
                        qty:GetPropertyChangedSignal("Value"):Connect(function()
                            self:RefreshFromRealData()
                        end)
                    end
                end
                stacks.ChildAdded:Connect(function(sf)
                    local qty = sf:FindFirstChild("Quantity")
                    if qty then
                        qty:GetPropertyChangedSignal("Value"):Connect(function()
                            self:RefreshFromRealData()
                        end)
                    end
                end)
            end

            if special then
                special.ChildAdded:Connect(function()
                    task.wait(0.05)
                    self:RefreshFromRealData()
                end)
                special.ChildRemoved:Connect(function()
                    self:RefreshFromRealData()
                end)
            end

            -- Legacy fallback
            petsFolder.ChildAdded:Connect(function(child)
                if child:IsA("Folder") and child.Name ~= "Info" and not stacks and not special then
                    self.logger:info("New pet detected in inventory", { petFolder = child.Name })
                    task.wait(0.1)
                    self:RefreshFromRealData()
                end
            end)

            -- Listen for pets being removed
            petsFolder.ChildRemoved:Connect(function(child)
                if child:IsA("Folder") and child.Name ~= "Info" and not stacks and not special then
                    self.logger:info("Pet removed from inventory", { petFolder = child.Name })
                    self:RefreshFromRealData()
                end
            end)
        end
    end
end

-- Live-update the OPEN bucket(s): the non-pet buckets (enhancements / consumables /
-- resources…) are projected by InventoryService:_updateBucketFolders, which DESTROYS and
-- rebuilds every item folder under the bucket on each change. So a freshly-collected cog
-- arrives as ChildRemoved+ChildAdded churn on its bucket folder — watch that and re-render.
-- Pets already live-update through their dedicated Stacks/Special listener
-- (SetupRealTimeUpdates), so we skip them here. Scoped to the currently-selected category's
-- folders so a burst in an off-screen bucket can't thrash the open view (Jason: cogs mined
-- with the panel already open needed a close/reopen to appear).
function InventoryPanel:_setupBucketListeners()
    self:_teardownBucketListeners()

    local inventoryFolder = self.player:FindFirstChild("Inventory")
    if not inventoryFolder then
        return
    end

    for _, folderName in ipairs(self:_getCategoryFolders(self.selectedCategory)) do
        if folderName ~= "pets" then
            local bucketFolder = inventoryFolder:FindFirstChild(folderName)
            if bucketFolder then
                -- the rebuild fires Removed-then-Added across the whole bucket; the per-event
                -- refresh is debounced so one burst collapses into a single re-render
                table.insert(
                    self._bucketConnections,
                    bucketFolder.ChildAdded:Connect(function()
                        self:_scheduleBucketRefresh()
                    end)
                )
                table.insert(
                    self._bucketConnections,
                    bucketFolder.ChildRemoved:Connect(function()
                        self:_scheduleBucketRefresh()
                    end)
                )
            end
        end
    end
end

function InventoryPanel:_teardownBucketListeners()
    if self._bucketConnections then
        for _, connection in ipairs(self._bucketConnections) do
            connection:Disconnect()
        end
    end
    self._bucketConnections = {}
end

-- Coalesce a burst of bucket folder events (a full destroy+rebuild fires many in one frame)
-- into ONE RefreshFromRealData on the next defer, so we rebuild the grid once, not per item.
function InventoryPanel:_scheduleBucketRefresh()
    if self._bucketRefreshPending then
        return
    end
    self._bucketRefreshPending = true
    task.defer(function()
        self._bucketRefreshPending = false
        if self.isVisible then
            self:RefreshFromRealData()
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════════
-- ⚔️ EQUIPPED ITEM TRACKING
-- ═══════════════════════════════════════════════════════════════════════════════════

function InventoryPanel:_setupEquippedFolderListeners()
    local player = Players.LocalPlayer

    self.logger:info("⚔️ Setting up equipped folder listeners...")

    -- Use task.spawn to avoid blocking
    task.spawn(function()
        -- Wait for equipped folder to be created
        local equippedFolder = player:WaitForChild("Equipped", 10)
        if not equippedFolder then
            self.logger:warn("❌ No equipped folder found after 10 seconds")
            return
        end

        self.logger:info("✅ Found equipped folder")

        -- Track equipped items for quick lookup
        self.equippedItems = {
            pets = {},
            tools = {},
        }

        -- Set up pets folder listener
        task.spawn(function()
            local petsFolder = equippedFolder:FindFirstChild("pets")
            if not petsFolder then
                self.logger:info("⚔️ Waiting for pets folder to be created...")
                petsFolder = equippedFolder.ChildAdded:Wait()
                while petsFolder.Name ~= "pets" do
                    petsFolder = equippedFolder.ChildAdded:Wait()
                end
            end

            self.logger:info("✅ Found pets folder, setting up listener")
            self:_setupCategoryEquippedListener(petsFolder, "pets")
        end)

        -- Set up tools folder listener
        task.spawn(function()
            local toolsFolder = equippedFolder:FindFirstChild("tools")
            if toolsFolder then
                self.logger:info("✅ Found existing tools folder, setting up listener")
                self:_setupCategoryEquippedListener(toolsFolder, "tools")
            else
                self.logger:info("⚔️ Waiting for tools folder to be created...")
                -- Listen for tools folder to be created
                equippedFolder.ChildAdded:Connect(function(child)
                    if child.Name == "tools" then
                        self.logger:info("✅ Tools folder created, setting up listener")
                        self:_setupCategoryEquippedListener(child, "tools")
                    end
                end)
            end
        end)

        self.logger:info("⚔️ Equipped folder listeners setup complete")
        -- Force an initial display refresh after listeners are attached
        self:_updateItemsDisplay()
    end)
end

function InventoryPanel:_setupCategoryEquippedListener(categoryFolder, categoryName)
    self.logger:info("⚔️ Setting up listener for category: " .. categoryName)

    -- Load initial equipped items
    local initialCount = 0
    for _, slotValue in pairs(categoryFolder:GetChildren()) do
        if slotValue:IsA("StringValue") and slotValue.Value ~= "" then
            self.equippedItems[categoryName][slotValue.Value] = slotValue.Name
            initialCount = initialCount + 1
            self.logger:info("📍 Initial equipped item found", {
                category = categoryName,
                slot = slotValue.Name,
                itemUid = slotValue.Value,
            })
        end
    end

    -- Listen for equipped changes
    categoryFolder.ChildAdded:Connect(function(slotValue)
        if slotValue:IsA("StringValue") then
            self.logger:info("📍 ChildAdded in " .. categoryName, {
                slotName = slotValue.Name,
                slotValue = slotValue.Value,
            })
            -- Treat as equip of current value
            if slotValue.Value ~= "" then
                self:_onEquippedChanged(categoryName, slotValue.Value, slotValue.Name, "equipped")
            end
            -- Attach change watcher with last-value tracking for accurate unequip
            local last = slotValue.Value
            slotValue.Changed:Connect(function(newValue)
                self.logger:info("📍 Value changed in " .. categoryName, {
                    slotName = slotValue.Name,
                    oldValue = last,
                    newValue = newValue,
                })
                if newValue ~= "" then
                    self:_onEquippedChanged(categoryName, newValue, slotValue.Name, "equipped")
                else
                    -- Use previous value for unequip mapping removal
                    if last and last ~= "" then
                        self:_onEquippedChanged(categoryName, last, slotValue.Name, "unequipped")
                    end
                end
                last = newValue
            end)
        end
    end)

    categoryFolder.ChildRemoved:Connect(function(slotValue)
        if slotValue:IsA("StringValue") then
            self.logger:info("📍 ChildRemoved in " .. categoryName, {
                slotName = slotValue.Name,
                slotValue = slotValue.Value,
            })
            self:_onEquippedChanged(categoryName, slotValue.Value, slotValue.Name, "unequipped")
        end
    end)

    -- Listen for value changes within slots
    for _, slotValue in pairs(categoryFolder:GetChildren()) do
        if slotValue:IsA("StringValue") then
            local last = slotValue.Value
            slotValue.Changed:Connect(function(newValue)
                self.logger:info("📍 Value changed in " .. categoryName, {
                    slotName = slotValue.Name,
                    oldValue = last,
                    newValue = newValue,
                })
                if newValue ~= "" then
                    self:_onEquippedChanged(categoryName, newValue, slotValue.Name, "equipped")
                else
                    if last and last ~= "" then
                        self:_onEquippedChanged(categoryName, last, slotValue.Name, "unequipped")
                    end
                end
                last = newValue
            end)
        end
    end

    self.logger:info("⚔️ Set up equipped listener complete", {
        category = categoryName,
        initialEquipped = initialCount,
        totalSlots = #categoryFolder:GetChildren(),
    })

    -- Ensure UI reflects initial equipped state immediately
    -- Without this, the first open may not show equipped badges until the panel is reopened
    if initialCount > 0 then
        self:_updateItemsDisplay()
    end
end

function InventoryPanel:_onEquippedChanged(categoryName, itemUid, slotName, action)
    self.logger:info("⚔️ EQUIPPED CHANGED", {
        category = categoryName,
        itemUid = itemUid,
        slot = slotName,
        action = action,
    })

    if action == "equipped" and itemUid ~= "" then
        self.equippedItems[categoryName][itemUid] = slotName
        self.logger:info("✅ Added to equipped items", { itemUid = itemUid, slot = slotName })
    elseif action == "unequipped" then
        self.equippedItems[categoryName][itemUid] = nil
        self.logger:info("❌ Removed from equipped items", { itemUid = itemUid })
    end

    -- Debug: print occupied slots snapshot after every change
    if categoryName == "pets" then
        local occupied = {}
        local equippedFolder = Players.LocalPlayer:FindFirstChild("Equipped")
        if equippedFolder and equippedFolder:FindFirstChild("pets") then
            for _, slot in ipairs(equippedFolder.pets:GetChildren()) do
                if slot:IsA("StringValue") then
                    table.insert(
                        occupied,
                        slot.Name .. "=" .. (slot.Value ~= "" and slot.Value or "<empty>")
                    )
                end
            end
        end
        print("[EQUIPPED SLOTS] " .. table.concat(occupied, ", "))
    end

    -- If this is a stack-backed equip value (bridge format), adjust just that stack card
    if categoryName == "pets" and type(itemUid) == "string" then
        local parts = string.split(itemUid, "|")
        if #parts >= 3 and parts[1] == "stack" then
            local stackKey = parts[2] -- id:variant
            self._stackFrames = self._stackFrames or {}
            self._stackDataByKey = self._stackDataByKey or {}
            -- Avoid manual local count math to prevent double-decrement; refresh from replicated data
            self:RefreshFromRealData()
            return
        end
    end

    -- Fallback: refresh full display
    self.logger:info("🔄 Refreshing UI for equipped change")
    self:_updateItemsDisplay()
end

-- Debug function to manually check equipped items
function InventoryPanel:DebugEquippedItems()
    print("=== EQUIPPED ITEMS DEBUG ===")
    if self.equippedItems then
        for category, items in pairs(self.equippedItems) do
            print(category .. ":")
            for itemUid, slot in pairs(items) do
                print("  " .. itemUid .. " -> " .. slot)
            end
        end
    else
        print("equippedItems not initialized")
    end

    -- Also check the actual folders
    local player = Players.LocalPlayer
    local equippedFolder = player:FindFirstChild("Equipped")
    if equippedFolder then
        print("=== ACTUAL FOLDERS ===")
        for _, categoryFolder in pairs(equippedFolder:GetChildren()) do
            if categoryFolder:IsA("Folder") then
                print(categoryFolder.Name .. ":")
                for _, slotValue in pairs(categoryFolder:GetChildren()) do
                    if slotValue:IsA("StringValue") then
                        print("  " .. slotValue.Name .. " = " .. slotValue.Value)
                    end
                end
            end
        end
    else
        print("No equipped folder found")
    end
    print("===========================")
end

function InventoryPanel:_isItemEquipped(item)
    if not self.equippedItems then
        return false
    end

    if item.folder_source == "pets" then
        -- If this is a ghost equipped instance from a stack, uid will be the equippedUid
        if typeof(item.uid) == "string" and string.sub(item.uid, 1, 17) == "stackInstance|" then
            return true
        end
        return self.equippedItems.pets[item.uid] ~= nil
    elseif item.folder_source == "tools" then
        return self.equippedItems.tools[item.uid] ~= nil
    end

    return false
end

function InventoryPanel:_applyEquippedStyling(itemFrame, isEquipped, originalColor)
    if not itemFrame then
        return
    end

    local stroke = itemFrame:FindFirstChild("RarityStroke")
        or itemFrame:FindFirstChildOfClass("UIStroke")

    if isEquipped then
        -- Equipped styling: preserve rarity/variant colors and make the ring more prominent.
        if stroke then
            local baseThickness = tonumber(stroke:GetAttribute("BaseThickness"))
                or stroke.Thickness
                or 2
            stroke.Thickness = baseThickness + 1
            stroke.Transparency = 0
        end

        -- Add equipped icon
        local equippedIcon = itemFrame:FindFirstChild("EquippedIcon")
        if not equippedIcon then
            equippedIcon = Instance.new("TextLabel")
            equippedIcon.Name = "EquippedIcon"
            equippedIcon.Size = UDim2.new(0, 24, 0, 24)
            equippedIcon.Position = UDim2.new(1, -30, 0, 6)
            equippedIcon.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
            equippedIcon.BackgroundTransparency = 0.2
            equippedIcon.BorderSizePixel = 0
            equippedIcon.Text = "⚔️"
            equippedIcon.TextSize = 14
            equippedIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
            equippedIcon.ZIndex = 110
            equippedIcon.Parent = itemFrame

            local iconCorner = Instance.new("UICorner")
            iconCorner.CornerRadius = UDim.new(0, 12)
            iconCorner.Parent = equippedIcon
        end
    else
        -- Unequipped styling: restore base ring weight without changing rarity colors.
        if stroke then
            stroke.Color = originalColor or stroke.Color
            stroke.Thickness = tonumber(stroke:GetAttribute("BaseThickness")) or 2
            stroke.Transparency = 0
        end

        -- Remove equipped icon
        local equippedIcon = itemFrame:FindFirstChild("EquippedIcon")
        if equippedIcon then
            equippedIcon:Destroy()
        end
    end
end

function InventoryPanel:Destroy()
    self:Hide()
    self.logger:info("Professional inventory panel destroyed")
end

return InventoryPanel
