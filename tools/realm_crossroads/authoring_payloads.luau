-- Offline authoring archive contract. Payloads are inert StringValues, never runtime scripts.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local Payloads = { folder = "CrossroadsAuthoringInputs", registry = "Registry" }
Payloads.keys = { font_source = "json", bundle_source = "json", client_source = "source" }
local function ensure(parent, class, name)
    local value = parent:FindFirstChild(name)
    if value then
        assert(value.ClassName == class, "Unexpected authoring archive class: " .. name)
    else
        value = roblox.Instance.new(class)
        value.Name, value.Parent = name, parent
    end
    return value
end
function Payloads.sync(storage, registryPath)
    local registryText = fs.readFile(registryPath)
    local registry = serde.decode("json", registryText)
    local old = storage:FindFirstChild(Payloads.folder)
    if old then
        old:Destroy()
    end
    local archive = ensure(storage, "Folder", Payloads.folder)
    archive:SetAttribute("AuthoringOnly", true)
    local record = ensure(archive, "StringValue", Payloads.registry)
    record.Value = registryText
    record:SetAttribute("SourcePath", registryPath)
    local total = 0
    for _, pass in ipairs(registry.application_order) do
        local text = fs.readFile(pass.config)
        local config = serde.decode("json", text)
        local path = assert(config[pass.source_key], "Missing source: " .. pass.config)
        ensure(storage, "ModuleScript", pass.module).Source = fs.readFile(path)
        ensure(storage, "StringValue", pass.config_value).Value = text
        local folder = ensure(archive, "Folder", pass.module)
        for key, kind in pairs(Payloads.keys) do
            if config[key] then
                local payload = ensure(folder, "StringValue", key)
                payload.Value = fs.readFile(config[key])
                payload:SetAttribute("SourcePath", config[key])
                payload:SetAttribute("PayloadKind", kind)
                total += 1
            end
        end
    end
    return #registry.application_order, total
end
return Payloads
