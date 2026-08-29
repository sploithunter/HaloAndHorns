--[[
    HoverboardShopService — Kade's Hall 1 shack shop.

    Spawns Kade from his Roblox avatar. The catalog is image-based (keyed
    skin icons) with mixed tender: free giveaways, gems, and permanent Robux
    passes. Ownership lives in GameData.Hoverboard, not mount inventory.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HoverboardLogic = require(ReplicatedStorage.Shared.Game.HoverboardLogic)
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local PROMPT_NAME = "HoverboardShopPrompt"
local R15_IDLE = "rbxassetid://507766388"

local HoverboardShopService = {}
HoverboardShopService.__index = HoverboardShopService

function HoverboardShopService.new()
    local self = setmetatable({}, HoverboardShopService)
    self._access = setmetatable({}, { __mode = "k" })
    return self
end

function HoverboardShopService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._economyService = self._modules and self._modules.EconomyService
    self._hoverboardService = self._modules and self._modules.HoverboardService
    self._monetizationService = self._modules and self._modules.MonetizationService
    local ok, cfg = pcall(function()
        return self._configLoader:LoadConfig("hoverboard")
    end)
    self._config = ok and type(cfg) == "table" and cfg or {}
    self._placesConfig = self._configLoader:LoadConfig("places")
end

function HoverboardShopService:Start()
    if PlaceRuntime.isMerge(game.PlaceId, self._placesConfig) then
        return
    end
    local shop = self._config.shop
    if self._config.enabled ~= true or type(shop) ~= "table" or shop.enabled ~= true then
        return
    end
    task.spawn(function()
        self:_setupShop()
    end)
end

function HoverboardShopService:_shop()
    return self._config.shop
end

function HoverboardShopService:_waitShack()
    local location = (self:_shop() and self:_shop().location) or {}
    local maps = Workspace:WaitForChild("Maps", 30)
    local world = maps and maps:WaitForChild(location.map_name or "FuturePath", 30)
    local tiles = world and world:WaitForChild("Tiles", 15)
    local tile = tiles and tiles:WaitForChild(location.tile_name or "Tile01_cap", 15)
    return tile and tile:WaitForChild(location.model_name or "Shack", 15)
end

function HoverboardShopService:_setupShop()
    local shack = self:_waitShack()
    if not shack then
        if self._logger then
            self._logger:Warn("Hoverboard shop shack was not found")
        end
        return
    end
    local folder = Instance.new("Folder")
    folder.Name = "HoverboardShop"
    folder.Parent = shack
    self._folder = folder
    self._anchor = self:_spawnKade(folder)
    if self._anchor then
        self:_bindPrompt(self._anchor)
    end
end

function HoverboardShopService:_npcCFrame()
    local pose = ((self:_shop() and self:_shop().location) or {}).npc or {}
    local position =
        Vector3.new(tonumber(pose.x) or 1814, tonumber(pose.y) or 3, tonumber(pose.z) or -202)
    local yaw = math.rad(tonumber(pose.yaw_degrees) or -90)
    return CFrame.new(position) * CFrame.Angles(0, yaw, 0)
end

function HoverboardShopService:_spawnKade(folder)
    local npc = (self:_shop() and self:_shop().npc) or {}
    local userId = tonumber(npc.user_id)
    local model
    if userId then
        local ok, desc = pcall(function()
            return Players:GetHumanoidDescriptionFromUserId(userId)
        end)
        if ok and desc then
            local ok2, rig = pcall(function()
                return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
            end)
            if ok2 then
                model = rig
            end
        end
    end
    if not model then
        if self._logger then
            self._logger:Warn("Hoverboard shop could not load Kade avatar")
        end
        return nil
    end
    model.Name = npc.name or "Kade"
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayName = npc.display_name or "Kade"
        humanoid.WalkSpeed = 0
        local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
        animator.Parent = humanoid
        local idle = Instance.new("Animation")
        idle.AnimationId = R15_IDLE
        local ok, track = pcall(function()
            return animator:LoadAnimation(idle)
        end)
        if ok and track then
            track.Looped = true
            track:Play()
        end
    end
    model:PivotTo(self:_npcCFrame())
    local root = model:FindFirstChild("HumanoidRootPart")
    if root then
        root.Anchored = true
        pcall(function()
            root:SetNetworkOwner(nil)
        end)
    end
    model:SetAttribute("HoverboardShopNpc", true)
    model.Parent = folder
    return root
end

function HoverboardShopService:_bindPrompt(part)
    local interaction = (self:_shop() and self:_shop().interaction) or {}
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = PROMPT_NAME
    prompt.ActionText = interaction.action_text or "Browse Boards"
    prompt.ObjectText = interaction.object_text or "Hoverboard Shop"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.MaxActivationDistance = tonumber(interaction.max_distance) or 18
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.Parent = part
    prompt.Triggered:Connect(function(player)
        self:_openFor(player)
    end)
end

function HoverboardShopService:_openFor(player)
    if typeof(player) ~= "Instance" or not player:IsA("Player") then
        return
    end
    self._access[player] = os.clock()
        + (tonumber((self:_shop().interaction or {}).access_seconds) or 120)
    local shop = self:_shop()
    Signals.HoverboardShopOpened:FireClient(player, {
        displayName = (shop.interaction or {}).object_text or "Kade",
        npc = (shop.npc or {}).display_name or "Kade",
        story = shop.story,
    })
end

function HoverboardShopService:_hasAccess(player)
    local expires = self._access[player]
    if type(expires) ~= "number" or os.clock() > expires then
        self._access[player] = nil
        return false
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not (root and self._anchor) then
        return false
    end
    local interaction = (self:_shop() and self:_shop().interaction) or {}
    local allowed = (tonumber(interaction.max_distance) or 18)
        + (tonumber(interaction.distance_grace) or 8)
    if (root.Position - self._anchor.Position).Magnitude > allowed then
        return false
    end
    self._access[player] = os.clock() + (tonumber(interaction.access_seconds) or 120)
    return true
end

function HoverboardShopService:_gems(player)
    return self._economyService and self._economyService:GetCurrency(player, "gems") or 0
end

function HoverboardShopService:_robuxPassId(offer)
    local passKey = type(offer) == "table" and offer.pass or nil
    if type(passKey) ~= "string" or passKey == "" then
        return 0
    end
    local ok, monetization = pcall(function()
        return self._configLoader:LoadConfig("monetization")
    end)
    if not (ok and type(monetization) == "table") then
        return 0
    end
    return tonumber((monetization.product_id_mapping or {})[passKey]) or 0
end

function HoverboardShopService:Catalog(player)
    if not self:_hasAccess(player) then
        return { ok = false, reason = "shop_out_of_range" }
    end
    local save = self._hoverboardService and self._hoverboardService:GetSave(player)
        or HoverboardLogic.normalizeSave(nil, self._config.default_skin)
    local gems = self:_gems(player)
    local offers = {}
    for _, entry in ipairs(HoverboardLogic.catalogEntries(self._config.skins, self:_shop().catalog)) do
        local owned = HoverboardLogic.isOwned(save.owned, entry.id)
        table.insert(offers, {
            id = entry.id,
            display_name = entry.display_name,
            icon = entry.icon,
            kind = entry.kind,
            price = entry.price,
            price_robux = entry.price_robux,
            pass = entry.pass,
            roblox_pass_id = self:_robuxPassId(entry),
            on_sale = entry.on_sale == true,
            owned = owned,
            equipped = save.equipped == entry.id,
        })
    end
    return {
        ok = true,
        gems = gems,
        equipped = save.equipped,
        story = (self:_shop() or {}).story,
        offers = offers,
    }
end

function HoverboardShopService:Buy(player, args)
    if not self:_hasAccess(player) then
        return { ok = false, reason = "shop_out_of_range" }
    end
    args = type(args) == "table" and args or {}
    local skinId = args.skinId
    local shopCatalog = (self:_shop() and self:_shop().catalog) or {}
    local offer = type(shopCatalog[skinId]) == "table" and shopCatalog[skinId] or nil
    if not offer or not (self._config.skins and self._config.skins[skinId]) then
        return { ok = false, reason = "invalid_skin" }
    end
    local save = self._hoverboardService:GetSave(player)
    local gems = self:_gems(player)
    local allowed, costOrReason = HoverboardLogic.canBuy(save.owned, skinId, offer, { gems = gems })
    if not allowed then
        return { ok = false, reason = costOrReason }
    end
    local kind = HoverboardLogic.offerKind(offer)
    if kind == "robux" then
        -- Route through MonetizationService so Kade uses the same ownership
        -- guard and PromptGamePassPurchase callback as every other pass.
        if not (self._monetizationService and self._monetizationService._handlePurchaseRequest) then
            return { ok = false, reason = "service_unavailable" }
        end
        if type(offer.pass) ~= "string" or offer.pass == "" then
            return { ok = false, reason = "robux_unwired" }
        end
        local passId = self:_robuxPassId(offer)
        if passId <= 0 then
            return { ok = false, reason = "robux_unwired" }
        end
        self._monetizationService:_handlePurchaseRequest(player, {
            productId = offer.pass,
            productType = "gamepass",
        })
        local catalog = self:Catalog(player)
        catalog.pending_robux = passId > 0
        return catalog
    end
    local cost = tonumber(costOrReason) or 0
    if kind == "gems" and cost > 0 then
        local debit = self._economyService:RemoveCurrency(player, "gems", cost, "hoverboard_shop")
        if debit == false then
            return { ok = false, reason = "debit_failed" }
        end
    end
    local granted = self._hoverboardService:GrantOwned(player, skinId)
    if not granted.ok then
        if kind == "gems" and cost > 0 then
            self._economyService:AddCurrency(player, "gems", cost, "hoverboard_shop_refund")
        end
        return granted
    end
    self._hoverboardService:Equip(player, skinId)
    return self:Catalog(player)
end

function HoverboardShopService:Equip(player, args)
    if not self:_hasAccess(player) then
        return { ok = false, reason = "shop_out_of_range" }
    end
    args = type(args) == "table" and args or {}
    local equipped = self._hoverboardService:Equip(player, args.skinId)
    if not equipped.ok then
        return equipped
    end
    return self:Catalog(player)
end

return HoverboardShopService
