--[[
    EnhancementShopService — buy/sell enhancements for gems (configs/enhancements.lua `shop`).

    Naturals-only for BUY (v1); SELL accepts any grade the player owns. Enhancements are STACKS keyed
    by identity (enh_<type>_<origins>_L<level>), so:
      • BUY routes through EnhancementService:Grant, which INCREMENTS the matching stack's quantity
        (no duplicate uids).
      • SELL decrements a stack by `quantity` via InventoryService:RemoveItem (deletes the stack at 0)
        and refunds gems = per-unit sellPrice × quantity.

    Pricing is the pure EnhancementPricing core; this service is the impure spend/grant boundary.
    Bus commands: enhancement.shop.catalog / .buy / .sell (GameAPIService).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnhancementPricing = require(ReplicatedStorage.Shared.Game.EnhancementPricing)
local Enhancements = require(ReplicatedStorage.Shared.Game.Enhancements)

local BUCKET = "enhancements"
local CURRENCY_FALLBACK = "gems"

local EnhancementShopService = {}
EnhancementShopService.__index = EnhancementShopService

function EnhancementShopService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._inventoryService = self._modules and self._modules.InventoryService
    self._enhancementService = self._modules and self._modules.EnhancementService
    self._config = self._configLoader and self._configLoader:LoadConfig("enhancements")
end

function EnhancementShopService:_shop()
    return self._config and self._config.shop
end

-- Sorted list of enhancement type keys (stable catalog order).
function EnhancementShopService:_typeKeys()
    local keys = {}
    for t in pairs((self._config and self._config.types) or {}) do
        keys[#keys + 1] = t
    end
    table.sort(keys)
    return keys
end

local function buyableSet(shop)
    local set = {}
    for _, g in ipairs((shop and shop.buyable_grades) or { "natural" }) do
        set[g] = true
    end
    return set
end

-- The player's gameplay level (same source slotting uses — keeps the shown band always slottable).
local function playerLevel(player)
    return tonumber(player:GetAttribute("Level")) or 1
end

-- The buyable catalog: one slottable band × buyable grades × non-excluded types, + the player's balance.
function EnhancementShopService:Catalog(player)
    local shop = self:_shop()
    if not (shop and shop.enabled) then
        return { ok = false, reason = "shop_disabled" }
    end
    local currency = shop.currency or CURRENCY_FALLBACK
    local cat = EnhancementPricing.catalog(playerLevel(player), self:_typeKeys(), shop)
    return {
        ok = true,
        currency = currency,
        balance = self._dataService:GetCurrency(player, currency),
        band = cat.band,
        offers = cat.offers,
    }
end

-- BUY one enhancement of `type` (grade defaults to natural). Snaps to the player's band level and
-- stacks via Grant. Deducts gems first; refunds if the grant fails.
function EnhancementShopService:Buy(player, args)
    local shop = self:_shop()
    if not (shop and shop.enabled) then
        return { ok = false, reason = "shop_disabled" }
    end
    args = args or {}
    local etype = args.type
    local grade = args.grade or "natural"
    if type(etype) ~= "string" or not (self._config.types and self._config.types[etype]) then
        return { ok = false, reason = "invalid_type" }
    end
    if shop.exclude_types and shop.exclude_types[etype] then
        return { ok = false, reason = "type_not_sold" }
    end
    if not buyableSet(shop)[grade] then
        return { ok = false, reason = "grade_not_buyable" }
    end

    -- ORIGINS by grade (validated BEFORE spending): natural is origin-less; single/dual carry the
    -- player's OWN origin so the bought enhancement is usable + slottable for them. No origin chosen
    -- yet → single/dual can't be made usable, so refuse (no spend).
    local origins = {}
    if grade == "single" or grade == "dual" then
        local arch = player:GetAttribute("Archetype")
        if type(arch) ~= "string" or arch == "" then
            return { ok = false, reason = "no_origin" }
        end
        if grade == "single" then
            origins = { arch }
        else
            local other
            for _, o in ipairs(self._config.origins or {}) do
                if o ~= arch then
                    other = o
                    break
                end
            end
            origins = other and { arch, other } or { arch }
        end
    end

    local level = EnhancementPricing.bandFor(playerLevel(player), shop)
    local price = EnhancementPricing.buyPrice(grade, level, shop)
    local currency = shop.currency or CURRENCY_FALLBACK
    if price <= 0 then
        return { ok = false, reason = "no_price" }
    end
    if self._dataService:GetCurrency(player, currency) < price then
        return { ok = false, reason = "insufficient_funds", needed = price }
    end

    local src = ("enh_buy:%s_L%d"):format(etype, level)
    if not self._dataService:RemoveCurrency(player, currency, price, src) then
        return { ok = false, reason = "spend_failed" }
    end

    local granted = self._enhancementService:Grant(player, {
        type = etype,
        origins = origins, -- {} natural, {arch} single, {arch,other} dual — usable by the buyer
        level = level,
    })
    if not (granted and granted.ok) then
        -- refund — the grant did not land
        self._dataService:AddCurrency(player, currency, price, src .. ":refund")
        return { ok = false, reason = (granted and granted.reason) or "grant_failed" }
    end

    self._dataService:RequestSave(player, "enh_shop_buy", { critical = true })
    return {
        ok = true,
        type = etype,
        grade = grade,
        level = level,
        price = price,
        uid = granted.uid,
        name = granted.name,
        balance = self._dataService:GetCurrency(player, currency),
    }
end

-- SELL `quantity` (default 1) from a stack `uid`. Reads grade off the owned stack so single/dual buy
-- back too; refunds gems = per-unit sellPrice × sold. Decrements the stack (deletes at 0).
function EnhancementShopService:Sell(player, args)
    local shop = self:_shop()
    if not (shop and shop.enabled) then
        return { ok = false, reason = "shop_disabled" }
    end
    args = args or {}
    local uid = args.uid
    if type(uid) ~= "string" or uid == "" then
        return { ok = false, reason = "invalid_uid" }
    end
    local stack = self._inventoryService:GetItem(player, BUCKET, uid)
    if not stack then
        return { ok = false, reason = "not_owned" }
    end

    local have = math.max(0, math.floor(tonumber(stack.quantity) or 0))
    local want = math.floor(tonumber(args.quantity) or 1)
    if want < 1 then
        want = 1
    end
    local qty = math.min(want, have)
    if qty < 1 then
        return { ok = false, reason = "none_to_sell" }
    end

    local grade = EnhancementPricing.gradeFromOrigins(stack.origins)
    local level = tonumber(stack.level) or 1
    local unit = EnhancementPricing.sellPrice(grade, level, shop)
    local total = unit * qty
    if total <= 0 then
        return { ok = false, reason = "no_value" }
    end

    local currency = shop.currency or CURRENCY_FALLBACK
    local ok = self._inventoryService:RemoveItem(player, BUCKET, uid, qty)
    if not ok then
        return { ok = false, reason = "remove_failed" }
    end

    local src = ("enh_sell:%s"):format(uid)
    self._dataService:AddCurrency(player, currency, total, src)
    self._dataService:RequestSave(player, "enh_shop_sell", { critical = true })
    return {
        ok = true,
        uid = uid,
        grade = grade,
        level = level,
        sold = qty,
        unit = unit,
        gems = total,
        remaining = have - qty,
        balance = self._dataService:GetCurrency(player, currency),
    }
end

-- The player's enhancement stacks as a flat array (for the sell panel + bulk junk sweep). uid = stack
-- identity; carries type/origins/level/quantity for display + pricing.
function EnhancementShopService:_stacks(player)
    local inv = self._inventoryService:GetInventory(player, BUCKET)
    local items = inv and inv.items
    local stacks = {}
    if type(items) == "table" then
        for uid, rec in pairs(items) do
            stacks[#stacks + 1] = {
                uid = uid,
                type = rec.type,
                origins = rec.origins,
                level = rec.level,
                quantity = rec.quantity,
            }
        end
    end
    return stacks
end

-- The player's chosen origin (data.Archetype) — drives dual usability (a dual is slottable only if one
-- of its origins is this). nil for pre-origin players (then every dual reads as wrong-origin junk).
function EnhancementShopService:_archetype(player)
    local data = self._dataService and self._dataService:GetData(player)
    return data and data.Archetype
end

-- The owned enhancement stacks for the sell panel: per-stack sell price + flags (dead / usable / junk
-- bucket) so the client can render + group without re-deriving the rules.
function EnhancementShopService:ListOwned(player)
    local shop = self:_shop()
    if not (shop and shop.enabled) then
        return { ok = false, reason = "shop_disabled" }
    end
    local archetype = self:_archetype(player)
    local lvl = playerLevel(player)
    local window = (shop.bulk and tonumber(shop.bulk.dead_window)) or 2
    local currency = shop.currency or CURRENCY_FALLBACK
    local items = {}
    for _, s in ipairs(self:_stacks(player)) do
        local grade = EnhancementPricing.gradeFromOrigins(s.origins)
        local lev = tonumber(s.level) or 0
        local dead = lev < (lvl - window)
        local usable = Enhancements.usableBy({ origins = s.origins }, archetype)
        local junk = (grade ~= "single")
            and ((grade == "natural" and dead) or (grade == "dual" and (dead or not usable)))
        items[#items + 1] = {
            uid = s.uid,
            type = s.type,
            origins = s.origins or {},
            level = lev,
            quantity = math.max(0, math.floor(tonumber(s.quantity) or 0)),
            grade = grade,
            sellUnit = EnhancementPricing.sellPrice(grade, lev, shop),
            dead = dead,
            usable = usable,
            junk = junk and true or false,
        }
    end
    return {
        ok = true,
        currency = currency,
        balance = self._dataService:GetCurrency(player, currency),
        items = items,
    }
end

-- Preview the bulk "Sell Junk" sweep WITHOUT selling — returns the two buckets (naturals always;
-- duals = dead-or-wrong-origin, gated behind the client's "include duals" checkbox) so the UI can
-- show totals live as the box is toggled.
function EnhancementShopService:JunkPreview(player)
    local shop = self:_shop()
    if not (shop and shop.enabled) then
        return { ok = false, reason = "shop_disabled" }
    end
    local plan = EnhancementPricing.junkSweep(
        self:_stacks(player),
        playerLevel(player),
        shop,
        { playerArchetype = self:_archetype(player) }
    )
    return {
        ok = true,
        currency = shop.currency or CURRENCY_FALLBACK,
        naturals = { count = plan.naturals.count, gems = plan.naturals.gems },
        duals = { count = plan.duals.count, gems = plan.duals.gems },
    }
end

-- BULK sell: clear DEAD naturals (always) + the duals bucket when `includeDuals`. One pass, removes
-- each stack fully, then credits the summed gems once. Singles never sold.
function EnhancementShopService:SellJunk(player, args)
    local shop = self:_shop()
    if not (shop and shop.enabled) then
        return { ok = false, reason = "shop_disabled" }
    end
    local includeDuals = args and args.includeDuals and true or false
    local plan = EnhancementPricing.junkSweep(
        self:_stacks(player),
        playerLevel(player),
        shop,
        { playerArchetype = self:_archetype(player) }
    )
    local toSell = {}
    for _, it in ipairs(plan.naturals.items) do
        toSell[#toSell + 1] = it
    end
    if includeDuals then
        for _, it in ipairs(plan.duals.items) do
            toSell[#toSell + 1] = it
        end
    end
    if #toSell == 0 then
        return { ok = false, reason = "nothing_to_sell" }
    end
    local currency = shop.currency or CURRENCY_FALLBACK
    local soldQty, gems = 0, 0
    for _, it in ipairs(toSell) do
        if self._inventoryService:RemoveItem(player, BUCKET, it.uid, it.quantity) then
            soldQty += it.quantity
            gems += it.gems
        end
    end
    if gems > 0 then
        self._dataService:AddCurrency(player, currency, gems, "enh_sell_junk")
        self._dataService:RequestSave(player, "enh_shop_sell_junk", { critical = true })
    end
    return {
        ok = true,
        sold = soldQty,
        stacks = #toSell,
        gems = gems,
        includedDuals = includeDuals,
        balance = self._dataService:GetCurrency(player, currency),
    }
end

return EnhancementShopService
