-- Presentation-only snapshot. Construct inside one render callback, then discard it.
-- Each requested folder is traversed once, rather than once per attacking pet.
local FrameTargetLookup = {}
FrameTargetLookup.__index = FrameTargetLookup

function FrameTargetLookup.new()
    return setmetatable({ scopes = {} }, FrameTargetLookup)
end

function FrameTargetLookup:find(scope, id)
    if not scope or id == nil then
        return nil
    end
    local targets = self.scopes[scope]
    if not targets then
        targets = {}
        self.scopes[scope] = targets
        for _, descendant in ipairs(scope:GetDescendants()) do
            if descendant.Name == "BreakableID" and descendant:IsA("NumberValue") then
                -- Preserve the traversal's first match, including duplicate authored IDs.
                if targets[descendant.Value] == nil then
                    targets[descendant.Value] = descendant
                end
            end
        end
    end
    local value = targets[id]
    if
        value
        and value.Parent
        and value.Name == "BreakableID"
        and value.Value == id
        and value:IsDescendantOf(scope)
    then
        return value.Parent
    end
    return nil
end

return FrameTargetLookup
