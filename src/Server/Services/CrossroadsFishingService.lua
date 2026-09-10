-- Client owns fishing timing and catch/escape. This adapter only saves configured rewards.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Timing = require(ReplicatedStorage.Shared.Game.FishingTiming)
local Service = {}
Service.__index = Service
function Service:Init()
    self.cfg = self._modules.ConfigLoader:LoadConfig("crossroads_fishing")
    self.busy = {}
    self.rng = Random.new()
end
function Service:_station(key)
    local root = workspace:FindFirstChild(self.cfg.root_name)
    local fishing = root and root:FindFirstChild(self.cfg.fishing_root)
    if fishing then
        for _, deck in ipairs(fishing:GetDescendants()) do
            if deck:IsA("BasePart") and deck:GetAttribute(self.cfg.station_attribute) == key then
                return deck
            end
        end
    end
end
function Service:Claim(player, args)
    local cfg = self.cfg
    if not cfg.enabled then
        return { ok = false, reason = "disabled" }
    end
    if
        type(args) ~= "table"
        or type(args.attempt) ~= "string"
        or #args.attempt > 64
        or #args.attempt < 1
        or type(args.station) ~= "string"
        or type(args.score) ~= "number"
        or args.score ~= args.score
        or args.score < 0
        or args.score > 100
        or type(args.caught) ~= "boolean"
    then
        return { ok = false, reason = "invalid_catch" }
    end
    local data = self._modules.DataService:GetData(player)
    if not data then
        return { ok = false, reason = "profile_unavailable" }
    end
    data.GameData = data.GameData or {}
    local history = data.GameData.CrossroadsFishing
    if not history then
        history = { receipts = {}, order = {} }
        data.GameData.CrossroadsFishing = history
    end
    if history.receipts[args.attempt] then
        return history.receipts[args.attempt]
    end
    if self.busy[player] then
        return { ok = false, reason = "busy" }
    end
    local deck = self:_station(args.station)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if
        not deck
        or not root
        or not humanoid
        or humanoid.Health <= 0
        or (root.Position - deck.Position).Magnitude > cfg.release_distance
    then
        return { ok = false, reason = "left_station" }
    end
    -- No server clock, minimum cast duration, reaction verification or luck re-derivation.
    -- A pending receipt also prevents an accidental retry after a partial grant exception.
    self.busy[player] = true
    local receipt = { ok = false, reason = "settling", attempt = args.attempt }
    history.receipts[args.attempt] = receipt
    table.insert(history.order, args.attempt)
    while #history.order > cfg.receipt_limit do
        history.receipts[table.remove(history.order, 1)] = nil
    end
    local ok, err = pcall(function()
        if not args.caught then
            receipt.ok, receipt.caught, receipt.reason = true, false, nil
            return
        end
        local row, tier = Timing.reward(cfg, args.score, self.rng:NextNumber())
        local result = self._modules.RewardService:Grant(
            player,
            row.bundle,
            "crossroads_fishing:" .. args.attempt
        )
        receipt.ok = result and result.ok == true
        receipt.caught, receipt.score, receipt.tier = true, args.score, tier
        receipt.label, receipt.granted = row.label, result and result.granted
        if receipt.ok then
            receipt.reason = nil
        else
            receipt.reason = "grant_failed"
        end
    end)
    if not ok then
        receipt.reason = "grant_failed"
        self._modules.Logger:Warn("Fishing reward could not settle", { error = tostring(err) })
    end
    self.busy[player] = nil
    self._modules.DataService:RequestSave(player, "crossroads_fishing")
    return receipt
end
function Service:Start()
    self._modules.GameAPIService:GetBus():register(self.cfg.command, {
        description = "Save a Crossroads catch using the client's locally stopped luck and escape result.",
        handler = function(context, args)
            return self:Claim(context.player, args)
        end,
    })
    Players.PlayerRemoving:Connect(function(player)
        self.busy[player] = nil
    end)
end
return Service
