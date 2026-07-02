--[[
    PetRevive — THE single definition of what reviving a pet means.

    Jason: "why do we have three revive sites? Why does the caster matter at
    all?" It shouldn't. Casters (squad Summon button, the Revive power, genie
    summon, natural recovery) decide WHETHER and WHICH pet; this module owns
    WHAT happens: clear the downed state, heal, zero cooldown, teleport the
    REUSED model to its owner (it otherwise pops up wherever it died and
    resumes that fight), and drop any stale target so it falls into formation.

    Add future revive behavior (VFX, events, invulnerability windows) HERE.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetEndurance = require(ReplicatedStorage.Shared.Game.PetEndurance)

local PetRevive = {}

-- RES SICKNESS (Jason 2026-07-02, tunable — configs/squad.lua revive.health_frac, start 50%):
-- a revived pet returns at a FRACTION of its max endurance, not full. The resurrection erases
-- the down, not the wound — an up-but-fragile pet keeps the healer in the moment (and gives the
-- Genie's HoT something to do). frac >= 1 (or any config failure) = full health, the old behavior.
local function reviveDamageTaken(pet)
    local frac = 1
    pcall(function()
        local squadCfg = require(ReplicatedStorage.Configs.squad)
        frac = tonumber(squadCfg.revive and squadCfg.revive.health_frac) or 1
    end)
    if frac >= 1 then
        return 0
    end
    local maxEnd = 0
    pcall(function()
        local pv = pet:FindFirstChild("Power")
        local combatCfg = require(ReplicatedStorage.Configs.combat)
        maxEnd = PetEndurance.maxEndurance(
            (pv and tonumber(pv.Value)) or 0,
            combatCfg.pet_down_threshold_factor or 1
        )
    end)
    if maxEnd <= 0 then
        return 0
    end
    return math.max(0, math.floor(maxEnd * (1 - math.max(0, frac))))
end

-- pet: the pet Model. owner (optional): the owning Player; resolved from the
-- pet's folder name when omitted. Safe on non-downed pets (idempotent).
function PetRevive.revive(pet, owner)
    if not (pet and pet.Parent) then
        return false
    end
    pet:SetAttribute("CombatDowned", false)
    local sickDamage = reviveDamageTaken(pet)
    pet:SetAttribute("CombatDamageTaken", sickDamage)
    -- SICKNESS WINDOW (Jason: "make it unhealable or leave it low for a bit — otherwise we could
    -- just do a 100% res"): while ResSicknessUntil is live, every heal path clamps against
    -- ResSicknessFloor (Shared/Game/ResSickness) — the pet stays at its res health until the
    -- window passes. No partial revive (frac >= 1) = no window.
    if sickDamage > 0 then
        local secs = 8
        pcall(function()
            local squadCfg = require(ReplicatedStorage.Configs.squad)
            secs = tonumber(squadCfg.revive and squadCfg.revive.sickness_seconds) or 8
        end)
        pet:SetAttribute("ResSicknessFloor", sickDamage)
        pet:SetAttribute("ResSicknessUntil", os.time() + secs)
    end
    pet:SetAttribute("CooldownUntil", 0)
    pet:SetAttribute("DownedReason", "")
    owner = owner or Players:FindFirstChild(pet.Parent.Name)
    local hrp = owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        pet:PivotTo(CFrame.new(hrp.Position + Vector3.new(2, 2, 2)))
    end
    local tid = pet:FindFirstChild("TargetID")
    if tid then
        tid.Value = 0
    end
    -- REVIVE GRACE (Jason's solidified beer): without this, an enemy that still
    -- holds aggro on the owner re-drafts the fresh pet on the NEXT combat tick
    -- and it renders right back at the fight it just died in. A few protected
    -- seconds let it reach the player's side first.
    pet:SetAttribute("ReviveGraceUntil", os.time() + 4)
    return true
end

return PetRevive
