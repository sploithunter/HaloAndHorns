--[[
    Theme-utility passives — Halo & Horns [PROTOTYPE] (Feature 6).

    A pet of theme T gains a utility passive ONLY when the player is in T's
    dichotomy (mirror-opposite) biome — e.g. an earth pet gains "Deep Roots" while
    in the desert. In its home theme (or unrelated biomes) no passive is active.
    Keyed by pet theme; biomes with no dichotomy (beach) have no passive.
    Read by `src/Shared/Game/ThemeUtility.lua`.
]]

return {
    passives = {
        earth = {
            id = "deep_roots",
            name = "Deep Roots",
            description = "Earth pets thrive amid the dunes.",
        },
        desert = {
            id = "mirage_step",
            name = "Mirage Step",
            description = "Desert pets thrive on solid earth.",
        },
        ice = {
            id = "flash_freeze",
            name = "Flash Freeze",
            description = "Ice pets thrive in the lava fields.",
        },
        lava = {
            id = "ashen_ward",
            name = "Ashen Ward",
            description = "Lava pets thrive on the ice.",
        },
    },
}
