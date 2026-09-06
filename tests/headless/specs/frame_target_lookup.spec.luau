local Lookup = loadModule("src/Shared/Game/FrameTargetLookup.lua")

local function folder()
    local scope = { descendants = {}, scans = 0 }
    function scope:GetDescendants()
        self.scans += 1
        return self.descendants
    end
    return scope
end

local function target(scope, id, kind)
    local model = {}
    local value = { Name = "BreakableID", Value = id, Parent = model, scope = scope }
    function value:IsA(class)
        return class == (kind or "NumberValue")
    end
    function value:IsDescendantOf(root)
        return self.scope == root and self.Parent ~= nil
    end
    table.insert(scope.descendants, value)
    return model, value
end

return function()
    describe("Frame-scoped presentation target lookup", function()
        it("scans once for repeated and different target IDs", function()
            local scope = folder()
            local a, b = target(scope, 1), target(scope, 2)
            local lookup = Lookup.new()
            for _ = 1, 100 do
                expect(lookup:find(scope, 1)).to.equal(a)
                expect(lookup:find(scope, 2)).to.equal(b)
                expect(lookup:find(scope, 999)).to.equal(nil)
            end
            expect(scope.scans).to.equal(1)
        end)
        it("isolates folders with identical IDs and keeps the first duplicate", function()
            local earth, ice = folder(), folder()
            local a, b = target(earth, 1), target(ice, 1)
            target(earth, 1)
            local lookup = Lookup.new()
            expect(lookup:find(earth, 1)).to.equal(a)
            expect(lookup:find(ice, 1)).to.equal(b)
        end)
        it("ignores non-number identifiers and unavailable scopes", function()
            local scope = folder()
            target(scope, 1, "IntValue")
            local lookup = Lookup.new()
            expect(lookup:find(scope, 1)).to.equal(nil)
            expect(lookup:find(nil, 1)).to.equal(nil)
            expect(lookup:find(scope, nil)).to.equal(nil)
        end)
        it("rejects detached, renamed, reidentified or moved snapshot entries", function()
            for _, change in ipairs({
                function(v)
                    v.Parent = nil
                end,
                function(v)
                    v.Name = "OtherID"
                end,
                function(v)
                    v.Value = 2
                end,
                function(v)
                    v.scope = folder()
                end,
            }) do
                local scope = folder()
                local model, value = target(scope, 1)
                local lookup = Lookup.new()
                expect(lookup:find(scope, 1)).to.equal(model)
                change(value)
                expect(lookup:find(scope, 1)).to.equal(nil)
            end
        end)
        it("rebuilds newly streamed and replaced targets on the next frame", function()
            local scope = folder()
            local old, value = target(scope, 1)
            local first = Lookup.new()
            expect(first:find(scope, 1)).to.equal(old)
            value.Parent = nil
            scope.descendants = {}
            local replacement = target(scope, 1)
            local added = target(scope, 2)
            expect(first:find(scope, 1)).to.equal(nil)
            expect(first:find(scope, 2)).to.equal(nil)
            local nextFrame = Lookup.new()
            expect(nextFrame:find(scope, 1)).to.equal(replacement)
            expect(nextFrame:find(scope, 2)).to.equal(added)
            expect(scope.scans).to.equal(2)
        end)
        it("allocates the snapshot inside the render callback, not at module lifetime", function()
            local source = readFile("src/Client/Systems/PetFollowController.lua")
            local render =
                assert(source:find("RunService.RenderStepped:Connect(function(dt)", 1, true))
            local allocation =
                assert(source:find("local targetLookup = FrameTargetLookup.new()", 1, true))
            local use = assert(source:find("findBreakable(targetLookup,", allocation, true))
            expect(render < allocation and allocation < use).to.equal(true)
        end)
    end)
end
