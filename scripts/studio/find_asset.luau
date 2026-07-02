--[[
    find_asset.luau — locate every reference to an asset id in the OPEN place.

    Run in the Studio Command Bar (Edit mode) or via the Studio MCP execute_luau.
    For each id you hunt it reports:
      • INSTANCE references — content properties (MeshId / Texture / Image / SoundId /
        AnimationId / SurfaceAppearance maps / Sky / ScrollingFrame slices / clothing)
        across game:GetDescendants(); prints the clickable instance + property + value.
      • SCRIPT references — the id appearing in any Script/LocalScript/ModuleScript
        .Source (catches Rojo-synced config tables too); prints path + line.

    Pairs with scripts/ownership_audit.py: that tells you WHICH ids are personal-owned
    (need group migration); this tells you WHERE each one lives so you can re-point it.

    Edit TARGETS, paste, run. Read-only — selects/changes nothing.
]]

local TARGETS = {
    "134283982892096",
    -- add more ids here, one per line (rbxassetid://, a full URL, or bare digits all work)
}

-- Content/asset-bearing properties, probed class-agnostically (pcall-guarded so a class
-- that lacks the property is simply skipped). Covers meshes, textures, decals, images,
-- sounds, animations, PBR surface maps, sky, scrolling-frame slices, and clothing.
local CONTENT_PROPS = {
    "MeshId",
    "TextureID",
    "TextureId",
    "Texture",
    "Image",
    "SoundId",
    "AnimationId",
    "ShirtTemplate",
    "PantsTemplate",
    "Graphic",
    "ColorMap",
    "MetalnessMap",
    "NormalMap",
    "RoughnessMap",
    "TopImage",
    "MidImage",
    "BottomImage",
    "SkyboxBk",
    "SkyboxDn",
    "SkyboxFt",
    "SkyboxLf",
    "SkyboxRt",
    "SkyboxUp",
    "MoonTextureId",
    "SunTextureId",
}

-- normalize a target to bare digits (so "rbxassetid://123", a URL paste, or "123" all match)
local function digits(s)
    return (tostring(s):gsub("%D", ""))
end

-- true if `id` appears in `s` and is NOT part of a longer run of digits (so 12345 does
-- not falsely match inside 9912345 / 1234567)
local function containsId(s, id)
    local from = 1
    while true do
        local i, j = string.find(s, id, from, true)
        if not i then
            return false
        end
        local before = i > 1 and s:sub(i - 1, i - 1) or ""
        local after = j < #s and s:sub(j + 1, j + 1) or ""
        if not before:match("%d") and not after:match("%d") then
            return true
        end
        from = j + 1
    end
end

local ids, idCount = {}, 0
for _, t in ipairs(TARGETS) do
    local d = digits(t)
    if #d > 0 and not ids[d] then
        ids[d] = true
        idCount += 1
    end
end

local descendants = game:GetDescendants()
print(("[find_asset] scanning %d instances for %d id(s)…"):format(#descendants, idCount))

local instanceHits, scriptHits = 0, 0
for _, inst in ipairs(descendants) do
    -- 1) content properties
    for _, prop in ipairs(CONTENT_PROPS) do
        local ok, val = pcall(function()
            return inst[prop]
        end)
        if ok and type(val) == "string" and val ~= "" then
            for id in pairs(ids) do
                if containsId(val, id) then
                    instanceHits += 1
                    warn(
                        ("  ▸ [%s] %s . %s = %s"):format(
                            inst.ClassName,
                            inst:GetFullName(),
                            prop,
                            val
                        )
                    )
                    print(inst) -- clickable in Output → selects the instance
                end
            end
        end
    end
    -- 2) script source (Edit mode only; pcall-guarded for runtime safety)
    if inst:IsA("LuaSourceContainer") then
        local ok, src = pcall(function()
            return inst.Source
        end)
        if ok and type(src) == "string" and src ~= "" then
            local line = 0
            for text in (src .. "\n"):gmatch("(.-)\n") do
                line += 1
                for id in pairs(ids) do
                    if containsId(text, id) then
                        scriptHits += 1
                        warn(
                            ("  ▸ %s : line %d → %s"):format(
                                inst:GetFullName(),
                                line,
                                (text:gsub("^%s+", ""))
                            )
                        )
                    end
                end
            end
        end
    end
end

print(
    ("[find_asset] done — %d instance hit(s), %d script hit(s)."):format(instanceHits, scriptHits)
)
if instanceHits + scriptHits == 0 then
    print(
        "[find_asset] no references in the open place. The id may live only in a config on "
            .. "disk (grep configs/ + the registries), or be loaded dynamically by id at runtime."
    )
end
