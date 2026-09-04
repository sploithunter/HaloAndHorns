-- Isolated server gate fixture. Captures route requests without teleporting anyone or touching
-- profiles; checks both gate-binding orders so late ZoneService cannot restore Coming Soon.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = game:GetService("ServerScriptService").Server.Services
local Merge = require(Services.MergeEggPrototypeService)
local Zone = require(Services.ZoneService)
local config = require(ReplicatedStorage.Configs.merge_egg_prototype)
local Smoke = {}

function Smoke.run()
    local fixture = Instance.new("Folder")
    fixture.Name = "MergePublicGateSmoke"
    fixture.Parent = workspace
    local ok, result = pcall(function()
        local gate = table.clone(config.gate)
        gate.hook_name = "MergePublicGateSmokeHook"
        local hook = Instance.new("Part")
        hook.Name = gate.hook_name
        hook.Anchored = true
        hook.Parent = fixture
        local title = Instance.new("Part")
        title.Name = "HallOfWorldsGateTitle"
        title.Anchored = true
        title.Parent = fixture
        local gui = Instance.new("SurfaceGui")
        gui.Parent = title
        local text = Instance.new("TextLabel")
        text.Text = "COMING SOON"
        text.Parent = gui
        local requested = {}
        local ordinaryPlayer = { UserId = 1, Name = "PublicGateFixture" }
        local merge = setmetatable({
            _config = { gate = gate },
            _internalAccountsConfig = {},
            _isDedicatedMergePlace = function()
                return true
            end,
            _teleportToRole = function(_, player, role)
                assert(player == ordinaryPlayer, "Route player changed")
                requested[#requested + 1] = role
                return true
            end,
        }, Merge)
        local zone = setmetatable({ _mergeGateConfig = gate }, Zone)
        assert(merge:_hasPreviewAccess(ordinaryPlayer), "Public direct entry denied")
        assert(merge:_enterFromHall(ordinaryPlayer), "Public gate denied")
        assert(merge:_returnToFarmAndFight(ordinaryPlayer), "Public return denied")
        assert(table.concat(requested, ",") == "merge,main", "Incorrect destination roles")
        zone:_sealDisabledHallEntryHook(hook)
        merge:_bindRestrictedHallGate()
        local prompt = hook:FindFirstChild(gate.prompt_name)
        assert(
            prompt and prompt.Enabled and prompt.ObjectText == gate.object_text,
            "Public prompt missing"
        )
        assert(text.Text == gate.title, "Merge bound after Zone has stale title")
        zone:_sealDisabledHallEntryHook(hook)
        assert(text.Text == gate.title, "Zone bound after Merge restored Coming Soon")
        assert(hook.CanCollide, "Retired in-place Hall route must remain sealed")
        return {
            passed = true,
            ordinaryPlayerAllowed = true,
            routes = requested,
            gateTitle = text.Text,
            bothBindingOrders = true,
        }
    end)
    fixture:Destroy()
    assert(ok, result)
    return result
end

return Smoke
