--[[
    StatusBadges — the shared buff/debuff badge engine for HudCard strips.

    Pets (SquadHud) and enemies (EnemyHud) are the same model at the data layer: both carry
    `*FxUntil` / `*Until` attributes the server stamps, and both ride identical HudCard chrome with
    a `status` frame anchored at the card's inner edge (grows toward screen centre — "out to the
    left"). The only thing that ever differed was this renderer, which used to live privately in
    SquadHud hardcoded to its pet effects. Extracted here so both strips drive the SAME badge code
    off their own descriptor table (PET_EFFECTS vs ENEMY_EFFECTS) — a buffed pet and a healed enemy
    light up through one path. (Jason: "there's not a lot of difference between pets and enemies —
    they're little expert systems on the same model.")

    A descriptor entry (one per buff/debuff KIND):
      key         — stable id (badge identity; same-kind instances pile + show xN)
      source      — which model carries the attribute; resolved via the `sources` map the caller
                    passes (pets: {pet=, player=}; enemies: {enemy=}).
      untilAttr   — attribute holding the os.time() expiry; the badge shows while expiry > now.
      poolAttr    — (alt to untilAttr) a magnitude attribute; shows the number while > 0.
      powerIdAttr — (optional) attribute holding the power id that applied this buff; when set the
                    badge resolves THAT power's element disc + tinted ring (matches the hotbar /
                    world icon). Falls back to the static `icon` when absent.
      stacksAttr  — (optional) # of same-kind sources folded into this buff (pile + xN).
      icon        — static disc image (fallback when no powerIdAttr disc resolves). "" = label chip.
      color/label — chip colour + short text (shown when there's no icon).
      pulse       — instant/flash effect: no countdown (blinks for its FX window).
      steady      — continuously-refreshed aura: SOLID, no countdown, never blinks, holds a fixed
                    slot by descriptor order (no refresh jitter).

    API:
      resolveEffects(EFFECTS, sources, now) -> effects[]   (pure read off attributes)
      update(card, effects, blinkLead)                     (reconcile badges into card.status)
      applyBlink(cards, blinkPeriod)                        (per-frame expiry flash for all cards)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local POWER_ICONS = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("power_icons"))
local PetBadge = require(script.Parent.PetBadge)

local StatusBadges = {}

-- DEV GUARD (Jason): dedupe so a misconfigured badge warns ONCE per descriptor key per session
-- (see the warn in resolveEffects) instead of every 0.2s reconcile.
local warnedBadge = {}

-- One badge cell. Same dimensions for every strip so pet + enemy rows read identically.
local BADGE_PX = 30
local BADGE_GAP = 3
StatusBadges.BADGE_PX = BADGE_PX

-- Read a descriptor table against the live attributes and return the active effects. `sources`
-- maps a descriptor's `source` ("pet"/"player"/"enemy") to the Instance that carries its attrs.
function StatusBadges.resolveEffects(EFFECTS, sources, now)
    local out = {}
    for idx, e in ipairs(EFFECTS) do
        local src = sources[e.source]
        if src then
            -- Resolve the FULL badge (element disc + tinted ring) from the POWER that applied this
            -- buff so it matches the hotbar / role badge / world shield; fall back to the static
            -- icon (no ring) when nothing tagged it.
            local icon = e.icon
            local ringImg, ringColor
            local pid
            if e.powerIdAttr then
                pid = src:GetAttribute(e.powerIdAttr)
                local badge = PetBadge.forPower(pid)
                local disc = badge and POWER_ICONS.discFor(badge.element, badge.symbol)
                if disc then
                    icon = disc
                    ringImg = POWER_ICONS.rings[badge.ring] or POWER_ICONS.rings.aura
                    ringColor = POWER_ICONS.elementColor3(badge.element, "dark")
                end
            end
            -- Static ring: a descriptor can declare `ringElement` (+ optional `ringShape`) so even a
            -- non-power-tagged status badge (enemy heal/held/hex) gets the standard tinted ring —
            -- no more ringless discs. Power-resolved rings above win when present.
            if not ringImg and e.ringElement then
                ringImg = POWER_ICONS.rings[e.ringShape or "aura"] or POWER_ICONS.rings.aura
                ringColor = POWER_ICONS.elementColor3(e.ringElement, "dark")
            end
            -- DEV GUARD (Jason): the instant a badge actually FIRES with no resolved disc — and it
            -- isn't a deliberate text chip (`labelOnly`) — warn ONCE naming the descriptor + power id.
            -- An unwired descriptor (missing powerIdAttr, like the old enemy "hex") or a missing/bad
            -- badge asset is caught immediately in the console instead of silently drawing a
            -- placeholder. Skips the powerId-lag frame (pid stamped a frame after the until attr).
            local firing = (e.untilAttr and (src:GetAttribute(e.untilAttr) or 0) > now)
                or (e.poolAttr and (src:GetAttribute(e.poolAttr) or 0) > 0)
            if
                firing
                and not e.labelOnly
                and not (icon and icon ~= "")
                and not warnedBadge[e.key]
                and not (e.powerIdAttr and (pid == nil or pid == "")) -- not just a replication-lag frame
            then
                warnedBadge[e.key] = true
                warn(
                    string.format(
                        "[StatusBadges] badge '%s' fired with NO icon disc — %s. Fix: set the descriptor's powerIdAttr, give it a static icon, or mark labelOnly=true.",
                        tostring(e.key),
                        e.powerIdAttr
                                and string.format(
                                    "powerIdAttr='%s' powerId='%s' did not resolve (PetBadge.forPower/discFor returned nil — missing symbol map or asset)",
                                    tostring(e.powerIdAttr),
                                    tostring(pid)
                                )
                            or "descriptor has no powerIdAttr and no static icon"
                    )
                )
            end
            if e.untilAttr then
                local until_ = src:GetAttribute(e.untilAttr) or 0
                if until_ > now then
                    out[#out + 1] = {
                        key = e.key,
                        color = e.color,
                        label = e.label,
                        -- Pulse/steady effects show no countdown; timed buffs do.
                        timer = (e.pulse or e.steady) and "" or (math.ceil(until_ - now) .. "s"),
                        icon = icon,
                        ringImg = ringImg,
                        ringColor = ringColor,
                        steady = e.steady, -- steady buffs never blink (continuously refreshed = permanent)
                        remaining = until_ - now, -- seconds left (drives the expiry blink)
                        order = idx, -- stable descriptor position (steady badges sort by this, not time)
                        -- # of same-kind sources stacked into this buff (e.g. 3 lava pets -> ATK x3) so the
                        -- card can pile the badge + show "xN" (same buff stacks; different ones stay separate).
                        stacks = e.stacksAttr and (src:GetAttribute(e.stacksAttr) or 1) or nil,
                    }
                end
            elseif e.poolAttr then
                local v = src:GetAttribute(e.poolAttr) or 0
                if v > 0 then
                    out[#out + 1] = {
                        key = e.key,
                        color = e.color,
                        label = e.label,
                        timer = tostring(math.floor(v)),
                        icon = icon,
                        ringImg = ringImg,
                        ringColor = ringColor,
                        order = idx,
                    }
                end
            end
        end
    end
    return out
end

-- A small status badge — one per buff INSTANCE (duplicates included). Positioned manually by
-- update() so same-kind instances overlap by half (a coin-stack); each blinks on its own timer.
local function makeBadge(parent)
    local f = Instance.new("Frame")
    f.Size = UDim2.fromOffset(BADGE_PX, BADGE_PX)
    f.BorderSizePixel = 0
    f.ClipsDescendants = true -- crop the icon's zoomed-out transparent border
    f.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = f
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.BackgroundTransparency = 1
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Size = UDim2.fromScale(1, 1) -- zoom set per-icon in update
    icon.Image = ""
    icon.Parent = f
    -- Tinted element ring framing the disc (power-applied buffs only; hidden otherwise).
    local ring = Instance.new("ImageLabel")
    ring.Name = "Ring"
    ring.BackgroundTransparency = 1
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.fromScale(0.5, 0.5)
    ring.Size = UDim2.fromScale(1, 1)
    ring.ScaleType = Enum.ScaleType.Fit
    ring.Image = ""
    ring.Visible = false
    ring.Parent = f
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0.6, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 9
    label.TextColor3 = Color3.fromRGB(20, 22, 28)
    label.Parent = f
    local timer = Instance.new("TextLabel")
    timer.Name = "Timer"
    timer.BackgroundTransparency = 1
    timer.Position = UDim2.fromScale(0, 0.55)
    timer.Size = UDim2.new(1, 0, 0.45, 0)
    timer.Font = Enum.Font.GothamBold
    timer.TextSize = 9
    timer.TextColor3 = Color3.fromRGB(20, 22, 28)
    timer.Parent = f
    return { frame = f, icon = icon, ring = ring, label = label, timer = timer }
end

-- Under the GUI's Sibling ZIndexBehavior, a badge frame's ZIndex governs the whole badge vs its
-- sibling badges (descendants keep their own intra-badge order). A more-urgent (later) instance
-- gets a higher ZIndex so it draws OVER the coin it overlaps — its blink stays visible on top.

-- Reconcile a card's badges against its active effects. Ordered so the SHORTEST remaining sits
-- leftmost (toward screen centre, most urgent): the row grows left under HorizontalAlignment.Right,
-- so a higher LayoutOrder = further left. The blink loop owns live transparency (badges are never
-- hidden/destroyed mid-blink, so the row never shifts).
function StatusBadges.update(card, effects, blinkLead)
    card.badges = card.badges or {} -- lazily owned per card (pet slot card or enemy bid card)
    -- ONE badge per buff INSTANCE (duplicates included): N lava buffers -> N ATK badges; the renderer
    -- is per-instance so distinct-expiry sources blink independently — only the coin within blinkLead
    -- of dropping flashes, not the whole stack.
    local instances = {}
    for _, eff in ipairs(effects) do
        local n = math.max(1, math.floor(eff.stacks or 1))
        for k = 1, n do
            instances[#instances + 1] = { eff = eff, k = k }
        end
    end
    -- Order: TIMED by shortest-remaining toward the centre EDGE (most urgent leftmost); STEADY auras
    -- hold a fixed slot by descriptor index (no refresh jitter). Same-kind instances end up adjacent.
    table.sort(instances, function(a, b)
        local ae, be = a.eff, b.eff
        local aSteady, bSteady = ae.steady or false, be.steady or false
        if aSteady ~= bSteady then
            return bSteady -- timed first -> leftmost edge
        end
        if aSteady then
            if (ae.order or 0) ~= (be.order or 0) then
                return (ae.order or 0) < (be.order or 0)
            end
            return a.k < b.k
        end
        if (ae.remaining or math.huge) ~= (be.remaining or math.huge) then
            return (ae.remaining or math.huge) > (be.remaining or math.huge) -- shortest -> leftmost
        end
        return a.k < b.k
    end)

    local seen = {}
    -- Position manually: adjacent DUPLICATES (same kind) overlap by HALF a badge (a coin-stack);
    -- different kinds get the normal gap. Lay out right(least urgent)->left(most urgent); the row is
    -- anchored at the card's inner edge and grows toward screen centre.
    local OVERLAP = math.floor(BADGE_PX / 2)
    local rightX = 0
    for i, inst in ipairs(instances) do
        local eff = inst.eff
        local id = eff.key .. "#" .. inst.k
        seen[id] = true
        local b = card.badges[id]
        if not b then
            b = makeBadge(card.status)
            b.frame.Name = id
            card.badges[id] = b
        end
        -- per-INSTANCE blink: only THIS coin flashes when IT is within blinkLead of expiry.
        b.blinking = not eff.steady and eff.remaining ~= nil and eff.remaining <= (blinkLead or 0)
        local hasIcon = eff.icon and eff.icon ~= ""
        b.frame.BackgroundColor3 = eff.color
        b.bgBase = hasIcon and 1 or 0 -- icon badges: transparent backing (no square chip behind the disc)
        b.label.Text = hasIcon and "" or eff.label
        b.icon.Image = eff.icon or ""
        if eff.ringImg then
            b.ring.Image = eff.ringImg
            b.ring.ImageColor3 = eff.ringColor or Color3.fromRGB(70, 76, 96)
            b.ring.Visible = true
            b.icon.Size = UDim2.fromScale(0.72, 0.72)
        else
            b.ring.Visible = false
            if hasIcon then
                local s = POWER_ICONS.scaleFor(eff.icon) -- zoom past the art's transparent border
                b.icon.Size = UDim2.fromScale(s, s)
            end
        end
        -- Only the FRONT (most-urgent) coin of a same-kind stack prints the countdown, so the pile
        -- doesn't stamp the same number on every coin underneath.
        local nextInst = instances[i + 1]
        local frontOfStack = not (nextInst and nextInst.eff.key == eff.key)
        b.timer.Text = (frontOfStack and eff.timer) or ""
        -- advance the right-edge offset: overlap-by-half when this instance duplicates the previous.
        local prev = instances[i - 1]
        if prev then
            rightX = rightX + ((prev.eff.key == eff.key) and OVERLAP or (BADGE_PX + BADGE_GAP))
        end
        -- Grow toward screen centre: default right-rail cards anchor at their right edge and step
        -- LEFT; left-rail cards (card.badgeSide=="right") anchor at their left edge and step RIGHT.
        if card.badgeSide == "right" then
            b.frame.AnchorPoint = Vector2.new(0, 0.5)
            b.frame.Position = UDim2.new(0, rightX, 0.5, 0)
        else
            b.frame.AnchorPoint = Vector2.new(1, 0.5)
            b.frame.Position = UDim2.new(1, -rightX, 0.5, 0)
        end
        b.frame.ZIndex = 2 + i -- later = more urgent (leftmost) = on top, so its blink shows
    end
    card.status.Size = UDim2.fromOffset(rightX + BADGE_PX, BADGE_PX)
    for key, b in pairs(card.badges) do
        if not seen[key] then
            b.frame:Destroy()
            card.badges[key] = nil
        end
    end
end

-- Expiry blink for a whole strip of cards. Call every frame (not on the reconcile tick) so the
-- flash is smooth. Blinks via TRANSPARENCY (not Visible) so each badge keeps its layout slot — the
-- row doesn't re-pack/shift each blink. Only badges flagged `blinking` (within blinkLead of expiry)
-- fade. `cards` is any map of card refs that carry a `.badges` table (slot->card or bid->card).
function StatusBadges.applyBlink(cards, blinkPeriod)
    local on = (os.clock() % blinkPeriod) < (blinkPeriod * 0.5)
    for _, card in pairs(cards) do
        if card.badges then
            for _, b in pairs(card.badges) do
                local hidden = b.blinking and not on
                b.icon.ImageTransparency = hidden and 1 or 0
                b.ring.ImageTransparency = hidden and 1 or 0
                b.label.TextTransparency = hidden and 1 or 0
                b.timer.TextTransparency = hidden and 1 or 0
                b.frame.BackgroundTransparency = hidden and 1 or (b.bgBase or 0)
            end
        end
    end
end

return StatusBadges
