--[[
    Audit imported map objects that look like gameplay binding candidates.

    Run in Studio edit mode before stamping tags. The output is intended for an
    AI-assisted or designer-assisted deployment pass: review candidate paths and
    positions, then copy the useful ones into a stamping script/config.
]]

local CONFIG = {
    root_path = "Workspace.Maps",
    max_results_per_kind = 80,
    kinds = {
        EggStand = {
            candidate_names = {
                "EggStand",
                "Egg Stand",
                "Egg",
                "Egg hatcher",
            },
            candidate_name_contains = {
                "egg",
                "hatch",
            },
        },
        Portal = {
            candidate_names = {
                "Portal",
                "Gate",
                "Door",
            },
            candidate_name_contains = {
                "portal",
                "gate",
                "door",
            },
        },
        ShopAnchor = {
            candidate_names = {
                "Shop",
                "Pet shop",
                "Low Poly Shop",
            },
            candidate_name_contains = {
                "shop",
            },
        },
    },
}

local function splitPath(path)
    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do
        table.insert(parts, part)
    end
    return parts
end

local function resolvePath(path)
    local current = game
    for _, part in ipairs(splitPath(path)) do
        if part ~= "game" then
            current = current:FindFirstChild(part)
            if not current then
                return nil
            end
        end
    end
    return current
end

local function getPosition(instance)
    if instance:IsA("BasePart") then
        return instance.Position
    end
    if instance:IsA("Model") then
        return instance:GetPivot().Position
    end
    local part = instance:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

local function matches(rule, name)
    local lowerName = string.lower(name)
    for _, exactName in ipairs(rule.candidate_names or {}) do
        if name == exactName then
            return true
        end
    end
    for _, contains in ipairs(rule.candidate_name_contains or {}) do
        if string.find(lowerName, string.lower(contains), 1, true) then
            return true
        end
    end
    return false
end

local root = resolvePath(CONFIG.root_path) or workspace
local lines = {
    string.format("Auditing %s", root:GetFullName()),
}

for kind, rule in pairs(CONFIG.kinds) do
    local found = 0
    table.insert(lines, "")
    table.insert(lines, "== " .. kind .. " candidates ==")

    for _, instance in ipairs(root:GetDescendants()) do
        if (instance:IsA("Model") or instance:IsA("BasePart")) and matches(rule, instance.Name) then
            found += 1
            if found <= CONFIG.max_results_per_kind then
                local position = getPosition(instance)
                table.insert(
                    lines,
                    string.format(
                        "%03d %s [%s] pos=%s",
                        found,
                        instance:GetFullName(),
                        instance.ClassName,
                        position and tostring(position) or "?"
                    )
                )
            end
        end
    end

    if found == 0 then
        table.insert(lines, "none")
    elseif found > CONFIG.max_results_per_kind then
        table.insert(
            lines,
            string.format("...%d more omitted", found - CONFIG.max_results_per_kind)
        )
    end
end

print(table.concat(lines, "\n"))
