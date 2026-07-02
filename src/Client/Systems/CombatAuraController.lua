--[[
    CombatAuraController — reactive combat VFX for Halo & Horns.

    PowerService sets combat attributes server-side; this client controller watches them and
    attaches the matching CombatFX so powers READ on the battlefield, not just in the numbers:

      pet  CombatShield > 0      -> element force-field BUBBLE only (no reskin)           [absorb/shield]
      pet  DefenseBuffUntil      -> element material RESKIN only (no bubble)              [defense_buff/armor]
      pet  HealFxUntil           -> heal aura for the remaining duration                 [heal]
      player PetDamageBuffUntil  -> damage buff aura on every owned pet                   [buff]
      enemy VulnerableUntil      -> debuff aura while vulnerable                          [vulnerable]
      enemy RootedUntil          -> debuff aura while rooted                              [root]

    Each pet's element comes from CombatOrigin (the same resolution the attack VFX uses): element
    from PetType, unified to the owner's archetype when origin.unify_to_player is set. The shield's
    armor reskin is element-themed via origin.element_reskin. Enemy debuffs use the caster's
    element (player archetype) so the wither reads in the player's theme.

    The *Until attributes are absolute os.time() stamps set once and expiring silently, so each is
    attached with duration = until - now and the effect self-expires; a re-cast (attribute change)
    restarts it. CombatShield is a depleting magnitude: the bubble persists (duration 0) while it's
    above zero and pops when it reaches zero.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CombatFX = require(ReplicatedStorage.Shared.Effects.CombatFX)
local CombatOrigin = require(ReplicatedStorage.Shared.Game.CombatOrigin)
local PowerIcons = require(ReplicatedStorage.Configs:WaitForChild("power_icons"))
local PetBadge = require(script.Parent.Parent.UI.PetBadge)
local PowerBadges = require(script.Parent.Parent.UI.PowerBadges) -- the badge SSOT reader (one path)

local CombatAuraController = {}

local localPlayer = Players.LocalPlayer
local started = false

-- per Instance -> { slot -> handle }; per Instance -> { connections } for cleanup.
local handles = setmetatable({}, { __mode = "k" })
local conns = setmetatable({}, { __mode = "k" })
local armorIcons = setmetatable({}, { __mode = "k" }) -- pet -> BillboardGui (shield icon while armored)
local armorTokens = setmetatable({}, { __mode = "k" }) -- pet -> token, for the badge self-expire
local armorTok = 0

-- A gold shield badge that floats over an armored pet, so "this pet has armor" reads at a glance.
local function showArmorIcon(pet)
    if armorIcons[pet] and armorIcons[pet].Parent then
        return
    end
    local pp = pet.PrimaryPart or pet:FindFirstChildWhichIsA("BasePart")
    if not pp then
        return
    end
    local up = 4
    local okE, ext = pcall(function()
        return pet:GetExtentsSize()
    end)
    if okE and ext then
        up = ext.Y * 0.5 + 2
    end
    local bb = Instance.new("BillboardGui")
    bb.Name = "ArmorIcon"
    bb.AlwaysOnTop = true
    bb.Size = UDim2.fromOffset(34, 34)
    bb.StudsOffset = Vector3.new(0, up, 0)
    bb.Adornee = pp
    -- The FULL badge the hotbar + squad card use (element disc + tinted ring) for the power that
    -- applied the shield, so it matches everywhere. Falls back to a generic gold shield disc (no
    -- ring) when nothing tagged it.
    -- shield powers stamp CombatShieldPowerId; armor/hardening powers (Stone Skin, Ice Armor) stamp
    -- DefenseBuffPowerId. Resolve whichever tagged this pet so the floating badge matches the card.
    local badge = PetBadge.forPower(
        pet:GetAttribute("CombatShieldPowerId") or pet:GetAttribute("DefenseBuffPowerId")
    )
    if badge then
        PetBadge.create(bb, { element = badge.element, symbol = badge.symbol, ring = badge.ring })
    else
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Size = UDim2.fromScale(1, 1)
        img.Image = (PowerIcons.status and PowerIcons.status.shield) or ""
        img.ImageColor3 = Color3.fromRGB(235, 200, 70)
        img.Parent = bb
    end
    bb.Parent = pp
    armorIcons[pet] = bb
end

local function hideArmorIcon(pet)
    local bb = armorIcons[pet]
    if bb then
        armorIcons[pet] = nil
        pcall(function()
            bb:Destroy()
        end)
    end
end

-- A debuff badge floating over a debuffed TARGET (enemy/crystal), so you can READ which debuff is on
-- it (Sunder/Expose/Cripple…) instead of decoding the particle aura. Keyed off DebuffPowerId, which
-- PowerService stamps when it applies a vulnerable/root family. Sits ABOVE the target; the aura still
-- plays underneath. Rebuilt when a different power re-debuffs the same target.
local debuffIcons = setmetatable({}, { __mode = "k" }) -- target -> { gui, powerId, token }
local debuffTok = 0
local function hideDebuffIcon(target)
    local rec = debuffIcons[target]
    if rec then
        debuffIcons[target] = nil
        pcall(function()
            rec.gui:Destroy()
        end)
    end
end
-- DEV GUARD (Jason): dedupe so an unresolved debuff badge warns ONCE per power id (the overhead
-- twin of the StatusBadges guard), not every refresh.
local warnedDebuff = {}
local function showDebuffIcon(target, secs)
    -- `secs` = the debuff's remaining time (from refreshEnemyDebuff's Vulnerable/Root read), so the
    -- badge doesn't depend on DebuffUntil having replicated yet. `pid` may lag VulnerableUntil by a
    -- frame; if it's not here yet we bail and the DebuffPowerId hook re-fires us once it lands.
    local pid = target:GetAttribute("DebuffPowerId")
    if not secs or secs <= 0 or not pid then
        hideDebuffIcon(target)
        return
    end
    debuffTok += 1
    local myTok = debuffTok
    local rec = debuffIcons[target]
    if rec and rec.gui.Parent and rec.powerId == pid then
        rec.token = myTok -- same debuff, just refreshed: keep the badge, re-arm the expiry
    else
        local badge = PetBadge.forPower(pid)
        if not badge then
            -- A debuff is firing but its power resolves no badge: warn ONCE per power so an unwired
            -- power / missing effect→symbol map is caught in the console instead of silently showing
            -- just the aura with no overhead disc.
            if not warnedDebuff[pid] then
                warnedDebuff[pid] = true
                warn(
                    "[CombatAuraController] debuff badge for power '"
                        .. tostring(pid)
                        .. "' did not resolve (PetBadge.forPower nil — missing power or effect→symbol map); showing the aura only."
                )
            end
            hideDebuffIcon(target)
            return -- unknown power -> rely on the aura alone
        end
        local pp = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
        if not pp then
            return
        end
        if rec then
            pcall(function()
                rec.gui:Destroy()
            end)
        end
        local up = 4
        local okE, ext = pcall(function()
            return target:GetExtentsSize()
        end)
        if okE and ext then
            up = ext.Y * 0.5 + 2
        end
        local bb = Instance.new("BillboardGui")
        bb.Name = "DebuffIcon"
        bb.AlwaysOnTop = true
        bb.Size = UDim2.fromOffset(32, 32)
        bb.StudsOffset = Vector3.new(0, up, 0)
        bb.Adornee = pp
        PetBadge.create(bb, { element = badge.element, symbol = badge.symbol, ring = badge.ring })
        bb.Parent = pp
        debuffIcons[target] = { gui = bb, powerId = pid, token = myTok }
    end
    -- self-expire: hide when the debuff runs out (no attribute event fires on natural expiry). A
    -- re-cast bumps the token so this stale timer noops.
    task.delay(secs + 0.2, function()
        local r = debuffIcons[target]
        if not (r and r.token == myTok) then
            return
        end
        local left = math.max(
            (target:GetAttribute("DebuffUntil") or 0) - os.time(),
            (target:GetAttribute("VulnerableUntil") or 0) - os.time(),
            (target:GetAttribute("RootedUntil") or 0) - os.time()
        )
        if left <= 0 then
            hideDebuffIcon(target)
        end
    end)
end

local originCfg = {}
local reskinDefs = {} -- config.reskins: reskin key ("stone"/"lava"/...) -> { material, color }
local powersCfg = {} -- configs/powers.lua: powerId -> def (for power-driven shield element)

local function elementForPet(pet)
    local petEl = originCfg.pettype_element
        and originCfg.pettype_element[pet:GetAttribute("PetType")]
    local archetype = localPlayer and localPlayer:GetAttribute("Archetype")
    return CombatOrigin.resolve(petEl, archetype, originCfg)
end

-- The element a player-applied debuff reads in (the caster's theme): archetype element, else default.
local function casterElement()
    local archetype = localPlayer and localPlayer:GetAttribute("Archetype")
    return CombatOrigin.resolve(nil, archetype, originCfg)
end

local function stopSlot(entity, slot)
    local t = handles[entity]
    local h = t and t[slot]
    if h then
        t[slot] = nil
        pcall(function()
            if h.stop then
                h.stop()
            end
        end)
    end
end

local function setSlot(entity, slot, spec)
    stopSlot(entity, slot)
    local ok, handle = pcall(CombatFX.attach, entity, spec)
    if ok and handle then
        handles[entity] = handles[entity] or {}
        handles[entity][slot] = handle
    end
end

-- Seconds remaining on an absolute os.time() "until" attribute (0 if absent/expired).
local function remaining(entity, attr)
    local untilT = entity:GetAttribute(attr) or 0
    return untilT - os.time()
end

-- ===== Pets =====
-- Two DISTINCT defensive looks, kept SEPARATE so a single power never shows both:
--   SHIELD = absorb pool (CombatShield > 0; Dune Shield / Ember Ward / dodge) -> the element
--     force-field BUBBLE only, no reskin. Depletes as it soaks, so the look persists (duration 0)
--     until it hits zero.
--   ARMOR  = defense % (DefenseBuffUntil; Stone Skin / Ice Armor / Bulwark) -> the element material
--     RESKIN only, no bubble. A timed hardening of the pet's own body.
-- A pet shows both ONLY if it genuinely has a shield AND an armor active (two powers). Each look
-- attaches once on its own bare->active transition and clears on active->bare.
-- A power's combat LOOK is READ FROM CONFIG, never inferred in code. `combat_vfx.look` wins; else it
-- defaults by the effect's family (absorb -> bubble, but absorb+evade -> dodge; defense_buff -> reskin;
-- heal -> aura). So a new power just declares its family/evade (or an explicit combat_vfx.look) and the
-- renderer obeys — no per-power branches here. Returns (vfx table | nil, look string | nil).
local DEFAULT_LOOK = { defense_buff = "reskin", heal = "aura" }
local function vfxForPower(powerId)
    local def = powerId and powersCfg.powers and powersCfg.powers[powerId]
    if not def then
        return nil, nil
    end
    local vfx = def.combat_vfx
    if vfx and vfx.look then
        return vfx, vfx.look
    end
    local kind = def.effect and powersCfg.effect_kinds and powersCfg.effect_kinds[def.effect]
    local family = kind and kind.family
    if family == "absorb" then
        return vfx, (kind.evade and "dodge" or "bubble")
    end
    return vfx, (family and DEFAULT_LOOK[family]) or nil
end

local function hasArmor(pet)
    return (pet:GetAttribute("DefenseBuffUntil") or 0) > os.time()
end

-- Canonical combat element (grass/lava/ice/desert) of the POWER behind a defensive effect, so the
-- bubble/reskin match the cast power (ember_ward=fire, ice_armor=ice, dune_shield=sand) even on a
-- pet of another origin. idAttr = which power-id attribute to read; nil if no power tagged it.
local function defenseElement(pet, idAttr)
    local pid = pet:GetAttribute(idAttr)
    local def = pid and powersCfg.powers and powersCfg.powers[pid]
    if not def then
        return nil
    end
    return (
        def.archetype
        and originCfg.archetype_element
        and originCfg.archetype_element[def.archetype]
    ) or def.element
end

local function refreshArmor(pet)
    -- SHIELD / DODGE: the absorb pool. Its LOOK comes from the cast power's config (vfxForPower) — a
    -- real shield bubbles, a dodge does not. No per-power code; new absorb powers obey their config.
    -- SSOT: the bubble is the POOL, but a TIMED shield is dead once CombatShieldUntil lapses — a
    -- stale pool (server one-shot clear lost on re-deploy) must NOT keep the bubble/strength up
    -- forever ("when a shield runs out it runs out" — Jason). A duration-0 shield (until unset/0)
    -- persists until depleted, so only suppress on a timer that was SET and has passed. (Dodge sets
    -- CombatShieldUntil with NO pool → pool is 0 → doesn't bubble, only badges, as before.)
    local shieldUntil = tonumber(pet:GetAttribute("CombatShieldUntil")) or 0
    local shieldExpired = shieldUntil > 0 and shieldUntil <= os.time()
    local shieldOn = (pet:GetAttribute("CombatShield") or 0) > 0 and not shieldExpired -- absorb POOL (drives the bubble)
    -- badge CHANNEL: CombatShieldUntil is set by real shields AND by dodge (Mirage Step sets it without
    -- the pool). The over-pet identity BADGE follows this so dodge shows a badge; the bubble still keys
    -- off the pool above so a dodge doesn't bubble.
    local shieldBadgeOn = remaining(pet, "CombatShieldUntil") > 0.05
    local shieldLook
    if shieldBadgeOn then
        shieldLook = select(2, vfxForPower(pet:GetAttribute("CombatShieldPowerId")))
        shieldLook = shieldLook or "bubble" -- absorb pool with no tagged power -> default bubble
    end
    local bubble = handles[pet] and handles[pet].shieldBubble
    if shieldOn and shieldLook == "bubble" then
        if not bubble then
            local element = defenseElement(pet, "CombatShieldPowerId") or elementForPet(pet)
            setSlot(pet, "shieldBubble", { category = "shield", element = element, duration = 0 })
        end
    elseif bubble then
        stopSlot(pet, "shieldBubble")
    end

    -- ARMOR (defense %) -> RESKIN only (category has no theme entry, so attach skips bubble + aura)
    local reskin = handles[pet] and handles[pet].armorReskin
    if hasArmor(pet) then
        if not reskin then
            local element = defenseElement(pet, "DefenseBuffPowerId") or elementForPet(pet)
            local reskinKey = originCfg.element_reskin and originCfg.element_reskin[element]
            local reskinDef = reskinKey and reskinDefs[reskinKey]
            if reskinDef then
                setSlot(
                    pet,
                    "armorReskin",
                    { category = "armor", element = element, reskin = reskinDef, duration = 0 }
                )
            end
        end
    elseif reskin then
        stopSlot(pet, "armorReskin")
    end

    -- Floating identity badge while ANY defensive effect is active (shield, dodge, OR armor) so you
    -- can tell the buff is up — unless the power opts out via combat_vfx.badge = false.
    -- ONE read path: PowerBadges (the SSOT) reports EVERY live power on this pet (generic Power_* set +
    -- the shield/dodge/defense channels), so the badge can't be missed for a new family. shieldBadgeOn
    -- above is now only used for the BUBBLE look. A power can opt out of the overhead badge via
    -- combat_vfx.badge=false.
    local showBadge = false
    for _, p in ipairs(PowerBadges.active(pet)) do
        local vfx = vfxForPower(p.powerId)
        if not (vfx and vfx.badge == false) then
            showBadge = true
            break
        end
    end
    if showBadge then
        showArmorIcon(pet)
        -- self-expire: a timed buff channel (dodge's CombatShieldUntil) fires no event at natural
        -- expiry, so schedule a re-check to drop the badge when the buff lapses (token-guarded so a
        -- re-cast supersedes the stale timer).
        local left = PowerBadges.maxUntil(pet) - os.time()
        if left > 0 then
            armorTok += 1
            local myTok = armorTok
            armorTokens[pet] = myTok
            task.delay(left + 0.2, function()
                if armorTokens[pet] == myTok then
                    refreshArmor(pet)
                end
            end)
        end
    else
        hideArmorIcon(pet)
    end
end

local function refreshTimedAura(pet, attr, slot, category, element)
    local secs = remaining(pet, attr)
    if secs > 0.05 then
        setSlot(
            pet,
            slot,
            { category = category, element = element or elementForPet(pet), duration = secs }
        )
    else
        stopSlot(pet, slot)
    end
end

-- AURA FIELD (bear's ground AoE): the server stamps AuraFieldUntil each engaged tick (a ~2s
-- keep-alive). Unlike the timed auras above, the field is PERSISTENT — attached ONCE on the first
-- live stamp and kept running (no per-tick re-attach churn), then stopped by a watchdog once the
-- keep-alive lapses (combat ended). The radius (AuraFieldRadius) sizes the field; element from PetType.
local fieldStopToken = setmetatable({}, { __mode = "k" }) -- pet -> latest watchdog token
-- DEBUG: force EVERY aura pet's field to this element so we can preview lava/ice/desert on the (grass)
-- bear without needing element-specific pets. Set back to nil to ship — the field uses the pet's real
-- element. (Reboot to apply; change the value + reboot to cycle elements.)
local DEBUG_FIELD_ELEMENT = nil
local function refreshAuraField(pet)
    local secs = remaining(pet, "AuraFieldUntil")
    if secs > 0.05 then
        if not (handles[pet] and handles[pet].aurafield) then
            setSlot(pet, "aurafield", {
                category = "aurafield",
                element = DEBUG_FIELD_ELEMENT or elementForPet(pet),
                duration = 0, -- persistent; the keep-alive watchdog ends it
                radius = pet:GetAttribute("AuraFieldRadius"),
            })
        end
        -- (re)arm a single watchdog; only the latest token may stop, so refreshes don't cut it early
        local token = {}
        fieldStopToken[pet] = token
        task.delay(secs + 0.2, function()
            if fieldStopToken[pet] == token and remaining(pet, "AuraFieldUntil") <= 0.05 then
                stopSlot(pet, "aurafield")
            end
        end)
    else
        stopSlot(pet, "aurafield")
    end
end

-- Floating "Dodge!" that rises + fades over a pet that just evaded a hit (Mirage Step). Server
-- bumps DodgeTick per turned-aside blow; we pop one of these per bump.
local function popDodge(pet)
    local root = pet.PrimaryPart
        or pet:FindFirstChild("HumanoidRootPart")
        or pet:FindFirstChildWhichIsA("BasePart")
    if not root then
        return
    end
    local bb = Instance.new("BillboardGui")
    bb.Name = "DodgePop"
    bb.Size = UDim2.fromOffset(90, 30)
    bb.StudsOffset = Vector3.new(0, 2.6, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = root
    bb.Parent = root
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    lbl.Text = "DODGE" -- all-caps to match the combat_text "MISS" float (consistent word-float style)
    lbl.TextColor3 = Color3.fromRGB(255, 221, 64) -- yellow (Jason) — reads as a lucky avoid, distinct from damage
    lbl.TextStrokeTransparency = 0.3
    lbl.Parent = bb
    TweenService
        :Create(
            bb,
            TweenInfo.new(0.7, Enum.EasingStyle.Quad),
            { StudsOffset = Vector3.new(0, 5.2, 0) }
        )
        :Play()
    TweenService:Create(lbl, TweenInfo.new(0.7), {
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    }):Play()
    task.delay(0.75, function()
        bb:Destroy()
    end)
end

local function hookPet(pet)
    if conns[pet] or not pet:IsA("Model") then
        return
    end
    local list = {}
    conns[pet] = list
    -- both defensive families -> armor look
    list[#list + 1] = pet:GetAttributeChangedSignal("CombatShield"):Connect(function()
        refreshArmor(pet)
    end)
    list[#list + 1] = pet:GetAttributeChangedSignal("DefenseBuffUntil"):Connect(function()
        refreshArmor(pet)
        -- defense_buff is time-gated and expires silently: re-check when it lapses to drop the armor.
        local secs = remaining(pet, "DefenseBuffUntil")
        if secs > 0 then
            task.delay(secs + 0.1, function()
                refreshArmor(pet)
            end)
        end
    end)
    list[#list + 1] = pet:GetAttributeChangedSignal("HealFxUntil"):Connect(function()
        refreshTimedAura(pet, "HealFxUntil", "heal", "heal")
    end)
    -- The tagging power decides the look (bubble vs dodge vs ...): re-resolve if it changes or lands
    -- a frame after CombatShield.
    list[#list + 1] = pet:GetAttributeChangedSignal("CombatShieldPowerId"):Connect(function()
        refreshArmor(pet)
    end)
    -- CombatShieldUntil is the badge channel (set by dodge without the absorb pool) — hook it so the
    -- badge appears whichever of (CombatShieldPowerId, CombatShieldUntil) replicates last.
    list[#list + 1] = pet:GetAttributeChangedSignal("CombatShieldUntil"):Connect(function()
        refreshArmor(pet)
    end)
    -- Evasion: each turned-aside blow bumps DodgeTick -> pop a floating "Dodge!".
    list[#list + 1] = pet:GetAttributeChangedSignal("DodgeTick"):Connect(function()
        popDodge(pet)
    end)
    -- Aura field (bear's ground AoE): the server bumps AuraFieldUntil each engaged tick.
    list[#list + 1] = pet:GetAttributeChangedSignal("AuraFieldUntil"):Connect(function()
        refreshAuraField(pet)
    end)
    -- catch any already-active state at hook time
    refreshArmor(pet)
    refreshTimedAura(pet, "HealFxUntil", "heal", "heal")
    refreshAuraField(pet)
end

local function unhook(entity)
    local list = conns[entity]
    if list then
        for _, c in ipairs(list) do
            c:Disconnect()
        end
        conns[entity] = nil
    end
    local t = handles[entity]
    if t then
        for slot in pairs(t) do
            stopSlot(entity, slot)
        end
        handles[entity] = nil
    end
    hideArmorIcon(entity)
end

-- Player-level damage buff -> a buff aura on every owned pet for the remaining duration.
local function refreshPlayerDamageBuff(petsFolder)
    local secs = remaining(localPlayer, "PetDamageBuffUntil")
    if not petsFolder then
        return
    end
    for _, pet in ipairs(petsFolder:GetChildren()) do
        if pet:IsA("Model") then
            if secs > 0.05 then
                setSlot(
                    pet,
                    "dmgbuff",
                    { category = "buff", element = elementForPet(pet), duration = secs }
                )
            else
                stopSlot(pet, "dmgbuff")
            end
        end
    end
end

-- ===== Enemies =====
local function refreshEnemyDebuff(enemy)
    -- ONE read path: PowerBadges (the SSOT) reports every live power on this enemy (generic Power_*
    -- set + the DebuffPowerId/Until channel), so the badge can't be missed for a new debuff family.
    -- The debuff AURA shows while anything is active; the badge itself is rendered by showDebuffIcon.
    local secs = PowerBadges.maxUntil(enemy) - os.time()
    if secs > 0.05 then
        setSlot(
            enemy,
            "debuff",
            { category = "debuff", element = casterElement(), duration = secs }
        )
        showDebuffIcon(enemy, secs) -- aura AND a badge: read which debuff it is at a glance
    else
        stopSlot(enemy, "debuff")
        hideDebuffIcon(enemy)
    end
end

-- Wildfire: real Roblox Fire on an enemy while it's BURNING (BurnUntil), so the contagion is visible
-- as it spreads — persistent like the shield, cleared when the burn expires. Display-only; the
-- vulnerability/damage live on the server. Re-ignition (attribute change) refreshes the clear timer.
local burnFx = setmetatable({}, { __mode = "k" }) -- enemy -> Fire instance
local function refreshEnemyBurn(enemy)
    local secs = remaining(enemy, "BurnUntil")
    if secs > 0.05 then
        local fire = burnFx[enemy]
        if not fire or not fire.Parent then
            local pp = enemy.PrimaryPart or enemy:FindFirstChildWhichIsA("BasePart")
            if not pp then
                return
            end
            local okE, ext = pcall(function()
                return enemy:GetExtentsSize()
            end)
            local szHint = (okE and ext) and math.max(ext.X, ext.Y, ext.Z) or 5
            -- Element-themed burn (BurnElement is stamped alongside BurnUntil) — frost reads blue, a
            -- wither burn green, etc. Falls back to lava inside enemyBurn.
            fire = CombatFX.enemyBurn(pp, enemy:GetAttribute("BurnElement"), szHint)
            if not fire then
                return
            end
            burnFx[enemy] = fire
        end
        task.delay(secs + 0.25, function()
            if remaining(enemy, "BurnUntil") <= 0.05 then
                local f = burnFx[enemy]
                if f then
                    f:Destroy()
                    burnFx[enemy] = nil
                end
            end
        end)
    else
        local f = burnFx[enemy]
        if f then
            f:Destroy()
            burnFx[enemy] = nil
        end
    end
end

local function hookEnemy(enemy)
    if conns[enemy] or not enemy:IsA("Model") then
        return
    end
    local list = {}
    conns[enemy] = list
    list[#list + 1] = enemy:GetAttributeChangedSignal("VulnerableUntil"):Connect(function()
        refreshEnemyDebuff(enemy)
    end)
    list[#list + 1] = enemy:GetAttributeChangedSignal("BurnUntil"):Connect(function()
        refreshEnemyBurn(enemy)
    end)
    list[#list + 1] = enemy:GetAttributeChangedSignal("RootedUntil"):Connect(function()
        refreshEnemyDebuff(enemy)
    end)
    -- DebuffPowerId can replicate a frame AFTER VulnerableUntil; re-run so the badge picks it up.
    list[#list + 1] = enemy:GetAttributeChangedSignal("DebuffPowerId"):Connect(function()
        refreshEnemyDebuff(enemy)
    end)
    -- DebuffUntil is the generic debuff timer (e.g. blind, which sets no Vulnerable/Rooted) — hook it
    -- so the badge appears whichever of (DebuffPowerId, DebuffUntil) replicates last.
    list[#list + 1] = enemy:GetAttributeChangedSignal("DebuffUntil"):Connect(function()
        refreshEnemyDebuff(enemy)
    end)
    refreshEnemyDebuff(enemy)
    refreshEnemyBurn(enemy)
end

-- Watch a folder's children (current + future), hooking each and unhooking on removal.
local function watchFolder(folder, hook)
    for _, child in ipairs(folder:GetChildren()) do
        hook(child)
    end
    folder.ChildAdded:Connect(hook)
    folder.ChildRemoved:Connect(unhook)
end

-- Non-blocking: run cb(child) for a named child of `parent` now if present, else once it appears.
local function whenChild(parent, name, cb)
    local existing = parent:FindFirstChild(name)
    if existing then
        cb(existing)
        return
    end
    local conn
    conn = parent.ChildAdded:Connect(function(child)
        if child.Name == name then
            conn:Disconnect()
            cb(child)
        end
    end)
end

function CombatAuraController.start()
    if started then
        return
    end
    started = true

    local cfg = require(ReplicatedStorage.Configs:WaitForChild("combat_fx"))
    originCfg = cfg.origin or {}
    reskinDefs = cfg.reskins or {}
    local okP, powers = pcall(function()
        return require(ReplicatedStorage.Configs:WaitForChild("powers"))
    end)
    powersCfg = (okP and powers) or {}

    -- Pets: workspace.PlayerPets[<localPlayer>] (each level appears when pets first spawn).
    whenChild(Workspace, "PlayerPets", function(root)
        whenChild(root, localPlayer.Name, function(mine)
            watchFolder(mine, hookPet)
            localPlayer:GetAttributeChangedSignal("PetDamageBuffUntil"):Connect(function()
                refreshPlayerDamageBuff(mine)
            end)
            refreshPlayerDamageBuff(mine)
        end)
    end)

    -- Enemies: workspace.Game.Enemies.
    whenChild(Workspace, "Game", function(g)
        whenChild(g, "Enemies", function(enemies)
            watchFolder(enemies, hookEnemy)
        end)
    end)
end

return CombatAuraController
