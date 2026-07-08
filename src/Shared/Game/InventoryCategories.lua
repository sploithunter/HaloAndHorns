--[[
    InventoryCategories — PURE category-visibility for the inventory panel tabs.

    Extracted after a live regression (Jason, 2026-07-08): tab visibility lived inline in
    InventoryPanel, was built ONCE from pre-data-load (all-zero) folder counts, and a
    debug "force show everything" line had been masking it — when that line was removed,
    every non-always_visible tab (Enhancements, Items, Eggs, Tools, …) vanished for good
    despite hundreds of owned items. Pure logic here = headless-speccable
    (tests/headless/specs/inventory_categories.spec.luau), so "a populated category must
    produce a tab" is now a CI assertion, not a hope.

    visible(displayCategories, folderCounts, settings) -> array of
        { config = <category config entry>, count = <summed item count> }
    in the given display order, containing exactly the categories a tab must exist for.
]]

local InventoryCategories = {}

function InventoryCategories.visible(displayCategories, folderCounts, settings)
    settings = settings or {}
    folderCounts = folderCounts or {}
    local hideEmpty = settings.hide_empty_categories == true
    local out = {}
    for _, categoryConfig in ipairs(displayCategories or {}) do
        local total = 0
        for _, folderName in ipairs(categoryConfig.folders or {}) do
            total += folderCounts[folderName] or 0
        end
        local show = categoryConfig.always_visible == true or total > 0
        if not hideEmpty then
            show = true -- hiding disabled: every configured category gets a tab
        end
        if show then
            out[#out + 1] = { config = categoryConfig, count = total }
        end
    end
    return out
end

return InventoryCategories
