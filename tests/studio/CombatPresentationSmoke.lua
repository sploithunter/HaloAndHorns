-- Isolated engine-Instance fixtures: no profiles, live pets, or Workspace content are changed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Audience = require(ReplicatedStorage.Shared.Network.CombatPresentationAudience)
local config = require(ReplicatedStorage.Configs.network).combat_presentation
local Smoke = {}

function Smoke.run()
    local roots = {}
    local function make(className, name, parent)
        local instance = Instance.new(className)
        instance.Name = name
        instance.Parent = parent
        if not parent then
            roots[#roots + 1] = instance
        end
        return instance
    end
    local ok, result = pcall(function()
        local pets = make("Folder", "PlayerPets")
        local roster = {}
        for id = 1, 4 do
            local character = make("Model", "Viewer" .. id)
            local root = make("Part", "HumanoidRootPart", character)
            root.Position = Vector3.new(id == 4 and config.animation_radius * 2 or 0, 0, 0)
            roster[id] = {
                UserId = id,
                Name = "Viewer" .. id,
                Character = character,
                GetAttribute = function(_, key)
                    return key == "MergeEggRunId" and ("run-" .. id) or nil
                end,
            }
        end
        local players = {
            GetPlayers = function()
                return roster
            end,
            GetPlayerFromCharacter = function()
                return nil
            end,
            FindFirstChild = function(_, name)
                for _, player in ipairs(roster) do
                    if player.Name == name then
                        return player
                    end
                end
                return nil
            end,
        }
        local function pet(id)
            local folder = make("Folder", "Viewer" .. id, pets)
            local model = make("Model", "Pet", folder)
            model.PrimaryPart = make("Part", "Root", model)
            return model
        end
        local ownerPet, helperPet = pet(1), pet(2)
        local enemy = make("Model", "Enemy")
        enemy.PrimaryPart = make("Part", "Root", enemy)
        enemy:SetAttribute("MergeRunId", "run-1")
        enemy:SetAttribute("MergeEggPrototypeEnemy", true)
        local audience = Audience.new(config, players)
        local function recipients(channel, payload, now)
            local ids = {}
            for _, player in ipairs(audience:select(channel, payload, roster, now)) do
                ids[#ids + 1] = tostring(player.UserId)
            end
            return table.concat(ids, ",")
        end
        local hit = { source = enemy, target = ownerPet }
        assert(recipients("Combat_Result", hit, 0) == "1", "spectator received results")
        assert(
            recipients("Combat_EnemyHit", { enemy = enemy, target = ownerPet }, 0) == "1,2,3",
            "animation distance routing"
        )
        assert(
            recipients("Combat_Result", { source = helperPet, sourceUserId = 2, target = enemy }, 1)
                == "1,2",
            "helper's first hit"
        )
        -- A reserve pet can retain its home run while helping elsewhere. The enemy's run wins.
        helperPet:SetAttribute("MergeEggRunId", "run-2")
        assert(
            recipients("Combat_Result", { source = enemy, target = helperPet }, 2) == "1,2",
            "cross-run enemy attack"
        )
        assert(recipients("Combat_Result", hit, 3) == "1,2", "helper participation not retained")
        local secondEnemy = make("Model", "SecondEnemy")
        secondEnemy.PrimaryPart = make("Part", "Root", secondEnemy)
        secondEnemy:SetAttribute("MergeRunId", "run-1")
        secondEnemy:SetAttribute("MergeEggPrototypeEnemy", true)
        assert(
            recipients("Combat_Result", { source = secondEnemy, target = ownerPet }, 3) == "1,2",
            "helper must receive the entire fight, not only the enemy they hit"
        )
        assert(
            recipients("Combat_Result", hit, config.participation_grace_seconds + 3) == "1",
            "helper participation not expired"
        )
        return {
            passed = true,
            owner = "1",
            nearbyAnimations = "1,2,3",
            helperResults = "1,2",
            farSpectator = "excluded",
        }
    end)
    for _, root in ipairs(roots) do
        root:Destroy()
    end
    assert(ok, result)
    return result
end

return Smoke
