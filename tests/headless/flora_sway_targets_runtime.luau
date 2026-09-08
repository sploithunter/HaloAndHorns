local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local source = fs.readFile("src/Client/Systems/FloraSway.lua")
local mathModule = luau.load(fs.readFile("src/Shared/Game/FloraSway.lua"))()
local config = luau.load(fs.readFile("configs/flora.lua"))().sway
local root = r.Instance.new("Folder")
local tagged = {}
local env = {
    Workspace = root,
    FloraSwayMath = mathModule,
    TAG = "FloraSway",
    CollectionService = {
        HasTag = function(_, instance, tag)
            return tagged[instance] == tag
        end,
    },
}
local first = assert(source:find("local function isSoftCandidate(", 1, true))
local last = assert(source:find("\nlocal function remember(", first, true))
local candidate =
    luau.load(source:sub(first, last - 1) .. "\nreturn isSoftCandidate", { environment = env })()
local function model(name, parent)
    local m = r.Instance.new("Model")
    m.Name = name
    m.Parent = parent or root
    return m
end
local stand = model("Grass")
local child = model("cloud_bush", stand)
local anchor = r.Instance.new("Part")
anchor.Name = "UIanchor"
anchor.Parent = stand
assert(
    not candidate(stand) and not candidate(child),
    "authored stand and contents must be excluded before egg placement"
)
stand:SetAttribute("FloraSway", true)
tagged[child] = "FloraSway"
assert(
    not candidate(stand) and not candidate(child),
    "flora opt-in must not override gameplay ownership"
)
anchor:Destroy()
stand:SetAttribute("FloraSway", nil)
tagged[child] = nil
for _, tag in ipairs({ "EggStand", "EggDisplay" }) do
    tagged[stand] = tag
    assert(not candidate(stand) and not candidate(child))
end
tagged[stand] = nil
for _, attr in ipairs({ "EggId", "MergeEggObjective", "MergeEggBoardEgg" }) do
    stand:SetAttribute(attr, attr == "EggId" and "grass_egg" or true)
    assert(not candidate(stand) and not candidate(child))
    stand:SetAttribute(attr, nil)
end
local bush = model("cloud_bush")
local tree = model("oak_tree")
assert(candidate(bush) and candidate(tree))
assert(mathModule.amplitude(tree.Name, nil, config) == 0)
assert(mathModule.amplitude(bush.Name, nil, config) > 0)
-- Trees are excluded before any bounds/pivot acquisition, so they consume no motion-loop entries.
local tracked = {}
env.tracked, env.config = tracked, config
first = assert(source:find("local function remember(", 1, true))
last = assert(source:find("\nlocal function forget(", first, true))
local remember =
    luau.load(source:sub(first, last - 1) .. "\nreturn remember", { environment = env })()
remember(tree)
assert(next(tracked) == nil)
root:Destroy()
print(
    "PASS: flora target ownership, ancestor exclusions, opt-in precedence, rigid-tree exclusion, small-plant motion"
)
