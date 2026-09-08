--[[
    Trade — Halo & Horns [PROTOTYPE] (Feature 19).

    Pets are tradeable (unless locked); currencies are NOT; cosmetics are.
    Hoverboards are durable personal unlocks and are explicitly NOT tradeable.
    Trades are server-authoritative, require both players to confirm, execute
    atomically (anti-duplication), and are written to a trade-history audit log.
    Pure rules: `src/Shared/Game/TradeLogic.lua`.
]]

return {
    -- Responsive player picker: fixed readable chrome, remaining height belongs to the list.
    live_layout = {
        width_scale = 0.96,
        height_scale = 0.94,
        max_width = 1100,
        max_height = 760,
        header_height = 32,
        column_title_height = 24,
        gap = 6,
        touch_height = 44,
        offer_highlight = Color3.fromRGB(46, 204, 113),
        offer_highlight_transparency = 0.88,
        offer_outline_thickness = 3,
        dialog_width_scale = 0.92,
        dialog_max_width = 460,
        confirmation_height = 230,
        request_height = 180,
    },
    picker_layout = {
        width_scale = 0.92,
        height_scale = 0.9,
        max_width = 850,
        max_height = 650,
        content_width_scale = 0.94,
        content_bottom_scale = 0.97,
        header_height = 48,
        touch_height = 44,
        gap = 8,
        row_height = 112,
        preference_label_height = 28,
        preference_columns = 3,
        text_size = 16,
    },
    -- Pending invitations are intentionally short-lived: unanswered prompts clear on both clients,
    -- the server rejects late responses, and the requester receives a timeout notice.
    invite_timeout_seconds = 30,
    -- Who may send this player a trade request. The picker exposes all three modes and the server
    -- independently enforces the recipient's saved choice. New profiles begin open to Everyone;
    -- existing profiles keep whichever persisted mode they already selected or migrated to.
    invite_privacy = {
        default = "everyone",
        modes = {
            everyone = {
                display = "Everyone",
                list_label = "Everyone",
            },
            friends = {
                display = "Friends only",
                list_label = "Friends only",
            },
            off = {
                display = "Off",
                list_label = "Requests off",
            },
        },
    },
    tradeable = {
        pets = true,
        currencies = false, -- gems are the exception, via tradeable_currencies below
        cosmetics = true,
        hoverboards = false,
        enhancements = true, -- all enhancements are tradeable (Jason)
        eggs = true, -- held tester/creator eggs preserve their complete provenance record
    },
    -- Per-currency trade allowlist (Pet Realm): the four biome coins are soulbound;
    -- gems are the only tradeable currency. Anything not listed here is non-tradeable.
    tradeable_currencies = {
        gems = true,
    },
    -- Raised 10 -> 100 for slider bulk-add (Jason: "trade 50-100 at a time with a
    -- slider"). Each escrowed copy is one offer item, but the offer columns aggregate
    -- same-kind copies into a single ×N card, so a big offer stays one card per kind.
    -- Dial back down to tighten how much can ride on one trade.
    max_offer_items = 100,
    -- Where the offer-amount slider starts when you tap a stack: "min" (1) or "max"
    -- (the whole stack). Default "min" per Jason. Falls back to "min".
    offer_picker_default = "min",
    -- Cap the in-memory audit log per player (full audit would be a DataStore).
    audit_log_limit = 100,
}
