--[[
    HoverboardService — server-authoritative Hall Level-2 board.

    Eligibility is tutorial complete + claimed Level 2. Mounted state is a player
    attribute, never a save field. Combat, missions, and death force a
    dismount. Walking Hall_1–Hall_4 (old gate lines) is not a teleport and
    must not dismount. Speed is max(normal effective walk, configured cruise).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local HoverboardLogic = require(ReplicatedStorage.Shared.Game.HoverboardLogic)
local HallOfWorldsLogic = require(ReplicatedStorage.Shared.Game.HallOfWorldsLogic)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local MeshAssembly = require(ReplicatedStorage.Shared.Assets.MeshAssembly)

local HoverboardService = {}
HoverboardService.__index = HoverboardService

function HoverboardService.new()
    local self = setmetatable({}, HoverboardService)
    self._logger = nil
    self._configLoader = nil
    self._dataService = nil
    self._playerProgressionService = nil
    self._config = nil
    return self
end

function HoverboardService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._playerProgressionService = self._modules and self._modules.PlayerProgressionService
    local ok, cfg = pcall(function()
        return self._configLoader:LoadConfig("hoverboard")
    end)
    self._config = ok and type(cfg) == "table" and cfg or {}
end

function HoverboardService:Start()
    if self._config.enabled ~= true then
        return
    end

    Signals.Hoverboard_Toggle.OnServerEvent:Connect(function(player, request)
        self:Toggle(player, request)
    end)

    fireGameEvent.tap(function(player, name)
        if
            name == "tutorial_complete"
            or name == "level_claimed"
            or name == "tutorial_level_awarded"
        then
            self:_refresh(player)
        end
    end)

    local function watch(player)
        player:GetAttributeChangedSignal("InCombat"):Connect(function()
            self:_refresh(player)
        end)
        player:GetAttributeChangedSignal("InMission"):Connect(function()
            self:_refresh(player)
        end)
        player:GetAttributeChangedSignal("ClaimedLevel"):Connect(function()
            self:_refresh(player)
        end)
        player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
            self:_refresh(player)
        end)
        player:GetAttributeChangedSignal("HoverboardSkin"):Connect(function()
            if player:GetAttribute("HoverboardMounted") == true then
                self:_applySpeed(player)
            end
        end)
        player.ChildAdded:Connect(function(child)
            if child.Name == "Inventory" then
                self:_publishInventory(player)
            end
        end)
        player.CharacterAdded:Connect(function(character)
            self:_bindCharacter(player, character)
            self:_refresh(player)
        end)
        if player.Character then
            self:_bindCharacter(player, player.Character)
        end
        self:_refresh(player)
    end

    Players.PlayerAdded:Connect(watch)
    for _, player in ipairs(Players:GetPlayers()) do
        task.defer(watch, player)
    end

    task.spawn(function()
        self:_publishTemplate()
    end)
end

function HoverboardService:_publishTemplate()
    local skins = self._config.skins
    if type(skins) ~= "table" then
        return
    end
    local folder = ReplicatedStorage:FindFirstChild("HoverboardTemplates")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "HoverboardTemplates"
        folder.Parent = ReplicatedStorage
    end
    local flatten = type(self._config.flatten) == "table" and self._config.flatten or nil
    for key, skin in pairs(skins) do
        if type(skin) == "table" and type(skin.mesh_asset) == "string" then
            local model, err = MeshAssembly.build(skin.mesh_asset, skin.texture_asset, {
                modelName = key,
                partName = "Deck",
                anchored = false,
                canCollide = false,
            })
            if model then
                local deck = model.PrimaryPart
                local target = tonumber(skin.length) or 5.4
                local longest = math.max(deck.Size.X, deck.Size.Y, deck.Size.Z)
                if longest > 0 then
                    deck.Size = deck.Size * (target / longest)
                end
                deck.Color = Color3.new(1, 1, 1)
                deck:SetAttribute("YawDegrees", tonumber(skin.deck_yaw_degrees) or 0)
                deck:SetAttribute(
                    "PitchDegrees",
                    tonumber(skin.pitch_degrees) or tonumber(flatten and flatten.pitch_degrees) or 0
                )
                deck:SetAttribute(
                    "RollDegrees",
                    tonumber(skin.roll_degrees) or tonumber(flatten and flatten.roll_degrees) or 0
                )
                local existing = folder:FindFirstChild(key)
                if existing then
                    existing:Destroy()
                end
                model.Parent = folder
            elseif self._logger then
                self._logger:Warn("Hoverboard template build failed", {
                    skin = key,
                    error = tostring(err),
                })
            end
        end
    end
end

function HoverboardService:_isEligible(player)
    return HoverboardLogic.isEligible(
        self:_claimedLevel(player),
        self:_tutorialDone(player),
        self._config.unlock
    ) == true
end

function HoverboardService:_save(player)
    local data = self._dataService and self._dataService:GetData(player)
    local eligible = typeof(player) == "Instance" and self:_isEligible(player)
    local defaultSkin = eligible and self._config.default_skin or nil
    if type(data) ~= "table" then
        return HoverboardLogic.normalizeSave(nil, defaultSkin)
    end
    data.GameData = type(data.GameData) == "table" and data.GameData or {}
    local normalized = HoverboardLogic.normalizeSave(data.GameData.Hoverboard, defaultSkin)
    local catalog = self._config.shop and self._config.shop.catalog
    normalized.owned = HoverboardLogic.stripCompleteFreeSet(normalized.owned, catalog, defaultSkin)
    if type(normalized.equipped) ~= "string" or normalized.owned[normalized.equipped] ~= true then
        normalized.equipped = defaultSkin
    end
    data.GameData.Hoverboard = normalized
    return normalized
end

function HoverboardService:ResetForBeginning(player)
    if typeof(player) ~= "Instance" or not player:IsA("Player") then
        return { ok = false, reason = "invalid_player" }
    end
    local data = self._dataService and self._dataService:GetData(player)
    if type(data) == "table" then
        data.GameData = type(data.GameData) == "table" and data.GameData or {}
        data.GameData.Hoverboard = HoverboardLogic.emptySave()
    end
    self:_setMounted(player, false)
    player:SetAttribute("HoverboardSkin", nil)
    player:SetAttribute("HoverboardEligible", false)
    player:SetAttribute("HoverboardWalkSpeed", nil)
    local inv = player:FindFirstChild("Inventory")
    local folder = inv and inv:FindFirstChild("hoverboards")
    if folder then
        folder:ClearAllChildren()
    end
    return { ok = true }
end

function HoverboardService:_publishInventory(player)
    local save = self:_save(player)
    local inv = player:FindFirstChild("Inventory")
    if not inv then
        return
    end
    local folder = inv:FindFirstChild("hoverboards")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "hoverboards"
        folder.Parent = inv
    end
    local keep = {}
    local skins = type(self._config.skins) == "table" and self._config.skins or {}
    for skinId in pairs(save.owned) do
        local skin = skins[skinId]
        if type(skin) == "table" then
            keep[skinId] = true
            local child = folder:FindFirstChild(skinId)
            if not child then
                child = Instance.new("Folder")
                child.Name = skinId
                child.Parent = folder
            end
            child:SetAttribute("DisplayName", skin.display_name or skinId)
            child:SetAttribute("Icon", type(skin.icon) == "string" and skin.icon or "")
            child:SetAttribute("Equipped", save.equipped == skinId)
            child:SetAttribute("Tradeable", false)
        end
    end
    for _, child in ipairs(folder:GetChildren()) do
        if keep[child.Name] ~= true then
            child:Destroy()
        end
    end
end

function HoverboardService:_applySkin(player)
    local save = self:_save(player)
    player:SetAttribute("HoverboardSkin", save.equipped)
    self:_publishInventory(player)
    return save
end

function HoverboardService:GetSave(player)
    return self:_save(player)
end

function HoverboardService:Equip(player, skinId)
    local save = self:_save(player)
    local ok, reason = HoverboardLogic.canEquip(save.owned, skinId)
    if not ok then
        return { ok = false, reason = reason }
    end
    save.equipped = skinId
    player:SetAttribute("HoverboardSkin", skinId)
    self:_publishInventory(player)
    if player:GetAttribute("HoverboardMounted") == true then
        self:_applySpeed(player)
    end
    return { ok = true, equipped = skinId, owned = save.owned }
end

function HoverboardService:GrantOwned(player, skinId)
    local save = self:_save(player)
    if type(skinId) ~= "string" or skinId == "" then
        return { ok = false, reason = "invalid_skin" }
    end
    save.owned[skinId] = true
    self:_publishInventory(player)
    return { ok = true, owned = save.owned, equipped = save.equipped }
end

function HoverboardService:Toggle(player, request)
    if typeof(player) ~= "Instance" or not player:IsA("Player") then
        return
    end
    request = type(request) == "table" and request or {}
    self:_refresh(player)
    if player:GetAttribute("HoverboardEligible") ~= true then
        return
    end

    local want = request.mounted
    if typeof(want) ~= "boolean" then
        want = player:GetAttribute("HoverboardMounted") ~= true
    end
    if want == true and HoverboardLogic.shouldSuppress(self:_flags(player)) then
        want = false
    end
    self:_setMounted(player, want == true)
end

function HoverboardService:_bindCharacter(player, character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        humanoid = character:WaitForChild("Humanoid", 5)
    end
    if humanoid then
        humanoid.Died:Connect(function()
            self:_setMounted(player, false)
        end)
    end
end

function HoverboardService:_tutorialDone(player)
    local data = self._dataService and self._dataService:GetData(player)
    local gameData = data and data.GameData
    local tutorial = data and data.Tutorial
    return HallOfWorldsLogic.isTutorialCompleted(gameData, tutorial)
end

function HoverboardService:_claimedLevel(player)
    if self._playerProgressionService and self._playerProgressionService.GetClaimedLevel then
        return self._playerProgressionService:GetClaimedLevel(player)
    end
    return tonumber(player:GetAttribute("ClaimedLevel")) or 1
end

function HoverboardService:_flags(player)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return {
        in_combat = player:GetAttribute("InCombat") == true,
        in_mission = player:GetAttribute("InMission") ~= nil,
        dead = humanoid ~= nil and humanoid.Health <= 0,
        teleporting = false,
        precision_interact = false,
    }
end

function HoverboardService:_refresh(player)
    if not player.Parent then
        return
    end
    local eligible = self:_isEligible(player)
    player:SetAttribute("HoverboardEligible", eligible == true)
    self:_applySkin(player)
    if not eligible then
        self:_setMounted(player, false)
        return
    end
    if
        player:GetAttribute("HoverboardMounted") == true
        and HoverboardLogic.shouldSuppress(self:_flags(player))
    then
        self:_setMounted(player, false)
        return
    end
    if player:GetAttribute("HoverboardMounted") == true then
        self:_applySpeed(player)
    end
end

function HoverboardService:_setMounted(player, mounted)
    local nextMounted = mounted == true
    if player:GetAttribute("HoverboardMounted") == nextMounted then
        if nextMounted then
            self:_applySpeed(player)
        end
        return
    end
    player:SetAttribute("HoverboardMounted", nextMounted)
    self:_applySpeed(player)
end

function HoverboardService:_applySpeed(player)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end
    local gameConfig = self._configLoader and self._configLoader:LoadConfig("game")
    local base = (gameConfig and gameConfig.WorldSettings and gameConfig.WorldSettings.WalkSpeed)
        or 16
    local mult = tonumber(player:GetAttribute("Eff_Speed")) or 1
    if player:GetAttribute("HoverboardMounted") == true then
        local save = self:GetSave(player)
        local skinKey = player:GetAttribute("HoverboardSkin")
        if type(skinKey) ~= "string" or skinKey == "" then
            skinKey = save and save.equipped
        end
        local skin = type(self._config.skins) == "table" and self._config.skins[skinKey]
        local cruise = HoverboardLogic.skinCruiseSpeed(skin, self._config.cruise_speed)
        local speed = HoverboardLogic.mountedSpeed(base, mult, cruise)
        humanoid.WalkSpeed = speed
        player:SetAttribute("HoverboardWalkSpeed", speed)
    else
        humanoid.WalkSpeed = base * mult
        player:SetAttribute("HoverboardWalkSpeed", nil)
    end
end

return HoverboardService
