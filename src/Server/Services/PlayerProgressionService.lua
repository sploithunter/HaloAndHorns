--[[
    PlayerProgressionService

    Config-driven player-level effects. This owns level-derived modifier
    contributions and level rewards such as extra equipped pet slots.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local Players = game:GetService("Players")

local LevelCurve = require(ReplicatedStorage.Shared.Game.LevelCurve)
local LevelTrack = require(ReplicatedStorage.Shared.Game.LevelTrack)
local XpReward = require(ReplicatedStorage.Shared.Game.XpReward)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local VeteranTrack = require(ReplicatedStorage.Shared.Game.VeteranTrack)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)
local EffectiveStats = require(ReplicatedStorage.Shared.Game.EffectiveStats)
local Principal = require(ReplicatedStorage.Shared.Game.Principal)

local PlayerProgressionService = {}
PlayerProgressionService.__index = PlayerProgressionService

function PlayerProgressionService.new()
    local self = setmetatable({}, PlayerProgressionService)
    self._logger = nil
    self._configLoader = nil
    self._dataService = nil
    self._modifierService = nil
    self._config = nil
    return self
end

-- buffs.axes.xp (cap) for the registry fold above; lazy + cached.
function PlayerProgressionService:_xpAxisCfg()
    if not self._xpAxis then
        local ok, buffs = pcall(function()
            return self._modules.ConfigLoader:LoadConfig("buffs")
        end)
        self._xpAxis = (ok and buffs and buffs.axes and buffs.axes.xp) or { cap = 3.0 }
    end
    return self._xpAxis
end

function PlayerProgressionService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._modifierService = self._modules.ModifierService
    self._statsService = self._modules.StatsService
    self._inventoryService = nil
    self._rewardService = nil
    self._enhancementService = nil
    self._config = self._configLoader:LoadConfig("player_progression")
    self._xpConfig = self._config.xp or { mode = "linear", per_level = 100 }
    local okTrack, track = pcall(function()
        return self._configLoader:LoadConfig("level_track")
    end)
    self._levelTrack = (okTrack and type(track) == "table" and track) or {}
    -- Veteran Levels (docs/VETERAN_LEVELS.md): the post-cap XP track. Own config file — the
    -- track is orthogonal to the claim machinery and level_track has in-flight economy edits.
    local okVet, vet = pcall(function()
        return self._configLoader:LoadConfig("veteran")
    end)
    self._veteranConfig = (okVet and type(vet) == "table" and vet) or nil

    local teamPower = self._config.team_power or {}
    local stage = teamPower.stage or "boosts"
    if self:IsEnabled() and teamPower.enabled ~= false and self._modifierService then
        self._modifierService:RegisterProvider(stage, function(context)
            return self:_getTeamPowerContribution(context)
        end)
    end

    self._logger:Info("PlayerProgressionService initialized", {
        context = "PlayerProgressionService",
        enabled = self:IsEnabled(),
        teamPowerStage = stage,
    })
end

function PlayerProgressionService:BindPeerServices(services)
    self._inventoryService = services.InventoryService
    self._rewardService = services.RewardService
    self._enhancementService = services.EnhancementService
end

function PlayerProgressionService:IsEnabled()
    return self._config and self._config.enabled ~= false
end

-- Publish derived level/XP to player attributes so the client HUD can read them
-- without a bespoke remote (Level, XP = xp into current level, XPForNext).
function PlayerProgressionService:Start()
    local function publishLater(player)
        task.spawn(function()
            if self._dataService and self._dataService.IsDataLoaded then
                Readiness.awaitAttribute(player, "DataLoaded", true, 15)
            end
            if player.Parent then
                self:_publish(player)
                -- Catch up any banked FILLER levels on join (e.g. earned offline); training
                -- levels still stall for the altar.
                self:_advanceAuto(player)
                -- RECONCILE the levels_gained mission counter with the actual claimed
                -- level (Jason hit this: at L6 the "Reach Level 5" mission read 0/4 —
                -- the counter only counted claims made AFTER it shipped, walling every
                -- pre-existing profile). claimed-1 = levels gained beyond L1.
                pcall(function()
                    local stats = self._statsService
                    local floor = math.max(0, self:GetClaimedLevel(player) - 1)
                    if (tonumber(stats:Get(player, "levels_gained")) or 0) < floor then
                        stats:Set(player, "levels_gained", floor)
                    end
                end)
            end
        end)
    end
    -- SIDEKICK refresh: joining/leaving a team republishes the combat level immediately
    -- (PartyService stamps TeamLead), so the accuracy/damage curves see the sync at once.
    local function hook(player)
        publishLater(player)
        player:GetAttributeChangedSignal("TeamLead"):Connect(function()
            player:SetAttribute("EffectiveLevel", self:GetEffectiveLevel(player))
        end)
    end
    Players.PlayerAdded:Connect(hook)
    for _, player in ipairs(Players:GetPlayers()) do
        hook(player)
    end
end

function PlayerProgressionService:GetExperience(player)
    if not player or not self._dataService or not self._dataService.GetStat then
        return 0
    end
    return math.max(0, math.floor(tonumber(self._dataService:GetStat(player, "Experience")) or 0))
end

-- EARNED level — derived from total XP (single source of truth), saturated at the cap.
-- Drives combat/egg "how strong is this player" scaling via the `Level` ATTRIBUTE and the
-- claim gate. NOT the reward-eligibility level (that's claimed — see GetLevel below).
function PlayerProgressionService:GetEarnedLevel(player)
    if not player then
        return 1
    end
    return LevelCurve.levelForXp(self:GetExperience(player), self._xpConfig)
end

-- CLAIMED level — what the player has actually claimed via the level-up sequence (stored
-- stat, default 1, never above earned or the cap). This is the REWARD/ELIGIBILITY level:
-- powers, augment slots, equip-slot milestones and the team-power boost all gate on it
-- (they route through GetLevel), so you don't get a level's benefits until you claim it.
function PlayerProgressionService:GetClaimedLevel(player)
    if not player then
        return 1
    end
    local stored = 1
    if self._dataService and self._dataService.GetStat then
        stored = math.floor(tonumber(self._dataService:GetStat(player, "ClaimedLevel")) or 1)
    end
    local earned = self:GetEarnedLevel(player)
    return math.clamp(math.max(1, stored), 1, math.max(1, earned))
end

-- Reward/eligibility gates read GetLevel -> claimedLevel (the choke-point used by
-- PowerService/AugmentationService/QuestService/InventoryService/team-power, so they become
-- claim-gated with no edits). Combat/egg scaling reads the `Level` attribute = earnedLevel.
function PlayerProgressionService:GetLevel(player)
    return self:GetClaimedLevel(player)
end

function PlayerProgressionService:GetPendingLevels(player)
    return math.max(0, self:GetEarnedLevel(player) - self:GetClaimedLevel(player))
end

-- EFFECTIVE level — the COMBAT level every level-diff curve reads (accuracy + damage scaling +
-- pet realization). Today it's just the earned level; the SEAM for teaming: sidekick/exemplar
-- will override this (sync to the team lead) and every curve picks it up via the published
-- `EffectiveLevel` attribute, with no curve rework. NOT an entitlement level (powers/access stay
-- on claimed).
function PlayerProgressionService:GetEffectiveLevel(player)
    if not player then
        return 1
    end
    -- SIDEKICK/EXEMPLAR (task #150, docs/TEAMING.md): a teamed player fights at the TEAM
    -- LEAD's combat level — up (sidekick: an L20 teaming with an L50 lead can actually hit
    -- the lead's content) or down (exemplar). POWER AXIS ONLY by construction: this feeds
    -- the level-diff curves via the EffectiveLevel attribute; entitlements (power picks,
    -- claims, shop) read claimed level. The lead anchors to themself (TeamLead == own name
    -- skips the override), so there is no loop.
    local own = self:GetEarnedLevel(player)
    local leadName = player:GetAttribute("TeamLead")
    if type(leadName) == "string" and leadName ~= "" and leadName ~= player.Name then
        local lead = Players:FindFirstChild(leadName)
        if lead then
            local leadLevel = self:GetEarnedLevel(lead)
            if leadLevel and leadLevel > 0 then
                local offset = -1
                pcall(function()
                    local teaming = require(ReplicatedStorage.Configs:WaitForChild("teaming"))
                    offset = tonumber(teaming.sidekick and teaming.sidekick.level_offset) or offset
                end)
                local anchor = math.max(1, leadLevel + offset)
                if own < anchor then
                    return anchor -- sidekick UP to just below the lead
                elseif own > leadLevel then
                    return leadLevel -- exemplar DOWN to the lead
                end
            end
        end
    end
    -- TEMPORARY ALLIANCE (2026-07-08, docs/TEAMING.md): an UNTEAMED player co-present at a
    -- spawn trigger anchors to the (higher) triggerer via the AllianceAnchor attribute that
    -- BaddieSpawnerService stamps for the encounter. SIDEKICK-UP ONLY — AllianceRules never
    -- lowers anyone. Formal teams above take precedence (the branch only runs unteamed).
    -- The anchor resolves as a PRINCIPAL, not a Player (docs/CREATOR_SUMMON.md): a summoned
    -- level-50 Creator NPC anchors a real alliance, so a nearby low player sidekicks up to it
    -- on this exact path. Players resolve identically to the old Players:FindFirstChild +
    -- GetEarnedLevel pair, so player behaviour is unchanged.
    local allyName = player:GetAttribute("AllianceAnchor")
    if type(allyName) == "string" and allyName ~= "" then
        local anchor = Principal.resolve(allyName, {
            findPlayer = function(name)
                return Players:FindFirstChild(name)
            end,
            earnedLevel = function(p)
                return self:GetEarnedLevel(p)
            end,
        })
        if anchor then
            local anchorLevel = Principal.levelOf(anchor)
            if anchorLevel and anchorLevel > 0 then
                local offset = -1
                pcall(function()
                    local teaming = require(ReplicatedStorage.Configs:WaitForChild("teaming"))
                    offset = tonumber(teaming.sidekick and teaming.sidekick.level_offset) or offset
                end)
                local AllianceRules = require(ReplicatedStorage.Shared.Game.AllianceRules)
                return AllianceRules.effectiveLevel(own, anchorLevel, offset)
            end
        end
    end
    return own
end

-- Progress object at the EARNED level (used by AddExperience/SetLevel return values).
function PlayerProgressionService:GetProgress(player)
    return LevelCurve.progress(self:GetExperience(player), self._xpConfig)
end

-- XP-bar progress relative to the CLAIMED level's window: fills toward the next unclaimed
-- level, so a full bar means "a level-up is waiting to be claimed". Saturates at the cap.
function PlayerProgressionService:_claimedProgress(player, claimed)
    local maxLevel = math.floor(tonumber(self._xpConfig.max_level) or 0)
    if maxLevel > 0 and claimed >= maxLevel then
        return { xpIntoLevel = 0, xpForNext = 0 } -- MAX
    end
    local xp = self:GetExperience(player)
    local base = LevelCurve.xpForLevel(claimed, self._xpConfig)
    local step = LevelCurve.stepCost(claimed, self._xpConfig)
    local into = math.clamp(xp - base, 0, step)
    return { xpIntoLevel = into, xpForNext = step }
end

-- Roblox's built-in player list only displays values parented under a lowercase
-- `leaderstats` folder. Level remains derived from XP; this IntValue is a replicated
-- presentation mirror, never another persistence/source-of-truth field.
function PlayerProgressionService:_publishNativeLevel(player, level)
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats and not leaderstats:IsA("Folder") then
        self._logger:Warn("Cannot publish native Level: leaderstats is not a Folder", {
            player = player.Name,
            className = leaderstats.ClassName,
            context = "PlayerProgressionService",
        })
        return
    end
    if not leaderstats then
        leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player
    end

    local nativeLevel = leaderstats:FindFirstChild("Level")
    if nativeLevel and not nativeLevel:IsA("IntValue") then
        self._logger:Warn("Cannot publish native Level: existing value is not an IntValue", {
            player = player.Name,
            className = nativeLevel.ClassName,
            context = "PlayerProgressionService",
        })
        return
    end
    if not nativeLevel then
        nativeLevel = Instance.new("IntValue")
        nativeLevel.Name = "Level"
        nativeLevel:SetAttribute("IsPrimary", true)
        nativeLevel.Parent = leaderstats
    end
    nativeLevel.Value = math.max(1, math.floor(tonumber(level) or 1))
end

-- Mirror earned/claimed level + XP onto player attributes for the HUD.
--   Level        = earnedLevel (combat/egg scaling — unchanged from before)
--   ClaimedLevel = the HUD badge / claim gate
--   PendingLevels= earned - claimed (drives the "LEVEL UP!" button), clamped to remaining
--   XP/XPForNext = progress within the next UNCLAIMED level
function PlayerProgressionService:_publish(player)
    if not player then
        return
    end
    local earned = self:GetEarnedLevel(player)
    -- LEVEL EARNED (Jason: the world moment is "when the bar changes to the blinking
    -- arrow" — not the claim): fire once per earned-level increase. The epic level-up
    -- animation + sound hang off THIS event (world_sound row in game_events).
    self._lastEarned = self._lastEarned or {}
    local prevEarned = self._lastEarned[player]
    self._lastEarned[player] = earned
    if prevEarned ~= nil and earned > prevEarned then
        fireGameEvent(player, "level_earned", { level = earned })
    end
    local claimed = self:GetClaimedLevel(player)
    local maxLevel = math.floor(tonumber(self._xpConfig.max_level) or 0)
    local remaining = maxLevel > 0 and math.max(0, maxLevel - claimed) or math.huge
    local pending = math.min(math.max(0, earned - claimed), remaining)
    local prog = self:_claimedProgress(player, claimed)
    player:SetAttribute("Level", earned)
    self:_publishNativeLevel(player, earned)
    player:SetAttribute("ClaimedLevel", claimed)
    -- Combat level the level-diff curves read (Accuracy + LevelScale). = earned today; teaming
    -- will override this attribute to sync sidekicks/exemplars to the team lead.
    player:SetAttribute("EffectiveLevel", self:GetEffectiveLevel(player))
    -- SIDEKICK cascade: this player's earned level anchors their teammates' combat level —
    -- when the LEAD levels, every member synced to them re-derives (members are never anyone
    -- else's anchor, so this fans out exactly one hop).
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and other:GetAttribute("TeamLead") == player.Name then
            other:SetAttribute("EffectiveLevel", self:GetEffectiveLevel(other))
        end
    end
    player:SetAttribute("PendingLevels", pending)
    player:SetAttribute("PendingTraining", self:GetPendingTraining(player))
    player:SetAttribute("XP", prog.xpIntoLevel)
    player:SetAttribute("XPForNext", prog.xpForNext)
    -- Total lifetime XP (monotonic; KEEPS growing past the level cap since AddExperience always
    -- adds even when the derived level saturates). The per-level `XP` above freezes at the cap, so
    -- the dev XP-rate bar reads this instead — it stays "spinning" at level 50.
    player:SetAttribute("XPTotal", self:GetExperience(player))
    -- VETERAN LEVELS (docs/VETERAN_LEVELS.md): at the cap the overflow XP becomes the vet track —
    -- 50 stays the BUILD cap (no stats; Rebirth/dragons is the other branch), every
    -- veteran.xp_per_level past it = a vet level paying enhancement rolls + status milestones.
    -- PlayerBar reads these to turn the pegged XP bar into the vet bar.
    local vetCfg = self._veteranConfig
    if vetCfg and vetCfg.enabled and maxLevel > 0 and claimed >= maxLevel then
        local capXp = LevelCurve.xpForLevel(maxLevel, self._xpConfig)
        local vet = VeteranTrack.progress(self:GetExperience(player), capXp, vetCfg)
        player:SetAttribute("VetLevel", vet.level)
        player:SetAttribute("VetXP", vet.into)
        player:SetAttribute("VetXPForNext", vet.step)
        self:_veteranPass(player, vet.level)
    end
    -- +1 egg max-hatch per claimed level (climbs ~3 -> ~52). HatchEntitlementService reads this
    -- `MaxEggHatchCount` override (clamped to its hard cap). Synced off CLAIMED level so the bump
    -- is part of the level-up reward. (If a gamepass later also grants hatch count, combine via
    -- max() here instead of overwriting.)
    player:SetAttribute("MaxEggHatchCount", LevelTrack.eggHatchForLevel(claimed, self._levelTrack))
end

-- VETERAN pass: pay out every vet level earned since the last payout (data.VeteranPaid is the
-- once-only ledger — offline/downtime overflow pays on the next publish). Each level grants
-- enhancement cog rolls (VeteranTrack.rollsFor — base + the premium beat; the player's current
-- area flavors the origin like world drops) and fires the veteran_level celebration, with
-- milestone=true on the announce beat (titles/world announcements hang off that later).
function PlayerProgressionService:_veteranPass(player, vetLevel)
    if not vetLevel or vetLevel <= 0 then
        return
    end
    local data = self._dataService and self._dataService:GetData(player)
    if not data then
        return
    end
    local paid = tonumber(data.VeteranPaid) or 0
    if vetLevel <= paid then
        return
    end
    local cfg = self._veteranConfig
    local enh = self._enhancementService
    -- No granter, no payout, NO ledger advance — a vet level must never be marked paid while the
    -- reward silently no-ops (that burned the first back-pay; the level stays owed until it pays).
    if not (enh and enh.RollDrop and enh.Grant) then
        return
    end
    local areaId = player:GetAttribute("CurrentArea")
    local grantedAny = false
    for lvl = paid + 1, vetLevel do
        local rolls = VeteranTrack.rollsFor(lvl, cfg)
        for _ = 1, rolls do
            if enh and enh.RollDrop and enh.Grant then
                local rec =
                    enh:RollDrop(nil, areaId, { playerLevel = player:GetAttribute("Level") })
                if rec then
                    -- #274: pure-data grants; ONE FlushBucket after the back-pay loop
                    enh:Grant(player, rec, { deferFlush = true })
                    grantedAny = true
                end
            end
        end
        fireGameEvent(player, "veteran_level", {
            level = lvl,
            rolls = rolls,
            milestone = VeteranTrack.isMilestone(lvl, cfg),
        })
    end
    data.VeteranPaid = vetLevel
    if grantedAny then -- the one flush pairing the deferFlush grants above (#274)
        local inventory = self._inventoryService
        if inventory and inventory.FlushBucket then
            inventory:FlushBucket(player, "enhancements", "veteran_backpay")
        end
    end
    self._dataService:RequestSave(player, "veteran_level")
end

-- Grant XP (the spine awards XP via RewardService -> here). `source` is an optional configured
-- activity key such as "mining" or "combat"; every source still resolves and mutates XP here.
-- Returns the new progress.
function PlayerProgressionService:AddExperience(player, amount, source)
    amount = math.floor(tonumber(amount) or 0)
    if not player or amount <= 0 or not self._dataService then
        return self:GetProgress(player)
    end
    -- XP Surge (xp axis): the player's xp buff boosts EVERY xp source (mining/combat/rewards) by
    -- its fraction. Single choke point so the multiplier applies everywhere.
    -- XP buff fold via THE registry (EffectiveStats — SSOT doctrine): same
    -- list as the published Eff_XP; BuffStack applies the axis cap (3.0).
    local xpMult = EffectiveStats.multiplier("xp", function(name)
        return player:GetAttribute(name)
    end, os.time(), self:_xpAxisCfg())
    if xpMult ~= 1 then
        amount = math.floor(amount * xpMult + 0.5)
    end
    -- Thriving Thursday (xp_multiplier global event): same choke point, additive fraction.
    local eventService = self._eventService
    if eventService == nil and self._modules then
        eventService = self._modules.EventService
        self._eventService = eventService
    end
    if eventService then
        local m = tonumber(eventService:GetModifier("xp_multiplier", 0)) or 0
        if m > 0 then
            amount = math.floor(amount * (1 + m) + 0.5)
        end
    end
    -- VIP pass (profile multiplier, monetization.lua benefits.multipliers.xp):
    -- same choke point as every other XP fold. Was WRITTEN by the pass grant
    -- but never read until the 2026-07-16 gamepass audit.
    do
        local vipMult = tonumber(self._dataService:GetMultiplier(player, "xp")) or 1
        if vipMult ~= 1 then
            amount = math.floor(amount * vipMult + 0.5)
        end
    end
    -- EARLY-GAME ONRAMP (leveling.onramp): the 1-to-5 climb earns boosted XP
    -- (Jason: "just the bottom end of the curve needs up") — same single
    -- choke point as every other XP multiplier.
    do
        if self._onrampCfg == nil then
            local ok, lvl = pcall(function()
                return self._configLoader:LoadConfig("leveling")
            end)
            self._onrampCfg = (ok and type(lvl) == "table" and lvl.onramp) or false
        end
        amount = XpReward.applyOnramp(
            amount,
            tonumber(player:GetAttribute("Level")) or 1,
            self._onrampCfg,
            source
        )
    end
    local newXp = self:GetExperience(player) + amount
    self._dataService:SetStat(player, "Experience", newXp)
    self:_publish(player)
    -- Hybrid: auto-claim filler levels in the field; training levels stall for the altar.
    self:_advanceAuto(player)
    return self:GetProgress(player)
end

-- Set the player to exactly `level` by writing the curve's threshold XP (used by the
-- test override + any admin grant). Level stays a pure function of XP.
function PlayerProgressionService:SetLevel(player, level)
    if not player or not self._dataService then
        return self:GetProgress(player)
    end
    local target = math.max(1, math.floor(tonumber(level) or 1))
    local xp = LevelCurve.xpForLevel(target, self._xpConfig)
    self._dataService:SetStat(player, "Experience", xp)
    -- Admin/reset set-level gives a fully-CLAIMED level (not one owing claims), so the player
    -- immediately has that level's powers/slots/boosts and no pending level-ups.
    self._dataService:SetStat(player, "ClaimedLevel", target)
    self:_publish(player)
    return self:GetProgress(player)
end

-- Bank `count` EARNED levels WITHOUT claiming them — raises Experience to the new earned threshold
-- but leaves ClaimedLevel, so the player now OWES that many level-ups (pending). This is the
-- testing/admin counterpart to SetLevel (which fully claims): it lets you walk the real claim flow.
function PlayerProgressionService:BankLevels(player, count)
    if not player or not self._dataService then
        return self:GetClaimState(player)
    end
    local maxLevel = (self._levelTrack and self._levelTrack.max_level) or 50
    local earned = self:GetEarnedLevel(player)
    local target = math.clamp(earned + math.max(1, math.floor(tonumber(count) or 1)), 1, maxLevel)
    self._dataService:SetStat(player, "Experience", LevelCurve.xpForLevel(target, self._xpConfig))
    -- ClaimedLevel intentionally untouched -> pending = target - claimed.
    self:_publish(player)
    return self:GetClaimState(player)
end

-- Fast-forward XP to one point beyond the NEXT earned-level threshold (testing/admin). This banks
-- exactly one new earned level without claiming it, so the normal power/gate choice still runs.
-- No-op at max level.
function PlayerProgressionService:GrantNextLevel(player)
    if not player or not self._dataService then
        return self:GetClaimState(player)
    end
    local maxLevel = (self._levelTrack and self._levelTrack.max_level) or 50
    local earned = self:GetEarnedLevel(player)
    if earned >= maxLevel then
        return self:GetClaimState(player)
    end
    local nextXp = LevelCurve.xpForLevel(earned + 1, self._xpConfig)
    self._dataService:SetStat(player, "Experience", nextXp + 1)
    self:_publish(player)
    return self:GetClaimState(player)
end

-- Pay out a claimed level's reward bundle (per-level + milestone) via RewardService, so the
-- audit ledger + fan-out (currencies/items/pets) are shared with every other reward source.
function PlayerProgressionService:_grantLevelRewards(player, entry)
    local rewardService = self._rewardService
    if not rewardService or not rewardService.Grant then
        return
    end
    if type(entry.rewards) == "table" then
        rewardService:Grant(player, entry.rewards, "level_up:" .. tostring(entry.level))
    end
    if type(entry.milestoneRewards) == "table" then
        rewardService:Grant(
            player,
            entry.milestoneRewards,
            "level_milestone:" .. tostring(entry.level)
        )
    end
end

-- Read-only claim state for the HUD / level-up sequence (the levelup.getState command).
function PlayerProgressionService:GetClaimState(player)
    local claimed = self:GetClaimedLevel(player)
    local earned = self:GetEarnedLevel(player)
    local r = LevelTrack.resolve(claimed, earned, self._levelTrack)
    local nextEntry = r.nextLevel and LevelTrack.entryForLevel(r.nextLevel, self._levelTrack) or nil
    return {
        claimedLevel = claimed,
        earnedLevel = earned,
        pendingLevels = r.pendingLevels,
        pendingTraining = self:GetPendingTraining(player),
        canClaim = r.canClaim,
        nextLevel = r.nextLevel,
        nextRequiresAltar = nextEntry and nextEntry.requiresAltar or false,
        atMax = r.atMax,
        maxLevel = r.maxLevel,
        nextEntry = nextEntry,
    }
end

-- Count of TRAINING levels owed (in (claimed, earned]) — power/slot/milestone levels that must
-- be claimed at the Ascension Altar. Drives the HUD nudge + the altar prompt.
function PlayerProgressionService:GetPendingTraining(player)
    local claimed = self:GetClaimedLevel(player)
    local earned = self:GetEarnedLevel(player)
    local maxLevel = math.floor(tonumber(self._xpConfig.max_level) or 0)
    if maxLevel > 0 then
        earned = math.min(earned, maxLevel)
    end
    local count = 0
    for lvl = claimed + 1, earned do
        if LevelTrack.entryForLevel(lvl, self._levelTrack).requiresAltar then
            count += 1
        end
    end
    return count
end

-- Apply ONE level: advance ClaimedLevel, pay its rewards, republish, and fire LevelUp_Claimed.
-- `auto` distinguishes a field auto-claim (filler -> client toast) from an altar claim (training
-- -> client reveal modal). Shared by _advanceAuto and ClaimLevel.
function PlayerProgressionService:_applyLevel(player, newLevel, auto, silent, skipProjection)
    self._dataService:SetStat(player, "ClaimedLevel", newLevel)
    local entry = LevelTrack.entryForLevel(newLevel, self._levelTrack)
    -- Gate-then-pay with a REVERT (2026-07-07 transaction audit): ClaimedLevel advanced first,
    -- so a throw inside the reward grant used to eat the level's bundle permanently (marked
    -- claimed, never paid, unreachable). A failed grant now rolls the gate back — the level
    -- stays claimable and the retry pays it.
    local okGrant, grantErr = pcall(function()
        self:_grantLevelRewards(player, entry)
    end)
    if not okGrant then
        self._dataService:SetStat(player, "ClaimedLevel", newLevel - 1)
        if self._logger then
            self._logger:Warn("Level reward grant failed; claim reverted", {
                player = player.Name,
                level = newLevel,
                error = tostring(grantErr),
            })
        end
        return false
    end
    -- Equipped-pet slots are derived from LEVEL (GetEquippedPetSlotBonus, read in
    -- InventoryService:_getMaxEquippedSlots → the PetEquipSlots attribute the Pets window draws).
    -- Re-run the projection so a milestone slot appears LIVE — without this it only refreshed on the
    -- next relog (Jason: "ascended to 8, no new pet slot until I logged out and back in").
    if not skipProjection then -- catch-up loops pass true and rebuild ONCE after (#274)
        local inventory = self._inventoryService
        if inventory and inventory.RebuildPetProjections then
            pcall(function()
                inventory:RebuildPetProjections(player)
            end)
        end
    end
    self:_publish(player)
    local payload = {
        level = newLevel,
        kind = entry.kind,
        powerPick = entry.powerPick,
        slots = entry.slots,
        milestone = entry.milestone,
        requiresAltar = entry.requiresAltar,
        eggHatchTotal = entry.eggHatchTotal,
        auto = auto == true,
        pendingLevels = self:GetPendingLevels(player),
        pendingTraining = self:GetPendingTraining(player),
    }
    if not silent then
        pcall(function()
            Signals.LevelUp_Claimed:FireClient(player, payload)
        end)
    end
    return entry, payload
end

-- Auto-claim consecutive FILLER (non-altar) levels in the field. Stops at a training level (so
-- the power/slot/milestone choice is made at the altar) or the cap. Called after AddExperience
-- and after an altar claim. The `requiresAltar` break is the single guard that keeps a choice
-- level from ever being silently claimed.
function PlayerProgressionService:_advanceAuto(player)
    if not player or not self._dataService then
        return
    end
    local maxLevel = math.floor(tonumber(self._xpConfig.max_level) or 0)
    local guard = 0
    local applied = 0
    while guard < 200 do
        guard += 1
        local claimed = self:GetClaimedLevel(player)
        local earned = self:GetEarnedLevel(player)
        if claimed >= earned then
            break
        end
        if maxLevel > 0 and claimed >= maxLevel then
            break
        end
        local nextLevel = claimed + 1
        if LevelTrack.entryForLevel(nextLevel, self._levelTrack).requiresAltar then
            break -- stall: this level must be trained at the altar
        end
        -- skipProjection: a big catch-up used to run a FULL RebuildPetProjections per level
        -- (up to 200 in one synchronous loop, #274) — the single rebuild below covers them all
        if not self:_applyLevel(player, nextLevel, true, nil, true) then
            break -- grant failed + gate reverted: stop, don't spin the guard retrying
        end
        applied += 1
    end
    if applied > 0 then -- the ONE projection rebuild for every level just applied
        local inventory = self._inventoryService
        if inventory and inventory.RebuildPetProjections then
            pcall(function()
                inventory:RebuildPetProjections(player)
            end)
        end
    end
end

-- Claim ONE pending level explicitly (the Ascension Altar / bus path — typically a TRAINING
-- level, since field filler auto-claims). Synchronous compare-and-increment: a mismatched
-- `expectedLevel` rejects, so a double-claim race is a harmless no-op. After claiming, roll any
-- subsequent filler via _advanceAuto. Fires the reveal modal (auto=false).
-- `silent` skips the LevelUp_Claimed reveal signal — used by the atomic levelup.commit (the menu is
-- already open and drives the reveal itself, so re-firing would re-open it).
function PlayerProgressionService:ClaimLevel(player, expectedLevel, silent)
    if not player or not self._dataService then
        return { ok = false, reason = "no_data" }
    end
    local claimed = self:GetClaimedLevel(player)
    local earned = self:GetEarnedLevel(player)
    local maxLevel = math.floor(tonumber(self._xpConfig.max_level) or 0)

    if expectedLevel ~= nil and math.floor(tonumber(expectedLevel) or -1) ~= claimed then
        return { ok = false, reason = "stale_level", claimedLevel = claimed }
    end
    if claimed >= earned then
        return { ok = false, reason = "nothing_to_claim", claimedLevel = claimed }
    end
    if maxLevel > 0 and claimed >= maxLevel then
        return { ok = false, reason = "at_max_level", claimedLevel = claimed }
    end

    local newLevel = claimed + 1
    local entry = self:_applyLevel(player, newLevel, false, silent)
    if not entry then -- grant failed, gate reverted: the level is still claimable
        return { ok = false, reason = "grant_failed", claimedLevel = self:GetClaimedLevel(player) }
    end
    self:_advanceAuto(player) -- auto-claim any filler that follows the trained level
    -- bus source (no default reactions — the client LevelUpController owns the level_up juice;
    -- this is the SERVER-truth signal consumers like the tutorial need)
    fireGameEvent(player, "level_claimed", { level = self:GetClaimedLevel(player) })
    if self._statsService then -- mission counter (Origin Story "Reach Level N")
        pcall(function()
            self._statsService:Increment(player, "levels_gained", 1)
        end)
    end

    return {
        ok = true,
        claimedLevel = self:GetClaimedLevel(player),
        pendingLevels = self:GetPendingLevels(player),
        pendingTraining = self:GetPendingTraining(player),
        entry = entry,
    }
end

function PlayerProgressionService:_getMilestoneCount(level, rewardConfig)
    if type(rewardConfig) ~= "table" or rewardConfig.enabled == false then
        return 0
    end

    level = math.max(1, math.floor(tonumber(level) or 1))
    local startLevel = math.max(1, math.floor(tonumber(rewardConfig.start_level) or 1))
    local everyLevels = math.max(1, math.floor(tonumber(rewardConfig.every_levels) or 1))
    if level < startLevel then
        return 0
    end

    return math.floor((level - startLevel) / everyLevels) + 1
end

function PlayerProgressionService:GetEquippedPetSlotBonus(player)
    if not self:IsEnabled() then
        return 0
    end

    local rewards = self._config.level_rewards or {}
    local equipSlots = rewards.equip_slots or {}
    local petSlots = equipSlots.pets or {}
    local milestones = self:_getMilestoneCount(self:GetLevel(player), petSlots)
    local perMilestone = math.max(0, math.floor(tonumber(petSlots.slots_per_milestone) or 0))
    local maxBonus = math.max(0, math.floor(tonumber(petSlots.max_bonus_slots) or 0))
    local bonus = milestones * perMilestone
    if maxBonus > 0 then
        bonus = math.min(bonus, maxBonus)
    end
    return math.max(0, bonus)
end

function PlayerProgressionService:_getTeamPowerContribution(context)
    if type(context) ~= "table" or context.kind ~= "team_power" or not context.player then
        return {}
    end

    local teamPower = self._config.team_power or {}
    if teamPower.enabled == false then
        return {}
    end

    local level = self:GetLevel(context.player)
    local startLevel = math.max(1, math.floor(tonumber(teamPower.start_level) or 1))
    local effectiveLevels = math.max(0, level - startLevel)
    local perLevel = tonumber(teamPower.percent_per_level) or 0
    local maxBonus = tonumber(teamPower.max_bonus_percent) or 0
    local bonus = math.max(0, effectiveLevels * perLevel)
    if maxBonus > 0 then
        bonus = math.min(bonus, maxBonus)
    end
    if bonus <= 0 then
        return {}
    end

    return {
        {
            id = "player_level_team_power",
            label = "Player Level",
            combine = "multiply",
            amount = 1 + bonus,
        },
    }
end

return PlayerProgressionService
