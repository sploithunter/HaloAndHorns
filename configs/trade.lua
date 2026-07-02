--[[
    Trade — Halo & Horns [PROTOTYPE] (Feature 19).

    Pets are tradeable (unless locked); currencies are NOT; cosmetics are. Trades
    are server-authoritative, require both players to confirm, execute atomically
    (anti-duplication), and are written to a trade-history audit log. Pure rules:
    `src/Shared/Game/TradeLogic.lua`.
]]

return {
    tradeable = {
        pets = true,
        currencies = false, -- gems are the exception, via tradeable_currencies below
        cosmetics = true,
        enhancements = true, -- all enhancements are tradeable (Jason)
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
