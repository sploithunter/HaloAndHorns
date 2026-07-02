local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Libraries.Signal)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

local AchievementsService = {}
AchievementsService.__index = AchievementsService

function AchievementsService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._statsService = self._modules.StatsService
    self._economyService = self._modules.EconomyService

    self._config = self._configLoader:LoadConfig("achievements")
    self.Completed = Signal.new()

    -- CLAIMABLE model (Jason 2026-06-29): achievements are NO LONGER auto-granted when a tier is
    -- reached — the player CLAIMS them in the Achievements panel (Claim → _grantTier). So the
    -- CounterChanged auto-grant connection and the on-join EvaluateAll are gone; reaching a goal only
    -- makes its tier *claimable*. EvaluateAll/_grantTier remain for the Studio smoke test.

    self._logger:Info("AchievementsService initialized", {
        context = "AchievementsService",
        achievements = self:_countAchievements(),
    })
end

function AchievementsService:Start()
    -- No-op: achievements are claim-driven now (the player claims reached tiers in the panel), so
    -- there's nothing to auto-grant on join. Kept so boot's Start() call stays valid.
end

function AchievementsService:_countAchievements()
    local count = 0
    for _ in pairs(self._config.achievements or {}) do
        count += 1
    end
    return count
end

function AchievementsService:_ensureAchievements(data)
    data.Achievements = data.Achievements or {}
    data.Achievements.Completed = data.Achievements.Completed or {}
    return data.Achievements
end

-- Runtime locator (RewardService is registered in boot; no boot-time dep cycle).
function AchievementsService:_service(name)
    local locator = _G.RBXTemplateServices
    if not locator then
        return nil
    end
    local ok, service = pcall(function()
        return locator:Get(name)
    end)
    return ok and service or nil
end

-- Translate an achievement tier reward into a RewardBundle. Supports the legacy
-- currency shape ({ type="currency", currency, amount }) and a forward-looking full
-- bundle ({ bundle = { currencies/pets/items/effects/slots } }) so achievements can
-- award anything the reward spine can grant.
local function rewardToBundle(reward)
    if type(reward) ~= "table" then
        return nil
    end
    if type(reward.bundle) == "table" then
        return reward.bundle
    end
    if reward.type == "currency" and reward.currency then
        local amount = tonumber(reward.amount) or 0
        if amount > 0 then
            return { currencies = { [reward.currency] = amount } }
        end
    end
    return nil
end

function AchievementsService:_grantReward(player, reward, source)
    local bundle = rewardToBundle(reward)
    if not bundle then
        return false, "Unsupported reward type"
    end

    -- Prefer the unified reward spine: one audited grant terminal that also handles
    -- items/pets/effects/slots, not just currency.
    local rewardService = self:_service("RewardService")
    if rewardService then
        local res = rewardService:Grant(player, bundle, source or "achievement_reward")
        if res and res.ok then
            return true
        end
    end

    -- Fallback: legacy currency-only path if RewardService is unavailable.
    if reward.type == "currency" then
        local amount = tonumber(reward.amount) or 0
        if amount <= 0 then
            return false, "Invalid reward amount"
        end
        if self._economyService and self._economyService.AddCurrency then
            return self._economyService:AddCurrency(
                player,
                reward.currency,
                amount,
                source or "achievement_reward"
            )
        end
        if self._dataService and self._dataService.AddCurrency then
            return self._dataService:AddCurrency(
                player,
                reward.currency,
                amount,
                source or "achievement_reward"
            )
        end
    end

    return false, "No reward grant service available"
end

function AchievementsService:_grantTier(player, achievement, tier, value)
    local data = self._dataService:GetData(player)
    if not data then
        return false
    end

    local state = self:_ensureAchievements(data)
    state.Completed[achievement.id] = state.Completed[achievement.id] or {}
    if state.Completed[achievement.id][tier.id] then
        return false
    end

    local ok, reason =
        self:_grantReward(player, tier.reward, "achievement_" .. achievement.id .. "_" .. tier.id)
    if not ok then
        self._logger:Warn("Failed to grant achievement reward", {
            context = "AchievementsService",
            player = player.Name,
            achievement = achievement.id,
            tier = tier.id,
            reason = reason,
        })
        return false
    end

    state.Completed[achievement.id][tier.id] = {
        completed_at = os.time(),
        stat = achievement.stat,
        goal = tier.goal,
        value = value,
    }

    local payload = {
        achievementId = achievement.id,
        tierId = tier.id,
        stat = achievement.stat,
        goal = tier.goal,
        value = value,
        reward = tier.reward,
        -- display text for the game_events float (Jason heard the jingle with NOTHING
        -- on screen — "what's going on?"): "🏆 Egg Hatchery 10"
        name = "🏆 " .. tostring(achievement.display_name or achievement.id) .. " " .. tostring(
            tier.goal
        ),
    }

    self.Completed:Fire(player, payload)
    Signals.AchievementCompleted:FireClient(player, payload)
    fireGameEvent(player, "achievement_completed", payload) -- config-driven fanfare (game_events)
    self._dataService:RequestSave(player, "achievement_completed", { critical = true })
    return true
end

function AchievementsService:_evaluateAchievement(player, achievement, value)
    local granted = {}
    for _, tier in ipairs(achievement.tiers or {}) do
        if value >= tier.goal and self:_grantTier(player, achievement, tier, value) then
            table.insert(granted, tier.id)
        end
    end
    return granted
end

-- EvaluateAll grants every reached tier at once — NO LONGER wired to gameplay (achievements are
-- claim-driven). Retained only for the Studio smoke test, which drives it explicitly.
function AchievementsService:EvaluateAll(player)
    local result = {}
    for achievementId, achievement in pairs(self._config.achievements or {}) do
        local value = self._statsService:Get(player, achievement.stat)
        result[achievementId] = self:_evaluateAchievement(player, achievement, value)
    end
    return result
end

function AchievementsService:GetAchievements(player)
    local data = self._dataService:GetData(player)
    local state = data and self:_ensureAchievements(data) or { Completed = {} }
    local result = {}

    for achievementId, achievement in pairs(self._config.achievements or {}) do
        local value = self._statsService:Get(player, achievement.stat)
        result[achievementId] = {
            id = achievement.id,
            category = achievement.category, -- panel grouping
            display_name = achievement.display_name,
            stat = achievement.stat,
            value = value,
            tiers = achievement.tiers,
            completed = state.Completed[achievement.id] or {}, -- now means CLAIMED
        }
    end

    return result
end

-- Category metadata (title/order/icon) for the panel's grouped layout.
function AchievementsService:Categories()
    return self._config.categories or {}
end

-- CLAIM a reached-but-unclaimed achievement tier (Jason: claim button on reached, progress bar
-- otherwise). Grants exactly that tier's reward once; _grantTier fires the fanfare + persists.
function AchievementsService:Claim(player, achievementId, tierId)
    local achievement = self._config.achievements and self._config.achievements[achievementId]
    if not achievement then
        return { ok = false, reason = "unknown_achievement" }
    end
    local tier
    for _, t in ipairs(achievement.tiers or {}) do
        if t.id == tierId then
            tier = t
            break
        end
    end
    if not tier then
        return { ok = false, reason = "unknown_tier" }
    end
    local data = self._dataService:GetData(player)
    if type(data) ~= "table" then
        return { ok = false, reason = "no_data" }
    end
    local state = self:_ensureAchievements(data)
    if state.Completed[achievementId] and state.Completed[achievementId][tierId] then
        return { ok = false, reason = "already_claimed" }
    end
    local value = self._statsService:Get(player, achievement.stat) or 0
    if value < tier.goal then
        return { ok = false, reason = "not_reached" }
    end
    if not self:_grantTier(player, achievement, tier, value) then
        return { ok = false, reason = "grant_failed" }
    end
    return { ok = true, achievementId = achievementId, tierId = tierId, reward = tier.reward }
end

return AchievementsService
