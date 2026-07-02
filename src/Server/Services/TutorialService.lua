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

local TutorialService = {}
TutorialService.__index = TutorialService

function TutorialService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._config = self._configLoader:LoadConfig("tutorial")

    fireGameEvent.tap(function(player, name, ctx)
        self:_onEvent(player, name, ctx)
    end)
end

function TutorialService:Start()
    -- client PULL: TutorialController fires this when it's ready to render — closes the
    -- join race where the one-shot push lands before the client connected the signal
    Signals.TutorialState.OnServerEvent:Connect(function(player)
        if self._dataService:IsDataLoaded(player) then
            self:_ensureProgress(player)
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
    local deadline = os.clock() + 20
    while player.Parent and not self._dataService:IsDataLoaded(player) and os.clock() < deadline do
        task.wait(0.2)
    end
    if player.Parent and self._dataService:IsDataLoaded(player) then
        self:_ensureProgress(player)
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
        local locator = _G.RBXTemplateServices
        local prog = locator and locator:Get("PlayerProgressionService")
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
    local progress, changed = TutorialFlow.advance(self._config, data.Tutorial, name, ctx)
    if not changed then
        return
    end
    data.Tutorial = progress
    self._dataService:RequestSave(player, "tutorial_step")
    self:_push(player)
    self:_applyStepGrant(player, data) -- reward on ENTER (e.g. slot step grants potency + a slot)
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

    local locator = _G.RBXTemplateServices
    if type(grant.enhancements) == "table" and locator then
        local enh = locator:Get("EnhancementService")
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

    self._dataService:RequestSave(player, "tutorial_grant", { critical = true })
end

function TutorialService:_push(player)
    local data = self._dataService:GetData(player)
    if not data then
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
