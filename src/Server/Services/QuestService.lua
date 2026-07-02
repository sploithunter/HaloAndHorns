--[[
    QuestService — Phase 7 (the condition-gated reward gate).

    Quests are reward bundles gated behind a pure Condition over a snapshot of the
    player's stat counters / level / currencies. Claim-once unless `repeatable`.
    The claim ledger (profile.QuestClaims: defId -> count) is the anti-replay store.
    Grants flow through RewardService. The "Quest" badge = Pending().
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Condition = require(ReplicatedStorage.Shared.Game.Condition)
local ClaimLogic = require(ReplicatedStorage.Shared.Game.ClaimLogic)
local QuestChain = require(ReplicatedStorage.Shared.Game.QuestChain)
local QuestActivation = require(ReplicatedStorage.Shared.Game.QuestActivation)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

local QuestService = {}
QuestService.__index = QuestService

function QuestService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._config = self._configLoader:LoadConfig("quests")
end

function QuestService:_service(name)
    local locator = _G.RBXTemplateServices
    if not locator then
        return nil
    end
    local ok, service = pcall(function()
        return locator:Get(name)
    end)
    return ok and service or nil
end

-- Build the Condition snapshot from the live player state.
function QuestService:_snapshot(player)
    local stats = self:_service("StatsService")
    local progression = self:_service("PlayerProgressionService")
    local counters = (stats and stats:GetAll(player)) or {}
    local level = (progression and progression:GetLevel(player)) or 1
    local currencies = {}
    local data = self._dataService and self._dataService:GetData(player)
    if data and type(data.Currencies) == "table" then
        for k, v in pairs(data.Currencies) do
            currencies[k] = v
        end
    end
    return { counters = counters, level = level, currencies = currencies }
end

local function claims(data)
    if type(data.QuestClaims) ~= "table" then
        data.QuestClaims = {}
    end
    return data.QuestClaims
end

-- QuestBaselines[id] = the counter value at the start of the quest's CURRENT open window (the
-- moment its track was activated / it became the active head). nil = paused / never started.
local function baselines(data)
    if type(data.QuestBaselines) ~= "table" then
        data.QuestBaselines = {}
    end
    return data.QuestBaselines
end

-- QuestBanked[id] = forward progress folded in from PRIOR active windows (so switching away and
-- back doesn't lose what you'd already earned). See Shared/Game/QuestActivation.
local function banked(data)
    if type(data.QuestBanked) ~= "table" then
        data.QuestBanked = {}
    end
    return data.QuestBanked
end

-- A quest is ACTIVATION-GATED iff it measures forward progress (since_start + a counter). Those
-- only accrue while their track is the active focus. Everything else (level/rebirth/visit/own-N)
-- is a milestone that always reads the lifetime total.
local function isGrind(def)
    local c = def and def.condition
    return (c and c.since_start == true and c.counter ~= nil) == true
end

-- Snapshot adjusted for one quest: grind quests read FORWARD progress (banked + open window);
-- milestones read the real lifetime snapshot unchanged.
local function forwardAdjusted(def, questId, snapshot, bases, bank)
    if not isGrind(def) then
        return snapshot
    end
    local counter = def.condition.counter
    local cur = (snapshot.counters and snapshot.counters[counter]) or 0
    local counters = table.clone(snapshot.counters or {})
    counters[counter] = QuestActivation.forward(bank[questId], bases[questId], cur)
    return { counters = counters, level = snapshot.level, currencies = snapshot.currencies }
end

-- The active HEAD of each track (first unlocked, unclaimed mission), as { track -> questId }.
-- Built from QuestChain over the live claim ledger.
function QuestService:_trackHeads(player)
    local ledger = claims(self._dataService:GetData(player))
    local entries = {}
    for id, def in pairs(self._config.defs or {}) do
        table.insert(entries, {
            id = id,
            track = def.track or "origin",
            order = tonumber(def.order) or math.huge,
            claimedCount = ledger[id] or 0,
            repeatable = def.repeatable == true,
        })
    end
    local _, heads = QuestChain.annotate(entries)
    local byTrack = {}
    for id in pairs(heads) do
        local def = self._config.defs[id]
        if def then
            byTrack[def.track or "origin"] = id
        end
    end
    return byTrack
end

-- Enforce the single-focus invariant: EXACTLY one window is open — the active track's grind head.
-- (1) any OTHER open window (a track you switched away from, or stale auto-baselines) gets BANKED so
--     its progress is preserved but frozen; and
-- (2) the active track's grind head gets its window OPENED if it isn't already — the safety net that
--     guarantees the focused branch always accrues, even if the head arrived by a path other than
--     SetActiveTrack/Claim (migration, a missed claim hook, etc.). Without this a focused head could
--     sit stuck at 0 forever (Jason: "earning crystals but the counter's not changing").
-- Idempotent; only saves when state actually changed. `forceAll = true` banks even the active head
-- and skips the open (used by SetActiveTrack, which re-opens the new head itself).
function QuestService:_reconcile(player, forceAll)
    local data = self._dataService:GetData(player)
    local bases = baselines(data)
    local bank = banked(data)
    local heads = self:_trackHeads(player)
    local activeHead = (not forceAll) and data.QuestActiveTrack and heads[data.QuestActiveTrack]
        or nil
    local snapshot = self:_snapshot(player)
    local function counterValue(id)
        local def = self._config.defs[id]
        local counter = def and def.condition and def.condition.counter
        return counter and ((snapshot.counters and snapshot.counters[counter]) or 0) or 0
    end

    local changed = false
    -- (1) bank every open window that isn't the active head
    local toBank = {}
    for id, base in pairs(bases) do
        if base ~= nil and id ~= activeHead then
            table.insert(toBank, id)
        end
    end
    for _, id in ipairs(toBank) do
        bank[id] = QuestActivation.bank(bank[id], bases[id], counterValue(id))
        bases[id] = nil
        changed = true
    end

    -- (2) ensure the active grind head has an OPEN window so it accrues going forward
    if activeHead and bases[activeHead] == nil and isGrind(self._config.defs[activeHead]) then
        bases[activeHead] = counterValue(activeHead)
        changed = true
    end

    if changed then
        self._dataService:RequestSave(player, "quest_reconcile")
    end
end

-- Switch the player's focus to `trackId` (nil clears it). Banks whatever was open, then OPENS the
-- new track's grind head window from NOW (so "Hatch 1,000" counts forward from this moment). Free
-- to switch back and forth — banked progress is never lost.
function QuestService:SetActiveTrack(player, trackId)
    if trackId ~= nil and not (self._config.tracks and self._config.tracks[trackId]) then
        return { ok = false, reason = "unknown_track" }
    end
    local data = self._dataService:GetData(player)
    self:_reconcile(player, true) -- bank ALL open windows (the outgoing focus included)
    data.QuestActiveTrack = trackId
    if trackId then
        local headId = self:_trackHeads(player)[trackId]
        local def = headId and self._config.defs[headId]
        if isGrind(def) and baselines(data)[headId] == nil then
            local snapshot = self:_snapshot(player)
            baselines(data)[headId] = (
                snapshot.counters and snapshot.counters[def.condition.counter]
            ) or 0
        end
    end
    self._dataService:RequestSave(player, "quest_active_track", { critical = true })
    return { ok = true, activeTrack = trackId }
end

-- First Steps is complete once every one of its quests has been claimed at least once.
function QuestService:_firstStepsIncomplete(data)
    local ledger = claims(data)
    for id, def in pairs(self._config.defs or {}) do
        if def.track == "first_steps" and (ledger[id] or 0) == 0 then
            return true
        end
    end
    return false
end

-- ACTIVE-FOCUS invariant (Jason): a quest is the single ACTIVE task. Keep the focus right:
--   • First Steps AUTO-ACTIVATES as the focus until it's done — but only AFTER the tutorial (so its
--     since_start windows baseline post-tutorial; otherwise tutorial casts pre-complete "Boost the
--     Patch"). It OVERRIDES any stale focus (e.g. a reset player still pointed at Warpath).
--   • A focus on a track that's now hidden (below unlock_level) or gone is dropped to nil.
-- Persists via SetActiveTrack (opens/banks the since_start windows). Only writes on an actual change.
function QuestService:_ensureFocus(player, data, level)
    -- Mid-tutorial: leave the focus alone (don't baseline First Steps on tutorial actions). A veteran
    -- with no tutorial state, or a player past it (Tutorial.done), is eligible.
    local tutorialDone = type(data.Tutorial) ~= "table" or data.Tutorial.done == true
    local desired = data.QuestActiveTrack
    local meta = desired and self._config.tracks and self._config.tracks[desired]
    if desired and (not meta or (tonumber(meta.unlock_level) or 1) > level) then
        desired = nil -- stale / hidden focus → clear
    end
    if tutorialDone and self:_firstStepsIncomplete(data) then
        desired = "first_steps" -- onramp owns the focus until complete
    end
    if desired ~= data.QuestActiveTrack then
        self:SetActiveTrack(player, desired)
    end
end

-- "New quests available!" — fire track_unlocked once for each track the player crosses the unlock
-- level for. data.QuestTracksSeen is seeded silently on first eval (so existing high-level players
-- don't get a burst of announces); only LATER crossings (a real level-up) announce.
function QuestService:_announceUnlocks(player, data, level)
    local seen = data.QuestTracksSeen
    local firstEval = seen == nil
    seen = seen or {}
    for trackId, meta in pairs(self._config.tracks or {}) do
        local unlockLevel = tonumber(meta.unlock_level) or 1
        if unlockLevel <= level and not seen[trackId] then
            seen[trackId] = true
            if not firstEval and unlockLevel > 1 then
                fireGameEvent(player, "track_unlocked", {
                    track = trackId,
                    title = meta.title or trackId,
                    name = "🆕 New Quests: " .. (meta.title or trackId) .. "!", -- banner text
                })
            end
        end
    end
    data.QuestTracksSeen = seen
end

function QuestService:List(player)
    self:_reconcile(player) -- keep the single open window honest before reading
    local snapshot = self:_snapshot(player)
    local data = self._dataService:GetData(player)
    if type(data) ~= "table" then
        -- Fresh-join race: a GameAPI quest.list can land before the profile loads. No data yet ->
        -- report no quests rather than nil-indexing (the panel just shows an empty list briefly).
        return { ok = true, quests = {}, activeTrack = nil }
    end
    -- LEVEL-GATED FOCUS (Jason): a quest is an ACTIVE task. Before reading, make sure the single focus
    -- is correct — auto-activate First Steps once the tutorial's done (so its since_start windows
    -- baseline AFTER the tutorial, not pre-completed by tutorial casts) and drop a stale/hidden focus —
    -- then announce any track the player has newly crossed the unlock level for ("New quests
    -- available!"). These persist via SetActiveTrack, so read ledger/bases AFTER them.
    local level = tonumber(player:GetAttribute("Level")) or 1
    self:_ensureFocus(player, data, level)
    self:_announceUnlocks(player, data, level)
    local ledger = claims(data)
    local bases = baselines(data)
    local bank = banked(data)
    local activeTrack = data.QuestActiveTrack
    local tracks = self._config.tracks or {}
    local out = {}
    for id, def in pairs(self._config.defs or {}) do
        local track = def.track or "origin"
        local meta = tracks[track]
        -- HIDDEN UNTIL UNLOCK: a track below its unlock_level doesn't appear at all (Jason: "it's not
        -- even available"). Crossing the level surfaces it + fires the announce above.
        local unlockLevel = (meta and tonumber(meta.unlock_level)) or 1
        if not meta or unlockLevel <= level then
            table.insert(out, {
                id = id,
                def = def,
                track = track,
                trackTitle = (meta and meta.title) or track,
                trackOrder = (meta and tonumber(meta.order)) or math.huge,
                order = tonumber(def.order) or math.huge,
                name = def.name,
                description = def.description,
                reward = def.reward, -- so the panel can summarize the prize (read-only)
                claimedCount = ledger[id] or 0,
                repeatable = def.repeatable == true,
            })
        end
    end
    -- PARALLEL TRACKS, SINGLE FOCUS (Jason): QuestChain locks a mission until every lower-order one
    -- IN ITS TRACK is claimed. since_start quests only accrue while their track is the ACTIVE focus.
    QuestChain.annotate(out)
    table.sort(out, function(a, b)
        if a.trackOrder ~= b.trackOrder then
            return a.trackOrder < b.trackOrder
        end
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.id < b.id
    end)
    for _, q in ipairs(out) do
        local def = q.def
        local grind = isGrind(def)
        local trackActive = (q.track == activeTrack)
        local progress =
            Condition.progress(def.condition, forwardAdjusted(def, q.id, snapshot, bases, bank))
        q.progress = progress
        q.claimable = not q.locked and ClaimLogic.canClaim(progress.met, q.claimedCount, def).ok
        q.activationGated = grind -- needs an active track to make progress
        q.trackActive = trackActive
        -- a grind quest you could be working, but its track isn't the current focus
        q.paused = grind and not trackActive and not q.locked and q.claimedCount == 0
        q.def = nil -- not for the wire
    end
    return { ok = true, quests = out, activeTrack = activeTrack }
end

function QuestService:_isLocked(player, questId)
    local res = self:List(player)
    for _, q in ipairs((res and res.quests) or {}) do
        if q.id == questId then
            return q.locked == true
        end
    end
    return false
end

function QuestService:Claim(player, questId)
    local def = (self._config.defs or {})[questId]
    if not def then
        return { ok = false, reason = "unknown_quest" }
    end
    self:_reconcile(player) -- keep the open window honest before scoring
    local snapshot = self:_snapshot(player)
    local data = self._dataService:GetData(player)
    local ledger = claims(data)
    local met = Condition.isMet(
        def.condition,
        forwardAdjusted(def, questId, snapshot, baselines(data), banked(data))
    )
    local verdict = ClaimLogic.canClaim(met, ledger[questId] or 0, def)
    if not verdict.ok then
        return verdict
    end
    if self:_isLocked(player, questId) then
        return { ok = false, reason = "locked" } -- chain order is server-authoritative
    end

    local rewards = self:_service("RewardService")
    local granted
    if rewards then
        granted = rewards:Grant(player, def.reward, "quest:" .. questId)
    end
    ledger[questId] = (ledger[questId] or 0) + 1
    -- The claimed quest's window is done; close it. If its track is still the active focus, OPEN the
    -- next head's window NOW so the chain keeps counting without re-activating (and no kills/hatches
    -- between this claim and the next poll leak into a late baseline).
    baselines(data)[questId] = nil
    if data.QuestActiveTrack == (def.track or "origin") then
        local nextHead = self:_trackHeads(player)[def.track or "origin"]
        local nd = nextHead and self._config.defs[nextHead]
        if isGrind(nd) and baselines(data)[nextHead] == nil then
            baselines(data)[nextHead] = (
                snapshot.counters and snapshot.counters[nd.condition.counter]
            ) or 0
        end
    end
    self._dataService:RequestSave(player, "quest_claim", { critical = true })
    fireGameEvent(player, "quest_complete", { quest = questId }) -- config-driven fanfare
    return { ok = true, quest = questId, reward = granted and granted.granted }
end

function QuestService:Pending(player)
    local n = 0
    for _, q in ipairs(self:List(player).quests) do
        if q.claimable then
            n += 1
        end
    end
    return n
end

return QuestService
