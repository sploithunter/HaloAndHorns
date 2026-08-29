--[[
    AutoCollectorController — presentation for the inventory-free Auto Collector pet.

    DropService owns entitlement, target selection, bounded movement, and wallet credit. The server
    publishes the collector's authoritative position at a modest rate; every client smooths and
    animates the authored pet locally. AutoCollectors live outside PlayerPets by design, so normal
    equip, HUD, work, combat, and aggro systems can never mistake this passive actor for a squad pet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Gait = require(ReplicatedStorage.Shared.Game.Gait)
local PetMeander = require(ReplicatedStorage.Shared.Game.PetMeander)
local PetAnimator = require(script.Parent.PetAnimator)

local AutoCollectorController = {}

local function visualOrientation(model)
    return CFrame.Angles(
        math.rad(tonumber(model:GetAttribute("OrientationX")) or 0),
        math.rad(tonumber(model:GetAttribute("OrientationY")) or 0),
        math.rad(tonumber(model:GetAttribute("OrientationZ")) or 0)
    )
end

function AutoCollectorController.start()
    local drops = require(ReplicatedStorage.Configs:WaitForChild("drops"))
    local collectorCfg = drops.auto_collector or {}
    if collectorCfg.enabled == false then
        return
    end
    local followCfg = require(ReplicatedStorage.Configs:WaitForChild("pet_follow"))
    local defaultGait = followCfg.gait or {}
    local gaitByType = followCfg.gait_by_type or {}
    local meanderCfg = followCfg.meander or {}
    local gaitCache = {}
    local states = setmetatable({}, { __mode = "k" })
    local folder = Workspace:WaitForChild("AutoCollectors", 30)
    if not folder then
        return
    end

    local function gaitFor(model)
        local petType = tostring(model:GetAttribute("PetType") or "_default")
        local gait = gaitCache[petType]
        if not gait then
            gait = Gait.resolve(defaultGait, gaitByType[petType])
            gaitCache[petType] = gait
        end
        return gait
    end

    RunService.RenderStepped:Connect(function(dt)
        local rate = math.max(0.1, tonumber(collectorCfg.render_lerp_rate) or 18)
        for _, model in ipairs(folder:GetChildren()) do
            if model:IsA("Model") and model.PrimaryPart then
                local target = model:GetAttribute("AutoCollectorPosition")
                if typeof(target) == "Vector3" then
                    local state = states[model]
                    if not state then
                        state = {
                            cf = model:GetPivot(),
                            gait = {},
                            meander = PetMeander.newState(meanderCfg, math.random),
                            stillFor = 0,
                        }
                        states[model] = state
                    end
                    local priorTarget = state.lastTarget
                    local flatTargetStep = priorTarget
                            and Vector3.new(target.X - priorTarget.X, 0, target.Z - priorTarget.Z)
                        or Vector3.zero
                    if priorTarget and flatTargetStep.Magnitude < 0.1 then
                        state.stillFor += dt
                    else
                        state.stillFor = 0
                    end
                    state.lastTarget = target

                    -- AutoCollectors are intentionally outside PlayerPets, but their passive
                    -- presentation should still feel like a real companion. Reuse the ordinary
                    -- pet idle-meander state machine once the collector has settled at its follow
                    -- slot. This offset is client-only: server targeting, pickup reach, and wallet
                    -- credit continue to use the clean AutoCollectorPosition.
                    local mayMeander = meanderCfg.enabled ~= false
                        and model:GetAttribute("AutoCollectorMode") == "follow"
                        and state.stillFor >= (tonumber(meanderCfg.player_still_seconds) or 2)
                    local idleX, idleZ = 0, 0
                    if mayMeander then
                        idleX, idleZ = PetMeander.step(state.meander, dt, meanderCfg, math.random)
                    else
                        PetMeander.reset(state.meander, meanderCfg, math.random)
                    end
                    target += Vector3.new(idleX, 0, idleZ)

                    local previous = state.cf.Position
                    local alpha = 1 - math.exp(-rate * dt)
                    local position = previous:Lerp(target, alpha)
                    local step = Vector3.new(position.X - previous.X, 0, position.Z - previous.Z)
                    local look = model:GetAttribute("AutoCollectorLookVector")
                    look = typeof(look) == "Vector3" and Vector3.new(look.X, 0, look.Z)
                        or Vector3.new(0, 0, -1)
                    if step.Magnitude > 0.001 then
                        look = step.Unit
                    elseif look.Magnitude > 0.001 then
                        look = look.Unit
                    else
                        look = Vector3.new(0, 0, -1)
                    end
                    state.cf = CFrame.lookAt(position, position + look)

                    local speed = step.Magnitude / math.max(dt, 1e-3)
                    local rendered = state.cf
                    if PetAnimator.isRigged(model) then
                        PetAnimator.update(model, speed)
                    else
                        local bob, roll, yaw =
                            Gait.advance(state.gait, gaitFor(model), step.Magnitude, dt)
                        rendered = CFrame.new(0, bob, 0) * rendered * CFrame.Angles(0, yaw, roll)
                    end
                    model:PivotTo(rendered * visualOrientation(model))
                end
            end
        end
        for model in pairs(states) do
            if not model.Parent then
                states[model] = nil
            end
        end
    end)
end

return AutoCollectorController
