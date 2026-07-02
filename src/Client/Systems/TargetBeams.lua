--[[
    TargetBeams (client) — an ADMIN overlay that draws WHO-IS-TARGETING-WHO as world-space beams,
    so fast combat is readable at a glance. (Server/client execute_luau probes can't land inside a
    live fight — by the time the read returns, the squad is already dead. This makes targeting a
    thing you SEE, not a thing you race to query.)

        GREEN   your pet  -> the enemy it is attacking      (pet.TargetID + TargetType == "Enemy")
        RED     an enemy   -> the pet/player it is biting    (enemy.AggroTargetRef ObjectValue,
                                                              published by EnemyService)

    A line stretched between attacker and target, refreshed every frame from a small pooled set of
    neon parts (client-only, parented under Workspace — never replicated). Gated behind the
    LocalPlayer "AdminOverlaysOn" attribute, the same single switch AdminController flips for every
    other dev overlay (DevSpawnPanel / PetSyncDiag / …).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TargetBeams = {}
local started = false

local GREEN = Color3.fromRGB(80, 235, 120) -- my pet -> its enemy target
local RED = Color3.fromRGB(235, 70, 70) -- enemy -> the pet/player it is hitting
local THICK = 0.35 -- beam cross-section (studs)
local Y_LIFT = 2 -- raise endpoints to ~chest height so the line reads above the ground

-- Resolve the enemy Model carrying BreakableID == id (mirrors PetFollowController.findBreakable).
local function findEnemy(enemiesFolder, id)
    if not enemiesFolder then
        return nil
    end
    for _, desc in ipairs(enemiesFolder:GetDescendants()) do
        if desc.Name == "BreakableID" and desc:IsA("NumberValue") and desc.Value == id then
            return desc.Parent
        end
    end
    return nil
end

local function pivotPos(model)
    local ok, cf = pcall(function()
        return model:GetPivot()
    end)
    if ok and cf then
        return cf.Position + Vector3.new(0, Y_LIFT, 0)
    end
    return nil
end

function TargetBeams.start()
    if started then
        return
    end
    started = true
    local player = Players.LocalPlayer

    -- Client-only container for the beam parts (never replicates to the server).
    local folder = Instance.new("Folder")
    folder.Name = "TargetBeamsDebug"
    folder.Parent = Workspace

    local pool = {} -- reusable neon segments
    local function segment(i)
        local p = pool[i]
        if not p then
            p = Instance.new("Part")
            p.Name = "Beam"
            p.Anchored = true
            p.CanCollide = false
            p.CanQuery = false
            p.CanTouch = false
            p.CastShadow = false
            p.Material = Enum.Material.Neon
            p.Transparency = 0.2
            p.TopSurface = Enum.SurfaceType.Smooth
            p.BottomSurface = Enum.SurfaceType.Smooth
            p.Parent = folder
            pool[i] = p
        end
        return p
    end

    local accum = 0
    RunService.RenderStepped:Connect(function(dt)
        local on = player:GetAttribute("AdminOverlaysOn") == true
        -- Light throttle: 20 Hz is plenty for a debug readout and keeps it cheap.
        accum += dt
        if on and accum < 0.05 then
            return
        end
        accum = 0

        if not on then
            for _, p in ipairs(pool) do
                p.Transparency = 1
            end
            return
        end

        local lines = {} -- { a = Vector3, b = Vector3, color = Color3 }

        -- GREEN: each of my pets -> the enemy it is attacking.
        local gameFolder = Workspace:FindFirstChild("Game")
        local enemiesFolder = gameFolder and gameFolder:FindFirstChild("Enemies")
        local petsFolder = Workspace:FindFirstChild("PlayerPets")
        petsFolder = petsFolder and petsFolder:FindFirstChild(player.Name)
        if petsFolder then
            for _, pet in ipairs(petsFolder:GetChildren()) do
                if pet:IsA("Model") then
                    local tt = pet:FindFirstChild("TargetType")
                    local tid = pet:FindFirstChild("TargetID")
                    if tt and tt.Value == "Enemy" and tid and tid.Value ~= 0 then
                        local enemy = findEnemy(enemiesFolder, tid.Value)
                        local a, b = pivotPos(pet), enemy and pivotPos(enemy)
                        if a and b then
                            lines[#lines + 1] = { a = a, b = b, color = GREEN }
                        end
                    end
                end
            end
        end

        -- RED: each enemy -> the pet/player it is biting (AggroTargetRef published by EnemyService).
        if enemiesFolder then
            for _, enemy in ipairs(enemiesFolder:GetChildren()) do
                if enemy:IsA("Model") then
                    local ref = enemy:FindFirstChild("AggroTargetRef")
                    local victim = ref and ref:IsA("ObjectValue") and ref.Value
                    if victim and victim:IsA("Model") then
                        local a, b = pivotPos(enemy), pivotPos(victim)
                        if a and b then
                            lines[#lines + 1] = { a = a, b = b, color = RED }
                        end
                    end
                end
            end
        end

        -- Lay the pooled segments along the desired lines; hide the leftovers.
        for i, ln in ipairs(lines) do
            local seg = segment(i)
            local delta = ln.b - ln.a
            local len = delta.Magnitude
            if len < 0.05 then
                seg.Transparency = 1
            else
                seg.Size = Vector3.new(THICK, THICK, len)
                seg.CFrame = CFrame.lookAt(ln.a + delta * 0.5, ln.b)
                seg.Color = ln.color
                seg.Transparency = 0.2
            end
        end
        for i = #lines + 1, #pool do
            pool[i].Transparency = 1
        end
    end)
end

return TargetBeams
