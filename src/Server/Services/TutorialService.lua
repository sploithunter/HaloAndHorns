--[[
    TutorialService — event-driven new-player tutorial (configs/tutorial.lua).

    Purely a BUS CONSUMER: it taps fireGameEvent (every server-side gameplay event flows
    through there) and advances the pure TutorialFlow step machine. No gameplay service knows
    the tutorial exists — adding a step is config + (at most) a new sources-only bus fire.

    Progress persists as profile.Tutorial { step, count, done }. Veteran saves (claimed level
    past the config threshold, or any powers already picked) complete silently on first sight —
    only genuinely new players are guided. State pushes to the client over Signals.TutorialState;
    TutorialController renders the objective capsule / egg beacon / UI pulse.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TutorialFlow = require(ReplicatedStorage.Shared.Game.TutorialFlow)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)
local Readiness = require(ReplicatedStorage.Shared.Utils.Readiness)

local TutorialService = {}
TutorialService.__index = TutorialService

function TutorialService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._playerProgressionService = self._modules and self._modules.PlayerProgressionService
    self._enhancementService = self._modules and self._modules.EnhancementService
    self._potionService = self._modules and self._modules.PotionService
    self._hotbarService = self._modules and self._modules.HotbarService
    self._config = self._configLoader:LoadConfig("tutorial")

    fireGameEvent.tap(function(player, name, ctx)
        self:_onEvent(player, name, ctx)
    end)
end

function TutorialService:Start()
    -- client PULL: TutorialController fires this when it's ready to render — closes the
    -- join race where the one-shot push lands before the client connected the signal
    Signals.TutorialStateRequest.OnServerEvent:Connect(function(player)
        if self._dataService:IsDataLoaded(player) then
            local data = self:_ensureProgress(player)
            self:_applyStepGrant(player, data)
            self:_push(player)
        end
    end)
    Players.PlayerAdded:Connect(function(player)
        task.spawn(function()
            self:_waitForDataAndPush(player)
        end)
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            self:_waitForDataAndPush(player)
        end)
    end
end

function TutorialService:_waitForDataAndPush(player)
    if Readiness.awaitAttribute(player, "DataLoaded", true, 20) and player.Parent then
        local data = self:_ensureProgress(player)
        self:_applyStepGrant(player, data)
        self:_push(player)
    end
end

-- First sight of a save decides veteran-vs-new ONCE; after that only advance() mutates.
function TutorialService:_ensureProgress(player)
    local data = self._dataService:GetData(player)
    if not data or type(data.Tutorial) == "table" then
        return data
    end
    local claimed = 0
    pcall(function()
        local prog = self._playerProgressionService
        claimed = prog and prog:GetClaimedLevel(player) or 0
    end)
    local hasProgress = type(data.Powers) == "table" and #data.Powers > 0
    if TutorialFlow.isVeteran(self._config, claimed, hasProgress) then
        data.Tutorial = { step = 1, count = 0, done = true }
    else
        data.Tutorial = TutorialFlow.normalizeProgress(nil)
    end
    self._dataService:RequestSave(player, "tutorial_init")
    return data
end

function TutorialService:_onEvent(player, name, ctx)
    if not (player and player.Parent) or not self._dataService:IsDataLoaded(player) then
        return
    end
    local data = self:_ensureProgress(player)
    if not data or data.Tutorial.done then
        return
    end
    local completedIndex = data.Tutorial.step
    local completedStep = self._config.steps and self._config.steps[completedIndex]
    local progress, changed = TutorialFlow.advance(self._config, data.Tutorial, name, ctx)
    if not changed then
        return
    end
    data.Tutorial = progress
    self._dataService:RequestSave(player, "tutorial_step")
    self:_applyStepGrant(player, data) -- reward on ENTER (e.g. slot step grants potency + a slot)
    self:_push(player)
    if completedStep and (progress.done or progress.step ~= completedIndex) then
        -- One semantic completion event keeps cross-cutting consumers independent from the
        -- tutorial's internal count/sum rules.
        fireGameEvent(player, "tutorial_step_completed", {
            stepId = completedStep.id,
            stepIndex = completedIndex,
        })
    end
    if progress.done then
        -- finishing the LAST step is its own moment: stinger + burst (configs/game_events)
        fireGameEvent(player, "tutorial_complete", {})
    end
    if self._logger then
        self._logger:Info("Tutorial advanced", {
            player = player.Name,
            step = progress.step,
            done = progress.done,
        })
    end
end

-- On ENTERING a step that carries a `grant`, apply it ONCE (idempotent via data.Tutorial.granted).
-- The slot step uses it: 3 natural Potency enhancements + an inherent slot on Resonance so a level-1
-- player has somewhere to drop one. Config-driven so future steps can reward without code.
function TutorialService:_applyStepGrant(player, data)
    if not (data and data.Tutorial) or data.Tutorial.done then
        return
    end
    local step = self._config.steps and self._config.steps[data.Tutorial.step]
    local grant = step and step.grant
    if type(grant) ~= "table" then
        return
    end
    local id = step.id or tostring(data.Tutorial.step)
    data.Tutorial.granted = data.Tutorial.granted or {}
    if data.Tutorial.granted[id] then
        return -- already rewarded this step (rejoin / repeated event)
    end
    data.Tutorial.granted[id] = true
    local grantFailed = false

    if type(grant.hotbar_bind) == "table" then
        local hotbar = self._hotbarService
        if hotbar and hotbar.EnsureBindAt then
            local ok, result = pcall(function()
                return hotbar:EnsureBindAt(player, grant.hotbar_bind.slot, {
                    type = grant.hotbar_bind.type,
                    target = grant.hotbar_bind.target,
                }, "tutorial_hotbar_grant")
            end)
            if not ok or (type(result) == "table" and result.ok == false) then
                grantFailed = true
                if self._logger then
                    self._logger:Warn("tutorial hotbar grant FAILED", {
                        player = player.Name,
                        target = tostring(grant.hotbar_bind.target),
                        err = not ok and tostring(result) or tostring(result and result.reason),
                    })
                end
            end
        else
            grantFailed = true
            if self._logger then
                self._logger:Warn("tutorial hotbar grant SKIPPED — HotbarService not injected", {
                    step = tostring(step.id),
                })
            end
        end
    end

    if type(grant.potions) == "table" then
        local potions = self._potionService
        if potions and potions.Grant then
            for _, g in ipairs(grant.potions) do
                local ok, res = pcall(function()
                    return potions:Grant(player, g.id, g.count or 1)
                end)
                if not ok or (type(res) == "table" and res.ok == false) then
                    self._logger:Warn("tutorial potion grant FAILED", {
                        player = player.Name,
                        potion = tostring(g.id),
                        err = not ok and tostring(res) or tostring(res.reason),
                    })
                end
            end
        else
            -- LOUD (Jason's rule): a missing peer must announce itself, not
            -- silently skip — this exact silence cost a debugging session
            self._logger:Warn("tutorial potion grant SKIPPED — PotionService not injected", {
                step = tostring((self._config.steps[data.Tutorial.step] or {}).id),
            })
        end
    end

    if type(grant.enhancements) == "table" then
        local enh = self._enhancementService
        if enh and enh.Grant then
            for _, e in ipairs(grant.enhancements) do
                for _ = 1, math.max(1, math.floor(tonumber(e.count) or 1)) do
                    pcall(function()
                        enh:Grant(player, {
                            type = e.type,
                            origins = e.origins or {},
                            level = e.level or 1,
                        })
                    end)
                end
            end
        end
    end

    -- Ensure the target power has at least one (inherent, free) slot so the granted enhancement has
    -- somewhere to go — innate powers don't get a pick-time inherent slot, and a level-1 player has no
    -- granted augmentation slots yet. Inherent slots don't draw from the granted pool.
    if type(grant.ensure_slot) == "string" then
        data.Slots = type(data.Slots) == "table" and data.Slots or {}
        local cur = data.Slots[grant.ensure_slot]
        if type(cur) ~= "table" or #cur == 0 then
            data.Slots[grant.ensure_slot] = { { inherent = true } }
        end
    end

    -- A failed service-backed grant must be retried by the next state pull/rejoin. This is safe for
    -- Rally's idempotent EnsureBindAt grant and prevents a transient startup race from stranding the
    -- tutorial while its UI points at an empty slot.
    if grantFailed then
        data.Tutorial.granted[id] = nil
    end
    self._dataService:RequestSave(player, "tutorial_grant", { critical = true })
end

function TutorialService:_push(player)
    local data = self._dataService:GetData(player)
    if not data then
        return
    end
    -- THE PROLOGUE COMES FIRST (Jason: "the tutorial shouldn't even start yet... we do our
    -- battle there, and when that battle is finished we go to tutorial one of ten"). Hold the
    -- tutorial state push while the prologue decision is pending or running; re-push when the
    -- attributes settle. Same decision-based, fail-open pattern as the starter chooser gate —
    -- if PrologueService never initialized, nothing is held.
    local prologueRuns = game:GetService("Workspace"):GetAttribute("PrologueServiceInit") == true
    if
        prologueRuns
        and (player:GetAttribute("InPrologue") or player:GetAttribute("PrologueGate") == nil)
    then
        self._prologueWaiters = self._prologueWaiters or {}
        if not self._prologueWaiters[player] then
            self._prologueWaiters[player] = true
            local function retry()
                if not player.Parent then
                    return
                end
                if
                    not player:GetAttribute("InPrologue")
                    and player:GetAttribute("PrologueGate") ~= nil
                then
                    self._prologueWaiters[player] = nil
                    self:_push(player)
                end
            end
            player:GetAttributeChangedSignal("InPrologue"):Connect(retry)
            player:GetAttributeChangedSignal("PrologueGate"):Connect(retry)
        end
        return
    end
    pcall(function()
        Signals.TutorialState:FireClient(player, TutorialFlow.stateFor(self._config, data.Tutorial))
    end)
end

-- Admin/testing: restart the tutorial for a player (bus command friendly).
function TutorialService:Reset(player)
    local data = self._dataService:GetData(player)
    if not data then
        return { ok = false, reason = "data_not_loaded" }
    end
    data.Tutorial = TutorialFlow.normalizeProgress(nil)
    self._dataService:RequestSave(player, "tutorial_reset")
    self:_push(player)
    return { ok = true }
end

return TutorialService
