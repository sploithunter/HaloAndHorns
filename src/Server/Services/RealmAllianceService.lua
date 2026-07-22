--[[
    RealmAllianceService — temporary alliances around live Heaven/Hell cave patrols.

    This intentionally runs beside, rather than inside, BaddieSpawnerService. Homeworld
    alliances have special first-fight/newcomer cadence; realm players have already passed
    that onboarding and only need the straightforward mixed-level patrol rule. While one
    patrol group is alive, the highest-level nearby unteamed player anchors eligible lower
    players. The alliance dissolves after the group dies or a member leaves the cave area.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AllianceRules = require(ReplicatedStorage.Shared.Game.AllianceRules)

local RealmAllianceService = {}
RealmAllianceService.__index = RealmAllianceService

function RealmAllianceService.new()
    return setmetatable({}, RealmAllianceService)
end

function RealmAllianceService:Init()
    self._logger = self._modules.Logger
    self._enemyService = self._modules.EnemyService
    self._playerProgressionService = self._modules.PlayerProgressionService
    self._statsService = self._modules.StatsService
    local ok, teaming = pcall(function()
        return self._modules.ConfigLoader:LoadConfig("teaming")
    end)
    self._teaming = (ok and teaming) or {}
    -- [lowPlayer] = { anchor, cave, lingerUntil }
    self._alliances = {}
end

function RealmAllianceService:_republishEffective(player)
    pcall(function()
        if self._playerProgressionService and self._playerProgressionService.GetEffectiveLevel then
            player:SetAttribute(
                "EffectiveLevel",
                self._playerProgressionService:GetEffectiveLevel(player)
            )
        end
    end)
end

function RealmAllianceService:_publishAllianceGroup(anchor)
    if not anchor or not anchor.Parent then
        return
    end
    local names = { anchor.Name }
    local lows = {}
    for low, rec in pairs(self._alliances) do
        if rec.anchor == anchor and low.Parent then
            lows[#lows + 1] = low
            names[#names + 1] = low.Name
        end
    end
    if #lows == 0 then
        anchor:SetAttribute("AllianceWith", nil)
        return
    end
    table.sort(names)
    local function otherNames(playerName)
        local others = {}
        for _, name in ipairs(names) do
            if name ~= playerName then
                others[#others + 1] = name
            end
        end
        return table.concat(others, ",")
    end
    anchor:SetAttribute("AllianceWith", otherNames(anchor.Name))
    for _, low in ipairs(lows) do
        low:SetAttribute("AllianceWith", otherNames(low.Name))
    end
end

function RealmAllianceService:_dissolve(low, reason)
    local rec = self._alliances[low]
    if not rec then
        return
    end
    self._alliances[low] = nil
    if low.Parent then
        low:SetAttribute("AllianceAnchor", nil)
        low:SetAttribute("AllianceWith", nil)
        self:_republishEffective(low)
    end
    self:_publishAllianceGroup(rec.anchor)
    self._logger:Info("Realm temporary alliance dissolved", {
        low = low.Name,
        anchor = rec.anchor and rec.anchor.Name or "?",
        cave = rec.cave and rec.cave.Name or "?",
        reason = reason,
    })
end

function RealmAllianceService:_ownsAsAnchor(player, cave)
    for _, rec in pairs(self._alliances) do
        if rec.anchor == player and rec.cave == cave then
            return true
        end
    end
    return false
end

function RealmAllianceService:_currentAnchor(cave)
    for _, rec in pairs(self._alliances) do
        if rec.cave == cave and rec.anchor and rec.anchor.Parent then
            return rec.anchor
        end
    end
    return nil
end

function RealmAllianceService:_nearbyCandidates(cave, radius)
    local candidates = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player:GetAttribute("TeamId") == nil then
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            local near = hrp and (hrp.Position - cave.Position).Magnitude <= radius
            local ownLow = self._alliances[player]
            local ownedHere = (ownLow and ownLow.cave == cave) or self:_ownsAsAnchor(player, cave)
            local hasForeignAlliance = (
                player:GetAttribute("AllianceAnchor") ~= nil
                or player:GetAttribute("AllianceWith") ~= nil
            ) and not ownedHere
            if near and not hasForeignAlliance then
                candidates[#candidates + 1] = player
            end
        end
    end
    table.sort(candidates, function(a, b)
        local aLevel = tonumber(a:GetAttribute("Level")) or 1
        local bLevel = tonumber(b:GetAttribute("Level")) or 1
        if aLevel == bLevel then
            return a.UserId < b.UserId
        end
        return aLevel > bLevel
    end)
    return candidates
end

function RealmAllianceService:_form(low, anchor, cave)
    local existing = self._alliances[low]
    if existing and existing.anchor == anchor and existing.cave == cave then
        existing.lingerUntil = nil
        return
    end
    if existing then
        self:_dissolve(low, "reanchored")
    end
    self._alliances[low] = { anchor = anchor, cave = cave }
    low:SetAttribute("AllianceAnchor", anchor.Name)
    self:_republishEffective(low)
    self:_publishAllianceGroup(anchor)
    pcall(function()
        self._statsService:Increment(low, "alliances_formed", 1)
        self._statsService:Increment(anchor, "allies_aided", 1)
    end)
    self._logger:Info("Realm temporary alliance formed", {
        low = low.Name,
        anchor = anchor.Name,
        cave = cave.Name,
    })
end

function RealmAllianceService:_realmCaves()
    local caves = {}
    local maps = Workspace:FindFirstChild("Maps")
    if not maps then
        return caves
    end
    for _, folder in ipairs(maps:GetChildren()) do
        if folder.Name:match("^Heaven_%d+$") or folder.Name:match("^Hell_%d+$") then
            for _, part in ipairs(folder:GetChildren()) do
                if part:IsA("BasePart") and part.Name:match("^BaddieSpawner") then
                    caves[#caves + 1] = part
                end
            end
        end
    end
    return caves
end

function RealmAllianceService:_maintainExisting(now)
    local allianceCfg = self._teaming.alliance or {}
    local radius = tonumber(allianceCfg.dissolve_radius) or 140
    local linger = tonumber(allianceCfg.linger_seconds) or 5
    for low, rec in pairs(self._alliances) do
        if not low.Parent or not rec.anchor.Parent then
            self:_dissolve(low, "player_left")
        elseif low:GetAttribute("TeamId") ~= nil or rec.anchor:GetAttribute("TeamId") ~= nil then
            self:_dissolve(low, "joined_team")
        elseif not rec.cave.Parent then
            self:_dissolve(low, "cave_removed")
        else
            local lowRoot = low.Character and low.Character:FindFirstChild("HumanoidRootPart")
            local anchorRoot = rec.anchor.Character
                and rec.anchor.Character:FindFirstChild("HumanoidRootPart")
            local bothNear = lowRoot
                and anchorRoot
                and (lowRoot.Position - rec.cave.Position).Magnitude <= radius
                and (anchorRoot.Position - rec.cave.Position).Magnitude <= radius
            if not bothNear then
                self:_dissolve(low, "left_area")
            elseif self._enemyService:IsPatrolBandAlive(rec.cave) then
                rec.lingerUntil = nil
            elseif rec.lingerUntil == nil then
                rec.lingerUntil = now + linger
            elseif now >= rec.lingerUntil then
                self:_dissolve(low, "fight_over")
            end
        end
    end
end

function RealmAllianceService:_formAtLivePatrols()
    local allianceCfg = self._teaming.alliance or {}
    if allianceCfg.enabled == false then
        return
    end
    local packCfg = self._teaming.pack or {}
    local radius = tonumber(packCfg.patrol_engaged_radius) or tonumber(packCfg.engaged_radius) or 90
    for _, cave in ipairs(self:_realmCaves()) do
        if self._enemyService:IsPatrolBandAlive(cave) then
            local candidates = self:_nearbyCandidates(cave, radius)
            -- Keep an encounter's original anchor stable. A higher player arriving later should
            -- not create a sidekick chain or rewrite the group mid-fight; after dissolution, the
            -- next patrol selects the then-highest nearby player.
            local anchor = self:_currentAnchor(cave) or candidates[1]
            if anchor then
                local anchorLevel = tonumber(anchor:GetAttribute("Level")) or 1
                for _, low in ipairs(candidates) do
                    if low ~= anchor then
                        local lowLevel = tonumber(low:GetAttribute("Level")) or 1
                        if AllianceRules.shouldAlly(anchorLevel, lowLevel, allianceCfg) then
                            self:_form(low, anchor, cave)
                        end
                    end
                end
            end
        end
    end
end

function RealmAllianceService:Start()
    local elapsed = 0
    self._heartbeat = RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed >= 0.5 then
            elapsed %= 0.5
            self:_maintainExisting(os.clock())
            self:_formAtLivePatrols()
        end
    end)
end

return RealmAllianceService
