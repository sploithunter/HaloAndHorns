-- Exercise the production touch picker with isolated instances and controlled ray/projection results.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local Target = luau.load(fs.readFile("src/Client/Systems/MergeEggDeploymentTarget.lua"), {
    environment = {
        Vector2 = r.Vector2,
        RaycastParams = {
            new = function()
                return {}
            end,
        },
        Enum = r.Enum,
    },
})()
local Policy = luau.load(fs.readFile("src/Client/Systems/MergeEggBoardTapPolicy.lua"))()
local function pad(id, x, tier, available)
    local p = r.Instance.new("Part")
    p.Position = r.Vector3.new(x, 100, 10)
    p:SetAttribute("MergeEggDeploymentTeamId", id)
    p:SetAttribute("MergeEggDeploymentAvailable", available ~= false)
    p:SetAttribute("MergeEggDeploymentTier", tier)
    return p
end
local function egg(id, position)
    local attributes = { MergeEggObjective = true, MergeEggTeamId = id }
    local e = {}
    local body = { Position = position, Parent = e }
    e.GetAttribute = function(_, name)
        return attributes[name]
    end
    e.IsA = function(_, name)
        return name == "Model"
    end
    e.GetPivot = function()
        return { Position = body.Position }
    end
    e.Destroy = function() end
    return e, body
end

local empty, matching, wrong, locked =
    pad(1, 100, 0), pad(2, 160, 3), pad(3, 125, 4), pad(4, 120, 0, false)
local ownEgg, body = egg(2, r.Vector3.new(160, 40, 10))
local lockedEgg = egg(4, r.Vector3.new(120, 40, 10))
local hit, included
local workspace = {
    Raycast = function(_, _, _, params)
        included = params.FilterDescendantsInstances
        return hit and { Instance = hit } or nil
    end,
}
local camera = {
    ScreenPointToRay = function(_, x, y)
        assert(x == 120 and y == 100)
        return { Origin = r.Vector3.zero, Direction = r.Vector3.zAxis }
    end,
    WorldToScreenPoint = function(_, position)
        return position, position.Y >= 0
    end,
}
local function pick(pads, objectives, radius)
    return Target.pick(
        workspace,
        camera,
        { X = 120, Y = 100 },
        pads,
        objectives or {},
        3,
        radius or 40
    )
end
-- A nested part of the visible objective maps to its purchased deployment slot.
hit = body
assert(pick({ matching }, { ownEgg }) == matching)
assert(table.find(included, ownEgg))
-- An unavailable slot's egg must not enter the raycast filter.
hit = nil
assert(pick({ locked }, { lockedEgg }) == nil)
assert(pick({ empty, matching, wrong, locked }, { ownEgg, lockedEgg }) == empty)
assert(not table.find(included, locked) and not table.find(included, lockedEgg))
-- Ignore the closer incompatible pad on a near miss; nearest compatible target wins.
assert(pick({ matching, wrong }) == matching)
assert(pick({ matching }, {}, 39) == nil)
-- Two equidistant destinations have a stable tie break regardless of iteration order.
local equal = pad(5, 140, 0)
assert(pick({ equal, empty }) == empty)
-- Direct incompatible hits stay direct so the tap policy can reject them, never substitute.
hit = wrong
local direct = pick({ empty, wrong })
assert(direct == wrong)
assert(Policy.resolve({ sourceSlot = 2, sourceTier = 3 }, {
    kind = "deployment",
    teamId = 3,
    deployedTier = direct:GetAttribute("MergeEggDeploymentTier"),
}).request == nil)
hit = nil
-- Near taps also use the visible egg center, not only its lower floor center.
matching.Position = r.Vector3.new(400, 400, 10)
body.Position = r.Vector3.new(120, 65, 10)
assert(pick({ matching }, { ownEgg }) == matching)
-- Hidden/off-screen/behind-camera pads cannot steal a nearby tap.
empty.Position = r.Vector3.new(120, 100, -10)
assert(pick({ empty }) == nil)
empty.Position = r.Vector3.new(120, -1, 10)
assert(pick({ empty }) == nil)
assert(Target.pick(workspace, nil, {}, {}, {}, 3, 40) == nil)
-- The resulting valid target feeds the unchanged server-authoritative action contract.
local result = Policy.resolve({ sourceSlot = 2, sourceTier = 3 }, {
    kind = "deployment",
    teamId = 2,
    deployedTier = 3,
})
assert(
    result.request.action == "deploy_to_hatcher"
        and result.request.sourceSlot == 2
        and result.request.teamId == 2
)
for _, instance in ipairs({ empty, matching, wrong, locked, equal, ownEgg, lockedEgg }) do
    instance:Destroy()
end
print(
    "PASS: mobile deployment target runtime (egg hit, near snap, eligibility, boundary, tie, projection, policy)"
)
