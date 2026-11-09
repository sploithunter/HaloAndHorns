-- Shared HH contracts, deliberately separate from the Merge world/backend adapter.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local view = require("../../src/Shared/Inventory/PetInventoryView")
local draft = require("../../src/Shared/Game/MergeEggDraft")
local inventory = assert(
    loadstring("local Color3,Vector2=...\n" .. fs.readFile("configs/inventory.lua"), "inventory")
)(roblox.Color3, roblox.Vector2)
local source = fs.readFile("configs/merge_egg_prototype.lua")
    :gsub("require%(script.Parent.merge_tier_art%)", "{}")
local merge = assert(loadstring(source, "merge"))()
local progression =
    assert(loadstring(fs.readFile("configs/player_progression.lua"), "progression"))()
local contract = {
    ownershipPath = "Inventory.pets.items",
    equipPath = "Equipped.pets",
    petStorage = {
        stack_key_fields = inventory.buckets.pets.stack_key_fields,
        max_stack_size = inventory.buckets.pets.max_stack_size,
        base_limit = inventory.buckets.pets.base_limit,
        special_rarities = inventory.buckets.pets.special_rarities,
        stacks_count_toward_limit = inventory.buckets.pets.stacks_count_toward_limit,
    },
    equipped = inventory.equipped.pets,
    progression = progression,
    mergePlayerReserve = merge.player_reserve,
    mergeRecovery = merge.player_pet_recovery,
}
local items = {
    ["bear:basic:"] = { id = "bear", variant = "basic", enchant = "", quantity = 2 },
    ["bear:basic:luck_copper"] = {
        id = "bear",
        variant = "basic",
        enchant = "luck_copper",
        quantity = 1,
    },
    ["doggy:golden:"] = { id = "doggy", variant = "golden", quantity = 0 },
    ["owned-unique"] = {
        uid = "owned-unique",
        id = "doggy",
        variant = "rainbow",
        unique = true,
        level = 7,
        exp = 23,
    },
}
local function stringKeys(values)
    local out = {}
    for key, value in pairs(values) do
        out[tostring(key)] = value
    end
    return out
end
local fixtures = { resolve = {}, build = {}, fill = {}, draft = {} }
local requests = {
    {},
    { "stack|bear:basic:" },
    { "stack|bear:basic:", "stack|bear:basic:", "owned-unique" },
    { "stack|bear:basic:", "stack|bear:basic:", "stack|bear:basic:" },
    { "owned-unique", "owned-unique" },
    { "not-owned", "stack|doggy:golden:" },
    { "stack|bear:basic:luck_copper", "stack|bear:basic:", "owned-unique" },
    { "temporary:run:hatcher:1", "special|owned-unique" },
}
for _, refs in ipairs(requests) do
    for _, capacity in ipairs({ 0, 1, 3 }) do
        for _, locks in ipairs({ {}, { slot_2 = true } }) do
            local previous = { slot_2 = "owned-unique" }
            local equipped, summary = view.buildEquipped(
                items,
                refs,
                capacity,
                { lockedSlots = locks, previous = previous }
            )
            table.insert(fixtures.build, {
                items = items,
                refs = refs,
                capacity = capacity,
                locks = locks,
                previous = previous,
                equipped = equipped,
                summary = summary,
            })
            local resolveInput = { slot_0 = "owned-unique", ghost = "owned-unique" }
            for i, ref in ipairs(refs) do
                resolveInput["slot_" .. tostring(i)] = ref
            end
            resolveInput["slot_" .. tostring(capacity + 1)] = "not-owned"
            local restored, counts = view.resolveEquipped(items, resolveInput, capacity)
            table.insert(fixtures.resolve, {
                items = items,
                equipped = resolveInput,
                capacity = capacity,
                slots = stringKeys(restored),
                counts = counts,
            })
            local filled, fillSummary = view.fillEmptySlots(items, previous, refs, capacity, locks)
            table.insert(fixtures.fill, {
                items = items,
                equipped = previous,
                refs = refs,
                capacity = capacity,
                locks = locks,
                result = filled,
                summary = fillSummary,
            })
        end
    end
end
local candidates = {
    { pet = "bear", role = "tank", combatPower = 12 },
    { pet = "bunny", role = "support", combatPower = 2 },
    { pet = "kitty", role = "ranged", combatPower = 30 },
    { pet = "doggy", role = "melee", combatPower = 10 },
}
local weakest, weakestIndex = draft.weakest(candidates)
for _, capacity in ipairs({ 3, 4 }) do
    local squad, reserve = draft.composePlayerRoster(candidates, capacity)
    table.insert(fixtures.draft, {
        candidates = candidates,
        capacity = capacity,
        weakest = weakest,
        weakestIndex = weakestIndex,
        squad = stringKeys(squad),
        reserve = reserve,
    })
end
fs.writeFile(
    "ports/spawn/world/scripts/lib/data/shared-account.yml",
    serde.encode("json", contract, true)
)
fs.writeFile("ports/spawn/tests/inventory-fixtures.json", serde.encode("json", fixtures, true))
print(
    "Exported shared inventory contracts and "
        .. tostring(#fixtures.build)
        .. " equip/restore/fill cases"
)
