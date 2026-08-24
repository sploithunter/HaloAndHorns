-- One-way pet gifts. Trading remains a two-party escrow exchange; gifts are
-- receiver-policy-gated deliveries that require no recipient interaction.

return {
    version = 1,

    -- Reconcile applies this to both new and existing profiles that have never
    -- chosen a gift policy. Saved explicit choices are preserved.
    default_acceptance = "any",
    preferences = {
        { id = "any", label = "Any gift" },
        { id = "uncommon_plus", label = "Uncommon+" },
        { id = "rare_plus", label = "Rare+" },
        { id = "mythic_plus", label = "Mythical+" },
        { id = "off", label = "Gifts off" },
    },

    limits = {
        save_confirm_timeout_seconds = 12,
        send_cooldown_seconds = 1,
    },

    -- All ids are group-owned and trace to scripts/gift_*_ids.json. Wrapper
    -- tiers reveal only a broad rarity band; the pet remains a surprise.
    assets = {
        -- Legacy/default fields keep older clients on the original blue gift.
        icon_decal_id = 74519461902415,
        -- rbxthumb resolves a Decal's underlying image for ImageLabels without a
        -- Studio-only Decal -> Image extraction step.
        inventory_icon = "rbxthumb://type=Asset&id=74519461902415&w=420&h=420",
        present_model_asset = "rbxassetid://75928057436522",
        replicated_model_name = "StarlightGift",
        presentations = {
            standard = {
                label = "Standard Gift",
                accent_rgb = { 70, 180, 255 },
                icon_decal_id = 74519461902415,
                inventory_icon = "rbxthumb://type=Asset&id=74519461902415&w=420&h=420",
                present_model_asset = "rbxassetid://75928057436522",
                replicated_model_name = "StarlightGift",
            },
            mythical = {
                label = "Mythical Gift",
                accent_rgb = { 166, 91, 255 },
                icon_decal_id = 100900758738930,
                inventory_icon = "rbxthumb://type=Asset&id=100900758738930&w=420&h=420",
                present_model_asset = "rbxassetid://117665017287463",
                replicated_model_name = "StarlightGiftPurple",
            },
            secret = {
                label = "Secret Gift",
                accent_rgb = { 220, 48, 82 },
                icon_decal_id = 131574195765765,
                inventory_icon = "rbxthumb://type=Asset&id=131574195765765&w=420&h=420",
                present_model_asset = "rbxassetid://138682808296676",
                replicated_model_name = "StarlightGiftCrimson",
            },
            exclusive = {
                label = "Exclusive Gift",
                accent_rgb = { 245, 190, 58 },
                icon_decal_id = 110223776207323,
                inventory_icon = "rbxthumb://type=Asset&id=110223776207323&w=420&h=420",
                present_model_asset = "rbxassetid://125462665041651",
                replicated_model_name = "StarlightGiftGold",
            },
        },
    },
}
