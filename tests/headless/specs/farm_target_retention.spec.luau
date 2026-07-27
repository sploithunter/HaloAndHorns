local FarmTargetRetention = loadModule("src/Shared/Game/FarmTargetRetention.lua")

return function()
    describe("FarmTargetRetention.withinLeash", function()
        it("keeps the target through the configured boundary", function()
            expect(FarmTargetRetention.withinLeash(119.9, 120)).to.equal(true)
            expect(FarmTargetRetention.withinLeash(120, 120)).to.equal(true)
        end)

        it("releases the target after the owner crosses the boundary", function()
            expect(FarmTargetRetention.withinLeash(120.1, 120)).to.equal(false)
        end)

        it("fails open when position data or a positive leash is unavailable", function()
            expect(FarmTargetRetention.withinLeash(nil, 120)).to.equal(true)
            expect(FarmTargetRetention.withinLeash(500, nil)).to.equal(true)
            expect(FarmTargetRetention.withinLeash(500, 0)).to.equal(true)
        end)

        it("releases mining work immediately when the owner enters combat", function()
            expect(FarmTargetRetention.shouldRelease({
                inCombat = true,
                distance = 10,
                maxDistance = 120,
            })).to.equal(true)
            expect(FarmTargetRetention.shouldRelease({
                inCombat = false,
                distance = 10,
                maxDistance = 120,
            })).to.equal(false)
        end)

        it("wires the auto-target acquisition distance into the pet work loop", function()
            local service = readFile("src/Server/Services/PetFollowService.lua")
            expect(service:find('LoadConfig("auto_systems")', 1, true)).to.be.ok()
            expect(service:find("FarmTargetRetention.shouldRelease", 1, true)).to.be.ok()
            expect(service:find('GetAttribute("InCombat")', 1, true)).to.be.ok()
            expect(service:find("autoTarget.max_target_distance", 1, true)).to.be.ok()
        end)

        it("recalls mining only when a proximity cave wave actually spawns", function()
            local follow = readFile("src/Server/Services/PetFollowService.lua")
            expect(follow:find("function PetFollowService:ReleaseMiningTargets", 1, true)).to.be.ok()
            expect(follow:find('targetType.Value)) == "crystals"', 1, true)).to.be.ok()

            local spawner = readFile("src/Server/Services/BaddieSpawnerService.lua")
            expect(spawner:find("if spawned > 0", 1, true)).to.be.ok()
            expect(spawner:find("self._petFollowService:ReleaseMiningTargets", 1, true)).to.be.ok()
            expect(spawner:find("elseif self:_isRealmCave(part)", 1, true)).to.be.ok()
        end)
    end)

    describe("FarmTargetRetention.shouldKeep", function()
        it("keeps an unfinished crystal during automatic farming", function()
            expect(FarmTargetRetention.shouldKeep({
                automatic = true,
                targetType = "Crystals",
                targetId = 42,
                targetHp = 99,
            })).to.equal(true)
        end)

        it("releases a finished or missing crystal for the next poll", function()
            expect(FarmTargetRetention.shouldKeep({
                automatic = true,
                targetType = "Crystals",
                targetId = 42,
                targetHp = 0,
            })).to.equal(false)
            expect(FarmTargetRetention.shouldKeep({
                automatic = true,
                targetType = "Crystals",
                targetId = 0,
                targetHp = 99,
            })).to.equal(false)
        end)

        it("never blocks a deliberate manual retarget", function()
            expect(FarmTargetRetention.shouldKeep({
                automatic = false,
                targetType = "Crystals",
                targetId = 42,
                targetHp = 99,
            })).to.equal(false)
        end)

        it("does not classify combat targets as retained mining work", function()
            expect(FarmTargetRetention.shouldKeep({
                automatic = true,
                targetType = "Enemy",
                targetId = 42,
                targetHp = 99,
            })).to.equal(false)
        end)
    end)
end
