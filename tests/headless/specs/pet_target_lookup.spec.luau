return function()
    describe("Pet work target registry integration", function()
        it("uses the existing enemy registry before the compatibility traversal", function()
            local source = readFile("src/Server/Services/PetFollowService.lua")
            local first = assert(source:find("function PetFollowService:_findBreakable(", 1, true))
            local indexed = assert(source:find("service:FindTargetModel(id)", first, true))
            local scope = assert(source:find("indexed:IsDescendantOf(enemies)", indexed, true))
            local fallback = assert(source:find("enemies:GetDescendants()", first, true))
            expect(indexed < scope and scope < fallback).to.equal(true)
        end)
        it(
            "validates indexed identity without introducing a separate retained model cache",
            function()
                local source = readFile("src/Server/Services/EnemyService.lua")
                local body = assert(
                    source:match(
                        "function EnemyService:FindTargetModel%(targetId%)(.-)function EnemyService:_setAggroOwner"
                    )
                )
                expect(body:find("self._enemies[targetId]", 1, true) ~= nil).to.equal(true)
                expect(body:find("model.Parent", 1, true) ~= nil).to.equal(true)
                expect(body:find("id.Value == targetId", 1, true) ~= nil).to.equal(true)
                expect(body:find('id:IsA("NumberValue")', 1, true) ~= nil).to.equal(true)
                expect(body:find("SetAttribute", 1, true)).to.equal(nil)
            end
        )
    end)
end
