-- Observer-only Merge detail follows the character, never their claimed bay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Policy = require(ReplicatedStorage.Shared.Game.MergePresentationPolicy)
local Visibility = require(script.Parent.PetDownedVisibility)
local RangedFX = require(ReplicatedStorage.Shared.Effects.RangedFX)
local config = require(ReplicatedStorage.Configs.merge_egg_prototype)
local Controller = {}
local started = false

function Controller.start()
    if started then
        return
    end
    started = true
    local cfg = config.distant_presentation
    if not cfg or not cfg.enabled then
        return
    end
    local player = Players.LocalPlayer
    local elapsed, focusId = 0, nil
    local hidden, nextSummary = {}, {}
    local enemyRoot, releaseEnemies

    local function mark(model, hide)
        if model:GetAttribute("MergeEggObjective") == true then
            hide = false
        end
        if hide then
            hidden[model] = true
            if model:GetAttribute("MergePresentationHidden") ~= true then
                model:SetAttribute("MergePresentationHidden", true)
            end
        elseif hidden[model] then
            hidden[model] = nil
            -- Hidden actors stopped cosmetic movement, not server movement. Resume
            -- at their current authoritative point, rather than their old visible pose.
            local pos = model:GetAttribute("NpcCombatPosition") or model:GetAttribute("MoveTarget")
            if typeof(pos) == "Vector3" and model:IsDescendantOf(Workspace) then
                model:PivotTo(CFrame.new(pos) * model:GetPivot().Rotation)
            end
            model:SetAttribute("MergePresentationHidden", nil)
        end
    end

    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < cfg.update_seconds then
            return
        end
        elapsed = 0
        local maps = Workspace:FindFirstChild(config.world.maps_root)
        local realm = maps and maps:FindFirstChild(config.realm_layout.root_name)
        local bayRoot = realm and realm:FindFirstChild("Bays")
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local bays = {}
        for _, model in ipairs(bayRoot and bayRoot:GetChildren() or {}) do
            local id = model:GetAttribute("MergeEggBayId")
            local side = model:GetAttribute("MergeEggBaySide")
            local column = model:GetAttribute("MergeEggBayColumn")
            if model:IsA("Model") and id and side and type(column) == "number" then
                local pos = model:GetPivot().Position
                bays[#bays + 1] =
                    { id = id, side = side, column = column, x = pos.X, z = pos.Z, model = model }
            end
        end
        if not root or #bays == 0 then
            for model in pairs(hidden) do
                mark(model, false)
            end
            focusId = nil
            player:SetAttribute("MergePresentationFocusBay", nil)
            return
        end
        local position = root.Position
        local focus = Policy.nearest(bays, position.X, position.Z, focusId, cfg.focus_hysteresis)
        focusId = focus and focus.id
        if player:GetAttribute("MergePresentationFocusBay") ~= focusId then
            player:SetAttribute("MergePresentationFocusBay", focusId)
        end
        for model in pairs(hidden) do
            if not model:IsDescendantOf(Workspace) then
                mark(model, false)
            end
        end
        local summaries = {}
        local function evaluate(model, ownPet, mergeContext)
            if not model:IsA("Model") then
                return
            end
            if
                not mergeContext
                and not model:GetAttribute("MergeEggRunId")
                and not model:GetAttribute("MergeRunId")
            then
                mark(model, false)
                return
            end
            local pos = model:GetAttribute("NpcCombatPosition") or model:GetAttribute("MoveTarget")
            if typeof(pos) ~= "Vector3" then
                pos = model:GetPivot().Position
            end
            local bay = Policy.nearest(bays, pos.X, pos.Z, nil, 0)
            local detailed = ownPet
                or Policy.detailed(focus, bay, cfg.neighboring_columns)
                or (pos - position).Magnitude <= cfg.nearby_actor_radius
            mark(model, not detailed)
            if
                not detailed
                and model:GetAttribute("MergeRunId")
                and not model:GetAttribute("Dying")
            then
                summaries[bay.id] = { bay = bay, position = pos }
            end
        end
        local pets = Workspace:FindFirstChild("PlayerPets")
        for _, folder in ipairs(pets and pets:GetChildren() or {}) do
            local owner = Players:FindFirstChild(folder.Name)
            local mergeContext = folder:GetAttribute("OfflineOwnedSquad") == true
                or (owner and owner:GetAttribute("MergeEggRunId") ~= nil)
            for _, model in ipairs(folder:GetChildren()) do
                evaluate(model, folder.Name == player.Name, mergeContext)
            end
        end
        local gameRoot = Workspace:FindFirstChild("Game")
        local enemies = gameRoot and gameRoot:FindFirstChild("Enemies")
        if enemies ~= enemyRoot then
            if releaseEnemies then
                releaseEnemies()
            end
            enemyRoot = enemies
            releaseEnemies = enemies and Visibility.bind(enemies, true) or nil
        end
        for _, model in ipairs(enemies and enemies:GetChildren() or {}) do
            evaluate(model, false)
        end
        local now = os.clock()
        for id, summary in pairs(summaries) do
            local colors = cfg.colors[summary.bay.side]
            if
                colors
                and now >= (nextSummary[id] or 0)
                and (summary.bay.model:GetAttribute("ActiveEnemies") or 0) > 0
            then
                nextSummary[id] = now + cfg.summary_interval
                RangedFX.playImpact(
                    cfg.summary_impact,
                    summary.position + Vector3.new(0, cfg.summary_height, 0),
                    colors[1],
                    colors[2],
                    { scale = cfg.summary_scale, sparks = cfg.summary_sparks }
                )
            end
        end
    end)
end

return Controller
