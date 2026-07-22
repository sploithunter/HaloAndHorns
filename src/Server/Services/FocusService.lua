--[[
    FocusService — Feature 12 (Player Character / Spirit Presence).

    The player is an ethereal, INVULNERABLE supporter — there is NO health stat. The only player
    resource is Focus, spent on support powers and disrupted by enemy "Sundering" attacks; it
    regenerates over time.

    Focus is RUNTIME-ONLY — held in memory (self._focus), NEVER persisted (Jason). It refills to
    focus_max in focus_max / regen_per_second seconds (~20s), far less than any logout→login gap, so
    a returning player is always effectively full no matter what we'd have saved — persisting it is
    pure wasted datastore writes. So: lazy-init to focus_max, regen in memory, mirror to the HUD via
    the Focus / FocusMax player attributes. No saves anywhere.

    The Focus economy lives here. PowerService:Cast CHARGES a power's focus_cost via FocusService:Cast
    at the commit point (an empty pool refuses the cast with not_enough_focus); cooldown lives with
    the Power system. The pure FocusMath core does the arithmetic.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FocusMath = require(ReplicatedStorage.Shared.Game.FocusMath)

-- Regen cadence: fine enough that a 20s fight doesn't feel stepped (Jason: 1s ≈ 5% of a fight).
-- Runtime-only state means NO per-tick save cost, so we can tick as fine as we like — 0.2s = +1/tick.
local REGEN_INTERVAL = 0.2

local FocusService = {}
FocusService.__index = FocusService

function FocusService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._config = self._configLoader:LoadConfig("focus")
    self._invulnConns = {}
    -- Runtime Focus pool, player -> number. Weak-keyed so it GCs when the player leaves; never saved.
    self._focus = setmetatable({}, { __mode = "k" })
end

-- The player's live Focus, lazy-initialized to focus_max on first access (i.e. effectively on join).
local function focusOf(self, player)
    local v = self._focus[player]
    if type(v) ~= "number" then
        v = self._config.focus_max
        self._focus[player] = v
    end
    return v
end

-- Make the player's character ethereal/invulnerable: no effective damage, no death. Realizes "Player
-- has 0 HP and cannot be damaged" (Feature 12) without a health stat by pinning health.
function FocusService:_makeInvulnerable(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        humanoid = character:WaitForChild("Humanoid", 5)
    end
    if not humanoid then
        return
    end
    humanoid.MaxHealth = math.huge
    humanoid.Health = math.huge
    pcall(function()
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    end)
    humanoid.HealthChanged:Connect(function()
        if humanoid.Health < humanoid.MaxHealth then
            humanoid.Health = humanoid.MaxHealth
        end
    end)
end

function FocusService:Start()
    local function hookPlayer(player)
        self:_push(player) -- start full, so the HUD bar fills immediately on join
        if player.Character then
            self:_makeInvulnerable(player.Character)
        end
        player.CharacterAdded:Connect(function(character)
            self:_makeInvulnerable(character)
        end)
    end
    for _, player in ipairs(Players:GetPlayers()) do
        hookPlayer(player)
    end
    Players.PlayerAdded:Connect(hookPlayer)

    -- FOCUS REGEN LOOP — refill every player's pool every REGEN_INTERVAL (regen_per_second × interval,
    -- clamped to focus_max) and mirror it to the HUD. Pure in-memory + attribute work (no datastore),
    -- so the fine cadence is free. RegenTick was previously defined but never driven — once Cast
    -- started charging focus_cost the pool drained to 0 and never refilled, silently blocking casts.
    task.spawn(function()
        while true do
            task.wait(REGEN_INTERVAL)
            for _, player in ipairs(Players:GetPlayers()) do
                self:RegenTick(player, REGEN_INTERVAL)
            end
        end
    end)
end

function FocusService:Get(player)
    return { ok = true, focus = focusOf(self, player), max = self._config.focus_max }
end

-- Mirror the live pool to the client via `Focus` / `FocusMax` player attributes so the HUD bar
-- (PlayerBar) can read + animate it the same way it reads Level/XP.
function FocusService:_push(player)
    player:SetAttribute("Focus", focusOf(self, player))
    player:SetAttribute("FocusMax", self._config.focus_max)
end

-- Spend Focus to cast a power. Rejects (no spend) if the pool can't cover it.
function FocusService:Cast(player, cost)
    local result = FocusMath.cast(focusOf(self, player), cost)
    if not result.ok then
        return { ok = false, reason = result.reason, focus = result.focus }
    end
    self._focus[player] = result.focus
    self:_push(player) -- HUD drops the instant you spend
    return { ok = true, focus = result.focus, spent = cost }
end

-- A Sundering enemy attack drains Focus (never below 0).
function FocusService:Sunder(player, amount)
    local before = focusOf(self, player)
    self._focus[player] = FocusMath.sunder(before, amount, self._config)
    self:_push(player)
    return { ok = true, focus = self._focus[player], drained = before - self._focus[player] }
end

-- Drain `amount` Focus (never below 0), then mirror to the HUD. Generic spend used by the always-on
-- toggle UPKEEP loop (PowerService) and the seam for a future focus-steal/transfer power. Returns the
-- new pool + how much was actually removed (less than asked if the pool ran dry).
function FocusService:Drain(player, amount)
    local before = focusOf(self, player)
    local want = math.max(0, tonumber(amount) or 0)
    local after = math.max(0, before - want)
    self._focus[player] = after
    self:_push(player)
    return { ok = true, focus = after, drained = before - after }
end

-- Compensate a committed cast when a downstream transactional action (currently World Travel)
-- fails after Focus was reserved. Never exceeds focus_max.
function FocusService:Restore(player, amount)
    local before = focusOf(self, player)
    local restored = math.max(0, tonumber(amount) or 0)
    self._focus[player] = math.min(self._config.focus_max, before + restored)
    self:_push(player)
    return { ok = true, focus = self._focus[player], restored = self._focus[player] - before }
end

-- Regenerate Focus over `elapsed` seconds (clamped to focus_max), then mirror to the HUD.
function FocusService:RegenTick(player, elapsed)
    self._focus[player] = FocusMath.regen(focusOf(self, player), elapsed, self._config)
    -- GUARDIAN WISH AURA (Genie of the Dunes — "the genie grants wishes"): a summon stamps
    -- FocusRegenBonus (+per-second) while FocusRegenBonusUntil is live — EXTRA regen on top of
    -- the base curve, same focus_max clamp. Generic seam: any future power can grant it.
    local now = os.time()
    local bonus = 0
    local wish = tonumber(player:GetAttribute("FocusRegenBonus")) or 0
    if wish > 0 and (tonumber(player:GetAttribute("FocusRegenBonusUntil")) or 0) > now then
        bonus += wish
    end
    -- INNER LIGHT (Lumen Dove support aura): its own additive channel, so the
    -- dove's trickle stacks with the Genie's wish window instead of fighting
    -- over one attribute. Same clamp; both refresh event-style (Until attrs).
    local auraRegen = tonumber(player:GetAttribute("FocusRegenAura")) or 0
    if auraRegen > 0 and (tonumber(player:GetAttribute("FocusRegenAuraUntil")) or 0) > now then
        bonus += auraRegen
    end
    if bonus > 0 then
        local maxFocus = tonumber(self._config and self._config.focus_max) or 100
        self._focus[player] =
            math.min(maxFocus, (self._focus[player] or 0) + bonus * (tonumber(elapsed) or 0))
    end
    self:_push(player)
    return { ok = true, focus = self._focus[player] }
end

return FocusService
