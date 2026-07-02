--[[
    BootGraph (shared, pure) — validate + order the boot milestone dependency graph.

    See docs/BOOT_ORCHESTRATION.md. Operates on the `milestones` table from configs/boot.lua:
    each entry is { produced_by = string, requires = { <milestone name>, ... }, background? }.

    The orchestrator runs validate() at boot so a missing/typo'd dependency or an accidental
    cycle is a LOUD startup error — the next race caught at boot, not in prod. order() gives a
    deterministic dependencies-before-dependents sequence for logging.

    Pure: standard Lua only; unit-tested via `mise run test-headless`.
]]

local BootGraph = {}

-- Validate the graph. Returns (ok: boolean, errors: { string }).
-- Flags: a `requires` edge pointing at an undeclared milestone, and any dependency cycle.
function BootGraph.validate(milestones)
    local errors = {}
    if type(milestones) ~= "table" then
        return false, { "milestones must be a table" }
    end

    for name, def in pairs(milestones) do
        if type(def) ~= "table" then
            table.insert(errors, string.format("milestone '%s' must be a table", tostring(name)))
        else
            if type(def.produced_by) ~= "string" or def.produced_by == "" then
                table.insert(errors, string.format("milestone '%s' missing produced_by", name))
            end
            for _, req in ipairs(def.requires or {}) do
                if not milestones[req] then
                    table.insert(
                        errors,
                        string.format("milestone '%s' requires unknown milestone '%s'", name, req)
                    )
                end
            end
        end
    end

    -- Cycle detection via DFS coloring (nil = unvisited, 1 = on stack, 2 = done).
    local color = {}
    local function dfs(name)
        if color[name] == 2 then
            return
        end
        if color[name] == 1 then
            table.insert(errors, string.format("dependency cycle through milestone '%s'", name))
            return
        end
        color[name] = 1
        local def = milestones[name]
        if type(def) == "table" then
            for _, req in ipairs(def.requires or {}) do
                if milestones[req] then
                    dfs(req)
                end
            end
        end
        color[name] = 2
    end
    for name in pairs(milestones) do
        if color[name] == nil then
            dfs(name)
        end
    end

    return #errors == 0, errors
end

-- Topologically ordered milestone names (dependencies before dependents). Deterministic: ties
-- and sibling edges are broken alphabetically so logs and tests are stable.
function BootGraph.order(milestones)
    local names = {}
    for name in pairs(milestones) do
        table.insert(names, name)
    end
    table.sort(names)

    local visited = {}
    local out = {}
    local function visit(name)
        if visited[name] then
            return
        end
        visited[name] = true
        local def = milestones[name]
        if type(def) == "table" then
            local reqs = {}
            for _, r in ipairs(def.requires or {}) do
                table.insert(reqs, r)
            end
            table.sort(reqs)
            for _, r in ipairs(reqs) do
                if milestones[r] then
                    visit(r)
                end
            end
        end
        table.insert(out, name)
    end
    for _, name in ipairs(names) do
        visit(name)
    end
    return out
end

return BootGraph
