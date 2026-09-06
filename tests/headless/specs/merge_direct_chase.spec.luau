local cfg = loadModule("configs/combat.lua").engagement.pathfinding

return function()
    describe("Merge direct pursuit contract", function()
        it("disables only Merge obstacle routing", function()
            expect(cfg.enabled).to.equal(true)
            expect(cfg.merge_enabled).to.equal(false)
        end)
        it("checks the authoritative enemy marker before any obstacle query", function()
            local source = readFile("src/Server/Services/EnemyService.lua")
            local first = assert(source:find('local route = "direct"', 1, true))
            local last = assert(source:find("local np = EnemyAI.chaseStep", first, true))
            local route = source:sub(first, last - 1)
            expect(
                route:find('model:GetAttribute("MergeEggPrototypeEnemy") == true', 1, true) ~= nil
            ).to.equal(true)
            expect(route:find("if not directArena and self:_directChaseBlocked", 1, true) ~= nil).to.equal(
                true
            )
            expect(route:find("self:_clearChasePath(entry)", 1, true) ~= nil).to.equal(true)
        end)
        it("retains bay clamping for march and chase", function()
            local source = readFile("src/Server/Services/EnemyService.lua")
            local march =
                assert(source:find("function EnemyService:_followAuthoredMarchGoal", 1, true))
            local chase = assert(source:find("local np = EnemyAI.chaseStep", march, true))
            expect(
                source:find("self:_leashToHomeArea(entry, Vector3.new(x, gy, z))", march, true)
                    < chase
            ).to.equal(true)
            expect(source:find("newPos = self:_leashToHomeArea(entry, newPos)", chase, true) ~= nil).to.equal(
                true
            )
            local spawn = readFile("src/Server/Services/MergeEggPrototypeService.lua")
            expect(
                spawn:find("movementLeash = self:_movementLeash(record, position)", 1, true) ~= nil
            ).to.equal(true)
        end)
    end)
end
