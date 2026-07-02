--[[
    EnemyBurnFx — individual "on fire" VFX for any enemy carrying a live burn (DoT).

    The DoT pass (EnemyService) stamps `BurnFxUntil` (os.time) on every enemy a burn ticks — a
    single-target burn, an AoE-splash burn, OR a contagion burn as it HOPS from enemy to enemy. This
    renders that marker: a real Roblox Fire on the enemy while the burn is live, removed when it
    expires. Per-enemy fire is what makes a DoT read as "burning" and a CONTAGION read as SPREADING —
    each enemy visibly ignites as the plague reaches it (vs one AoE burst, which is the targeted_aoe
    look). Purely visual + client-local; the damage is server-authoritative. Every client renders
    from the replicated attribute, so the fire is shared-world.
]]

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatFX = require(ReplicatedStorage.Shared.Effects.CombatFX)

local EnemyBurnFx = {}

local fires = {} -- [enemyModel] = ParticleEmitter (client-local)

local function enemiesFolder()
    local g = Workspace:FindFirstChild("Game")
    return g and g:FindFirstChild("Enemies")
end

-- Element-themed burn emitter (BurnElement stamped server-side; lava fallback inside enemyBurn).
local function attach(part, enemy)
    local okE, ext = pcall(function()
        return enemy:GetExtentsSize()
    end)
    local szHint = (okE and ext) and math.max(ext.X, ext.Y, ext.Z) or 6
    return CombatFX.enemyBurn(part, enemy:GetAttribute("BurnElement"), szHint)
end

function EnemyBurnFx.start()
    local accum = 0
    RunService.Heartbeat:Connect(function(dt)
        accum += dt
        if accum < 0.2 then -- ~5 Hz is plenty for igniting/clearing
            return
        end
        accum = 0
        local now = os.time()
        local en = enemiesFolder()
        if en then
            for _, e in ipairs(en:GetChildren()) do
                if e:IsA("Model") then
                    local burning = (e:GetAttribute("BurnFxUntil") or 0) > now
                    local part = e.PrimaryPart or e:FindFirstChildWhichIsA("BasePart")
                    local fire = fires[e]
                    if burning and part then
                        if not fire or fire.Parent ~= part then
                            if fire then
                                fire:Destroy()
                            end
                            fires[e] = attach(part, e)
                        end
                    elseif fire then
                        fire:Destroy()
                        fires[e] = nil
                    end
                end
            end
        end
        -- reap fires whose enemy despawned
        for e, fire in pairs(fires) do
            if not e.Parent then
                fire:Destroy()
                fires[e] = nil
            end
        end
    end)
end

return EnemyBurnFx
