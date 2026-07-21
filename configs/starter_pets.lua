--[[
    First-companion choice shown to genuinely new players before their first Earth Egg hatch.

    This is deliberately separate from configs/eggs.lua: the choice is a one-time BASIC pet
    grant that teaches combat roles. The following Earth Egg remains the normal, highly lucky
    first hatch (including its golden/rainbow/huge rolls).
]]

return {
    version = 1,
    enabled = true,

    grant = {
        variant = "basic",
        source = "starter_choice",
        locked = true, -- free starter cannot be traded between alternate accounts
        unique = true, -- preserve locked/source metadata on this individual copy
        auto_equip = true,
    },

    choices = {
        {
            id = "bunny",
            display_name = "Bunny",
            role = "support",
            role_label = "SUPPORT",
            summary = "Boosts the whole squad instead of dealing heavy damage.",
            detail = "Fragile and low damage. While deployed, Bunny increases your luck when hatching eggs.",
            accent = { 95, 225, 125 },
        },
        {
            id = "bear",
            display_name = "Bear",
            role = "tank",
            role_label = "TANK",
            summary = "Soaks up damage and draws enemies away from fragile allies.",
            detail = "The toughest starter, with moderate damage.",
            accent = { 90, 175, 255 },
        },
        {
            id = "doggy",
            display_name = "Doggy",
            role = "melee",
            role_label = "MELEE",
            summary = "A dependable up-close fighter with balanced damage and toughness.",
            detail = "Simple, flexible, and always useful.",
            accent = { 245, 175, 55 },
        },
        {
            id = "kitty",
            display_name = "Kitty",
            role = "ranged",
            role_label = "RANGED • LEGENDARY",
            summary = "A glass-cannon blaster that attacks safely from range.",
            detail = "High damage, low health—keep enemies off it.",
            accent = { 190, 105, 255 },
        },
    },
}
