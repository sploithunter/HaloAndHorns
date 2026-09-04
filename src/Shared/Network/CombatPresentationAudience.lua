-- Server-only resolution of the existing ownership/run attributes; no combat state is mutated.
local Interest = require(script.Parent.CombatPresentationInterest)
local CombatPresentationAudience = {}
CombatPresentationAudience.__index = CombatPresentationAudience

local function position(instance)
    if typeof(instance) ~= "Instance" then
        return nil
    end
    local move = instance:GetAttribute("MoveTarget")
    if typeof(move) == "Vector3" then
        return move
    end
    if instance:IsA("BasePart") then
        return instance.Position
    end
    local part = instance:IsA("Model")
        and (instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart"))
    return part and part.Position or nil
end

function CombatPresentationAudience.new(config, players)
    return setmetatable(
        { _interest = Interest.new(config), _players = players },
        CombatPresentationAudience
    )
end

function CombatPresentationAudience:_identity(instance)
    local owner, run
    local node = typeof(instance) == "Instance" and instance or nil
    while node and node ~= workspace do
        -- Allied actors carry MergeEggRunId; spawned enemies carry MergeRunId.
        run = run or node:GetAttribute("MergeEggRunId") or node:GetAttribute("MergeRunId")
        owner = owner or tonumber(node:GetAttribute("MergeEggOwnerUserId"))
        local player
        if node:IsA("Model") then
            player = self._players:GetPlayerFromCharacter(node)
        end
        if node.Parent and node.Parent.Name == "PlayerPets" then
            player = player
                or self._players:FindFirstChild(node:GetAttribute("NpcOwner") or node.Name)
        end
        if player then
            owner = owner or player.UserId
        end
        node = node.Parent
    end
    return owner, run
end

function CombatPresentationAudience:select(channel, payload, candidates, now)
    local source = payload.source or payload.pet or payload.enemy
    local sourceOwner, sourceRun = self:_identity(source)
    local targetOwner, targetRun = self:_identity(payload.target)
    local sourceUserId = tonumber(payload.sourceUserId) or sourceOwner
    local sourceIsEnemy = typeof(source) == "Instance"
        and source:GetAttribute("MergeEggPrototypeEnemy") == true
    local run = (sourceIsEnemy and sourceRun) or targetRun or sourceRun
    local fight = run
    -- Outside Merge, participation is scoped to the enemy, never globally to a player.
    fight = fight or (sourceUserId and payload.target or source or payload.target)
    local facts = { fight = fight, direct = {}, owners = {}, participants = {} }
    for _, userId in pairs({ sourceUserId, targetOwner }) do
        facts.direct[userId] = true
        facts.participants[userId] = true
    end
    if run then
        for _, player in ipairs(self._players:GetPlayers()) do
            if player:GetAttribute("MergeEggRunId") == run then
                facts.owners[player.UserId] = true
            end
        end
    end
    self._interest:observe(facts, now)
    local hitPosition = payload.position or position(payload.target) or position(source)
    local sourcePosition = position(source)
    local recipients = {}
    for _, player in ipairs(candidates) do
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local distance = root and hitPosition and (root.Position - hitPosition).Magnitude
        if root and sourcePosition then
            local fromSource = (root.Position - sourcePosition).Magnitude
            distance = distance and math.min(distance, fromSource) or fromSource
        end
        if
            self._interest:allows(
                channel,
                facts,
                { userId = player.UserId, distance = distance },
                now
            )
        then
            recipients[#recipients + 1] = player
        end
    end
    return recipients
end

function CombatPresentationAudience:prune(now, removedUserId)
    self._interest:prune(now, removedUserId)
end

return CombatPresentationAudience
