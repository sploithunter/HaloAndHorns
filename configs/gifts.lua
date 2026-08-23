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

    -- Both ids are group-owned and trace to scripts/gift_*_ids.json.
    assets = {
        icon_decal_id = 74519461902415,
        -- rbxthumb resolves a Decal's underlying image for ImageLabels without a
        -- Studio-only Decal -> Image extraction step.
        inventory_icon = "rbxthumb://type=Asset&id=74519461902415&w=420&h=420",
        present_model_asset = "rbxassetid://75928057436522",
        replicated_model_name = "StarlightGift",
    },
}
