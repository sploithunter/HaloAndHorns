--[[
    TradeService — Feature 19 (Trade System), escrow model (Phase 10).

    Roblox has NO native in-experience trading/escrow API (the platform Trading
    System is for avatar catalog Limiteds + Robux between accounts; the old web
    Trade API was deprecated). So we implement the escrow PATTERN ourselves,
    server-authoritatively:

      Request -> Accept -> (each Add MOVES the pet into server escrow) ->
      both Confirm -> deliver each side's escrow to the other (all-or-nothing) ->
      Cancel / Decline / disconnect -> refund escrow to its owner.

    Escrow is the anti-duplication guarantee: an offered pet leaves the owner's
    inventory immediately, so it can't be sold, deleted, or offered in a second
    trade while pending. Live state is pushed to both clients via the TradeUpdate
    RemoteEvent. Pure rules (tradeable / both-confirm / audit record) live in the
    shared TradeLogic core.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local TradeLogic = require(ReplicatedStorage.Shared.Game.TradeLogic)
local fireGameEvent = require(ReplicatedStorage.Shared.Network.FireGameEvent)

local TradeService = {}
TradeService.__index = TradeService

local UPDATE_REMOTE = "TradeUpdate"
local PETS_BUCKET = "pets"
local ENH_BUCKET = "enhancements" -- matches EnhancementService's InventoryService bucket
local GEM_CURRENCY = "gems" -- the only tradeable currency (configs/trade.lua tradeable_currencies)

function TradeService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._config = self._configLoader:LoadConfig("trade")
    self._sessions = {} -- sessionId -> session
    self._playerSession = {} -- userId -> sessionId
    self._invites = {} -- targetUserId -> { from = userId }
    self._nextId = 0
    self._auditLog = {} -- append-only, capped

    -- Server -> client push channel (recreated to survive Studio hot-sync).
    local existing = ReplicatedStorage:FindFirstChild(UPDATE_REMOTE)
    if existing then
        existing:Destroy()
    end
    local remote = Instance.new("RemoteEvent")
    remote.Name = UPDATE_REMOTE
    remote.Parent = ReplicatedStorage
    self._remote = remote
end

function TradeService:Start()
    Players.PlayerRemoving:Connect(function(player)
        self:_onLeave(player)
    end)
end

function TradeService:_service(name)
    local locator = _G.RBXTemplateServices
    if not locator then
        return nil
    end
    local ok, service = pcall(function()
        return locator:Get(name)
    end)
    return ok and service or nil
end

-- Pure rule check (kept for the original Feature 19 bus command / tests).
function TradeService:CanAdd(category, item)
    return TradeLogic.canAddItem(category, item, self._config)
end

----------------------------------------------------------------------
-- Session helpers
----------------------------------------------------------------------

local function playerById(userId)
    return Players:GetPlayerByUserId(userId)
end

function TradeService:_sessionOf(userId)
    local id = self._playerSession[userId]
    return id and self._sessions[id]
end

-- Per-recipient view: your side + the partner's side (offers + confirm flags).
function TradeService:_view(session, forUserId)
    local otherId = (forUserId == session.a) and session.b or session.a
    local other = playerById(otherId)
    return {
        sessionId = session.id,
        you = {
            items = session.offers[forUserId].items,
            confirmed = session.offers[forUserId].confirmed,
        },
        them = {
            userId = otherId,
            name = other and other.Name or "Player",
            items = session.offers[otherId].items,
            confirmed = session.offers[otherId].confirmed,
        },
    }
end

function TradeService:_push(session, eventType)
    for _, userId in ipairs({ session.a, session.b }) do
        local plr = playerById(userId)
        if plr then
            self._remote:FireClient(plr, { type = eventType, state = self:_view(session, userId) })
        end
    end
end

function TradeService:_notify(player, payload)
    if player then
        self._remote:FireClient(player, payload)
    end
end

----------------------------------------------------------------------
-- Online-player list + invite handshake
----------------------------------------------------------------------

function TradeService:ListPlayers(player)
    local out = {}
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player then
            table.insert(out, {
                userId = other.UserId,
                name = other.Name,
                busy = self._playerSession[other.UserId] ~= nil,
            })
        end
    end
    return { ok = true, players = out }
end

function TradeService:Request(player, targetUserId)
    if targetUserId == player.UserId then
        return { ok = false, reason = "cannot_trade_self" }
    end
    local target = playerById(targetUserId)
    if not target then
        return { ok = false, reason = "player_not_found" }
    end
    if self._playerSession[player.UserId] or self._playerSession[targetUserId] then
        return { ok = false, reason = "already_trading" }
    end
    self._invites[targetUserId] = { from = player.UserId }
    self:_notify(target, { type = "request", fromUserId = player.UserId, fromName = player.Name })
    return { ok = true, pending = true }
end

function TradeService:Respond(player, fromUserId, accept)
    local invite = self._invites[player.UserId]
    if not invite or invite.from ~= fromUserId then
        return { ok = false, reason = "no_invite" }
    end
    self._invites[player.UserId] = nil
    local requester = playerById(fromUserId)

    if not accept then
        self:_notify(requester, { type = "declined", byUserId = player.UserId })
        return { ok = true, accepted = false }
    end
    if not requester then
        return { ok = false, reason = "player_not_found" }
    end
    if self._playerSession[player.UserId] or self._playerSession[fromUserId] then
        return { ok = false, reason = "already_trading" }
    end
    return self:_open(requester, player)
end

function TradeService:_open(playerA, playerB)
    self._nextId += 1
    local id = self._nextId
    local session = {
        id = id,
        a = playerA.UserId,
        b = playerB.UserId,
        offers = {
            [playerA.UserId] = { items = {}, confirmed = false },
            [playerB.UserId] = { items = {}, confirmed = false },
        },
        escrow = {
            [playerA.UserId] = {}, -- uid -> normalized pet descriptor
            [playerB.UserId] = {},
        },
    }
    self._sessions[id] = session
    self._playerSession[playerA.UserId] = id
    self._playerSession[playerB.UserId] = id
    self:_push(session, "opened")
    return { ok = true, sessionId = id }
end

----------------------------------------------------------------------
-- Escrow add / remove
----------------------------------------------------------------------

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for key, sub in pairs(value) do
        out[key] = deepCopy(sub)
    end
    return out
end

-- Escrow the FULL record (deep copy) so a traded special pet keeps its level/exp/
-- enchantments/serial — minimal descriptors silently dropped progression. equipped_slot is
-- cleared (an escrowed pet is not equipped); uid is kept to key the escrow table.
local function descriptorFromRecord(uid, rec)
    local copy = deepCopy(rec)
    copy.uid = uid
    copy.category = "pets"
    copy.equipped_slot = nil
    return copy
end

-- Re-add an escrowed pet to a player, minting a fresh uid but preserving every other field.
-- For a common the descriptor is a single copy (quantity 1) which AddItem folds back into the
-- recipient's stack; for a special it is the full record.
local function grantDescriptor(inventory, player, descriptor)
    local petData = deepCopy(descriptor)
    petData.uid = nil
    petData.equipped_slot = nil
    petData.equipped_slots = nil
    petData.quantity = 1
    inventory:AddItem(player, PETS_BUCKET, petData)
end

-- Synthetic, unique escrow key for an offered COMMON copy (commons have no uid).
local offerSeq = 0
local function nextOfferId()
    offerSeq += 1
    return "offer_" .. tostring(offerSeq)
end

-- Detach a pet from references before it leaves the inventory. Under the SSOT model
-- the equipped state lives on the record itself, so RemoveItem (which deletes the record)
-- plus RebuildPetProjections clears the equipped slot + folder automatically — no slot
-- string or ephemeral equip_<...> folder to hand-clean. We only drop roster references
-- here; _reloadEquipped() then despawns any orphaned world model.
function TradeService:_detachPet(player, uid, _rec)
    local rosters = self:_service("RosterService")
    if rosters and rosters.RemovePetReference then
        pcall(function()
            rosters:RemovePetReference(player, uid)
        end)
    end
end

-- Force a clean respawn of equipped pets (despawns orphaned follow models).
function TradeService:_reloadEquipped(player)
    if type(_G.RBXReloadEquippedPets) == "function" then
        pcall(function()
            _G.RBXReloadEquippedPets(player)
        end)
    end
end

-- Add a pet to the offer: validate, then MOVE it out of inventory into escrow.
function TradeService:Add(player, uid)
    local session = self:_sessionOf(player.UserId)
    if not session then
        return { ok = false, reason = "no_trade" }
    end
    local inventory = self:_service("InventoryService")
    if not inventory then
        return { ok = false, reason = "service_unavailable" }
    end
    -- Resolve the client identifier to a concrete target (special uid or common stack).
    local target = inventory.ResolvePetTarget and inventory:ResolvePetTarget(player, uid) or nil
    local bucket = inventory:GetInventory(player, PETS_BUCKET)
    local items = bucket and bucket.items
    if not target or not items then
        return { ok = false, reason = "pet_not_found" }
    end

    local offer = session.offers[player.UserId]
    if #offer.items >= (self._config.max_offer_items or 10) then
        return { ok = false, reason = "offer_full" }
    end

    local descriptor
    if target.kind == "special" then
        local rec = items[target.uid]
        if not rec then
            return { ok = false, reason = "pet_not_found" }
        end
        local verdict =
            TradeLogic.canAddItem("pets", { id = rec.id, locked = rec.locked }, self._config)
        if not verdict.ok then
            return verdict
        end
        -- Escrow lock: drop references, remove the record (anti-dup), then despawn the model.
        self:_detachPet(player, target.uid, rec)
        inventory:RemoveItem(player, PETS_BUCKET, target.uid, 1)
        descriptor = descriptorFromRecord(target.uid, rec)
    else
        local stack = items[target.stackKey]
        if not stack or (tonumber(stack.quantity) or 0) <= 0 then
            return { ok = false, reason = "pet_not_found" }
        end
        local verdict =
            TradeLogic.canAddItem("pets", { id = stack.id, locked = stack.locked }, self._config)
        if not verdict.ok then
            return verdict
        end
        -- Move ONE copy out of the stack into escrow (single-copy descriptor).
        inventory:RemoveItem(player, PETS_BUCKET, target.stackKey, 1)
        descriptor = {
            uid = nextOfferId(),
            category = "pets",
            id = stack.id,
            variant = stack.variant or "basic",
            quantity = 1,
        }
        if stack.element ~= nil then
            descriptor.element = stack.element
        end
    end

    self:_reloadEquipped(player)
    session.escrow[player.UserId][descriptor.uid] = descriptor
    table.insert(offer.items, descriptor)

    -- Any change invalidates both confirmations.
    session.offers[session.a].confirmed = false
    session.offers[session.b].confirmed = false
    self:_push(session, "updated")
    return { ok = true, count = #offer.items }
end

-- Bulk-offer N copies of a STACK in one shot (Jason: "a slider, trade 50-100 at a
-- time, not a window full of individual cards"). One escrow op + one push instead of
-- N round-trips through Add. Specials are unique (count is meaningless) so they fall
-- through to Add. The amount is clamped to BOTH the offer headroom (max_offer_items)
-- and the stack's available quantity, and reported back as `added` so the client can
-- toast a partial fill. Each escrowed copy is still its own descriptor (the offer
-- column aggregates them into one ×N card), keeping the swap/refund paths unchanged.
function TradeService:AddMany(player, uid, count)
    count = math.floor(tonumber(count) or 1)
    if count <= 1 then
        return self:Add(player, uid) -- single copy / special: the existing path
    end
    local session = self:_sessionOf(player.UserId)
    if not session then
        return { ok = false, reason = "no_trade" }
    end
    local inventory = self:_service("InventoryService")
    if not inventory then
        return { ok = false, reason = "service_unavailable" }
    end
    local target = inventory.ResolvePetTarget and inventory:ResolvePetTarget(player, uid) or nil
    local bucket = inventory:GetInventory(player, PETS_BUCKET)
    local items = bucket and bucket.items
    if not target or not items then
        return { ok = false, reason = "pet_not_found" }
    end
    -- specials can't bulk (one unique record) — defer to the single-add path
    if target.kind == "special" then
        return self:Add(player, uid)
    end

    local offer = session.offers[player.UserId]
    local headroom = (self._config.max_offer_items or 10) - #offer.items
    if headroom <= 0 then
        return { ok = false, reason = "offer_full" }
    end

    local stack = items[target.stackKey]
    if not stack or (tonumber(stack.quantity) or 0) <= 0 then
        return { ok = false, reason = "pet_not_found" }
    end
    local verdict =
        TradeLogic.canAddItem("pets", { id = stack.id, locked = stack.locked }, self._config)
    if not verdict.ok then
        return verdict
    end

    local available = math.floor(tonumber(stack.quantity) or 0)
    local toAdd = math.min(count, headroom, available)
    if toAdd <= 0 then
        return { ok = false, reason = "offer_full" }
    end

    -- Move N copies out of the stack at once, then escrow N single-copy descriptors.
    inventory:RemoveItem(player, PETS_BUCKET, target.stackKey, toAdd)
    for _ = 1, toAdd do
        local descriptor = {
            uid = nextOfferId(),
            category = "pets",
            id = stack.id,
            variant = stack.variant or "basic",
            quantity = 1,
        }
        if stack.element ~= nil then
            descriptor.element = stack.element
        end
        session.escrow[player.UserId][descriptor.uid] = descriptor
        table.insert(offer.items, descriptor)
    end

    self:_reloadEquipped(player)
    session.offers[session.a].confirmed = false
    session.offers[session.b].confirmed = false
    self:_push(session, "updated")
    return { ok = true, count = #offer.items, added = toAdd }
end

-- Add gems to the offer. Validates the amount + balance, then MOVES the gems out of the player's
-- balance into escrow (anti-dup, exactly like a pet): refunded on remove/cancel, delivered on
-- confirm. Each call is one offer card; the UI aggregates same-currency cards into a running total.
function TradeService:AddGems(player, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return { ok = false, reason = "bad_amount" }
    end
    local session = self:_sessionOf(player.UserId)
    if not session then
        return { ok = false, reason = "no_trade" }
    end
    local verdict = TradeLogic.canAddItem("currencies", { id = GEM_CURRENCY }, self._config)
    if not verdict.ok then
        return verdict
    end
    if not self._dataService then
        return { ok = false, reason = "service_unavailable" }
    end
    local offer = session.offers[player.UserId]
    if #offer.items >= (self._config.max_offer_items or 10) then
        return { ok = false, reason = "offer_full" }
    end
    if (tonumber(self._dataService:GetCurrency(player, GEM_CURRENCY)) or 0) < amount then
        return { ok = false, reason = "insufficient_gems" }
    end
    if self._dataService:RemoveCurrency(player, GEM_CURRENCY, amount, "trade_escrow") == false then
        return { ok = false, reason = "insufficient_gems" }
    end

    local descriptor =
        { uid = nextOfferId(), category = "currencies", id = GEM_CURRENCY, amount = amount }
    session.escrow[player.UserId][descriptor.uid] = descriptor
    table.insert(offer.items, descriptor)
    session.offers[session.a].confirmed = false
    session.offers[session.b].confirmed = false
    self:_push(session, "updated")
    return { ok = true, count = #offer.items }
end

-- Set the player's offered gems to an EXACT total (the trade UI's "Set" button). Keeps a single
-- gem escrow entry and moves currency by the DELTA: putting up more escrows the difference;
-- lowering it refunds the difference; 0 pulls them all back. The readout always equals what you set.
function TradeService:SetGems(player, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    local session = self:_sessionOf(player.UserId)
    if not session then
        return { ok = false, reason = "no_trade" }
    end
    if not self._dataService then
        return { ok = false, reason = "service_unavailable" }
    end
    local verdict = TradeLogic.canAddItem("currencies", { id = GEM_CURRENCY }, self._config)
    if not verdict.ok then
        return verdict
    end

    local escrow = session.escrow[player.UserId]
    local gemUid, current
    for uid, d in pairs(escrow) do
        if d.category == "currencies" and d.id == GEM_CURRENCY then
            gemUid, current = uid, tonumber(d.amount) or 0
            break
        end
    end
    current = current or 0
    if amount == current then
        return { ok = true, gems = amount }
    end

    if amount > current then
        local diff = amount - current
        if (tonumber(self._dataService:GetCurrency(player, GEM_CURRENCY)) or 0) < diff then
            return { ok = false, reason = "insufficient_gems" }
        end
        self._dataService:RemoveCurrency(player, GEM_CURRENCY, diff, "trade_escrow")
    else
        self._dataService:AddCurrency(player, GEM_CURRENCY, current - amount, "trade_refund")
    end

    local offer = session.offers[player.UserId]
    if amount > 0 then
        if gemUid then
            escrow[gemUid].amount = amount
            for _, it in ipairs(offer.items) do
                if it.uid == gemUid then
                    it.amount = amount
                end
            end
        else
            local d =
                { uid = nextOfferId(), category = "currencies", id = GEM_CURRENCY, amount = amount }
            escrow[d.uid] = d
            table.insert(offer.items, d)
        end
    elseif gemUid then
        escrow[gemUid] = nil
        for i = #offer.items, 1, -1 do
            if offer.items[i].uid == gemUid then
                table.remove(offer.items, i)
            end
        end
    end

    session.offers[session.a].confirmed = false
    session.offers[session.b].confirmed = false
    self:_push(session, "updated")
    return { ok = true, gems = amount }
end

-- Add an enhancement to the offer. `uid` is the inventory uid from EnhancementService:GetState().
-- Moves ONE copy out of the (stacked) enhancements bucket into escrow.
function TradeService:AddEnhancement(player, uid)
    local session = self:_sessionOf(player.UserId)
    if not session then
        return { ok = false, reason = "no_trade" }
    end
    local inventory = self:_service("InventoryService")
    if not inventory then
        return { ok = false, reason = "service_unavailable" }
    end
    local bucket = inventory:GetInventory(player, ENH_BUCKET)
    local rec = bucket and bucket.items and bucket.items[uid]
    if not rec then
        return { ok = false, reason = "enhancement_not_found" }
    end
    local verdict = TradeLogic.canAddItem("enhancements", { id = rec.id }, self._config)
    if not verdict.ok then
        return verdict
    end
    local offer = session.offers[player.UserId]
    if #offer.items >= (self._config.max_offer_items or 10) then
        return { ok = false, reason = "offer_full" }
    end

    inventory:RemoveItem(player, ENH_BUCKET, uid, 1)
    local descriptor = {
        uid = nextOfferId(),
        category = "enhancements",
        id = rec.id,
        enh = {
            id = rec.id,
            type = rec.type,
            origins = deepCopy(rec.origins),
            origins_csv = rec.origins_csv,
            level = rec.level,
            name = rec.name,
        },
    }
    session.escrow[player.UserId][descriptor.uid] = descriptor
    table.insert(offer.items, descriptor)
    session.offers[session.a].confirmed = false
    session.offers[session.b].confirmed = false
    self:_push(session, "updated")
    return { ok = true, count = #offer.items }
end

-- Pull a pet back out of the offer and return it to the owner's inventory.
function TradeService:Remove(player, uid)
    local session = self:_sessionOf(player.UserId)
    if not session then
        return { ok = false, reason = "no_trade" }
    end
    local descriptor = session.escrow[player.UserId][uid]
    if not descriptor then
        return { ok = false, reason = "not_offered" }
    end
    self:_grantDescriptor(player, descriptor) -- back to owner (pet / gems / enhancement)
    session.escrow[player.UserId][uid] = nil
    local offer = session.offers[player.UserId]
    for i = #offer.items, 1, -1 do
        if offer.items[i].uid == uid then
            table.remove(offer.items, i)
        end
    end
    session.offers[session.a].confirmed = false
    session.offers[session.b].confirmed = false
    self:_push(session, "updated")
    return { ok = true }
end

----------------------------------------------------------------------
-- Confirm / deliver / cancel / refund
----------------------------------------------------------------------

function TradeService:Confirm(player)
    local session = self:_sessionOf(player.UserId)
    if not session then
        return { ok = false, reason = "no_trade" }
    end
    session.offers[player.UserId].confirmed = true
    local offerA, offerB = session.offers[session.a], session.offers[session.b]
    if TradeLogic.canExecute(offerA, offerB).ok then
        return self:_deliver(session)
    end
    self:_push(session, "updated")
    return { ok = true, waiting = true }
end

-- Grant ONE escrowed descriptor to a player, dispatched by category. Pets fold into the pets
-- bucket (fresh uid); gems credit the gem currency; enhancements re-enter the enhancements bucket.
-- This is the single seam that makes _deliver / _refund / Remove bucket-agnostic.
function TradeService:_grantDescriptor(player, descriptor)
    if not (player and descriptor) then
        return
    end
    local category = descriptor.category or "pets"
    if category == "currencies" then
        local amount = math.floor(tonumber(descriptor.amount) or 0)
        if amount > 0 and self._dataService then
            self._dataService:AddCurrency(player, descriptor.id or GEM_CURRENCY, amount, "trade")
        end
        return
    end
    local inventory = self:_service("InventoryService")
    if not inventory then
        return
    end
    if category == "enhancements" then
        if descriptor.enh then
            inventory:AddItem(player, ENH_BUCKET, deepCopy(descriptor.enh))
        end
        return
    end
    grantDescriptor(inventory, player, descriptor) -- pets (default)
end

function TradeService:_giveAll(player, escrowForOwner)
    for _, descriptor in pairs(escrowForOwner or {}) do
        self:_grantDescriptor(player, descriptor)
    end
end

-- Both confirmed: deliver A's escrow to B and B's escrow to A. All-or-nothing —
-- the items are already escrowed, so neither side can be left holding both/none.
function TradeService:_deliver(session)
    local pa, pb = playerById(session.a), playerById(session.b)
    self:_giveAll(pb, session.escrow[session.a])
    self:_giveAll(pa, session.escrow[session.b])

    local rec = TradeLogic.auditRecord(
        session.a,
        session.b,
        session.offers[session.a],
        session.offers[session.b],
        os.time()
    )
    self:_appendAudit(rec)
    self:_push(session, "completed")
    -- trader-track stats (Jason: capture the data now, leaderboard later) —
    -- trades_completed rides the trade_complete event via StatEventCounters;
    -- the per-pet counts vary per trade so they increment here.
    local function countPets(escrow)
        local n = 0
        for _, d in pairs(escrow or {}) do
            if (d.category or "pets") == "pets" then
                n += 1 -- pets_traded counters: gems/enhancements ride their own paths
            end
        end
        return n
    end
    local gaveA, gaveB = countPets(session.escrow[session.a]), countPets(session.escrow[session.b])
    local stats = self:_service("StatsService")
    if stats then
        if pa then
            stats:Increment(pa, "pets_traded_away", gaveA)
            stats:Increment(pa, "pets_traded_received", gaveB)
        end
        if pb then
            stats:Increment(pb, "pets_traded_away", gaveB)
            stats:Increment(pb, "pets_traded_received", gaveA)
        end
    end

    -- config-driven celebration for BOTH sides of a completed trade (game_events)
    if pa then
        fireGameEvent(pa, "trade_complete", { with = session.b })
    end
    if pb then
        fireGameEvent(pb, "trade_complete", { with = session.a })
    end
    self:_close(session.id)
    if pa then
        self._dataService:RequestSave(pa, "trade_complete", { critical = true })
    end
    if pb then
        self._dataService:RequestSave(pb, "trade_complete", { critical = true })
    end
    return { ok = true, executed = true, audit = rec }
end

-- Return every escrowed pet to its owner (cancel / decline / disconnect).
function TradeService:_refund(session)
    for _, userId in ipairs({ session.a, session.b }) do
        self:_giveAll(playerById(userId), session.escrow[userId])
        session.escrow[userId] = {}
    end
end

function TradeService:Cancel(player)
    local session = self:_sessionOf(player.UserId)
    if not session then
        return { ok = true }
    end
    self:_refund(session)
    self:_push(session, "cancelled")
    self:_close(session.id)
    return { ok = true }
end

function TradeService:_onLeave(player)
    -- Clear any invite addressed to or from the leaving player.
    self._invites[player.UserId] = nil
    for target, invite in pairs(self._invites) do
        if invite.from == player.UserId then
            self._invites[target] = nil
        end
    end
    local session = self:_sessionOf(player.UserId)
    if session then
        self:_refund(session) -- refunds the leaver too (their save flushes on remove)
        self:_push(session, "cancelled")
        self:_close(session.id)
    end
end

function TradeService:_close(sessionId)
    local session = self._sessions[sessionId]
    if not session then
        return
    end
    self._playerSession[session.a] = nil
    self._playerSession[session.b] = nil
    self._sessions[sessionId] = nil
end

-- The player's tradeable pets (for the offer picker). Pets already escrowed in an
-- active trade are gone from inventory, so they naturally don't appear here.
function TradeService:ListMyPets(player)
    local inventory = self:_service("InventoryService")
    if not inventory then
        return { ok = false, reason = "service_unavailable" }
    end
    local bucket = inventory:GetInventory(player, PETS_BUCKET)
    local out = {}
    for uid, rec in pairs((bucket and bucket.items) or {}) do
        table.insert(out, {
            uid = uid,
            id = rec.id,
            variant = rec.variant or "basic",
            element = rec.element,
            huge = rec.huge,
            locked = rec.locked,
            -- display payload (Jason: "we have all the code for the UI — why isn't
            -- it all there"): stack size + the special-record identity fields
            quantity = tonumber(rec.quantity) or 1,
            serial = rec.serial,
            level = rec.level,
            rarity_id = rec.rarity_id,
        })
    end
    return { ok = true, pets = out }
end

-- The player's tradeable enhancements (source list for the trade picker). Each entry is tagged
-- category="enhancements" so the offer columns render it through the simple-card path.
function TradeService:ListMyEnhancements(player)
    local enh = self:_service("EnhancementService")
    if not (enh and enh.GetState) then
        return { ok = false, reason = "service_unavailable" }
    end
    local state = enh:GetState(player)
    local out = {}
    for _, item in ipairs((state and state.inventory) or {}) do
        out[#out + 1] = {
            uid = item.uid,
            category = "enhancements",
            id = item.uid, -- the inventory uid IS what trade.addEnhancement takes
            type = item.type,
            origins = item.origins, -- the trade card renders PetBadge.createEnhancementBadge
            level = item.level,
            name = item.name,
            count = item.count,
        }
    end
    return { ok = true, enhancements = out }
end

function TradeService:GetState(player)
    local session = self:_sessionOf(player.UserId)
    if not session then
        return { ok = true, active = false }
    end
    return { ok = true, active = true, state = self:_view(session, player.UserId) }
end

----------------------------------------------------------------------
-- Audit log + test affordance
----------------------------------------------------------------------

function TradeService:_appendAudit(rec)
    table.insert(self._auditLog, rec)
    local limit = self._config.audit_log_limit or 100
    while #self._auditLog > limit do
        table.remove(self._auditLog, 1)
    end
end

function TradeService:GetAuditLog(userId)
    if not userId then
        return { ok = true, records = self._auditLog }
    end
    local out = {}
    for _, rec in ipairs(self._auditLog) do
        if rec.a == userId or rec.b == userId then
            table.insert(out, rec)
        end
    end
    return { ok = true, records = out }
end

-- Rules + execute-gate + audit-record logic without two live players.
function TradeService:Simulate(opts)
    opts = opts or {}
    local offerA = opts.offerA or { items = {}, confirmed = false }
    local offerB = opts.offerB or { items = {}, confirmed = false }
    local adds = {}
    for _, it in ipairs(opts.adds or {}) do
        adds[#adds + 1] = TradeLogic.canAddItem(it.category, it, self._config)
    end
    local exec = TradeLogic.canExecute(offerA, offerB)
    local audit = nil
    if exec.ok then
        audit = TradeLogic.auditRecord(
            opts.a or "A",
            opts.b or "B",
            offerA,
            offerB,
            opts.timestamp or 0
        )
    end
    return { ok = true, adds = adds, canExecute = exec, audit = audit }
end

return TradeService
