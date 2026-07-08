--[[
    stamp_mission_graybox — M2 smoke: solve a seed, stamp the gray-box kit,
    frame the camera over it. Run in EDIT mode (command bar / MCP execute_luau).
    Design SSOT: docs/MISSION_WORLDGEN.md §8.

    Everything lands under Workspace.MissionInstances.MissionInstance_demo_<seed>;
    re-running for the same seed replaces it. The kit is built into a scratch
    folder INSIDE the container (NOT ReplicatedStorage.Assets.Models — that
    subtree is Rojo-owned in Edit mode), so deleting the container removes
    every trace. Cleanup-all:
        local f = workspace:FindFirstChild("MissionInstances")
        if f then f:Destroy() end
]]

local SEED = 12345 -- change per run to inspect other maps

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TileCatalog = require(ReplicatedStorage.Shared.Worldgen.TileCatalog)
local LayoutSolver = require(ReplicatedStorage.Shared.Worldgen.LayoutSolver)
local GrayBoxKit = require(ReplicatedStorage.Shared.Worldgen.GrayBoxKit)
local TileKitBuilder = require(ServerScriptService.Server.World.TileKitBuilder)
local MissionStamper = require(ServerScriptService.Server.World.MissionStamper)

local SOLVER_PARAMS = { -- keep in lockstep with tests/headless/specs/mission_worldgen.spec.luau
    tile_budget = 30,
    target_depth = { min = 4, max = 8 },
    class_weights_by_band = {
        { upto = 0.5, corridor = 3, room = 1, junction = 1 },
        { upto = 1.0, corridor = 1, room = 3, junction = 1 },
    },
}

local SLOT_ORIGIN = CFrame.new(0, 400, 0) -- demo slot: high above the authored map

local instanceId = "demo_" .. SEED

-- replace any previous demo stamp for this seed
local existingFolder = workspace:FindFirstChild("MissionInstances")
local previous = existingFolder and existingFolder:FindFirstChild("MissionInstance_" .. instanceId)
if previous then
    previous:Destroy()
end

local catalog = TileCatalog.build(GrayBoxKit.definition())
local spec, report = LayoutSolver.solve(catalog, SOLVER_PARAMS, SEED)
assert(spec, "solve failed: " .. tostring(report and report.error))

local ok, problems = LayoutSolver.validate(catalog, spec, SOLVER_PARAMS)
assert(ok, "spec failed validation: " .. table.concat(problems or {}, " / "))

-- build the kit templates into a detached scratch folder, stamp from it,
-- then drop the templates — the clones in the container are self-sufficient
local kitScratch = Instance.new("Folder")
kitScratch.Name = "_MissionKitScratch"
local kitFolder = TileKitBuilder.build(GrayBoxKit, kitScratch)

local container, hooks = MissionStamper.stamp(spec, {
    kitFolder = kitFolder,
    slotOrigin = SLOT_ORIGIN,
    instanceId = instanceId,
    yieldEvery = 0, -- Edit mode: run synchronously
})
kitScratch:Destroy()

print(("[stamp_mission_graybox] seed=%d tiles=%d attempts=%d caps=%d loops=%d")
    :format(SEED, #spec.tiles, report.attempts, report.caps, report.loopMates))
print(("[stamp_mission_graybox] hooks: spawns=%d objectives=%d")
    :format(#(hooks.PlayerSpawn or {}), #(hooks.MissionObjective or {})))

-- frame the editor camera over the map
local bbox = spec.bbox
local center = SLOT_ORIGIN * CFrame.new((bbox.minx + bbox.maxx) / 2, 0, (bbox.minz + bbox.maxz) / 2)
local span = math.max(bbox.maxx - bbox.minx, bbox.maxz - bbox.minz)
workspace.CurrentCamera.CFrame = CFrame.lookAt(
    center.Position + Vector3.new(0, span * 1.1, span * 0.35),
    center.Position
)

return container
