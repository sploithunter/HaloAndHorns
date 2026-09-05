local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PlaceRuntime = require(ReplicatedStorage.Shared.Game.PlaceRuntime)
local Plan = require(ReplicatedStorage.Shared.Game.FarmAssetPlan)
local PetInventoryView = require(ReplicatedStorage.Shared.Inventory.PetInventoryView)
local ModelTemplateStore = require(ReplicatedStorage.Shared.Utils.ModelTemplateStore)
local EggWorldQuery = require(ReplicatedStorage.Shared.Services.EggWorldQuery)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local Service = {}
Service.__index = Service

local function folder(parent, name)
    local existing = parent:FindFirstChild(name)
    if existing then
        return existing
    end
    local result = Instance.new("Folder")
    result.Name, result.Parent = name, parent
    return result
end

function Service:Init()
    local loader = self._modules.ConfigLoader
    self._config = loader:LoadConfig("farm_asset_warmup")
    self._places = loader:LoadConfig("places")
    self._pets = loader:LoadConfig("pets")
    self._thumbnails = loader:LoadConfig("pet_thumbnail_assets")
    self._data = self._modules.DataService
    self._logger = self._modules.Logger
    self._records = {}
end

function Service:_enabled()
    return self._config.enabled and PlaceRuntime.isRole(game.PlaceId, self._places, "main")
end

function Service:_record(player)
    local record = self._records[player]
    if not record then
        record = { retained = {}, requested = {}, lastRequest = -math.huge }
        self._records[player] = record
    end
    return record
end

function Service:_input(player, record, now)
    local data = self._data:GetData(player) or {}
    local items = data.Inventory and data.Inventory.pets and data.Inventory.pets.items or {}
    local equipped =
        PetInventoryView.resolveEquipped(items, data.Equipped and data.Equipped.pets, math.huge)
    local input = {
        now = now,
        owned = items,
        equipped = equipped,
        requested = record.requested,
        active = {},
        eggs = {},
    }
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if root and player:GetAttribute("InPrologue") ~= true then
        for _, egg in ipairs(EggWorldQuery.GetEggs()) do
            if egg.anchor and egg.anchor:IsDescendantOf(workspace) then
                input.eggs[#input.eggs + 1] =
                    { id = egg.eggType, distance = (egg.anchor.Position - root.Position).Magnitude }
            end
        end
    end
    local live = workspace:FindFirstChild("PlayerPets")
    for _, owner in ipairs(live and live:GetChildren() or {}) do
        for _, model in ipairs(owner:GetChildren()) do
            if model:IsA("Model") and model:GetAttribute("PetType") then
                if
                    owner.Name == player.Name
                    or (
                        root
                        and (model:GetPivot().Position - root.Position).Magnitude
                            <= self._config.nearby_pet_radius
                    )
                then
                    input.active[#input.active + 1] = {
                        id = model:GetAttribute("PetType"),
                        variant = model:GetAttribute("PetVariant"),
                    }
                end
            end
        end
    end
    return input
end

function Service:_reconcile(player)
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    local root = ModelTemplateStore.root()
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if
        not self:_enabled()
        or player.Parent ~= Players
        or not playerGui
        or not root
        or not assets
        or assets:GetAttribute("ModelsReady") ~= true
    then
        return
    end
    local now, record = os.clock(), self:_record(player)
    for key, request in pairs(record.requested) do
        if request.expiresAt <= now then
            record.requested[key] = nil
        end
    end
    local desired, desiredEggs =
        Plan.build(self._config, self._pets, self:_input(player, record, now))
    record.desired = desired
    local cache = folder(playerGui, self._config.cache_folder)
    local models = folder(cache, "Models")
    local pets, eggs, images =
        folder(models, "Pets"), folder(models, "Eggs"), folder(cache, "Images")
    local wanted = {}
    local function keep(category, id, variant, source, parent)
        if not source then
            return
        end
        local key = category .. ":" .. id .. ":" .. variant
        wanted[key] = true
        local entry = record.retained[key]
        if not entry or entry.instance.Parent ~= parent then
            local clone = source:Clone()
            clone.Name = variant
            clone.Parent = parent
            entry = { instance = clone }
            record.retained[key] = entry
        end
        entry.untilTime = now + self._config.retention_seconds
    end
    local sourcePets, sourceEggs = root:FindFirstChild("Pets"), root:FindFirstChild("Eggs")
    for id, variants in pairs(desired) do
        local source = sourcePets and sourcePets:FindFirstChild(id)
        local target = folder(pets, id)
        for variant in pairs(variants) do
            keep("pet", id, variant, source and source:FindFirstChild(variant), target)
            -- Flat art and mesh dependencies are fetched separately by the client warmup worker.
            for _, imageVariant in ipairs({ variant, variant .. "__huge" }) do
                local uri = (self._thumbnails.pets[id] or {})[imageVariant]
                if uri then
                    local key = id .. ":" .. imageVariant
                    local image = images:FindFirstChild(key)
                    if not image then
                        image = Instance.new("ImageLabel")
                        image.Name, image.Image, image.Visible = key, uri, false
                        image.Parent = images
                    end
                    wanted["image:" .. key] = true
                    record.retained["image:" .. key] =
                        { instance = image, untilTime = now + self._config.retention_seconds }
                end
            end
        end
    end
    for id in pairs(desiredEggs) do
        keep("egg", id, id, sourceEggs and sourceEggs:FindFirstChild(id), eggs)
    end
    for key, entry in pairs(record.retained) do
        if not wanted[key] and entry.untilTime <= now then
            entry.instance:Destroy()
            record.retained[key] = nil
        end
    end
    -- Rapid travel must not accumulate a tour of the whole catalog during the grace period.
    -- Only unused cache entries are capped; active/selected templates and live actors are safe.
    local unused = {}
    for key, entry in pairs(record.retained) do
        if not wanted[key] then
            unused[#unused + 1] = { key = key, entry = entry }
        end
    end
    table.sort(unused, function(a, b)
        return a.entry.untilTime < b.entry.untilTime
    end)
    for index = 1, #unused - self._config.maximum_retained_unused_entries do
        local old = unused[index]
        old.entry.instance:Destroy()
        record.retained[old.key] = nil
    end
    for _, family in ipairs(pets:GetChildren()) do
        if #family:GetChildren() == 0 then
            family:Destroy()
        end
    end
    cache:SetAttribute("WarmPetTypeCount", #pets:GetChildren())
    cache:SetAttribute("WarmSourceCount", #eggs:GetChildren())
end

function Service:_request(player, request)
    if not self:_enabled() or type(request) ~= "table" then
        return false
    end
    local id, variant = request.id, request.variant
    if type(id) ~= "string" or type(variant) ~= "string" then
        return false
    end
    local record, now = self:_record(player), os.clock()
    if now - record.lastRequest < self._config.request_interval_seconds then
        return false
    end
    record.lastRequest = now
    local data = self._data:GetData(player)
    local items = data and data.Inventory and data.Inventory.pets and data.Inventory.pets.items
    if
        not Plan.owns(items, id, variant)
        and not (record.desired and record.desired[id] and record.desired[id][variant])
    then
        return false
    end
    local count = 0
    for key, entry in pairs(record.requested) do
        if entry.expiresAt <= now then
            record.requested[key] = nil
        else
            count += 1
        end
    end
    local key = id .. ":" .. variant
    if count >= self._config.maximum_requested_models and not record.requested[key] then
        return false
    end
    record.requested[key] =
        { id = id, variant = variant, expiresAt = now + self._config.requested_retention_seconds }
    self:_reconcile(player)
    return true
end

function Service:Start()
    Signals.PetPreviewRequest.OnServerInvoke = function(player, request)
        return self:_request(player, request)
    end
    if not self:_enabled() then
        return
    end
    Players.PlayerRemoving:Connect(function(player)
        self._records[player] = nil
    end)
    local nextReconcile = 0
    self._heartbeat = RunService.Heartbeat:Connect(function()
        if os.clock() >= nextReconcile then
            nextReconcile = os.clock() + self._config.reconcile_interval
            for _, player in ipairs(Players:GetPlayers()) do
                local ok, err = pcall(function()
                    self:_reconcile(player)
                end)
                if not ok then
                    self._logger:Warn("Farm asset warmup failed", { error = tostring(err) })
                end
            end
        end
    end)
end

return Service
