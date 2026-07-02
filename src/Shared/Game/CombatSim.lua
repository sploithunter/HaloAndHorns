--[[
    CombatSim — pure, deterministic combat resolution (Feature 10).

    Composes Targeting + CombatMath + FocusMath into a turn-based fight that is
    fully deterministic (no randomness, no Roblox APIs, no clock). Dependencies
    are INJECTED so the same module runs headlessly (spec passes loadModule'd
    cores) and in Studio (the service passes required cores) — this avoids the
    string-vs-Instance require split between Lune and Roblox.

      run(scenario, deps, cfg) -> report

    scenario = {
        enemies = { { id, hp, position, attack = {damage, cadence, sundering}, drop_table }, ... },
        pets    = { { power, position? }, ... },   -- position defaults to origin
        buff?       = number,   -- support-power damage multiplier (default 1)
        maxRounds?  = integer,  -- safety bound (default 500)
        focusStart? = number,   -- starting Focus (default cfg.focus.focus_max)
    }
    deps = { Targeting, CombatMath, FocusMath }
    cfg  = { combat = <configs/combat>, focus = <configs/focus> }

    report = {
        ok, rounds, ended,
        enemiesTotal, enemiesDefeated,
        loot = { [currency] = amount },   -- summed deterministic drops of defeated enemies
        petsDowned, petsTotal,
        focusRemaining,
    }
]]

local CombatSim = {}

local ORIGIN = { x = 0, y = 0, z = 0 }

-- First living, non-downed pet (deterministic victim selection).
local function pickVictim(petState)
    for _, ps in ipairs(petState) do
        if not ps.downed then
            return ps
        end
    end
    return nil
end

function CombatSim.run(scenario, deps, cfg)
    local Targeting = deps.Targeting
    local CombatMath = deps.CombatMath
    local FocusMath = deps.FocusMath

    local enemies = scenario.enemies
    local buff = scenario.buff or 1
    local maxRounds = scenario.maxRounds or 500
    local focus = scenario.focusStart or cfg.focus.focus_max

    local petState = {}
    for _, p in ipairs(scenario.pets) do
        table.insert(petState, {
            power = p.power,
            position = p.position or ORIGIN,
            dmgTaken = 0,
            downed = false,
        })
    end

    local rounds = 0
    while rounds < maxRounds and not CombatMath.encounterEnded(enemies) do
        rounds += 1

        -- 1) Pets auto-attack their nearest living enemy.
        for _, ps in ipairs(petState) do
            if not ps.downed then
                local target = Targeting.nearestEnemy(ps.position, enemies)
                if target then
                    target.hp =
                        CombatMath.applyDamage(target.hp, CombatMath.attackDamage(ps.power, buff))
                end
            end
        end

        if CombatMath.encounterEnded(enemies) then
            break
        end

        -- 2) Each living enemy strikes a pet and may Sunder the player's Focus.
        for _, enemy in ipairs(Targeting.livingEnemies(enemies)) do
            local victim = pickVictim(petState)
            if victim then
                victim.dmgTaken += enemy.attack.damage
                if CombatMath.isPetDowned(victim.dmgTaken, victim.power, cfg.combat) then
                    victim.downed = true
                end
            end
            local sunder = CombatMath.sunderAmount(enemy.attack)
            if sunder > 0 then
                focus = FocusMath.sunder(focus, sunder, cfg.focus)
            end
        end
    end

    -- Resolve deterministic loot for every defeated enemy.
    local loot = {}
    local defeated = 0
    for _, enemy in ipairs(enemies) do
        if CombatMath.isDefeated(enemy.hp) then
            defeated += 1
            for currency, amount in pairs(CombatMath.resolveLoot(enemy.drop_table)) do
                loot[currency] = (loot[currency] or 0) + amount
            end
        end
    end

    local petsDowned = 0
    for _, ps in ipairs(petState) do
        if ps.downed then
            petsDowned += 1
        end
    end

    return {
        ok = true,
        rounds = rounds,
        ended = CombatMath.encounterEnded(enemies),
        enemiesTotal = #enemies,
        enemiesDefeated = defeated,
        loot = loot,
        petsDowned = petsDowned,
        petsTotal = #petState,
        focusRemaining = focus,
    }
end

return CombatSim
