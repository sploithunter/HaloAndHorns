-- Run in Studio Edit via execute_luau. Executes production methods against isolated doubles;
-- never changes a Player, profile, real squad, or authored map.
local services = game.ServerScriptService.Server.Services
local configs = game.ReplicatedStorage.Configs
local function method(module, className, name, prelude, ...)
    local source = module.Source
    local first = assert(source:find("function " .. className .. ":" .. name .. "(", 1, true))
    local last = source:find("\nfunction " .. className .. ":", first + 1, true) or #source + 1
    return assert(
        loadstring(
            (prelude or "")
                .. "\nlocal "
                .. className
                .. " = {}\n"
                .. source:sub(first, last - 1)
                .. "\nreturn "
                .. className
                .. "."
                .. name
        )
    )(...)
end
local attrs = { InCombatTutorial = true, InMission = "training" }
local player = { Parent = true, Name = "IsolatedHandoffFixture" }
function player:GetAttribute(key)
    return attrs[key]
end
function player:SetAttribute(key, value)
    attrs[key] = value
end
local pending = { bayId = "fixture" }
local resumed, restored, loopClears = 0, 0, 0
local merge = { _combatTrainingReturns = { [player] = pending } }
merge._resumeAfterCombatTraining = method(
    services.MergeEggPrototypeService,
    "MergeEggPrototypeService",
    "_resumeAfterCombatTraining",
    "local task = ...",
    {
        spawn = function(fn)
            fn()
        end,
    }
)
function merge:_recordFor()
    return nil
end
function merge:_begin()
    resumed += 1
    return true
end
merge:_resumeAfterCombatTraining(player, "not_ready")
assert(resumed == 0 and merge._combatTrainingReturns[player] == pending)
attrs.InMission = nil
merge:_resumeAfterCombatTraining(player, "mission_closed_first")
assert(resumed == 0 and merge._combatTrainingReturns[player] == pending)
local tutorial = { _sessions = { [player] = {} } }
tutorial._leave = method(services.CombatTutorialService, "CombatTutorialService", "_leave")
function tutorial:_clearSessionLoops()
    loopClears += 1
end
function tutorial:_rewindLeaveResume() end
function tutorial:_despawnTutorialEnemies() end
function tutorial:_destroyHomeworldVenue() end
function tutorial:_restoreLoanedSquad()
    restored += 1
    assert(
        attrs.InCombatTutorial == true and loopClears > 0,
        "Readiness published before restoration"
    )
    merge:_resumeAfterCombatTraining(player, "during_restore")
    assert(resumed == 0, "Merge resumed during restoration")
    self:_leave(player) -- attribute watchers re-entering while restoration yields must be harmless
    assert(restored == 1, "Restoration ran twice")
end
tutorial:_leave(player)
assert(attrs.InCombatTutorial == nil and tutorial._sessions[player] == nil)
merge:_resumeAfterCombatTraining(player, "restored")
merge:_resumeAfterCombatTraining(player, "duplicate_signal")
assert(resumed == 1 and restored == 1)
local combatConfig = assert(loadstring(configs.combat.Source))()
local challenge = require(game.ReplicatedStorage.Shared.Game.ChallengeRun)
local enemy = { _combatConfig = combatConfig }
enemy._engagesCombat = method(
    services.EnemyService,
    "EnemyService",
    "_engagesCombat",
    "local ChallengeRun = ...",
    challenge
)
attrs.Level, attrs.EffectiveLevel = 2, 2
assert(enemy:_engagesCombat(player) == false, "Untrained onramp changed")
attrs.CombatTutorialDone = true
assert(enemy:_engagesCombat(player) == true, "Graduate still blocked until rejoin")
-- Run real target assignment too: an enemy engaged with a hatcher (not this player) must
-- become acquirable immediately after graduation. Fixtures stay outside Workspace.
local fixture = Instance.new("Folder")
local squad = Instance.new("Folder")
squad.Parent = fixture
local pet = Instance.new("Model")
local part = Instance.new("Part")
part.Parent = pet
pet.PrimaryPart = part
pet.Parent = squad
local tid = Instance.new("NumberValue")
tid.Name = "TargetID"
tid.Parent = pet
local tt = Instance.new("StringValue")
tt.Name = "TargetType"
tt.Value = "Enemy"
tt.Parent = pet
local foe = Instance.new("Model")
foe:SetAttribute("HP", 100)
foe.Parent = fixture
local targetPriority = require(game.ReplicatedStorage.Shared.Game.TargetPriority)
enemy._assignPetTargets = method(
    services.EnemyService,
    "EnemyService",
    "_assignPetTargets",
    "local Workspace, TargetPriority = ...\nlocal AggroTable = {get=function() return 0 end}\nlocal function traceEnabled() return false end",
    {
        FindFirstChild = function()
            return {
                GetChildren = function()
                    return { squad }
                end,
            }
        end,
    },
    targetPriority
)
enemy._enemies = {
    [1] = { model = foe, pos = Vector3.new(1, 0, 0), def = {}, aggroPlayerName = "HatcherFixture" },
}
function enemy:_petFollowService()
    return nil
end
function enemy:_playerForPetFolder()
    return player
end
function enemy:_petPosition()
    return Vector3.zero
end
function enemy:_aggroV2()
    return nil
end
function enemy:_inTerritory()
    return true
end
function enemy:_petHostileToEnemy()
    return true
end
attrs.CombatTutorialDone = nil
enemy:_assignPetTargets(combatConfig.engagement)
assert(tid.Value == 0, "Untrained pet initiated combat")
attrs.CombatTutorialDone = true
enemy:_assignPetTargets(combatConfig.engagement)
assert(tid.Value == 1 and tt.Value == "Enemy", "Graduate did not acquire nearby enemy")
fixture:Destroy()
attrs.CombatTutorialDone = nil
attrs.Level, attrs.EffectiveLevel = 5, 5
assert(enemy:_engagesCombat(player) == true, "Existing level gate changed")
local drops = assert(loadstring(configs.drops.Source))()
assert(drops.collect_radius == 20, "Base magnet is not twenty studs")
return "PASS: restore-before-resume, reentrant leave, exactly-once return, live graduate targeting, peaceful onramp, 20-stud magnet"
