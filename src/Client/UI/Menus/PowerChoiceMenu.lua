--[[
    PowerChoiceMenu — the interactive level-up workflow (Feature 14/15 surface).

    Dual column: NATURAL (generic pool, purple) + one ORIGIN archetype (element-coloured).
    You level up from 1; every level grants SOMETHING to do (config-driven cadence):
      • a power-pick level (in powers.selection_levels) -> pick ONE not-yet-owned power
        that's unlocked at your level (click an "available" row).
      • otherwise -> place 2 enhancement slots onto powers you already own (click an "owned"
        row to add a slot, up to 6 — the slots PowerSlotRow already draws).

    STAGE → COMMIT. Clicking a row STAGES the choice; nothing is final until you press COMMIT.
      • pick beat: clicking is a radio — a second power replaces the first; clicking the staged
        one clears it.
      • slot beat: each click stages a slot; ↶ UNDO pops the last staged action.
      • COMMIT writes the staged beat into `owned` + the log; then LEVEL UP unlocks the next beat.
        You cannot level past an un-committed beat, and must spend the grant before committing.
      • committed picks are permanent (RESET is the dev full-run wipe; real respec comes later).

    TWO MODES (same UX, different data source):
      • LIVE (default when the GameAPICommand bus is up): the SERVER is authoritative. On open we
        load archetype.get / power.get / augment.get / levelup.getState; the origin is LOCKED to the
        player's real archetype. COMMIT sends the staged beat to the bus (pick -> power.select,
        slot -> augment.place), LEVEL UP -> levelup.claim (one real level per click); admins can
        bank a level first (levelup.bank) to walk the track without grinding XP. After each call we
        re-read the server and re-render. RESET = discard staged + resync (no destructive wipe).
      • PREVIEW (fallback if the bus isn't reachable): a purely local model (level / owned / pending
        / staged + self.log), origin cycles via the header, RESET wipes the local run from L1.

    MenuManager panel interface: new() -> { Show(parent), Hide(), GetFrame() }.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local powersCfg = require(Configs:WaitForChild("powers"))
local archetypesCfg = require(Configs:WaitForChild("archetypes"))
local levelTrackCfg = require(Configs:WaitForChild("level_track"))
local PowerSelection = require(ReplicatedStorage.Shared.Game.PowerSelection)
local PetBadge = require(script.Parent.Parent.PetBadge)
local PowerDescribe = require(ReplicatedStorage.Shared.Game.PowerDescribe)
local Enhancements = require(ReplicatedStorage.Shared.Game.Enhancements)
local EnhancementPricing = require(ReplicatedStorage.Shared.Game.EnhancementPricing)
local enhancementsCfg = require(ReplicatedStorage.Configs:WaitForChild("enhancements"))
local PowerSlotRow = require(script.Parent.Parent.PowerSlotRow)
local Enhancements = require(ReplicatedStorage.Shared.Game.Enhancements)
local enhCfg = require(Configs:WaitForChild("enhancements"))
-- result-preview math (the SAME path PowerService casts through): record -> effective stats,
-- diffed committed-vs-staged so the strip can show what slotting will change before APPLY.
local PowerRegistry = require(ReplicatedStorage.Shared.Game.PowerRegistry)
local PowerStats = require(ReplicatedStorage.Shared.Game.PowerStats)
local PowerStatsDiff = require(ReplicatedStorage.Shared.Game.PowerStatsDiff)
local FocusUpkeep = require(ReplicatedStorage.Shared.Game.FocusUpkeep)
local CloseButton = require(script.Parent.Parent.Components.CloseButton)
local PanelChrome = require(script.Parent.Parent.Components.PanelChrome)
local Pill = require(script.Parent.Parent.Pill)
-- The level a new player chooses their origin (NATURAL picks come before this; ORIGIN powers after).
local ORIGIN_CHOICE_LEVEL = levelTrackCfg.origin_choice_level or 5

-- Bus call (mirrors LevelUpController): returns the handler's domain result, or nil if the bus
-- isn't up. Synchronous (RemoteFunction). Used only in LIVE mode.
local function callBus(name, args)
    local remote = ReplicatedStorage:FindFirstChild("GameAPICommand")
    if not remote then
        return nil
    end
    local ok, envelope = pcall(function()
        return remote:InvokeServer(name, args or {})
    end)
    if not ok or type(envelope) ~= "table" then
        return nil
    end
    return envelope.result
end

local function isAdmin()
    local lp = Players.LocalPlayer
    return RunService:IsStudio() or (lp and lp:GetAttribute("IsAdmin") == true)
end

-- DEV affordances (LEVEL UP self-pacer + RESET) only show when the admin overlay toggle is ON.
-- A real player sees just UNDO + COMMIT — they level up at the altar, not via a button here.
local function devMode()
    local lp = Players.LocalPlayer
    return lp and lp:GetAttribute("AdminOverlaysOn") == true
end

local ORIGINS = { "geomancer", "sandwalker", "cryomancer", "pyromancer" }
local ORIGIN_COLOR = {
    geomancer = Color3.fromRGB(150, 230, 150),
    sandwalker = Color3.fromRGB(240, 215, 130),
    cryomancer = Color3.fromRGB(140, 200, 255),
    pyromancer = Color3.fromRGB(255, 150, 120),
}
local NATURAL_COLOR = Color3.fromRGB(196, 156, 255)
local MAX_LEVEL = 50
local MAX_SLOTS = 6
local SLOTS_PER_ROUND = 2

-- chip palette (base colours; dimmed when a chip is disabled)
local COMMIT_COLOR = Color3.fromRGB(235, 200, 90)
local UNDO_COLOR = Color3.fromRGB(150, 150, 165)
local LEVEL_COLOR = Color3.fromRGB(120, 205, 130)
local RESET_COLOR = Color3.fromRGB(150, 120, 200)
local STAGED_GLOW = Color3.fromRGB(235, 200, 90)

-- selection levels -> set, for O(1) "is this a power level?"
local SEL = {}
for _, l in ipairs(powersCfg.selection_levels or {}) do
    SEL[l] = true
end

-- what a given level grants: "power" (1, on a selection level) or "slots" (2). L1 grants nothing —
-- the lowest power unlocks at L2, so the first LEVEL UP (to L2) hands you your first pick.
local function grantFor(level)
    if SEL[level] then
        return "power", 1
    end
    return "slots", SLOTS_PER_ROUND
end

local function pickLevelOf(id)
    local def = powersCfg.powers[id]
    return PowerSelection.pickLevel(def and def.unlock_level or 1, powersCfg.selection_levels)
end

local PowerChoiceMenu = {}
PowerChoiceMenu.__index = PowerChoiceMenu

function PowerChoiceMenu.new()
    local self = setmetatable({}, PowerChoiceMenu)
    self.frame = nil
    self.originIndex = 1
    self.level = 1
    self.owned = {} -- [powerId] = slotCount (1..6) — COMMITTED only
    self.pendingPower = 0 -- power picks granted this beat (not yet committed)
    self.pendingSlots = 0 -- slots granted this beat (not yet committed)
    self.staged = {} -- { { action = "pick"|"slot", id = powerId }, ... } — reversible, pre-commit
    self.log = {} -- COMMITTED actions (preview mode only): { { action, id, level }, ... }
    -- live (server-backed) state
    self.live = false -- true once the bus loads real state; false = local preview fallback
    self.archetype = nil -- the player's real origin (live mode locks the ORIGIN column to it)
    self.pendingLevels = 0 -- earned - claimed (claimable level-ups waiting), from the server
    self.atMax = false
    self.notice = nil -- transient error/notice text (e.g. a rejected bus call)
    -- ui refs
    self.naturalCol = nil
    self.originCol = nil
    self.originHeader = nil
    self.statusLabel = nil
    self.levelBtn = nil
    self.commitBtn = nil
    self.undoBtn = nil
    self.resetBtn = nil
    return self
end

-- ---- staged-buffer helpers ----------------------------------------------

function PowerChoiceMenu:_stagedPickCount()
    local n = 0
    for _, s in ipairs(self.staged) do
        if s.action == "pick" then
            n += 1
        end
    end
    return n
end

function PowerChoiceMenu:_stagedSlotCount()
    local n = 0
    for _, s in ipairs(self.staged) do
        if s.action == "slot" then
            n += 1
        end
    end
    return n
end

function PowerChoiceMenu:_stagedSlotsOn(id)
    local n = 0
    for _, s in ipairs(self.staged) do
        if s.action == "slot" and s.id == id then
            n += 1
        end
    end
    return n
end

function PowerChoiceMenu:_isStagedPick(id)
    for _, s in ipairs(self.staged) do
        if s.action == "pick" and s.id == id then
            return true
        end
    end
    return false
end

-- slots that would show on a row: committed base + staged slots (staged pick = its inherent 1)
function PowerChoiceMenu:_effectiveSlots(id)
    if self.owned[id] then
        return self.owned[id] + self:_stagedSlotsOn(id)
    elseif self:_isStagedPick(id) then
        return 1
    end
    return 1
end

function PowerChoiceMenu:_remainingPicks()
    return self.pendingPower - self:_stagedPickCount()
end

function PowerChoiceMenu:_remainingSlots()
    return self.pendingSlots - self:_stagedSlotCount()
end

-- is there ANY committed power that could still take a slot? (avoids a late-game commit soft-lock)
function PowerChoiceMenu:_canPlaceSlot()
    for id, count in pairs(self.owned) do
        if count + self:_stagedSlotsOn(id) < MAX_SLOTS then
            return true
        end
    end
    return false
end

-- COMMIT is allowed once the beat's grant is fully allocated (picks always; slots unless none fit)
function PowerChoiceMenu:_canCommit()
    if self.pendingPower == 0 and self.pendingSlots == 0 then
        return false -- nothing granted this beat
    end
    if self:_remainingPicks() > 0 then
        return false
    end
    if self:_remainingSlots() > 0 and self:_canPlaceSlot() then
        return false
    end
    return true
end

-- ---- live (server-backed) state -----------------------------------------

-- Pull the player's REAL state off the bus into the menu's cache. Returns false if the bus isn't
-- up (caller falls back to local preview). Slot count per power = #data.Slots[id] (incl. the free
-- inherent slot). pendingPower/pendingSlots come straight from the server's owed amounts.
function PowerChoiceMenu:_loadLive()
    local arche = callBus("archetype.get", {})
    local lvl = callBus("levelup.getState", {})
    local pw = callBus("power.get", {})
    local aug = callBus("augment.get", {})
    if not (arche and lvl and lvl.state and pw and aug) then
        return false
    end
    -- slotted enhancements per power: the ROWS render their slot contents too (Jason:
    -- the row circles looked empty after slotting — only the strip knew)
    local enhState = callBus("enh.get", {})
    self.enhSlots = (enhState and enhState.slots) or {}
    local st = lvl.state
    self.archetype = arche.archetype
    self.claimedLevel = st.claimedLevel or 1
    self.pendingLevels = math.max(0, st.pendingLevels or 0)
    self.atMax = st.atMax == true or self.claimedLevel >= MAX_LEVEL
    self.owned = {}
    local slots = aug.slots or {}
    for _, id in ipairs(pw.powers or {}) do
        local list = slots[id]
        self.owned[id] = (type(list) == "table" and #list) or 1
    end
    -- PREVIEW the next claimable level — it is NOT claimed yet. The beat shown is THAT level's grant;
    -- COMMIT claims the level AND applies the pick/slots atomically (levelup.commit). Until COMMIT,
    -- nothing is granted, so a disconnect mid-menu never leaves you leveled without a choice.
    if st.canClaim and st.nextEntry and not self.atMax then
        self.level = st.nextLevel or (self.claimedLevel + 1)
        self.pendingPower = st.nextEntry.powerPick and 1 or 0
        self.pendingSlots = math.max(0, tonumber(st.nextEntry.slots) or 0)
    else
        self.level = self.claimedLevel
        self.pendingPower = 0
        self.pendingSlots = 0
    end
    self.staged = {}
    return true
end

-- Decide the mode on open: LIVE if the bus loads real state, else local PREVIEW.
function PowerChoiceMenu:_initState()
    self.notice = nil
    self.live = self:_loadLive()
    if not self.live then
        self:_reset()
    end
end

-- ---- model ---------------------------------------------------------------

function PowerChoiceMenu:_grant(level)
    local kind, n = grantFor(level)
    if kind == "power" then
        self.pendingPower += n
    else
        self.pendingSlots += n
    end
end

function PowerChoiceMenu:_reset()
    if self.live then
        -- live: RESET = discard staged + resync from the server (NOT a destructive wipe).
        self.staged = {}
        self.notice = nil
        self:_loadLive()
        return
    end
    self.level = 1
    self.owned = {}
    self.pendingPower = 0
    self.pendingSlots = 0
    self.staged = {}
    self.log = {}
    -- L1 grants nothing; the first LEVEL UP (to L2) hands the first power pick.
end

function PowerChoiceMenu:_levelUp()
    if self.atMax or self.level >= MAX_LEVEL then
        return
    end
    -- must commit (clear) the current beat before advancing
    if self.pendingPower > 0 or self.pendingSlots > 0 then
        return
    end
    if self.live then
        -- DEV self-pacer only (players never see this button): BANK an earned level so the next
        -- level becomes claimable to PREVIEW. The real claim happens on COMMIT (levelup.commit).
        if isAdmin() then
            callBus("levelup.bank", { count = 1 })
            self:_loadLive()
            self:_render()
        end
        return
    end
    self.level += 1
    self:_grant(self.level)
    self:_render()
end

-- click a row: stage a slot (committed power) OR stage/clear a pick (radio on a pick beat).
function PowerChoiceMenu:_onRow(id)
    self.notice = nil
    if self.owned[id] then
        -- committed power: stage a slot if the beat grants slots and it isn't maxed
        if self:_remainingSlots() > 0 and self:_effectiveSlots(id) < MAX_SLOTS then
            self.staged[#self.staged + 1] = { action = "slot", id = id }
            self:_render()
        elseif self.live and self.pendingPower == 0 and self:_remainingSlots() == 0 then
            -- no beat to resolve: clicking an owned power opens its ENHANCE strip (slot
            -- enhancements from the inventory into its empty slots)
            self:_toggleEnhance(id)
        end
    elseif self:_isStagedPick(id) then
        -- clicking the staged pick clears it (undo)
        for i = #self.staged, 1, -1 do
            if self.staged[i].action == "pick" and self.staged[i].id == id then
                table.remove(self.staged, i)
            end
        end
        self:_render()
    else
        -- attempt to stage this as the pick
        if self.pendingPower > 0 and pickLevelOf(id) <= self.level then
            if self:_remainingPicks() > 0 then
                self.staged[#self.staged + 1] = { action = "pick", id = id }
            elseif self.pendingPower == 1 then
                -- radio: a second choice replaces the first
                for i = #self.staged, 1, -1 do
                    if self.staged[i].action == "pick" then
                        table.remove(self.staged, i)
                    end
                end
                self.staged[#self.staged + 1] = { action = "pick", id = id }
            else
                return
            end
            self:_render()
        end
    end
end

function PowerChoiceMenu:_undo()
    if #self.staged == 0 then
        return
    end
    table.remove(self.staged)
    self:_render()
end

-- RESET button. Admin + live: a FULL wipe (powers/slots cleared, back to L1, origin kept) so you
-- can retest the climb. Otherwise: just discard staged / local-preview wipe (see _reset).
function PowerChoiceMenu:_resetRun()
    if self.live and isAdmin() then
        local res = callBus("levelup.resetRun", {})
        self.staged = {}
        self.notice = (res and res.ok == false) and ("Reset failed: " .. tostring(res.reason))
            or nil
        self:_loadLive()
        self:_render()
        return
    end
    self:_reset()
    self:_render()
end

function PowerChoiceMenu:_commit()
    if not self:_canCommit() then
        return
    end
    if self.live then
        -- ATOMIC: one call CLAIMS the previewed level AND applies the staged pick/slots. Nothing is
        -- granted unless this succeeds — so quitting before COMMIT never leaves you leveled with no
        -- choice. (Server pre-validates the pick at the post-claim level.)
        local picks, slots = {}, {}
        for _, s in ipairs(self.staged) do
            if s.action == "pick" then
                picks[#picks + 1] = s.id
            else
                slots[#slots + 1] = s.id
            end
        end
        local res = callBus("levelup.commit", {
            expectedLevel = self.level,
            picks = picks,
            slots = slots,
        })
        self.staged = {}
        self.notice = (res and res.ok == false) and ("Commit failed: " .. tostring(res.reason))
            or nil
        self:_loadLive() -- the server is authoritative; re-read claimed/owned/preview
        self:_render()
        -- Player flow: they came to resolve ONE level. With nothing left and no LEVEL UP button,
        -- close so they're not on a dead menu. Devs keep it open to keep testing.
        if not devMode() and self.pendingPower == 0 and self.pendingSlots == 0 then
            if _G.MenuManager and _G.MenuManager.CloseCurrentPanel then
                _G.MenuManager:CloseCurrentPanel()
            end
        end
        return
    end
    for _, s in ipairs(self.staged) do
        if s.action == "pick" then
            self.owned[s.id] = 1 -- a freshly-picked power comes with its inherent first slot
        else
            self.owned[s.id] = (self.owned[s.id] or 1) + 1
        end
        self.log[#self.log + 1] = { action = s.action, id = s.id, level = self.level }
    end
    self.staged = {}
    self.pendingPower = 0
    self.pendingSlots = 0
    self:_render()
end

-- ---- render --------------------------------------------------------------

-- ===== ENHANCE strip ======================================================================
-- Outside a level-up beat, clicking an OWNED power opens this strip: the power's slots
-- (filled = the enhancement's disc+ring; single = same colour group, dual = mixed) plus a
-- clickable row of inventory enhancements COMPATIBLE with the power and USABLE by the
-- player's origin. Clicking one slots it into the first empty slot (server-validated).

-- shared composer (PetBadge owns the one assembly path; inventory cards use the same call)
-- level label color vs the PLAYER's level (Jason): red = below the window (dead),
-- yellow = below you (reduced), blue = on target, green = above you (boosted)
local function levelColor(lvl, playerLvl)
    local window = ((enhCfg.drops or {}).levels or {}).scaling
    window = (window and window.window) or 2
    local d = (tonumber(lvl) or playerLvl) - playerLvl
    if d < -window then
        return Color3.fromRGB(220, 90, 90) -- dead: contributes nothing
    elseif d < 0 then
        return Color3.fromRGB(235, 205, 90) -- low: reduced effect
    elseif d == 0 then
        return Color3.fromRGB(120, 180, 255) -- on target
    end
    return Color3.fromRGB(120, 220, 120) -- above: boosted
end

-- readable row height in PIXELS: desktop ~7.5% of the column (same as the old
-- scale sizing), clamped to a 34px floor so phone text stays legible
local function rowPixelHeight()
    local cam = workspace.CurrentCamera
    local vpY = (cam and cam.ViewportSize.Y) or 720
    local colH = vpY * 0.92 * 0.82
    return math.clamp(math.floor(colH * 0.075), 34, 64)
end

local function enhBadge(parent, size, pos, rec, dead)
    return PetBadge.createEnhancementBadge(
        parent,
        { size = size, position = pos, record = rec, dead = dead }
    )
end

-- format an effective-stat value for the result preview: seconds (8.0s), a 0..1 chance as a
-- percent (92%), or a plain number (whole when it rounds clean, else one decimal).
local function fmtStat(value, unit)
    value = tonumber(value) or 0
    if unit == "s" then
        return ("%.1fs"):format(value)
    elseif unit == "%" then
        return ("%d%%"):format(math.floor(value * 100 + 0.5))
    elseif math.abs(value - math.floor(value + 0.5)) < 0.05 then
        return ("%d"):format(math.floor(value + 0.5))
    end
    return ("%.1f"):format(value)
end

local PREVIEW_UP = Color3.fromRGB(120, 220, 120) -- the staged change helps this axis
local PREVIEW_DOWN = Color3.fromRGB(225, 130, 120) -- … or hurts it (e.g. a longer recharge)

function PowerChoiceMenu:_toggleEnhance(powerId)
    if self.enhanceFor == powerId then
        self.enhanceFor = nil
    else
        self.enhanceFor = powerId
    end
    self:_renderEnhanceStrip()
end

-- RESULT PREVIEW math. Resolve the power's effective stats TWICE — committed slots vs
-- committed + the staged enhancement dropped into its target slot — then diff. Reuses the
-- exact cast path (PowerRegistry.record -> Enhancements.aggregate -> PowerStats.resolveEffective)
-- so the preview can never disagree with what the power actually does. Returns the diff rows
-- (PowerStatsDiff order) or nil if the power has no record.
function PowerChoiceMenu:_previewDiff(powerId, slots, staged)
    local record = PowerRegistry.record(tostring(powerId), powersCfg)
    if not (record and staged and staged.item) then
        return nil
    end
    local lvl = self.level
    -- projected slot list = the committed slots with the staged record placed at its index
    -- (overwrites whatever's there — APPLY replaces a filled slot, mirroring the preview).
    -- slots is a pure array of slot records, so a shallow clone is the projected list.
    local projected = table.clone(slots)
    projected[staged.slotIndex] = {
        enh = {
            type = staged.item.type,
            origins = staged.item.origins,
            level = staged.item.level,
        },
    }
    -- radius-magnitude families (Magnet): range folds into magnitude, exactly as the cast
    -- stamp does — record.effect IS the effect-kind family (PowerRegistry sets it).
    local radiusMagnitude = (enhCfg.radius_families or {})[record.effect] == true
    local damageIsMagnitude = (enhCfg.damage_as_magnitude_families or {})[record.effect] == true
    local healIsMagnitude = (enhCfg.heal_as_magnitude_families or {})[record.effect] == true
    local function resolve(slotList)
        return PowerStats.resolveEffective(record, {
            casterLevel = lvl,
            scaling = powersCfg.scaling, -- nil today ⇒ identity; matches PowerService
            enhancements = Enhancements.aggregate(enhCfg, slotList, lvl),
            radiusMagnitude = radiusMagnitude,
            damageIsMagnitude = damageIsMagnitude,
            healIsMagnitude = healIsMagnitude,
        })
    end
    return PowerStatsDiff.diff(resolve(slots), resolve(projected))
end

-- The staged enhancement's FOCUS impact. `focus` is NOT a PowerStats axis (PowerService reads it for
-- a toggle's per-second upkeep / an active power's cast cost), so it never shows in the diff rows — a
-- Focus enhancement otherwise looks like it only LOWERS potency (the slot it replaced). Surface the
-- real benefit here. Returns { label, from, to, unit, deltaPct } or nil (power spends no Focus / no change).
function PowerChoiceMenu:_previewFocus(powerId, slots, staged)
    if not (staged and staged.item) then
        return nil
    end
    local def = powersCfg.powers[powerId]
    if not def then
        return nil
    end
    local kind = def.effect and (powersCfg.effect_kinds or {})[def.effect]
    local isToggle = kind ~= nil and (kind.passive == true or kind.toggle == true)
    local base = isToggle and tonumber(def.focus_upkeep) or tonumber(def.focus_cost)
    if not (base and base > 0) then
        return nil -- this power doesn't spend Focus → nothing to show
    end
    local lvl = self.level
    local projected = table.clone(slots)
    projected[staged.slotIndex] = {
        enh = {
            type = staged.item.type,
            origins = staged.item.origins,
            level = staged.item.level,
        },
    }
    local function rate(list)
        local r = Enhancements.aggregate(enhCfg, list, lvl).focus or 0
        -- SSOT: the exact division the live upkeep/cost path uses, so the preview can't diverge
        return FocusUpkeep.effectiveRate(base, r)
    end
    local from, to = rate(slots), rate(projected)
    if math.abs(from - to) < 1e-6 then
        return nil
    end
    return {
        label = isToggle and "Focus drain" or "Focus cost",
        unit = isToggle and "/s" or "",
        from = from,
        to = to,
        deltaPct = (to - from) / from, -- negative = cheaper to run (an improvement)
    }
end

-- For a radius-magnitude power (Magnet), the `magnitude` axis IS the reach, so the preview
-- labels that line "Range" rather than the generic "Potency".
function PowerChoiceMenu:_isRadiusMagnitude(powerId)
    local def = powersCfg.powers[powerId]
    local family = def and (powersCfg.effect_kinds[def.effect] or {}).family
    return family ~= nil and (enhCfg.radius_families or {})[family] == true
end

-- The preview card: the power name + each stat line the staged enhancement would shift, with
-- the before→after and signed %, improvements green / regressions red. Lives in the staged
-- block of _renderEnhanceStrip, so it's rebuilt on every stage and gone on APPLY/CANCEL.
function PowerChoiceMenu:_renderResultPreview(parent, powerId, slots, staged)
    local rows = self:_previewDiff(powerId, slots, staged)
    if not rows then
        return
    end
    local def = powersCfg.powers[powerId] or {}

    local card = Instance.new("Frame")
    card.Name = "ResultPreview"
    card.AnchorPoint = Vector2.new(1, 1)
    card.Position = UDim2.fromScale(0.985, 0.88) -- tucked above APPLY/CANCEL, right side
    card.Size = UDim2.new(0.34, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = Color3.fromRGB(16, 14, 26)
    card.BackgroundTransparency = 0.05
    card.ZIndex = 12
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 8)
    cc.Parent = card
    local cs = Instance.new("UIStroke")
    cs.Color = Color3.fromRGB(255, 205, 70) -- the menu's gold tooltip stroke
    cs.Thickness = 1.5
    cs.Parent = card
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = card
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Vertical
    list.Padding = UDim.new(0, 4)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = card
    card.Parent = parent

    local order = 0
    local function line(text, color, size, font)
        order += 1
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Size = UDim2.new(1, 0, 0, 0)
        l.AutomaticSize = Enum.AutomaticSize.Y
        l.Font = font or Enum.Font.Gotham
        l.TextSize = size or 13
        l.TextColor3 = color
        l.TextWrapped = true
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.LayoutOrder = order
        l.ZIndex = 13
        l.Text = text
        l.Parent = card
        return l
    end

    line("RESULT PREVIEW", Color3.fromRGB(170, 160, 110), 11, Enum.Font.GothamBold)
    line(def.display_name or powerId, Color3.fromRGB(255, 205, 70), 15, Enum.Font.GothamBold)
    -- the PowerDescribe summary, so it reads like the row tooltips
    local d = PowerDescribe.describe(powersCfg, powerId)
    if d and d.summary then
        line(d.summary, Color3.fromRGB(205, 205, 220), 12)
    end
    line(
        "with " .. Enhancements.displayName(enhCfg, staged.item),
        Color3.fromRGB(150, 150, 170),
        11
    )

    -- FOCUS impact (upkeep/cost) — not a PowerStats axis, so render it explicitly. Lower = green.
    local focusInfo = self:_previewFocus(powerId, slots, staged)
    if #rows == 0 and not focusInfo then
        line("No change at your level", Color3.fromRGB(170, 170, 190), 12, Enum.Font.GothamMedium)
        return
    end
    if focusInfo then
        line(
            ("%s   %.2f%s → %.2f%s  (%+d%%)"):format(
                focusInfo.label,
                focusInfo.from,
                focusInfo.unit,
                focusInfo.to,
                focusInfo.unit,
                math.floor(focusInfo.deltaPct * 100 + 0.5)
            ),
            PREVIEW_UP,
            13,
            Enum.Font.GothamMedium
        )
    end
    local radiusMagnitude = self:_isRadiusMagnitude(powerId)
    for _, r in ipairs(rows) do
        local color = r.improved and PREVIEW_UP or PREVIEW_DOWN
        -- Magnet's magnitude IS its reach — say "Range", not the generic "Potency"
        local label = (radiusMagnitude and r.axis == "magnitude") and "Range" or r.label
        local arrow = ("%s → %s"):format(fmtStat(r.from, r.unit), fmtStat(r.to, r.unit))
        local pctText = r.deltaPct and ("  (%+d%%)"):format(math.floor(r.deltaPct * 100 + 0.5))
            or ""
        line(("%s   %s%s"):format(label, arrow, pctText), color, 13, Enum.Font.GothamMedium)
    end
end

function PowerChoiceMenu:_renderEnhanceStrip()
    if self.enhStrip then
        self.enhStrip:Destroy()
        self.enhStrip = nil
    end
    local powerId = self.enhanceFor
    -- the power-list columns hide while the enhance view is open (Jason: "dismiss that
    -- menu until apply/cancel/exit") — hidden GUIs fire no MouseEnter, so the rows'
    -- tooltips can't bleed through the overlay
    local listsVisible = not powerId
    if self.naturalCol then
        self.naturalCol.Visible = listsVisible
    end
    if self.originCol then
        self.originCol.Visible = listsVisible
    end
    if not (powerId and self.frame and self.live) then
        return
    end
    local state = callBus("enh.get", {})
    if not (state and state.ok) then
        self.enhanceFor = nil
        return
    end
    local slots = (state.slots or {})[powerId] or {}
    local def = powersCfg.powers[powerId] or {}

    -- FULL-SIZE enhance view (Jason: "bring up an entirely new full-size menu — then
    -- we've got all sorts of space"). Covers the menu's content area; ✕ returns to the
    -- power lists. Active sinks clicks so nothing underneath can steal them.
    local strip = Instance.new("Frame")
    strip.Name = "EnhanceStrip"
    strip.AnchorPoint = Vector2.new(0.5, 0)
    strip.Position = UDim2.fromScale(0.5, 0.115)
    strip.Size = UDim2.fromScale(0.96, 0.77)
    strip.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
    strip.BorderSizePixel = 0
    strip.Active = true
    strip.ZIndex = 6
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0.02, 0)
    c.Parent = strip
    local st = Instance.new("UIStroke")
    st.Color = Color3.fromRGB(180, 160, 90)
    st.Thickness = 1.5
    st.Parent = strip
    strip.Parent = self.frame
    self.enhStrip = strip

    local filled, total, firstEmpty = 0, 0, nil
    for i, slot in ipairs(slots) do
        if type(slot) == "table" then
            total += 1
            if slot.enh then
                filled += 1
            elseif not firstEmpty then
                firstEmpty = i
            end
        end
    end
    local header = Instance.new("TextLabel")
    header.Size = UDim2.fromScale(0.7, 0.07)
    header.Position = UDim2.fromScale(0.03, 0.02)
    header.BackgroundTransparency = 1
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Font = Enum.Font.GothamBold
    header.TextScaled = true
    header.TextColor3 = Color3.fromRGB(235, 220, 170)
    header.Text = "ENHANCE — "
        .. (def.display_name or powerId)
        .. ("   (%d/%d slots)"):format(filled, total)
        .. ("   \u{1F48E}%d"):format(
            game:GetService("Players").LocalPlayer:GetAttribute("Gems") or 0
        )
    header.ZIndex = 7
    header.Parent = strip

    -- THE standard close X (shared component; the old "✕" glyph tofu-boxed in Gotham —
    -- Jason: "I found that weird page button inside of the powers menu")
    CloseButton.attach(strip, {
        zindex = 7,
        onClick = function()
            self.enhanceFor = nil
            self:_renderEnhanceStrip()
        end,
    })

    -- ===== SLOTS row: big badges, click to target (gold halo), staged ghost =====
    if self._enhTargetPower ~= powerId then
        self._enhTargetPower, self._enhTargetSlot, self._enhStaged = powerId, nil, nil
    end
    local SLOT_W, SLOT_H, SLOT_GAP = 0.085, 0.16, 0.02
    local rowW = total * SLOT_W + math.max(0, total - 1) * SLOT_GAP
    local slotX = 0.5 - rowW / 2
    for i, slot in ipairs(slots) do
        if type(slot) == "table" then
            local hit = Instance.new("TextButton")
            hit.Size = UDim2.fromScale(SLOT_W, SLOT_H)
            hit.Position = UDim2.fromScale(slotX, 0.12)
            hit.BackgroundTransparency = 1
            hit.Text = ""
            hit.ZIndex = 8
            local hc = Instance.new("UICorner")
            hc.CornerRadius = UDim.new(1, 0)
            hc.Parent = hit
            hit.Parent = strip
            if self._enhTargetSlot == i then
                local halo = Instance.new("Frame")
                halo.AnchorPoint = Vector2.new(0.5, 0.5)
                halo.Position = UDim2.fromScale(0.5, 0.5)
                halo.Size = UDim2.fromScale(1.18, 1.18)
                halo.BackgroundTransparency = 1
                halo.ZIndex = 10
                local hcorner = Instance.new("UICorner")
                hcorner.CornerRadius = UDim.new(1, 0)
                hcorner.Parent = halo
                local ring = Instance.new("UIStroke")
                ring.Color = Color3.fromRGB(235, 200, 90)
                ring.Thickness = 3
                ring.Parent = halo
                halo.Parent = hit
            end
            if slot.enh then
                hit.MouseEnter:Connect(function()
                    self:_showEnhTooltip(hit, slot.enh)
                end)
                hit.MouseLeave:Connect(function()
                    self:_hideTooltip()
                end)
            end
            hit.Activated:Connect(function()
                self._enhTargetSlot = (self._enhTargetSlot ~= i) and i or nil -- toggle
                self._enhStaged = nil
                if self._enhTargetSlot and slots[i].enh then
                    self.notice = ("Slot %d targeted — pick an enhancement, then APPLY (replaces the old one)"):format(
                        i
                    )
                elseif self._enhTargetSlot then
                    self.notice = ("Slot %d targeted — pick an enhancement below, then APPLY"):format(
                        i
                    )
                else
                    self.notice = nil
                end
                self:_render()
                self:_renderEnhanceStrip()
            end)
            if slot.enh then
                local dead = Enhancements.levelFactor(enhCfg, slot.enh.level, self.level) == 0
                local b =
                    enhBadge(hit, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), slot.enh, dead)
                b.ZIndex = 9
                -- level label under the slotted badge (Jason: levels clearly labeled)
                if slot.enh.level then
                    local lv = Instance.new("TextLabel")
                    lv.Size = UDim2.fromScale(1, 0.3)
                    lv.Position = UDim2.fromScale(0, 0.88) -- tucked to the icon (Jason)
                    lv.BackgroundTransparency = 1
                    lv.Font = Enum.Font.GothamBold
                    lv.TextScaled = true
                    lv.TextColor3 = levelColor(slot.enh.level, self.level)
                    lv.Text = tostring(slot.enh.level)
                    lv.ZIndex = 9
                    lv.Parent = hit
                end
            else
                local empty = Instance.new("Frame")
                empty.Size = UDim2.fromScale(1, 1)
                empty.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
                empty.BackgroundTransparency = 0.2
                empty.ZIndex = 9
                local ec = Instance.new("UICorner")
                ec.CornerRadius = UDim.new(1, 0)
                ec.Parent = empty
                empty.Parent = hit
            end
            slotX += SLOT_W + SLOT_GAP
        end
    end

    -- ===== AVAILABLE grid: grouped stacks (type+origins+level), dead-filtered =====
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(0.5, 0.05)
    label.Position = UDim2.fromScale(0.03, 0.36)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.GothamMedium
    label.TextScaled = true
    label.TextColor3 = Color3.fromRGB(170, 170, 190)
    label.ZIndex = 7
    label.Parent = strip

    -- group: identical (type, origins, level) stack into one badge with ×N
    local groups, order = {}, {}
    local hidden = 0
    for _, item in ipairs(state.inventory or {}) do
        local okType = Enhancements.compatibleWith(enhCfg, item.type, def, powersCfg.effect_kinds)
        local okSlot = Enhancements.canSlotAtLevel(enhCfg, item.level, self.level)
        -- dead-filter (Jason: "showing ones that are out of range makes no sense")
        local alive = Enhancements.levelFactor(enhCfg, item.level, self.level) > 0
        if okType and item.usable and okSlot and alive then
            local key = tostring(item.type)
                .. "|"
                .. table.concat(item.origins or {}, "+")
                .. "|"
                .. tostring(item.level)
            if not groups[key] then
                groups[key] = { item = item, count = 0, uids = {} }
                order[#order + 1] = key
            end
            -- server stacks now carry a count (quantity); legacy items count as 1
            groups[key].count += (item.count or 1)
            groups[key].uids[#groups[key].uids + 1] = item.uid
        elseif okType and item.usable then
            hidden += 1
        end
    end
    -- BUY offers render in their OWN labeled section below (Jason: don't jumble buy + owned in one
    -- stack). `shop`/`gemBalance` are declared here so the BUY section + click handlers can read them.
    local shop = enhCfg.shop
    local gemBalance = (game:GetService("Players").LocalPlayer:GetAttribute("Gems")) or 0
    -- strongest first (Jason): GRADE is the strength order — single (0.33) > dual (0.20)
    -- > natural (0.15) — then the more potent LEVEL within a grade (above you scales up),
    -- then type for a stable read. This mixes types together, which is fine: a power takes
    -- several enhancement types and you want the biggest gains on top regardless of axis.
    table.sort(order, function(a, b)
        local ia, ib = groups[a].item, groups[b].item
        local va, vb = Enhancements.value(enhCfg, ia), Enhancements.value(enhCfg, ib)
        if va ~= vb then
            return va > vb
        end
        local fa = Enhancements.levelFactor(enhCfg, ia.level, self.level)
        local fb = Enhancements.levelFactor(enhCfg, ib.level, self.level)
        if fa ~= fb then
            return fa > fb
        end
        return tostring(ia.type) < tostring(ib.type)
    end)

    local G_W, G_H, G_GAPX, G_GAPY = 0.075, 0.14, 0.012, 0.05
    local perRow = 10
    local gx0, gy0 = 0.03, 0.43
    local shown = 0
    for gi, key in ipairs(order) do
        local g = groups[key]
        local row = math.floor((gi - 1) / perRow)
        local col = (gi - 1) % perRow
        local gx = gx0 + col * (G_W + G_GAPX)
        local gy = gy0 + row * (G_H + G_GAPY)
        if gy + G_H > 0.74 then -- reserve the bottom band for the separate BUY section
            hidden += (g.count or 0) -- honest overflow (no silent caps)
        else
            shown += 1
            local item = g.item
            local rec = { type = item.type, origins = item.origins }
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.fromScale(G_W, G_H)
            btn.Position = UDim2.fromScale(gx, gy)
            btn.BackgroundTransparency = 1
            btn.Text = ""
            btn.ZIndex = 7
            btn.Parent = strip
            enhBadge(btn, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), rec).ZIndex = 7
            -- the STAGED pick wears the same gold halo as the targeted slot (Jason:
            -- "when I click what I want to fill it with I should also have a circle")
            if self._enhStaged and self._enhStaged.groupKey == key then
                local halo = Instance.new("Frame")
                halo.AnchorPoint = Vector2.new(0.5, 0.5)
                halo.Position = UDim2.fromScale(0.5, 0.5)
                halo.Size = UDim2.fromScale(1.18, 1.18)
                halo.BackgroundTransparency = 1
                halo.ZIndex = 10
                local hcorner = Instance.new("UICorner")
                hcorner.CornerRadius = UDim.new(1, 0)
                hcorner.Parent = halo
                local ring = Instance.new("UIStroke")
                ring.Color = Color3.fromRGB(235, 200, 90)
                ring.Thickness = 3
                ring.Parent = halo
                halo.Parent = btn
            end
            -- level label under the badge (Jason: "Level 7 — just say 7 underneath")
            local lv = Instance.new("TextLabel")
            lv.Size = UDim2.fromScale(1, 0.28)
            lv.Position = UDim2.fromScale(0, 0.9) -- tucked to the icon (Jason)
            lv.BackgroundTransparency = 1
            lv.Font = Enum.Font.GothamBold
            lv.TextScaled = true
            lv.TextColor3 = levelColor(item.level, self.level)
            lv.Text = tostring(item.level or "—")
            lv.ZIndex = 7
            lv.Parent = btn
            -- stack count chip, top-right (Jason: "3x if they're stacked")
            if g.count > 1 then
                local chip = Instance.new("TextLabel")
                chip.AnchorPoint = Vector2.new(1, 0)
                chip.Size = UDim2.fromScale(0.55, 0.34)
                chip.Position = UDim2.fromScale(1.12, -0.12)
                chip.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
                chip.TextColor3 = Color3.fromRGB(235, 220, 170)
                chip.Font = Enum.Font.GothamBold
                chip.TextScaled = true
                chip.Text = "×" .. g.count
                chip.ZIndex = 10
                local cc = Instance.new("UICorner")
                cc.CornerRadius = UDim.new(0.4, 0)
                cc.Parent = chip
                chip.Parent = btn
            end
            btn.MouseEnter:Connect(function()
                self:_showEnhTooltip(
                    btn,
                    { type = item.type, origins = item.origins, level = item.level }
                )
            end)
            btn.MouseLeave:Connect(function()
                self:_hideTooltip()
            end)
            btn.Activated:Connect(function()
                local target = self._enhTargetSlot or firstEmpty
                if not target then
                    self.notice = "No empty slot — click a filled slot to replace it"
                    self:_render()
                    return
                end
                local replacing = slots[target] and slots[target].enh ~= nil
                self._enhStaged =
                    { slotIndex = target, uid = g.uids[1], item = item, groupKey = key }
                self.notice = replacing
                        and ("STAGED for slot %d — APPLY will DESTROY the enhancement currently there"):format(
                            target
                        )
                    or ("STAGED for slot %d — press APPLY to slot"):format(target)
                self:_render()
                self:_renderEnhanceStrip()
            end)
        end
    end
    label.Text = (
        shown > 0 and "AVAILABLE:"
        or (
            hidden > 0 and "No usable enhancements at your level"
            or "No enhancements — find drops!"
        )
    )
        .. (
            (hidden > 0 and shown > 0)
                and ("    +%d more (level range / overflow)"):format(hidden)
            or ""
        )

    -- ===== BUY: gem-priced band naturals in their OWN section (Jason: separate from AVAILABLE) =====
    if shop and shop.enabled then
        local band = EnhancementPricing.bandFor(self.level, shop)
        local exclude = shop.exclude_types or {}
        -- BUY offers across EVERY buyable grade (config: buyable_grades). natural is origin-less;
        -- single/dual carry the player's OWN origin so the bought enhancement is usable + slottable for
        -- them (no origin chosen → skip those grades). Each offer has its own grade price + colour.
        local arch = game:GetService("Players").LocalPlayer:GetAttribute("Archetype")
        local function buyOrigins(grade)
            if grade == "single" then
                return arch and { arch } or nil
            elseif grade == "dual" then
                if not arch then
                    return nil
                end
                for _, o in ipairs(enhCfg.origins or {}) do
                    if o ~= arch then
                        return { arch, o }
                    end
                end
                return { arch }
            end
            return {} -- natural
        end
        local offers = {}
        for _, grade in ipairs(shop.buyable_grades or { "natural" }) do
            local gradeOrigins = buyOrigins(grade)
            if gradeOrigins then
                local gradePrice = EnhancementPricing.buyPrice(grade, band, shop)
                for t in pairs(enhCfg.types or {}) do
                    if
                        not exclude[t]
                        and Enhancements.compatibleWith(enhCfg, t, def, powersCfg.effect_kinds)
                    then
                        offers[#offers + 1] =
                            { type = t, grade = grade, origins = gradeOrigins, price = gradePrice }
                    end
                end
            end
        end
        -- strongest grade first (single 0.33 > dual 0.20 > natural 0.15), then type for a stable read
        table.sort(offers, function(a, b)
            local va = Enhancements.value(enhCfg, { type = a.type, origins = a.origins })
            local vb = Enhancements.value(enhCfg, { type = b.type, origins = b.origins })
            if va ~= vb then
                return va > vb
            end
            return tostring(a.type) < tostring(b.type)
        end)
        if #offers > 0 then
            local buyLabel = Instance.new("TextLabel")
            buyLabel.Size = UDim2.fromScale(0.7, 0.045)
            buyLabel.Position = UDim2.fromScale(0.03, 0.765)
            buyLabel.BackgroundTransparency = 1
            buyLabel.TextXAlignment = Enum.TextXAlignment.Left
            buyLabel.Font = Enum.Font.GothamMedium
            buyLabel.TextScaled = true
            buyLabel.TextColor3 = Color3.fromRGB(190, 140, 255)
            buyLabel.Text = ("BUY — L%d  (natural / dual / single \u{1F48E})"):format(band)
            buyLabel.ZIndex = 7
            buyLabel.Parent = strip
            local byy = 0.82
            for bi, offer in ipairs(offers) do
                local t = offer.type
                local price = offer.price
                local affordable = gemBalance >= price
                local col = (bi - 1) % perRow
                local row = math.floor((bi - 1) / perRow)
                local gx = gx0 + col * (G_W + G_GAPX)
                local gy = byy + row * (G_H + G_GAPY)
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.fromScale(G_W, G_H)
                btn.Position = UDim2.fromScale(gx, gy)
                btn.BackgroundTransparency = 1
                btn.Text = ""
                btn.ZIndex = 7
                btn.Parent = strip
                enhBadge(
                    btn,
                    UDim2.fromScale(1, 1),
                    UDim2.fromScale(0, 0),
                    { type = t, origins = offer.origins }
                ).ZIndex =
                    7
                if
                    self._enhStaged
                    and self._enhStaged.groupKey == ("buy|" .. offer.grade .. "|" .. t)
                then
                    local halo = Instance.new("Frame")
                    halo.AnchorPoint = Vector2.new(0.5, 0.5)
                    halo.Position = UDim2.fromScale(0.5, 0.5)
                    halo.Size = UDim2.fromScale(1.18, 1.18)
                    halo.BackgroundTransparency = 1
                    halo.ZIndex = 10
                    local hcorner = Instance.new("UICorner")
                    hcorner.CornerRadius = UDim.new(1, 0)
                    hcorner.Parent = halo
                    local ring = Instance.new("UIStroke")
                    ring.Color = Color3.fromRGB(235, 200, 90)
                    ring.Thickness = 3
                    ring.Parent = halo
                    halo.Parent = btn
                end
                -- gem price chip UNDERNEATH the icon (Jason: above looked weird); per-item so dual/
                -- single can carry different prices later. Dim the badge when unaffordable.
                local pchip = Instance.new("TextLabel")
                pchip.AnchorPoint = Vector2.new(0.5, 0)
                pchip.Size = UDim2.fromScale(1.15, 0.3)
                pchip.Position = UDim2.fromScale(0.5, 0.92) -- tucked up under the icon (Jason: less gap)
                pchip.BackgroundColor3 = affordable and Color3.fromRGB(58, 46, 78)
                    or Color3.fromRGB(78, 46, 46)
                pchip.TextColor3 = affordable and Color3.fromRGB(200, 150, 255)
                    or Color3.fromRGB(200, 150, 150)
                pchip.Font = Enum.Font.GothamBold
                pchip.TextScaled = true
                pchip.Text = "\u{1F48E}" .. tostring(price)
                pchip.ZIndex = 10
                local pcc = Instance.new("UICorner")
                pcc.CornerRadius = UDim.new(0.4, 0)
                pcc.Parent = pchip
                pchip.Parent = btn
                if not affordable then
                    for _, d in ipairs(btn:GetDescendants()) do
                        if d:IsA("ImageLabel") then
                            d.ImageTransparency = 0.55
                        end
                    end
                end
                btn.MouseEnter:Connect(function()
                    self:_showEnhTooltip(btn, { type = t, origins = offer.origins, level = band })
                end)
                btn.MouseLeave:Connect(function()
                    self:_hideTooltip()
                end)
                btn.Activated:Connect(function()
                    local target = self._enhTargetSlot or firstEmpty
                    if not target then
                        self.notice = "No empty slot — click a filled slot to replace it"
                        self:_render()
                        return
                    end
                    -- STAGE for preview only — the actual purchase happens on APPLY (so you can
                    -- evaluate the result first, and CANCEL costs nothing). needsBuy + price ride along.
                    self._enhStaged = {
                        slotIndex = target,
                        item = { type = t, origins = offer.origins, level = band },
                        groupKey = "buy|" .. offer.grade .. "|" .. t,
                        needsBuy = true,
                        buyType = t,
                        buyGrade = offer.grade,
                        price = price,
                    }
                    self.notice = ("Preview %s L%d — APPLY buys (\u{1F48E}%d) + slots it; CANCEL is free"):format(
                        t,
                        band,
                        price
                    )
                    self:_render()
                    self:_renderEnhanceStrip()
                end)
            end
        end
    end

    -- ===== STAGED: ghost over the destination slot + APPLY / CANCEL =====
    local staged = self._enhStaged
    if staged and staged.item then
        -- live RESULT PREVIEW: what the power becomes once this enhancement is APPLIED
        self:_renderResultPreview(strip, powerId, slots, staged)
        local gxs = (0.5 - rowW / 2) + (staged.slotIndex - 1) * (SLOT_W + SLOT_GAP)
        local ghost = enhBadge(
            strip,
            UDim2.fromScale(SLOT_W, SLOT_H),
            UDim2.fromScale(gxs, 0.12),
            { type = staged.item.type, origins = staged.item.origins }
        )
        ghost.ZIndex = 11
        for _, layer in ipairs(ghost:GetDescendants()) do
            if layer:IsA("ImageLabel") then
                layer.ImageTransparency = 0.45
                layer.ZIndex = 11
            end
        end
        -- the ghost wears the STAGED level (Jason: "I put a 6 in and it still says 5") —
        -- above the old slot label underneath, colored vs the player's level like the rest
        if staged.item.level then
            local lv = Instance.new("TextLabel")
            lv.Size = UDim2.fromScale(1, 0.3)
            lv.Position = UDim2.fromScale(0, 0.88)
            lv.BackgroundTransparency = 1
            lv.Font = Enum.Font.GothamBold
            lv.TextScaled = true
            lv.TextColor3 = levelColor(staged.item.level, self.level)
            lv.Text = tostring(staged.item.level)
            lv.ZIndex = 12
            lv.Parent = ghost
        end
        local applyBtn = Instance.new("TextButton")
        applyBtn.Size = UDim2.fromScale(0.12, 0.08)
        applyBtn.AnchorPoint = Vector2.new(1, 1)
        applyBtn.Position = UDim2.fromScale(0.84, 0.98)
        applyBtn.BackgroundColor3 = Color3.fromRGB(90, 170, 90)
        applyBtn.Text = "✓ APPLY"
        applyBtn.TextScaled = true
        applyBtn.Font = Enum.Font.GothamBold
        applyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        applyBtn.ZIndex = 10
        applyBtn.Parent = strip
        local ac = Instance.new("UICorner")
        ac.CornerRadius = UDim.new(0, 6)
        ac.Parent = applyBtn
        local cancelBtn = applyBtn:Clone()
        cancelBtn.BackgroundColor3 = Color3.fromRGB(120, 70, 70)
        cancelBtn.Text = "CANCEL" -- (was "✕ CANCEL"; the glyph tofu-boxes in Gotham)
        cancelBtn.Position = UDim2.fromScale(0.97, 0.98)
        cancelBtn.Parent = strip
        applyBtn.Activated:Connect(function()
            local uid = staged.uid
            -- A staged BUY isn't purchased until APPLY (so you can evaluate the preview first and
            -- CANCEL costs nothing) — buy it now, then slot the resulting stack.
            if staged.needsBuy then
                local buyRes = callBus("enhancement.shop.buy", {
                    type = staged.buyType,
                    grade = staged.buyGrade, -- natural / dual / single (nil = natural)
                })
                if not (buyRes and buyRes.ok) then
                    self.notice = "Buy failed: " .. tostring(buyRes and buyRes.reason)
                    self:_render()
                    self:_renderEnhanceStrip() -- keep it staged; CANCEL still costs nothing
                    return
                end
                uid = buyRes.uid
            end
            local res = callBus("enh.slot", {
                powerId = powerId,
                slotIndex = staged.slotIndex,
                uid = uid,
            })
            self._enhStaged = nil
            if res and res.ok then
                self._enhTargetSlot = nil
                self.notice = "Applied ✓"
                self:_loadLive()
            else
                self.notice = "Apply failed: " .. tostring(res and res.reason)
            end
            self:_render()
            self:_renderEnhanceStrip()
        end)
        cancelBtn.Activated:Connect(function()
            self._enhStaged = nil
            self.notice = nil
            self:_render()
            self:_renderEnhanceStrip()
        end)
    end
end

function PowerChoiceMenu:_statusText()
    if self.notice then
        return self.notice, Color3.fromRGB(255, 180, 120)
    end
    if self.pendingPower > 0 then
        if self:_remainingPicks() > 0 then
            return "PICK A POWER  —  choose 1", Color3.fromRGB(150, 230, 150)
        end
        return "READY — press COMMIT  (or click another to change)", COMMIT_COLOR
    elseif self.pendingSlots > 0 then
        local rs = self:_remainingSlots()
        if rs > 0 and self:_canPlaceSlot() then
            return ("PLACE A SLOT  (%d of %d left) — click an owned power"):format(
                rs,
                self.pendingSlots
            ),
                Color3.fromRGB(140, 200, 255)
        end
        return "READY — press COMMIT", COMMIT_COLOR
    end
    return "Level Up for your next choice", Color3.fromRGB(200, 200, 210)
end

-- Hover tooltip: derived power description (PowerDescribe — summary from the LIVE numbers).
-- One shared frame per menu; rows show/hide it. Touch taps fire MouseEnter too, so mobile
-- gets the description on the same tap that stages a pick.
function PowerChoiceMenu:_ensureTooltip()
    if self._tooltip and self._tooltip.Parent then
        return self._tooltip
    end
    local tip = Instance.new("Frame")
    tip.Name = "PowerTooltip"
    tip.Size = UDim2.fromOffset(240, 0)
    tip.AutomaticSize = Enum.AutomaticSize.Y
    tip.BackgroundColor3 = Color3.fromRGB(16, 14, 26)
    tip.BackgroundTransparency = 0.05
    tip.Visible = false
    tip.ZIndex = 60
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = tip
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 205, 70)
    stroke.Thickness = 1.5
    stroke.Parent = tip
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = tip
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Vertical
    list.Padding = UDim.new(0, 4)
    list.Parent = tip

    local function label(name, size, color, font)
        local l = Instance.new("TextLabel")
        l.Name = name
        l.BackgroundTransparency = 1
        l.Size = UDim2.new(1, 0, 0, 0)
        l.AutomaticSize = Enum.AutomaticSize.Y
        l.Font = font or Enum.Font.Gotham
        l.TextSize = size
        l.TextColor3 = color
        l.TextWrapped = true
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.ZIndex = 61
        l.Parent = tip
        return l
    end
    label("Title", 14, Color3.fromRGB(255, 205, 70), Enum.Font.GothamBold).LayoutOrder = 1
    label("Summary", 12, Color3.fromRGB(235, 235, 245)).LayoutOrder = 2
    label("Stats", 11, Color3.fromRGB(160, 160, 185)).LayoutOrder = 3
    tip.Parent = self.frame
    self._tooltip = tip
    return tip
end

-- Hover tooltip for an ENHANCEMENT badge in the enhance strip (slotted or available):
-- what it boosts, grade/value, level + window state — intelligent decisions before
-- slotting (Jason). Reuses the row tooltip frame.
function PowerChoiceMenu:_showEnhTooltip(anchor, rec)
    if not (rec and self.frame) then
        return
    end
    local tip = self:_ensureTooltip()
    local natural = Enhancements.isNatural(rec)
    local single = Enhancements.isSingle(rec)
    local grade = natural and "Natural" or (single and "Single origin" or "Dual origin")
    local value = Enhancements.value(enhCfg, rec)
    tip.Title.Text = Enhancements.displayName(enhCfg, rec)
    tip.Summary.Text = ("Boosts %s by %d%%  ·  %s"):format(
        tostring(rec.type or "?"):gsub("^%l", string.upper),
        math.floor(value * 100 + 0.5),
        grade
    )
    local lines = {}
    if rec.level then
        local factor = Enhancements.levelFactor(enhCfg, rec.level, self.level)
        lines[#lines + 1] = ("L%d%s"):format(
            rec.level,
            factor == 0 and "  (OUT OF RANGE — no effect at your level)"
                or (factor ~= 1 and ("  (×%.1f at your level)"):format(factor) or "")
        )
    end
    lines[#lines + 1] = natural and "Usable by anyone" or "Usable by matching origins"
    tip.Stats.Text = table.concat(lines, "   ·   ")
    tip.Stats.Visible = true
    local fa = self.frame.AbsolutePosition
    local aa, asz = anchor.AbsolutePosition, anchor.AbsoluteSize
    tip.Position = UDim2.fromOffset(
        math.clamp(aa.X - fa.X, 0, math.max(0, self.frame.AbsoluteSize.X - 250)),
        math.max(0, aa.Y - fa.Y - 110)
    )
    tip.Visible = true
end

function PowerChoiceMenu:_showTooltip(row, powerId)
    local d = PowerDescribe.describe(powersCfg, powerId)
    if not d or not self.frame then
        return
    end
    local def = powersCfg.powers[powerId] or {}
    local tip = self:_ensureTooltip()
    tip.Title.Text = def.display_name or powerId
    tip.Summary.Text = d.summary
    local statLines = table.clone(d.lines)
    -- which enhancement types this power accepts (same gate the server enforces)
    local enhNames =
        PowerDescribe.compatibleEnhancements(powersCfg, powerId, enhancementsCfg, Enhancements)
    if #enhNames > 0 then
        statLines[#statLines + 1] = "Enhances: " .. table.concat(enhNames, ", ")
    else
        statLines[#statLines + 1] = "Enhances: —"
    end
    tip.Stats.Text = table.concat(statLines, "   ·   ")
    tip.Stats.Visible = #statLines > 0
    -- beside the row, flipped left when the row sits in the menu's right half
    local fa, fs = self.frame.AbsolutePosition, self.frame.AbsoluteSize
    local ra, rs = row.AbsolutePosition, row.AbsoluteSize
    local rightOfRow = ra.X + rs.X - fa.X + 8
    local x = (rightOfRow + 240 <= fs.X) and rightOfRow or (ra.X - fa.X - 248)
    tip.Position = UDim2.fromOffset(x, math.clamp(ra.Y - fa.Y, 0, math.max(0, fs.Y - 120)))
    tip.Visible = true
end

function PowerChoiceMenu:_hideTooltip()
    if self._tooltip then
        self._tooltip.Visible = false
    end
end

function PowerChoiceMenu:_fillColumn(holder, pool)
    for _, child in ipairs(holder:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    if not pool then
        return
    end
    local ownedSet = {}
    for id in pairs(self.owned) do
        ownedSet[id] = true
    end
    local rows = PowerSelection.menuRows(
        pool,
        powersCfg.powers,
        self.level,
        ownedSet,
        powersCfg.selection_levels
    )
    for i, r in ipairs(rows) do
        local def = powersCfg.powers[r.id] or {}
        local stagedPick = self:_isStagedPick(r.id)
        local stagedSlots = self:_stagedSlotsOn(r.id)
        local hasStaged = stagedPick or stagedSlots > 0
        -- a row GLOWS as actionable only while a grant is UNSPENT. (#195: the old
        -- `or pendingPower == 1` radio-swap term kept the green glow on EVERY other available
        -- row after staging a pick — "random rows light up". Swapping stays clickable in
        -- _onRow; we just stop painting the alternatives once the pick is staged.)
        local actionable = (
            r.state == "owned"
            and self:_remainingSlots() > 0
            and self:_effectiveSlots(r.id) < MAX_SLOTS
        )
            or (
                r.state == "available"
                and not stagedPick
                and self.pendingPower > 0
                and self:_remainingPicks() > 0
            )
        local wrap = Instance.new("TextButton")
        wrap.Name = "Row_" .. r.id
        wrap.LayoutOrder = i
        wrap.Size = UDim2.new(0.99, 0, 0, rowPixelHeight())
        wrap.BackgroundTransparency = 1
        wrap.AutoButtonColor = false
        wrap.Text = ""
        wrap.Parent = holder
        wrap.Activated:Connect(function()
            self:_onRow(r.id)
        end)
        wrap.MouseEnter:Connect(function()
            self:_showTooltip(wrap, r.id)
        end)
        wrap.MouseLeave:Connect(function()
            self:_hideTooltip()
        end)
        local contents
        for i, slot in ipairs((self.enhSlots or {})[r.id] or {}) do
            if type(slot) == "table" and slot.enh then
                contents = contents or {}
                contents[i] = {
                    record = slot.enh,
                    dead = Enhancements.levelFactor(enhCfg, slot.enh.level, self.level) == 0,
                }
            end
        end
        PowerSlotRow.create(wrap, {
            powerId = r.id,
            name = def.display_name or r.id,
            -- the type line is DECISION-time info (Jason: "they don't need to know
            -- what it is after they've already selected it") — owned rows drop it
            -- and give the space to the slotted-enhancement discs
            subtitle = r.state ~= "owned"
                    and ("L" .. tostring(r.pickLevel) .. " · " .. (def.subtitle or ""))
                or nil,
            state = r.state,
            slotCount = self:_effectiveSlots(r.id),
            slotContents = contents,
            selected = stagedPick,
            size = UDim2.fromScale(1, 1),
            rowPx = rowPixelHeight(),
        })
        -- glow: gold = staged (unsaved); green/blue = actionable this beat
        local glowColor
        if hasStaged then
            glowColor = STAGED_GLOW
        elseif actionable then
            glowColor = (r.state == "owned") and Color3.fromRGB(140, 200, 255)
                or Color3.fromRGB(150, 230, 150)
        end
        if glowColor then
            local glow = Instance.new("UIStroke")
            glow.Color = glowColor
            glow.Thickness = hasStaged and 2.5 or 2
            glow.Transparency = hasStaged and 0 or 0.15
            local bar = wrap:FindFirstChild("PowerRow") and wrap.PowerRow:FindFirstChild("Bar")
            if bar then
                glow.Parent = bar
            end
        end
    end
end

-- Choose an origin (live mode, no origin yet). One-time server pick; unlocks the origin powers.
function PowerChoiceMenu:_chooseOrigin(origin)
    if not self.live then
        return
    end
    local res = callBus("archetype.select", { archetype = origin })
    self.notice = (res and res.ok == false) and ("Origin pick failed: " .. tostring(res.reason))
        or nil
    self:_loadLive()
    self:_render()
end

-- Render the ORIGIN column as a CHOOSER (4 origin cards) — or a locked note before L5.
function PowerChoiceMenu:_fillOriginChooser(holder)
    for _, child in ipairs(holder:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    if self.level < ORIGIN_CHOICE_LEVEL then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.fromScale(0.95, 0.12)
        lbl.BackgroundTransparency = 1
        lbl.Text = "Choose your Origin at Level " .. ORIGIN_CHOICE_LEVEL
        lbl.TextColor3 = Color3.fromRGB(170, 170, 185)
        lbl.TextWrapped = true
        lbl.TextScaled = true
        lbl.Font = Enum.Font.GothamMedium
        lbl.Parent = holder
        return
    end
    for i, origin in ipairs(ORIGINS) do
        local def = archetypesCfg.archetypes and archetypesCfg.archetypes[origin]
        local card = Instance.new("TextButton")
        card.Name = "Origin_" .. origin
        card.LayoutOrder = i
        card.Size = UDim2.fromScale(0.95, 0.14)
        card.BackgroundColor3 = Color3.fromRGB(40, 38, 52)
        card.AutoButtonColor = true
        card.Text = (def and def.display_name or origin):upper()
        card.TextColor3 = ORIGIN_COLOR[origin] or Color3.new(1, 1, 1)
        card.TextScaled = true
        card.Font = Enum.Font.GothamBold
        card.Parent = holder
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0.03, 0)
        pad.PaddingBottom = UDim.new(0.03, 0)
        pad.Parent = card
        local cc = Instance.new("UICorner")
        cc.CornerRadius = UDim.new(0.25, 0)
        cc.Parent = card
        local cs = Instance.new("UIStroke")
        cs.Color = ORIGIN_COLOR[origin] or Color3.new(1, 1, 1)
        cs.Thickness = 2
        cs.Transparency = 0.25
        cs.Parent = card
        card.Activated:Connect(function()
            self:_chooseOrigin(origin)
        end)
    end
end

function PowerChoiceMenu:_refreshOrigin()
    if self.live and not self.archetype then
        -- no origin yet: the ORIGIN column is a chooser (at L5+) or a locked note (before L5)
        if self.originHeader then
            local ready = self.level >= ORIGIN_CHOICE_LEVEL
            self.originHeader.Text = ready and "CHOOSE ORIGIN"
                or ("ORIGIN — L" .. ORIGIN_CHOICE_LEVEL)
            self.originHeader.TextColor3 = ready and Color3.fromRGB(235, 230, 250)
                or Color3.fromRGB(170, 170, 185)
        end
        if self.originCol then
            self:_fillOriginChooser(self.originCol)
        end
        return
    end
    local origin = self.live and self.archetype or ORIGINS[self.originIndex]
    local def = archetypesCfg.archetypes and archetypesCfg.archetypes[origin]
    if self.originHeader then
        local name = (def and def.display_name or tostring(origin)):upper()
        self.originHeader.Text = self.live and name or ("‹ " .. name .. " ›")
        self.originHeader.TextColor3 = ORIGIN_COLOR[origin] or Color3.new(1, 1, 1)
    end
    if self.originCol then
        self:_fillColumn(self.originCol, def and def.power_pool)
    end
end

local function setChipEnabled(btn, on)
    if not btn then
        return
    end
    btn.Active = on
    btn.AutoButtonColor = on
    -- Dim the whole pill (fill + stroke + child label) when the action isn't available — the
    -- semi-transparent "can't choose yet" state (Jason).
    btn.BackgroundTransparency = on and 0 or 0.55
    local label = btn:FindFirstChild("Label")
    if label then
        label.TextTransparency = on and 0 or 0.5
    end
    local stroke = btn:FindFirstChildOfClass("UIStroke")
    if stroke then
        stroke.Transparency = on and 0 or 0.55
    end
end

function PowerChoiceMenu:_render()
    self:_hideTooltip()
    if self.naturalCol then
        self:_fillColumn(self.naturalCol, archetypesCfg.generic_pool)
    end
    self:_refreshOrigin()
    if self.statusLabel then
        local txt, col = self:_statusText()
        self.statusLabel.Text = txt
        self.statusLabel.TextColor3 = col
    end
    if self.levelBtn then
        -- DEV-only button (hidden for players below). In live mode it BANKS a level (so the next
        -- one previews); in local-preview mode it advances the fake level. Enabled unless at max.
        local atMax = self.atMax or (self.claimedLevel or self.level) >= MAX_LEVEL
        self.levelBtn.Text = atMax and ("MAX (L" .. MAX_LEVEL .. ")") or "LEVEL UP  ▶  (BANK)"
        setChipEnabled(self.levelBtn, not atMax)
    end
    setChipEnabled(self.commitBtn, self:_canCommit())
    setChipEnabled(self.undoBtn, #self.staged > 0)

    -- DEV-only controls: LEVEL UP (self-pacer) + RESET. A player resolves the pick they came for
    -- (UNDO + COMMIT) and levels up at the altar — so for them, hide those two and re-center the
    -- pair. Tracks the live ADMIN toggle.
    local dev = devMode()
    if self.levelBtn then
        self.levelBtn.Visible = dev
    end
    if self.resetBtn then
        self.resetBtn.Visible = dev
    end
    if self.undoBtn then
        self.undoBtn.Position = dev and UDim2.fromScale(0.12, 0.965) or UDim2.fromScale(0.34, 0.965)
    end
    if self.commitBtn then
        self.commitBtn.Position = dev and UDim2.fromScale(0.36, 0.965)
            or UDim2.fromScale(0.62, 0.965)
    end
end

-- ---- build ---------------------------------------------------------------

-- SCROLLING columns with PIXEL-height rows (Jason, iPhone playtest: "what was not
-- readable was the power selection"). Rows were 7.5%-of-column tall — ~20px on a
-- phone, ant-sized text. Now rows get a readable pixel floor and the column scrolls
-- when they don't fit; desktop computes above the floor, so it looks unchanged.
local function makeColumnHolder(parent, xScale)
    local f = Instance.new("ScrollingFrame")
    f.Size = UDim2.fromScale(0.46, 0.815)
    f.Position = UDim2.fromScale(xScale, 0.138)
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.ScrollBarThickness = 6
    f.ScrollBarImageColor3 = Color3.fromRGB(180, 160, 90)
    f.CanvasSize = UDim2.new()
    f.AutomaticCanvasSize = Enum.AutomaticSize.Y
    f.ScrollingDirection = Enum.ScrollingDirection.Y
    f.Parent = parent
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 3)
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = f
    return f
end

local function chip(parent, text, size, pos, color, order)
    -- THE shared currency-HUD capsule (Pill.button): rounded + gradient + stroke + child label.
    local b, label = Pill.button({
        parent = parent,
        color = color,
        size = size,
        position = pos,
        anchorPoint = Vector2.new(0.5, 0.5),
        text = text,
        textColor = Color3.fromRGB(20, 20, 28),
        zIndex = 140, -- above the 130 panel pill border
    })
    b.LayoutOrder = order or 0
    label.TextScaled = true
    return b
end

function PowerChoiceMenu:Show(parent)
    -- the menu (and its tooltips) must paint ABOVE the HUD — the quest tracker was
    -- covering the enhance hover (Jason: "this menu should be top level"). Raise the
    -- hosting ScreenGui while we're shown; restore on Hide.
    do
        local gui = parent
        while gui and not gui:IsA("ScreenGui") do
            gui = gui.Parent
        end
        if gui and gui:IsA("ScreenGui") then
            self._hostGui, self._hostOrder = gui, gui.DisplayOrder
            -- above the PlayerBar gui (DisplayOrder 80), which hosts the quest
            -- tracker capsule that was covering the enhance tooltips
            gui.DisplayOrder = 100
        end
    end
    local root = Instance.new("Frame")
    root.Name = "PowerChoiceMenu"
    root.Size = UDim2.fromScale(0.5, 0.92)
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    root.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    root.BorderSizePixel = 0
    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0.02, 0)
    rc.Parent = root
    -- Standard game pill border (area-themed, same size/style as the other panels) — replaces the
    -- thin gray stroke. Jason: "needs a pill in the same style as the other pills."
    PanelChrome.pillBorder(root, PanelChrome.areaPill(), 130, 0, 0.07) -- match the shared shell
    self.frame = root

    local title = Instance.new("TextLabel")
    title.Size = UDim2.fromScale(0.6, 0.05)
    title.Position = UDim2.fromScale(0.2, 0.012)
    title.BackgroundTransparency = 1
    title.Text = "POWER CHOICE"
    title.TextColor3 = Color3.fromRGB(235, 230, 250)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = root

    -- status line (what to do this beat)
    local status = Instance.new("TextLabel")
    status.Size = UDim2.fromScale(0.8, 0.03)
    status.Position = UDim2.fromScale(0.5, 0.062)
    status.AnchorPoint = Vector2.new(0.5, 0)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.TextScaled = true
    status.Font = Enum.Font.GothamMedium
    status.Parent = root
    self.statusLabel = status

    -- close — THE standard X (shared component). This was Jason's "weird page button":
    -- a maroon circle whose "✕" glyph has no Gotham glyph, rendering as the tofu box.
    CloseButton.attach(root, {
        zindex = 146, -- above the 130 panel pill border
        onClick = function()
            if _G.MenuManager then
                _G.MenuManager:CloseCurrentPanel()
            end
        end,
    })

    -- headers
    local nHeader = Instance.new("TextLabel")
    nHeader.Size = UDim2.fromScale(0.46, 0.036)
    nHeader.Position = UDim2.fromScale(0.02, 0.094)
    nHeader.BackgroundTransparency = 1
    nHeader.Text = "NATURAL"
    nHeader.TextColor3 = NATURAL_COLOR
    nHeader.TextScaled = true
    nHeader.Font = Enum.Font.GothamBold
    nHeader.Parent = root

    local oHeader = Instance.new("TextButton")
    oHeader.Size = UDim2.fromScale(0.46, 0.036)
    oHeader.Position = UDim2.fromScale(0.52, 0.094)
    oHeader.BackgroundColor3 = Color3.fromRGB(46, 43, 60)
    oHeader.BackgroundTransparency = 0.35
    oHeader.AutoButtonColor = true
    oHeader.Text = ""
    oHeader.TextScaled = true
    oHeader.Font = Enum.Font.GothamBold
    oHeader.Parent = root
    local ohc = Instance.new("UICorner")
    ohc.CornerRadius = UDim.new(0.35, 0)
    ohc.Parent = oHeader
    local ohs = Instance.new("UIStroke")
    ohs.Color = Color3.fromRGB(120, 110, 150)
    ohs.Thickness = 1.5
    ohs.Parent = oHeader
    self.originHeader = oHeader
    oHeader.Activated:Connect(function()
        if self.live then
            return -- origin is locked to your real archetype in live mode
        end
        self.originIndex = (self.originIndex % #ORIGINS) + 1
        self:_reset() -- a new origin = a fresh run from L1
        self:_render()
    end)

    -- columns + divider
    self.naturalCol = makeColumnHolder(root, 0.02)
    self.originCol = makeColumnHolder(root, 0.52)
    local div = Instance.new("Frame")
    div.Size = UDim2.fromScale(0.0025, 0.78)
    div.Position = UDim2.fromScale(0.5, 0.55)
    div.AnchorPoint = Vector2.new(0.5, 0.5)
    div.BackgroundColor3 = Color3.fromRGB(120, 110, 80)
    div.BorderSizePixel = 0
    div.Parent = root

    -- bottom controls: ↶ UNDO · ✓ COMMIT · LEVEL UP ▶ · ↺ RESET
    self.undoBtn = chip(
        root,
        "↶ UNDO",
        UDim2.fromScale(0.17, 0.05),
        UDim2.fromScale(0.12, 0.965),
        UNDO_COLOR,
        1
    )
    self.undoBtn.Activated:Connect(function()
        self:_undo()
    end)

    self.commitBtn = chip(
        root,
        "✓ COMMIT",
        UDim2.fromScale(0.24, 0.055),
        UDim2.fromScale(0.36, 0.965),
        COMMIT_COLOR,
        2
    )
    self.commitBtn.Activated:Connect(function()
        self:_commit()
    end)

    self.levelBtn = chip(
        root,
        "LEVEL UP  ▶",
        UDim2.fromScale(0.24, 0.055),
        UDim2.fromScale(0.64, 0.965),
        LEVEL_COLOR,
        3
    )
    self.levelBtn.Activated:Connect(function()
        self:_levelUp()
    end)

    self.resetBtn = chip(
        root,
        "↺ RESET",
        UDim2.fromScale(0.15, 0.05),
        UDim2.fromScale(0.88, 0.965),
        RESET_COLOR,
        4
    )
    self.resetBtn.Activated:Connect(function()
        self:_resetRun()
    end)

    -- The menu owns the level-up claim UX while open — suppress the old LevelUpController reveal
    -- modal so they don't fight over LevelUp_Claimed.
    _G.PowerChoiceMenuOpen = true
    self:_initState()
    self:_render()
    root.Parent = parent
end

function PowerChoiceMenu:Hide()
    if self._hostGui then
        self._hostGui.DisplayOrder = self._hostOrder or 0
        self._hostGui = nil
    end
    self.enhanceFor = nil
    if self.enhStrip then
        self.enhStrip:Destroy()
        self.enhStrip = nil
    end
    _G.PowerChoiceMenuOpen = false
    if self.frame then
        self.frame:Destroy()
        self.frame = nil
    end
    self.naturalCol = nil
    self.originCol = nil
    self.originHeader = nil
    self.statusLabel = nil
    self.levelBtn = nil
    self.commitBtn = nil
    self.undoBtn = nil
    self.resetBtn = nil
end

function PowerChoiceMenu:GetFrame()
    return self.frame
end

return PowerChoiceMenu
