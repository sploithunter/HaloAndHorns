-- Offline checkpoint/source audit. Does not open Studio or run any installer.
-- Supply the accepted native paver count explicitly; it is an acceptance input, not art tuning.
-- mise exec -- lune run tools/realm_crossroads/validate_checkpoint.luau --expected-pavers 300
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local payloads = require("./authoring_payloads")
local function argument(name, fallback)
    for index, value in ipairs(process.args) do
        if value == name then
            return assert(process.args[index + 1], "Missing " .. name .. " value")
        end
    end
    return fallback
end
local registryPath = argument("--registry", "configs/realm_crossroads_polish.json")
local registry = serde.decode("json", fs.readFile(registryPath))
local path = argument("--checkpoint", registry.native_checkpoint)
local paverInput = assert(argument("--expected-pavers"), "Supply accepted --expected-pavers count")
local expectedPavers = tonumber(paverInput)
assert(expectedPavers and expectedPavers > 0, "Invalid expected paver count")
local game = roblox.deserializePlace(fs.readFile(path))
local storage, replicated = game.ServerStorage, game.ReplicatedStorage
local starter = game.StarterPlayer.StarterPlayerScripts
assert(
    not storage:FindFirstChild("CrossroadsReplayBackup"),
    "Remove/exclude temporary CrossroadsReplayBackup before checkpoint export"
)
local archive = assert(
    storage:FindFirstChild(payloads.folder),
    "Missing inert authoring payload archive; refresh checkpoint with save_native_terrain"
)
local terrainConfig = serde.decode("json", fs.readFile("configs/realm_crossroads_terrain.json"))
local world = assert(game.Workspace:FindFirstChild(terrainConfig.root), "Missing native world")
assert(game.Workspace:FindFirstChild("Terrain"), "Missing native Terrain")
local function equal(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    for k, v in pairs(a) do
        if not equal(v, b[k]) then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end
local function jsonMatches(text, expected, label)
    assert(equal(serde.decode("json", text), expected), "JSON mismatch: " .. label)
end
local function only(parent, name, class)
    local found
    for _, child in ipairs(parent:GetChildren()) do
        if child.Name == name then
            assert(not found, "Duplicate " .. name)
            assert(not class or child.ClassName == class, "Wrong class: " .. name)
            found = child
        end
    end
    return assert(found, "Missing " .. name)
end
jsonMatches(only(archive, payloads.registry, "StringValue").Value, registry, "registry")
assert(#archive:GetChildren() == #registry.application_order + 1, "Stale or missing pass archives")
local supplemental, pavers, clients = 0, 0, 0
local function cache(name, template)
    local folder = only(storage, name)
    if template then
        only(folder, template)
    end
    return folder
end
for _, pass in ipairs(registry.application_order) do
    local cfg = serde.decode("json", fs.readFile(pass.config))
    local source = fs.readFile(cfg[pass.source_key])
    assert(
        only(storage, pass.module, "ModuleScript").Source == source,
        "Installer source mismatch: " .. pass.module
    )
    jsonMatches(only(storage, pass.config_value, "StringValue").Value, cfg, pass.config)
    local folder = only(archive, pass.module, "Folder")
    local expectedSupplemental = 0
    for key, kind in pairs(payloads.keys) do
        if cfg[key] then
            local item = only(folder, key, "StringValue")
            assert(
                item.Value == fs.readFile(cfg[key]),
                "Supplemental source mismatch: " .. cfg[key]
            )
            assert(
                item:GetAttribute("SourcePath") == cfg[key]
                    and item:GetAttribute("PayloadKind") == kind,
                "Supplemental metadata mismatch"
            )
            supplemental += 1
            expectedSupplemental += 1
        end
    end
    assert(
        #folder:GetChildren() == expectedSupplemental,
        "Stale supplemental payloads: " .. pass.module
    )
    if cfg.template_cache then
        cache(cfg.template_cache)
    end
    if cfg.flora and cfg.flora.cache then
        local templates = cache(cfg.flora.cache)
        for _, entry in ipairs(cfg.flora.entries) do
            only(templates, entry.name)
        end
    end
    if cfg.placement and cfg.placement.cache then
        cache(cfg.placement.cache, cfg.placement.template)
    end
    if cfg.cache and cfg.models then
        local templates = cache(cfg.cache)
        for name in pairs(cfg.models) do
            only(templates, name)
        end
    end
    if cfg.asset_caches then
        local present = false
        for _, name in ipairs(cfg.asset_caches) do
            present = present or storage:FindFirstChild(name) ~= nil
        end
        assert(present, "Missing every configured native asset cache")
    end
    if cfg.entries and cfg.template_cache then
        local templates = cache(cfg.template_cache)
        for _, entry in ipairs(cfg.entries) do
            if entry.asset then
                only(templates, entry.asset)
            end
        end
    end
    if cfg.font_source then
        local templates = cache("CrossroadsLetterSolids")
        for i = 1, #cfg.text do
            only(templates, cfg.text:sub(i, i))
        end
    end
    if cfg.paving then
        local root = only(world, cfg.root)
        for _, item in ipairs(root:GetDescendants()) do
            if item.Name == "StonePaver" and item:IsA("BasePart") then
                pavers += 1
            end
        end
    end
    if cfg.bundle_source then
        local bundle = serde.decode("json", fs.readFile(cfg.bundle_source))
        local runtime = only(replicated, cfg.runtime_root, "Folder")
        for name, moduleSource in pairs(bundle.modules) do
            assert(
                only(runtime, name, "ModuleScript").Source == moduleSource,
                "Installed FX module mismatch: " .. name
            )
        end
        jsonMatches(only(runtime, "ConfigJSON", "StringValue").Value, {
            integration = cfg,
            schema = bundle.schema,
            presets = bundle.presets,
            ripple = bundle.ripple,
        }, "installed FX bundle/config")
        -- FX client is a literal authored inside its installer; parse without executing the installer.
        local clientSource = assert(
            source:match("client%.Source%s*=%s*%[==%[(.-)%]==%]"),
            "FX literal client boundary changed; update validator"
        )
        clientSource = clientSource:gsub("^\r?\n", "", 1)
        assert(
            only(starter, cfg.client_name, "LocalScript").Source == clientSource,
            "Installed FX client source mismatch; replay installer"
        )
        clients += 1
    elseif cfg.client_source then
        local name = cfg.runtime_root or cfg.runtime_folder
        local runtime = only(replicated, name, "Folder")
        assert(
            only(starter, name, "LocalScript").Source == fs.readFile(cfg.client_source),
            "Installed client source mismatch: " .. name
        )
        local actual = serde.decode("json", only(runtime, "Config", "StringValue").Value)
        if cfg.asset_cache then
            cache(cfg.asset_cache, cfg.asset_template)
            local template = only(runtime, cfg.template_name, "Model")
            local asset = serde.decode("json", fs.readFile(cfg.asset_source))
            for _, boneName in ipairs({ asset.rig.body_bone, asset.rig.tail_bone }) do
                local bone = template:FindFirstChild(boneName, true)
                assert(bone and bone.ClassName == "Bone", "Missing fish Bone: " .. boneName)
            end
            -- Installed water_y is a measured result; compare every authored key separately.
            for i, pond in ipairs(actual.ponds) do
                assert(type(pond.water_y) == "number", "Missing sampled native waterline")
                pond.water_y = cfg.ponds[i].water_y
            end
        end
        assert(equal(actual, cfg), "Installed runtime config mismatch: " .. name)
        clients += 1
    end
end
assert(
    pavers == expectedPavers,
    "Native paver count mismatch: " .. pavers .. " vs " .. expectedPavers
)
for _, item in ipairs(world:GetDescendants()) do
    assert(item.Name ~= "GreenPoolMist", "Legacy double-emission mist remains")
    assert(item.Name ~= "ArenaSightlineQA", "Temporary native QA geometry remains")
end
print(
    "PASS checkpoint/source audit: "
        .. #registry.application_order
        .. " installers/configs, "
        .. supplemental
        .. " supplemental payloads, "
        .. clients
        .. " runtime clients, "
        .. pavers
        .. " pavers; "
        .. #game:GetDescendants()
        .. " instances"
)
print(
    "Source consistency is not geometry replay proof. Native walk/collision, water visibility and runtime lifecycle QA remain separate."
)
