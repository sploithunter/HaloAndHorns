--[[
    audit_ownership.luau — find every consumed asset NOT owned by the project group.

    Run in the Studio Command Bar (Edit mode) or via the Studio MCP execute_luau.
    Scans ReplicatedStorage.Configs script sources for asset-id-shaped numbers, then
    asks MarketplaceService:GetProductInfo who owns each — so it reproduces
    scripts/ownership_audit.py from INSIDE Studio with NO Open Cloud key. Reports the
    ids whose Creator is not group 15872767, bucketed by asset type + owner, so you
    know exactly what to re-home (re-upload to the group, or extract to a git .rbxm).

    GetProductInfo is rate-limited, so it throttles + chunks. ~800 candidate ids takes
    a couple of minutes; narrow SCAN_ROOTS or paste a fixed ID list to go faster.

    Read-only — touches nothing.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GROUP_ID = 15872767
local THROTTLE = 0.05 -- seconds between GetProductInfo calls (avoid HTTP rate limit)
local MIN_DIGITS = 11 -- asset ids are big; skip small numbers

-- where to harvest ids from (script sources). Add services if assets live elsewhere.
local SCAN_ROOTS = { ReplicatedStorage:FindFirstChild("Configs") }

local TYPE_NAME = {
    [1] = "Image",
    [3] = "Audio",
    [10] = "Model",
    [13] = "Decal",
    [24] = "Animation",
    [40] = "MeshPart",
    [8] = "Hat",
}

-- harvest unique ids from every LuaSourceContainer under the scan roots
local ids, order = {}, {}
local pattern = "%d%d%d%d%d%d%d%d%d%d%d+" -- 11+ consecutive digits
for _, root in ipairs(SCAN_ROOTS) do
    if root then
        for _, inst in ipairs(root:GetDescendants()) do
            if inst:IsA("LuaSourceContainer") then
                local ok, src = pcall(function()
                    return inst.Source
                end)
                if ok and type(src) == "string" then
                    for num in src:gmatch(pattern) do
                        if #num >= MIN_DIGITS and not ids[num] then
                            ids[num] = true
                            table.insert(order, num)
                        end
                    end
                end
            end
        end
    end
end

print(("[audit_ownership] %d unique candidate ids — querying owners…"):format(#order))

local out, nGroup, nOther, nErr = {}, 0, 0, 0
for i, num in ipairs(order) do
    local id = tonumber(num)
    local ok, info = pcall(function()
        return MarketplaceService:GetProductInfo(id)
    end)
    if not ok then
        nErr += 1 -- deleted / moderated / not a real asset id
    else
        local c = info.Creator or {}
        if c.CreatorType == "Group" and c.CreatorTargetId == GROUP_ID then
            nGroup += 1
        else
            nOther += 1
            local atype = TYPE_NAME[info.AssetTypeId] or ("type" .. tostring(info.AssetTypeId))
            table.insert(
                out,
                ("NOT-GROUP %s  [%s]  owner=%s:%s  '%s'"):format(
                    num,
                    atype,
                    tostring(c.CreatorType),
                    tostring(c.CreatorTargetId),
                    tostring(info.Name)
                )
            )
        end
    end
    if i % 20 == 0 then
        print(("  …%d / %d"):format(i, #order))
    end
    task.wait(THROTTLE)
end

table.sort(out)
table.insert(
    out,
    1,
    ("=== %d ids: %d group-owned | %d NOT-group | %d errored(deleted/moderated) ==="):format(
        #order,
        nGroup,
        nOther,
        nErr
    )
)
return table.concat(out, "\n")
