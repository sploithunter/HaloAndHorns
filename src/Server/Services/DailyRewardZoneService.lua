--[[
    DailyRewardZoneService — the in-world Daily Reward pad (no menu, no prompt).

    A map-authored "Daily Reward" model sits near the SHOP under Workspace.Maps. Walk
    into its volume and the daily streak AUTO-claims — no ProximityPrompt, no key press
    (Jason: "if you go in there just auto-claim it — no menu — and put a float for maybe
    8 seconds"). Mirrors AscensionAltarService's find-a-named-map-object shape, but the
    trigger is a per-player Heartbeat distance check to the model pivot instead of a
    prompt, so it never fires for pets (only Players are scanned) and fires once per
    entry/day (per-player inside-debounce + DailyService's own claimable gate).

    ORIGIN-COIN REWARD: the daily calendar (configs/daily.lua) pays "area_coins", which
    RewardService normally resolves to the coin of the area you're standing in. Here we
    OVERRIDE that for the claim to the player's ORIGIN biome coin instead — Geomancer ->
    Earth (grass_coins), Pyromancer -> lava_coins, Cryomancer -> ice_coins, Sandwalker ->
    desert_coins. Pre-origin (no archetype yet) defaults to EARTH coins (grass_coins; see
    DECISIONS "Biome Naming" — Earth is the canonical name, grass the frozen currency id).

    On a successful claim we fire the "daily_reward" GameEvents row (configs/game_events.lua)
    with a description string, which renders the lingering ~8s float over the player.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

-- The authored model's name. Confirmed live in a Studio play session (search
-- Workspace.Maps for the "Daily Reward" label). The find falls back to a label-text
-- scan if the exact name ever drifts, but the constant is the primary key.
local MODEL_NAME = "Daily Reward"
local LABEL_FALLBACK = "Daily Reward" -- world-label text used to locate the model if the name drifts

local ENTER_RADIUS = 10 -- studs from the model pivot that count as "inside" (Jason: ~10)
local EXIT_RADIUS = 14 -- leave-and-re-enter hysteresis so a player loitering on the edge can't spam
local CHECK_INTERVAL = 0.3 -- Heartbeat throttle for the per-player distance scan

-- Pre-origin default coin (Earth). grass_coins is the frozen internal id for the
-- player-facing "Earth" biome.
local DEFAULT_ORIGIN_COIN = "grass_coins"

local DailyRewardZoneService = {}
DailyRewardZoneService.__index = DailyRewardZoneService

function DailyRewardZoneService.new()
    local self = setmetatable({}, DailyRewardZoneService)
    self._logger = nil
    self._configLoader = nil
    self._dataService = nil
    self._part = nil -- the BasePart/Model we measure distance to
    self._inside = {} -- [player] = true while standing in the volume (entry debounce)
    self._currencyNames = {} -- currency id -> display name
    self._biomes = nil
    self._archetypes = nil
    return self
end

function DailyRewardZoneService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService

    local function load(name)
        local ok, cfg = pcall(function()
            return self._configLoader:LoadConfig(name)
        end)
        return ok and type(cfg) == "table" and cfg or nil
    end
    self._biomes = load("biomes") or {}
    self._archetypes = load("archetypes") or {}

    -- Currency id -> display name, with Earth as the canonical name for grass_coins
    -- (DECISIONS "Biome Naming"). The frozen id stays grass_coins; players see "Earth".
    local currencies = load("currencies") or {}
    for _, c in ipairs(currencies) do
        if type(c) == "table" and c.id then
            self._currencyNames[c.id] = c.name or c.id
        end
    end
    self._currencyNames.grass_coins = "Earth Coins"
end

function DailyRewardZoneService:_service(name)
    local locator = _G.RBXTemplateServices
    if not locator then
        return nil
    end
    local ok, service = pcall(function()
        return locator:Get(name)
    end)
    return ok and service or nil
end

-- Find the authored model by name anywhere under Workspace; fall back to a model/part
-- that carries the "Daily Reward" world label if the exact name ever drifts.
local function findModel()
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d.Name == MODEL_NAME and (d:IsA("Model") or d:IsA("BasePart")) then
            return d
        end
    end
    -- Label fallback: a TextLabel/BillboardGui/SurfaceGui reading "Daily Reward" — bind
    -- to its nearest Model (or BasePart) ancestor.
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("TextLabel") and string.find(d.Text or "", LABEL_FALLBACK, 1, true) then
            local model = d:FindFirstAncestorWhichIsA("Model")
            if model and model.Parent ~= Workspace.Parent then
                return model
            end
            local part = d:FindFirstAncestorWhichIsA("BasePart")
            if part then
                return part
            end
        end
    end
    return nil
end

-- World-space center we measure player distance against.
function DailyRewardZoneService:_pivot()
    local part = self._part
    if not part then
        return nil
    end
    if part:IsA("Model") then
        return part:GetPivot().Position
    end
    return part.Position
end

-- The player's ORIGIN biome coin: data.Archetype -> archetypes[*].theme -> biomes[theme].currency.
-- Pre-origin (no archetype) -> Earth (grass_coins).
function DailyRewardZoneService:_originCoin(player)
    local data = self._dataService and self._dataService:GetData(player)
    local archetype = data and data.Archetype
    if not archetype then
        return DEFAULT_ORIGIN_COIN
    end
    local archCfg = self._archetypes.archetypes and self._archetypes.archetypes[archetype]
    local theme = archCfg and archCfg.theme
    local biome = theme and self._biomes.biomes and self._biomes.biomes[theme]
    return (biome and biome.currency) or DEFAULT_ORIGIN_COIN
end

local function formatCount(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(n)
    -- thousands separators (25000 -> 25,000) so a big daily reads at a glance
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

-- Build the float description from what was actually granted.
function DailyRewardZoneService:_describe(reward)
    local parts = {}
    for currency, amount in pairs((reward and reward.currencies) or {}) do
        local name = self._currencyNames[currency] or currency
        table.insert(parts, ("+%s %s"):format(formatCount(amount), name))
    end
    for _, pet in ipairs((reward and reward.pets) or {}) do
        local label = pet.variant and (pet.variant .. " " .. pet.id) or tostring(pet.id)
        table.insert(parts, "+" .. label)
    end
    if #parts == 0 then
        return "Reward"
    end
    table.sort(parts) -- stable order regardless of pairs() iteration
    return table.concat(parts, ", ")
end

-- Auto-claim the daily for a player who just entered the volume. Only fires when the
-- streak is actually claimable today; debounced by the caller so it runs once per entry.
function DailyRewardZoneService:_claim(player)
    local daily = self:_service("DailyService")
    if not daily then
        return
    end
    local status = daily:Status(player)
    if not (status and status.claimable) then
        return -- already claimed today (or otherwise not claimable) — no re-grant
    end

    -- Tie the calendar's area_coins to the player's ORIGIN coin for this claim only.
    local originCoin = self:_originCoin(player)
    local rewards = self:_service("RewardService")
    if rewards and rewards.SetAreaCoinOverride then
        rewards:SetAreaCoinOverride(player, originCoin)
    end
    local ok, result = pcall(function()
        return daily:Claim(player)
    end)
    if rewards and rewards.SetAreaCoinOverride then
        rewards:SetAreaCoinOverride(player, nil) -- always clear, even on error
    end

    if not ok or type(result) ~= "table" or not result.ok then
        return
    end

    local streak = result.streak or (status and status.nextStreak) or 0
    local desc = self:_describe(result.reward)
    local text = ("Daily Reward! %s  ·  Streak %d"):format(desc, streak)
    -- Reuse the GameEvents float path (configs/game_events.lua daily_reward, seconds = 8).
    -- No position -> the float anchors over the claiming player's character.
    fireGameEvent(player, "daily_reward", { name = text })

    if self._logger then
        self._logger:Info("DailyRewardZoneService auto-claimed", {
            player = player.Name,
            coin = originCoin,
            streak = streak,
        })
    end
end

-- Per-player distance gate: enter the volume -> claim once; must leave past EXIT_RADIUS
-- before another entry can fire. Only Players are scanned, so pets never trigger it.
function DailyRewardZoneService:_scan()
    local pivot = self:_pivot()
    if not pivot then
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local dist = (root.Position - pivot).Magnitude
            if dist <= ENTER_RADIUS then
                if not self._inside[player] then
                    self._inside[player] = true
                    self:_claim(player)
                end
            elseif dist > EXIT_RADIUS then
                self._inside[player] = nil
            end
        end
    end
end

function DailyRewardZoneService:Start()
    Players.PlayerRemoving:Connect(function(player)
        self._inside[player] = nil
    end)

    -- Map geometry may stream in slightly after boot; retry a few times for the model.
    task.spawn(function()
        for _ = 1, 10 do
            self._part = findModel()
            if self._part then
                break
            end
            task.wait(2)
        end
        if not self._part then
            if self._logger then
                self._logger:Warn("DailyRewardZoneService: daily-reward model not found", {
                    name = MODEL_NAME,
                })
            end
            return
        end
        if self._logger then
            self._logger:Info("DailyRewardZoneService bound", {
                name = self._part.Name,
                class = self._part.ClassName,
            })
        end

        local accumulator = 0
        RunService.Heartbeat:Connect(function(dt)
            accumulator = accumulator + dt
            if accumulator < CHECK_INTERVAL then
                return
            end
            accumulator = 0
            local ok, err = pcall(function()
                self:_scan()
            end)
            if not ok and self._logger then
                self._logger:Warn("DailyRewardZoneService scan error", { error = tostring(err) })
            end
        end)
    end)
end

return DailyRewardZoneService
