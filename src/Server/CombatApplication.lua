--[[
    CombatApplication — authoritative combat-state mutation and result publication.

    Runtime combat code must not pair a health write with an unrelated presentation call. These
    three entry points own that contract:

      ApplyHit(target, context)        resolved hit outcome (damage/miss/dodge/block/absorb)
      ApplyDamage(target, amount, context)
      ApplyPowerHeal(target, amount, context)

    HP targets use the HP attribute. Pets use the inverse CombatDamageTaken endurance resource when
    context.resource == "pet_endurance". Spawn/scaling/admin restoration and passive regeneration
    remain deliberately outside this module because they are state maintenance, not visible combat.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetCombat = require(ReplicatedStorage.Shared.Game.PetCombat)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local CombatApplication = {}

local VISIBLE_OUTCOMES = {
    damage = true,
    heal = true,
    miss = true,
    dodge = true,
    blocked = true,
    absorbed = true,
    immune = true,
}

local function targetPosition(target)
    if not target then
        return nil
    end
    local moveTarget = target:GetAttribute("MoveTarget")
    if typeof(moveTarget) == "Vector3" then
        return moveTarget
    end
    if target:IsA("Model") then
        local part = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
        return part and part.Position or nil
    end
    return target:IsA("BasePart") and target.Position or nil
end

local function sourceUserId(context)
    local player = context and context.sourcePlayer
    if typeof(player) == "Instance" and player:IsA("Player") then
        return player.UserId
    end
    return tonumber(context and context.sourceUserId)
end

local function publish(target, outcome, amount, context)
    context = context or {}
    if context.silent == true or not VISIBLE_OUTCOMES[outcome] then
        return
    end
    Signals.Combat_Result:FireAllClients({
        outcome = outcome,
        target = target,
        position = context.position or targetPosition(target),
        amount = math.max(0, tonumber(amount) or 0),
        crit = context.crit == true,
        blind = context.blind == true,
        source = context.source,
        sourceUserId = sourceUserId(context),
        powerId = context.powerId,
        element = context.element,
        kind = context.kind,
    })
end

local function credit(target, amount, context)
    local uid = sourceUserId(context)
    local contrib = uid and amount > 0 and target:FindFirstChild("Contrib")
    if not contrib then
        return
    end
    local key = tostring(uid)
    local value = contrib:FindFirstChild(key)
    if not value then
        value = Instance.new("NumberValue")
        value.Name = key
        value.Parent = contrib
    end
    value.Value += amount
end

-- Apply guaranteed damage. Accuracy/dodge/etc. belong in ApplyHit; an already-armed DoT calls this
-- directly. Returns a compatibility-shaped result (`hp`/`contributed`) plus before/after/outcome.
function CombatApplication.ApplyDamage(target, amount, context)
    context = context or {}
    amount = math.max(0, tonumber(amount) or 0)
    if not (target and target.Parent) or amount <= 0 then
        return {
            outcome = "damage",
            amount = 0,
            contributed = 0,
            before = 0,
            after = 0,
            hp = 0,
        }
    end

    local before
    local after
    context.position = context.position or targetPosition(target)
    if context.resource == "pet_endurance" then
        before = math.max(0, tonumber(target:GetAttribute("CombatDamageTaken")) or 0)
        after = before + amount
        target:SetAttribute("CombatDamageTaken", after)
    else
        before = math.max(0, tonumber(target:GetAttribute("HP")) or 0)
        local applied = PetCombat.applyDamage(before, amount)
        after = applied.hp
        amount = applied.contributed
        credit(target, amount, context)
        target:SetAttribute("HP", after)
    end

    if amount > 0 then
        publish(target, "damage", amount, context)
    end
    return {
        outcome = "damage",
        amount = amount,
        contributed = amount,
        before = before,
        after = after,
        hp = after,
        crit = context.crit == true,
    }
end

-- Apply a resolved attack outcome. Callers still own their domain-specific roll and mitigation
-- math; this function is the one place where the result becomes state + player-visible feedback.
function CombatApplication.ApplyHit(target, context)
    context = context or {}
    local outcome = context.outcome or "damage"
    if outcome == "damage" then
        return CombatApplication.ApplyDamage(target, context.amount, context)
    end
    publish(target, outcome, context.amount, context)
    return {
        outcome = outcome,
        amount = 0,
        contributed = 0,
        before = nil,
        after = nil,
        hp = target and target:GetAttribute("HP") or nil,
        crit = false,
    }
end

-- Apply an ACTIVE/power heal and publish its green number. Passive regeneration intentionally writes
-- its resource directly and never calls this function. `minimumTaken` preserves resurrection
-- sickness for pet endurance; HP heals clamp to MaxHP.
function CombatApplication.ApplyPowerHeal(target, amount, context)
    context = context or {}
    amount = math.max(0, tonumber(amount) or 0)
    if not (target and target.Parent) or amount <= 0 then
        return { outcome = "heal", amount = 0, before = 0, after = 0 }
    end

    local before
    local after
    local healed
    context.position = context.position or targetPosition(target)
    if context.resource == "pet_endurance" then
        before = math.max(0, tonumber(target:GetAttribute("CombatDamageTaken")) or 0)
        local minimumTaken = math.max(0, tonumber(context.minimumTaken) or 0)
        after = math.max(minimumTaken, before - amount)
        healed = before - after
        target:SetAttribute("CombatDamageTaken", after)
    else
        before = math.max(0, tonumber(target:GetAttribute("HP")) or 0)
        local maxHp = math.max(before, tonumber(target:GetAttribute("MaxHP")) or before)
        after = math.min(maxHp, before + amount)
        healed = after - before
        target:SetAttribute("HP", after)
    end

    if healed > 0 then
        if context.fxUntil then
            target:SetAttribute("HealFxUntil", context.fxUntil)
        elseif context.fxSeconds then
            target:SetAttribute("HealFxUntil", os.time() + context.fxSeconds)
        end
        publish(target, "heal", healed, context)
    end
    return {
        outcome = "heal",
        amount = healed,
        before = before,
        after = after,
        hp = context.resource == "pet_endurance" and nil or after,
    }
end

return CombatApplication
