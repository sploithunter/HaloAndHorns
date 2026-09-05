-- Production service in isolated Instances; no live profiles, actor removal, or data writes.
local rs = game.ReplicatedStorage
local function fresh(module)
    return assert(loadstring(module.Source))()
end
local config = fresh(rs.Configs.farm_asset_warmup)
local petsConfig = fresh(rs.Configs.pets)
local sources = game.ServerStorage.Assets.Models
local shared = rs.Shared
local fakeRS, world, uiA, uiB =
    Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder")
local assets = Instance.new("Folder")
assets.Name, assets.Parent = "Assets", fakeRS
assets:SetAttribute("ModelsReady", true)
local live = Instance.new("Folder")
live.Name, live.Parent = "PlayerPets", world
local playerService = {}
local function player(name, ui)
    local character = Instance.new("Model")
    local root = Instance.new("Part")
    root.Name, root.Anchored, root.Parent = "HumanoidRootPart", true, character
    character.Parent = world
    return {
        Name = name,
        Parent = playerService,
        Character = character,
        GetAttribute = function()
            return nil
        end,
        FindFirstChildOfClass = function()
            return ui
        end,
    }
end
local a, b = player("OwnerA", uiA), player("OwnerB", uiB)
local now, selected = 0, "basic_egg"
local profiles = {
    [a] = { Inventory = { pets = { items = {} } } },
    [b] = { Inventory = { pets = { items = {} } } },
}
local ok, result = pcall(function()
    local source = game.ServerScriptService.Server.Services.FarmAssetWarmupService.Source
    local first = assert(source:find("local Service =", 1, true))
    source = source:sub(first)
    local runtime = assert(
        loadstring(
            "local Players, ReplicatedStorage, workspace, game, os, PlaceRuntime, Plan, PetInventoryView, ModelTemplateStore, EggWorldQuery, Signals, RunService = ...\n"
                .. source
        )
    )(
        playerService,
        fakeRS,
        world,
        { PlaceId = fresh(rs.Configs.places).roles.main.place_ids[1] },
        {
            clock = function()
                return now
            end,
        },
        fresh(shared.Game.PlaceRuntime),
        fresh(shared.Game.FarmAssetPlan),
        fresh(shared.Inventory.PetInventoryView),
        {
            root = function()
                return sources
            end,
        },
        {
            GetEggs = function()
                return {}
            end,
        },
        {},
        {}
    )
    local service = setmetatable({
        _config = config,
        _places = fresh(rs.Configs.places),
        _pets = petsConfig,
        _thumbnails = fresh(rs.Configs.pet_thumbnail_assets),
        _records = {},
        _data = {
            GetData = function(_, who)
                return profiles[who]
            end,
        },
    }, runtime)
    local realInput = service._input
    function service:_input(who, record, clock)
        local input = realInput(self, who, record, clock)
        input.eggs = { { id = selected, distance = 0 } }
        return input
    end
    service:_reconcile(a)
    service:_reconcile(b)
    local cacheA, cacheB =
        uiA:FindFirstChild(config.cache_folder), uiB:FindFirstChild(config.cache_folder)
    assert(cacheA and cacheB and cacheA ~= cacheB, "Cache ownership must be per player")
    assert(
        cacheA.Models.Pets.bunny.basic and cacheA.Models.Pets.dragon.rainbow,
        "Earth pool incomplete"
    )
    assert(cacheA.Images:FindFirstChild("bunny:basic"), "Missing flat thumbnail prefetch")
    local count, model = #cacheA.Models.Pets:GetDescendants(), cacheA.Models.Pets.bunny.basic
    service:_reconcile(a)
    assert(
        cacheA.Models.Pets.bunny.basic == model and #cacheA.Models.Pets:GetDescendants() == count,
        "No-op cloned models"
    )
    local owner = Instance.new("Folder")
    owner.Name, owner.Parent = a.Name, live
    local survivor = sources.Pets.bunny.basic:Clone()
    survivor:SetAttribute("PetType", "bunny")
    survivor:SetAttribute("PetVariant", "basic")
    survivor.Parent = owner
    selected = "lava_egg"
    now = config.retention_seconds + 1
    service:_reconcile(a)
    assert(cacheA.Models.Pets.bunny.basic, "Living old pet evicted")
    assert(not cacheA.Models.Pets:FindFirstChild("kitty"), "Unused old family never evicted")
    assert(cacheB.Models.Pets.kitty.basic, "Owner A reconciliation touched Owner B")
    assert(survivor.Parent == owner, "Cache eviction removed live actor")
    assert(
        not service:_request(a, { id = "kitty", variant = "basic" }),
        "Unowned remote preview accepted"
    )
    now += 1
    profiles[a].Inventory.pets.items.owned = { id = "kitty", variant = "golden" }
    assert(
        service:_request(a, { id = "kitty", variant = "golden" }),
        "Owned remote preview rejected"
    )
    assert(cacheA.Models.Pets.kitty.golden, "Owned preview was not published")
    service._places = { default_role = "merge", roles = {} }
    local empty = Instance.new("Folder")
    local c = player("MergeOnly", empty)
    service:_reconcile(c)
    assert(#empty:GetChildren() == 0, "Farm cache leaked into Merge")
    empty:Destroy()
    return "PASS: complete Earth variants/images, separate owner caches, stable no-op, surviving old pet retained, unused eviction, owned-only requests, Merge exclusion"
end)
fakeRS:Destroy()
world:Destroy()
uiA:Destroy()
uiB:Destroy()
assert(ok, result)
return result
