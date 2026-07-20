--[[
    dump_mission_decor_live.luau — capture MeshId + albedo bind from
    ReplicatedStorage.MissionProps for the pairing audit.

    Run in Studio Edit (MCP execute_luau or command bar). Copy the returned
    JSON to scripts/mission_decor_live_dump.json, then:

        node scripts/check_mission_decor_pairings.js
        node scripts/check_mission_decor_pairings.js --stamp-from-live  # after visual bless

    Why: kaleidoscope is usually wrong-generation albedo on a mesh (decimate/
    rebake multi-path), not mysterious CDN rot. This dump is the live truth.
]]

local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local store = RS:FindFirstChild("MissionProps")
assert(store, "ReplicatedStorage.MissionProps missing")

local props = {}
local kids = store:GetChildren()
table.sort(kids, function(a, b)
    return a.Name < b.Name
end)

for _, child in ipairs(kids) do
    if not (string.find(child.Name, "^heaven_") or string.find(child.Name, "^hell_")) then
        continue
    end
    local mp
    for _, d in ipairs(child:GetDescendants()) do
        if d:IsA("MeshPart") then
            mp = d
            break
        end
    end
    if not mp then
        props[child.Name] = { error = "no_meshpart" }
        continue
    end
    local boneCount = 0
    for _, d in ipairs(child:GetDescendants()) do
        if d:IsA("Bone") then
            boneCount += 1
        end
    end
    local sa = mp:FindFirstChildWhichIsA("SurfaceAppearance")
    local function strip(id)
        id = tostring(id or "")
        return (string.gsub(id, "^rbxassetid://", ""))
    end
    props[child.Name] = {
        mesh_id = strip(mp.MeshId),
        texture_id = strip(mp.TextureID),
        has_skinned_mesh = mp.HasSkinnedMesh == true,
        bone_count = boneCount,
        bind_mode = if sa
            then "SurfaceAppearance"
            elseif strip(mp.TextureID) ~= "" then "TextureID"
            else "none",
        color_map = sa and strip(sa.ColorMap) or "",
        metalness_map = sa and strip(sa.MetalnessMap) or "",
        normal_map = sa and strip(sa.NormalMap) or "",
        roughness_map = sa and strip(sa.RoughnessMap) or "",
    }
end

return HttpService:JSONEncode({
    source = "ReplicatedStorage.MissionProps",
    captured_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    place = game.Name,
    props = props,
})
