-- Isolated actual-method regression; no live players, saves, or Workspace mutations.
local source = game.ServerScriptService.Server.Services.EnemyService.Source
local policy = assert(loadstring(game.ReplicatedStorage.Shared.Game.EnemyRewardPolicy.Source))()
local root = Instance.new("Folder")
local players = {}
local workspaceDouble = {
    FindFirstChild = function()
        return root
    end,
}
local playersDouble = {
    GetPlayerByUserId = function(_, id)
        return players[id]
    end,
}
local function method(name)
    local first = assert(source:find("function EnemyService:" .. name .. "(", 1, true))
    local last = source:find("\nfunction EnemyService:", first + 1, true) or #source + 1
    return assert(
        loadstring(
            "local Workspace, Players, EnemyRewardPolicy = ...\nlocal EnemyService={}\n"
                .. source:sub(first, last - 1)
                .. "\nreturn EnemyService."
                .. name
        )
    )(workspaceDouble, playersDouble, policy)
end
local awards = {}
local service = {
    _enemies = {},
    _combatConfig = { merge_xp_credit = { enabled = true, player_radius = 150 } },
    _playerForPetFolder = function(_, folder)
        return players[tonumber(folder.Name)]
    end,
    _clearEnemyFromPetThreat = function() end,
    _releasePets = function() end,
    _playDefeatDeath = function() end,
    _combatService = function()
        return {
            AwardExperience = function(_, player, _, _, _, _, opts)
                awards[player.UserId] = (awards[player.UserId] or 0) + opts.xpMultiplier
            end,
        }
    end,
    _awardCombatDefeat = function(_, player, _, _, _, _, opts)
        awards[player.UserId] = (awards[player.UserId] or 0) + opts.xpMultiplier
    end,
}
service._mergeXpParticipants = method("_mergeXpParticipants")
service._onDefeated = method("_onDefeated")
local function player(id, position)
    local char = Instance.new("Model")
    char.Parent = root
    local part = Instance.new("Part")
    part.Name = "HumanoidRootPart"
    part.Position = position
    part.Parent = char
    Instance.new("Humanoid", char)
    players[id] = {
        UserId = id,
        Parent = true,
        Character = char,
        GetAttribute = function(_, key)
            return key == "MergeEggPlayerCombatMode" and "full" or key == "CombatTutorialDone"
        end,
    }
    return players[id]
end
player(1, Vector3.zero)
player(2, Vector3.zero)
player(3, Vector3.new(1000, 0, 0))
local function pet(owner, target, personal, downed)
    local folder = root:FindFirstChild(tostring(owner)) or Instance.new("Folder")
    folder.Name = tostring(owner)
    folder.Parent = root
    local model = Instance.new("Model", folder)
    local part = Instance.new("Part", model)
    model.PrimaryPart = part
    model:SetAttribute("PetRecordKey", personal and "durable" or nil)
    model:SetAttribute("CombatDowned", downed)
    local tid = Instance.new("IntValue", model)
    tid.Name = "TargetID"
    tid.Value = target
    local tt = Instance.new("StringValue", model)
    tt.Name = "TargetType"
    tt.Value = "Enemy"
end
local function enemy(id, run)
    local model = Instance.new("Model", root)
    model:SetAttribute("MergeRunId", run)
    model:SetAttribute("MergeEggPrototypeEnemy", true)
    model:SetAttribute("MergeEggCombatXpMultiplier", 1)
    local entry =
        { model = model, pos = Vector3.zero, rewardPolicy = "none", enemyId = "fixture", def = {} }
    service._enemies[id] = entry
    return entry
end
local dead = enemy(10, "A")
enemy(11, "A")
enemy(20, "B")
pet(1, 10, true)
pet(1, 11, true)
pet(2, 11, true)
pet(9, 10, false)
pet(9, 11, false)
pet(9, 11, false)
pet(3, 20, true) -- another bay does not enter denominator
pet(1, 10, true, true) -- downed pets do not count
pet(1, 0, true) -- merely equipped is not engaged
local counts, total = service:_mergeXpParticipants(dead, 10)
assert(
    total == 6 and counts[players[1]] == 2 and counts[players[2]] == 1 and not counts[players[3]]
)
service:_onDefeated(10) -- NPC kill still pays both engaged owners
assert(awards[1] == 2 / 6 and awards[2] == 1 / 6 and awards[3] == nil)
awards = {}
dead = enemy(10, "A")
dead.model:SetAttribute("MergeEggPlayerPetKillUserId", 1)
service:_onDefeated(10)
assert(awards[1] == 1 and awards[2] == 1 / 6) -- max, never sum
root:Destroy()
return "PASS: NPC kills pay participation; personal killer paid once; helpers, idle/downed pets and other bays isolated"
