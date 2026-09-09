-- Temporary Server Script for a fresh Studio Play session. Never install into the saved place.
-- All arena rewards must be disabled; settings below are transient Player attributes, not profile writes.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local e = require(game.ServerScriptService.Server.Services.EnemyService)
local api = require(game.ServerScriptService.Server.Services.GameAPIService)
local arena = api._moduleLoader:Get("CrossroadsArena")
local Leash = require(game.ReplicatedStorage.Shared.Game.EnemyLeash)
local LevelScale = require(game.ReplicatedStorage.Shared.Game.LevelScale)
local p = assert(Players:GetPlayers()[1], "Join first")
assert(arena.cfg.studio_rewards == false, "Do not test with live rewards")
local original = {
    position = p.Character:GetPivot(),
    level = p:GetAttribute("EffectiveLevel"),
    offset = p:GetAttribute("EnemyLevelOffset"),
    group = p:GetAttribute("TrialGroupScale"),
}
local report = { cases = {}, displacementSamples = 0, territorySamples = 0 }
local ok, err = xpcall(function()
    local bounds = workspace.RealmCrossroadsR4.CrossroadsActivitiesR7.PatrolGrove.CombatBounds
    for _, case in ipairs({
        { level = 1, offset = -3, group = 0.25 },
        { level = 16, offset = 3, group = 2 },
    }) do
        arena:_clear("qa_reset")
        arena.nextAt = math.huge
        p:SetAttribute("EffectiveLevel", case.level)
        p:SetAttribute("EnemyLevelOffset", case.offset)
        p:SetAttribute("TrialGroupScale", case.group)
        p.Character:PivotTo(CFrame.new(bounds.Position + Vector3.new(0, 0, 32)))
        arena:_begin(p, { p })
        local run = assert(arena.run, "Arena did not start")
        local deadline = os.clock() + 30
        repeat
            for _, model in ipairs(run.models) do
                model:SetAttribute("CombatShield", 1000000000)
                model:SetAttribute("HeldUntil", os.time() + 120)
            end
            task.wait(0.05)
        until not run.pending or arena.run ~= run or os.clock() >= deadline
        assert(arena.run == run and not run.pending, "Arena arrival failed")
        local count, bosses = 0, 0
        for _, model in ipairs(run.models) do
            local entry =
                assert(e._enemies[model.BreakableID.Value], "Enemy lost before inspection")
            assert(entry.rewardPolicy == "none", "Studio enemy rewards enabled")
            local expected = LevelScale.effectiveLevel(
                math.max(1, case.level + case.offset),
                e._levelingConfig.rank_offset[entry.def.tier] or 0
            )
            assert(model:GetAttribute("Level") == expected, "Incorrect level/menu scaling")
            local base = entry.pos
            for degrees = 0, 359, 15 do
                local angle = math.rad(degrees)
                local wanted = base + Vector3.new(math.cos(angle) * 1000, 0, math.sin(angle) * 1000)
                e:SetScriptedMove(model, wanted)
                assert(
                    Leash.inside(
                        entry.pos.X,
                        entry.pos.Z,
                        entry.movementLeash.shapes,
                        entry.bodyRadius
                    ),
                    "Scripted movement escaped outer edge"
                )
                local moved =
                    e:_resolvePlanarDest(entry, base, wanted - base, 1000, { leash_inset = 0 })
                assert(
                    moved
                        and Leash.inside(
                            moved.X,
                            moved.Z,
                            entry.movementLeash.shapes,
                            entry.bodyRadius
                        ),
                    "Displacement escaped outer edge"
                )
                report.displacementSamples += 2
            end
            e:SetScriptedMove(model, base)
            local shape = entry.movementLeash.shapes[1]
            for _, pos in ipairs({
                Vector3.new(shape.cx - shape.halfX - 1, bounds.Position.Y, shape.cz),
                Vector3.new(shape.cx + shape.halfX + 1, bounds.Position.Y, shape.cz),
                Vector3.new(shape.cx, bounds.Position.Y, shape.cz - shape.halfZ - 1),
                Vector3.new(shape.cx, bounds.Position.Y, shape.cz + shape.halfZ + 1),
            }) do
                p.Character:PivotTo(CFrame.new(pos))
                assert(not e:_inTerritory(entry, p), "Spectator is inside combat territory")
                report.territorySamples += 1
            end
            p.Character:PivotTo(CFrame.new(bounds.Position + Vector3.new(0, 0, 32)))
            assert(e:_inTerritory(entry, p), "Inside fighter rejected")
            if entry.def.tier == "boss" or entry.def.tier == "archvillain" then
                assert(
                    entry.def.exclusive_egg and entry.def.exclusive_egg.chance > 0,
                    "Boss egg missing"
                )
                bosses += 1
            else
                assert(entry.def.exclusive_egg == nil, "Non-boss egg roll")
            end
            count += 1
        end
        assert(count <= arena.cfg.max_enemies and bosses >= 1, "Invalid pack capacity/boss count")
        table.insert(report.cases, {
            level = case.level,
            offset = case.offset,
            group = case.group,
            enemies = count,
            bosses = bosses,
        })
        local defeatedIds = {}
        for _, model in ipairs(run.models) do
            table.insert(defeatedIds, model.BreakableID.Value)
            model:SetAttribute("HP", 0)
        end
        task.wait(arena.cfg.poll_seconds * 2)
        assert(arena.run == nil, "Defeated round did not finish")
        for _, id in ipairs(defeatedIds) do
            e:_onDefeated(id)
        end
        assert(run.remaining == 0, "Repeated defeat duplicated settlement")
    end
end, debug.traceback)
arena:_clear("qa_finished")
p:SetAttribute("EffectiveLevel", original.level)
p:SetAttribute("EnemyLevelOffset", original.offset)
p:SetAttribute("TrialGroupScale", original.group)
p.Character:PivotTo(original.position)
report.ok, report.error = ok, not ok and tostring(err) or nil
local result = Instance.new("StringValue")
result.Name = "CrossroadsArenaQAResult"
result.Value = game.HttpService:JSONEncode(report)
result.Parent = ServerStorage
print("[ArenaQA] " .. result.Value)
