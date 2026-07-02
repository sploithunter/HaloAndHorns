--[[
    BuffStatsHud (client, Studio-only) — live "current buffs" readout, sibling to DevMetricsHud.

    Where DevMetricsHud shows OUTPUT rates (DPS / coins-per-sec / XP-per-min), this shows the
    INPUT multipliers feeding them: the player's CURRENT effective buff stack, resolved exactly the
    way the server consumers resolve it (same BuffStack math, same axis caps, same attribute names),
    so you can glance at "am I really at x1.75 attack right now?" while testing powers/auras.

      ⚔ Attack    pet_damage : PetDamageBuff + PetTeamDamageBuff (multipliers) ADD -> x, cap 5.0
      🛡 Defense   per-pet    : DefenseBuff + TeamDefenseBuff (flat) on the selected/best pet -> +N (M%)
      💰 Coin      coin_yield : CoinYieldBuff (mult) + CoinYieldPower (fraction) ADD -> x, cap 5.0
      ⛏ Mining    mining     : 1 + MiningBuff (fraction) -> x, cap 5.0
      🍀 Luck      luck       : 1 + LuckBuff (fraction) -> x, cap 3.0
      🐾 Speed     move_speed : 1 + MoveSpeedBuff (fraction) -> x, cap 1.0
      ⚡ Recharge  recharge   : RechargeBuff (fraction, clamp 0.9) -> -N% cooldown
      ✨ XP        xp         : 1 + XpBuff (fraction) -> x, cap 3.0
      👥 Team Power / 🌍 In Area / 🌍 With Buffs : Σ over the deployed squad of the
         DEALT-chain power (PetPowerView.profile — the same resolver the inventory card
         and _mine run, #132), in three layers (Jason: "team power in area and team power
         with buffs in area as well"): intrinsic (zone-neutral), × the current zone's
         biome-RPS resonance, × the live pet_damage axis. The buffer-balance instrument:
         each layer's pip shows its own contribution (squad size / net area % / net buff %).
      🎲 EV / Swing : the rolls (accuracy, crit) folded to expected value — a probability
         is just a damage multiplier you haven't averaged yet. ⛏ never misses (mining);
         ⚔ × to-hit vs an EVEN-LEVEL enemy (the standard candle — what the training dummy
         measures); both × (1 + crit·(critMult−1)) incl. live CritBuff/CritAura channels.
      🛡 Toughness / With Buffs : team effective HP. A pet's pool is its endurance
         threshold (Power × pet_down_threshold_factor); armor is MULTIPLICATIVE on it
         (EHP = pool × (Defense+k)/k — Jason: armor "is essentially a hit point increase");
         shields (CombatShield, incl. Mirage "evasion") are ADDITIVE flat pools on top.
         Buffed row folds DefenseBuff + the penguin's TeamDefenseBuff onto the curve.
      ⏱ matchup rows : THE PACING ROWS — one per combat.dev_candle matchup (Lieut. /
         Boss / 3 Minions / Warband...), each played FOR REAL by BattleSim N times
         (Jason: "the only way to make this real is to simulate it... what if my armor
         buffer dies? It is no longer armoring"): swing timers, hit/crit rolls,
         threat/taunt targeting, downs that remove a dead pet's damage AND its auras.
         "⚔ 14s ❤ 62%" = median clear + EHP margin; "💀 9s" = you go down first;
         pip = wins/trials; color = the verdict (green sweep / amber costly / red losing).
         Sims recompute every ~2s (cheap: ~tick-per-0.1s × trials), rows repaint from cache.

    A row dims to grey at base (x1.00 / no buff); an active row fills a faint bar toward its axis cap
    and shows the remaining seconds of the soonest-expiring source, blinking under ~5s. Pure dev tool:
    Studio-gated, reads only replicated attributes — no gameplay effect.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BuffStack = require(ReplicatedStorage.Shared.Game.BuffStack)
local PetPowerView = require(ReplicatedStorage.Shared.Game.PetPowerView)
local ElementResonance = require(ReplicatedStorage.Shared.Game.ElementResonance)
local Accuracy = require(ReplicatedStorage.Shared.Game.Accuracy)
local PetCombat = require(ReplicatedStorage.Shared.Game.PetCombat)
local BattleSim = require(ReplicatedStorage.Shared.Game.BattleSim)
local BuffsConfig = require(ReplicatedStorage.Configs:WaitForChild("buffs"))
local CombatConfig = require(ReplicatedStorage.Configs:WaitForChild("combat"))
local DropsConfig = require(ReplicatedStorage.Configs:WaitForChild("drops"))
local enemiesOk, EnemiesConfig = pcall(function()
    return require(ReplicatedStorage.Configs:WaitForChild("enemies"))
end)
local rolesOk, PetRolesConfig = pcall(function()
    return require(ReplicatedStorage.Configs:WaitForChild("pet_roles"))
end)

-- Role definition for a pet model (mirrors EnemyService resolution: PetRole attr ->
-- by_type[PetType] -> default role). Used for defense, threat_mult, implicit_taunt.
local function roleDefFor(pet)
    if not (rolesOk and PetRolesConfig) then
        return {}
    end
    local id = pet:GetAttribute("PetRole")
        or (PetRolesConfig.by_type and PetRolesConfig.by_type[pet:GetAttribute("PetType")])
        or PetRolesConfig.default
    return (PetRolesConfig.roles and PetRolesConfig.roles[id]) or {}
end

local function roleDefenseFor(pet)
    return tonumber(roleDefFor(pet).defense) or 0
end

-- A pet's variant effect multiplier (basic 1 / golden 1.25 / rainbow 1.5) — the same
-- table EnemyService:_supportPass scales auras with.
local function variantEffectMultFor(pet)
    local mults = rolesOk and PetRolesConfig and PetRolesConfig.variant_effect_multipliers
    return (
        mults and tonumber(mults[string.lower(tostring(pet:GetAttribute("PetVariant") or "basic"))])
    ) or 1
end

-- A pet's support auras as BattleSim aura specs (kind + magnitude x the variant effect
-- multiplier — the same scaling EnemyService:_supportPass applies). Combat-relevant
-- kinds only; luck/yield buff the economy, not the fight. RAGE passes through RAW:
-- its rules live in SupportAura.rageFraction (the unified path EnemyService also
-- stamps from), which BattleSim calls with the pet spec's variantMult.
local function simAurasFor(pet)
    if not (rolesOk and PetRolesConfig) then
        return {}
    end
    local entry = PetRolesConfig.support_auras
        and PetRolesConfig.support_auras[pet:GetAttribute("PetType")]
    if not entry then
        return {}
    end
    local list = entry.kind and { entry } or entry -- single aura or a LIST (colorado)
    local vMult = variantEffectMultFor(pet)
    local auras = {}
    for _, a in ipairs(list) do
        if a.kind == "offense" then
            table.insert(
                auras,
                { kind = "offense", fraction = ((tonumber(a.mult) or 1) - 1) * vMult }
            )
        elseif a.kind == "defense" then
            table.insert(auras, { kind = "defense", amount = (tonumber(a.amount) or 0) * vMult })
        elseif a.kind == "heal" then
            table.insert(auras, {
                kind = "heal",
                fraction = (tonumber(a.fraction) or 0) * vMult,
                interval = tonumber(a.interval) or 2,
            })
        elseif a.kind == "rage" then
            table.insert(auras, { kind = "rage", enrage_below = a.enrage_below, mult = a.mult })
        end
    end
    return auras
end

-- Biome-RPS configs for the team-power rows (pcall'd: a template game without these
-- configs just reads neutral resonance, the rows still work).
local elementsOk, ElementsConfig = pcall(function()
    return require(ReplicatedStorage.Configs:WaitForChild("elements"))
end)
local fxOk, CombatFxConfig = pcall(function()
    return require(ReplicatedStorage.Configs:WaitForChild("combat_fx"))
end)
local areasOk, AreasConfig = pcall(function()
    return require(ReplicatedStorage.Configs:WaitForChild("areas"))
end)

-- Zone-resonance multiplier for a pet type RIGHT NOW — the same resolution the inventory
-- card and the server damage path use (ElementResonance.biomeMultiplier), so the team sum
-- changes when the player crosses a zone border, exactly like the cards do.
local function zoneResonanceFor(player, petType)
    if not (elementsOk and ElementsConfig) then
        return 1
    end
    local petElement = fxOk
        and CombatFxConfig
        and CombatFxConfig.origin
        and CombatFxConfig.origin.pettype_element
        and CombatFxConfig.origin.pettype_element[petType]
    local zones = areasOk and AreasConfig and AreasConfig.zones
    local zone = zones and zones[tostring(player:GetAttribute("CurrentArea"))]
    return ElementResonance.biomeMultiplier(petElement, zone and zone.element, ElementsConfig)
end

local REFRESH = 0.25 -- readout cadence (s)
local BLINK_LEAD = 5 -- seconds-to-expiry under which the time pip blinks
local RECHARGE_CLAMP = 0.9 -- mirrors PowerService cooldown-reduction clamp

local BuffStatsHud = {}
BuffStatsHud.__index = BuffStatsHud

local function axis(name)
    return (BuffsConfig.axes and BuffsConfig.axes[name]) or { cap = BuffsConfig.default_cap }
end

-- Soonest future expiry across a list of *Until attrs (0 = none live). Returns secs remaining, or nil
-- for "permanent" — #180: a TOGGLE (Hasten / Super Speed) sets its Until far in the future, so it
-- reads as on-with-no-countdown rather than a giant timer.
local PERMANENT_THRESHOLD = 60 * 60 * 24 * 365 -- > 1 year out = permanent (toggle / aura), no timer
local function soonestRemaining(player, untilAttrs, now)
    local soon
    for _, a in ipairs(untilAttrs) do
        local u = player:GetAttribute(a) or 0
        if u > now and (not soon or u < soon) then
            soon = u
        end
    end
    if not soon then
        return nil
    end
    local remaining = soon - now
    return remaining < PERMANENT_THRESHOLD and remaining or nil -- nil = permanent (no countdown)
end

local _instance -- singleton (the badge-pile button toggles it from another module)

function BuffStatsHud.start()
    local self = setmetatable({}, BuffStatsHud)
    self.player = Players.LocalPlayer
    self.rows = {}
    self._blinkOn = true
    self._blinkAccum = 0
    self:_build()
    self:_connect()
    -- PROMOTED from Studio-only dev overlay to a player panel (Jason: tap the badge
    -- pile -> "that opens up the whole buff panel"): hidden by default in production,
    -- visible at boot in Studio (the original dev-readout behavior). ADMINS also get it
    -- open at boot on published servers (balance testing — Jason: "I have it in Studio but
    -- not on the published instance"); regular players still open it via the badge pile.
    local function showByDefault()
        return RunService:IsStudio() or self.player:GetAttribute("IsAdmin") == true
    end
    self.gui.Enabled = showByDefault()
    -- IsAdmin replicates after data load (post-boot), so re-evaluate when it arrives.
    self.player:GetAttributeChangedSignal("IsAdmin"):Connect(function()
        if showByDefault() then
            self.gui.Enabled = true
        end
    end)
    _instance = self
    return self
end

-- Toggle the panel (the badge pile is the opener; works on touch and mouse).
function BuffStatsHud.toggle()
    if _instance and _instance.gui then
        _instance.gui.Enabled = not _instance.gui.Enabled
    end
end

-- ---- UI -----------------------------------------------------------------

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = inst
end

function BuffStatsHud:_build()
    local gui = Instance.new("ScreenGui")
    gui.Name = "BuffStatsHud"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 100
    gui.Parent = self.player:WaitForChild("PlayerGui")
    self.gui = gui

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    -- height follows the row list (conditional rows + the team-power pair come and go)
    panel.Size = UDim2.new(0, 240, 0, 0)
    panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.Position = UDim2.new(0, 8, 0, 180) -- top-left, stacked under DevMetricsHud
    panel.AnchorPoint = Vector2.new(0, 0)
    panel.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    panel.BackgroundTransparency = 0.2
    panel.BorderSizePixel = 0
    corner(panel, 8)
    panel.Parent = gui

    local pad = Instance.new("UIPadding")
    for _, s in ipairs({ "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" }) do
        pad[s] = UDim.new(0, 6)
    end
    pad.Parent = panel
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 3)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = panel

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 14)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(170, 175, 195)
    title.Text = "ACTIVE BUFFS"
    title.LayoutOrder = 0
    title.Parent = panel

    local function makeRow(key, label, color, order)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 19)
        row.BackgroundColor3 = Color3.fromRGB(34, 37, 50)
        row.BorderSizePixel = 0
        row.LayoutOrder = order
        corner(row, 4)
        row.Parent = panel
        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = color
        fill.BackgroundTransparency = 0.35
        fill.BorderSizePixel = 0
        fill.ZIndex = 2
        corner(fill, 4)
        fill.Parent = row
        local text = Instance.new("TextLabel")
        text.Size = UDim2.new(1, -10, 1, 0)
        text.Position = UDim2.new(0, 6, 0, 0)
        text.BackgroundTransparency = 1
        text.Font = Enum.Font.GothamBold
        text.TextSize = 12
        text.TextXAlignment = Enum.TextXAlignment.Left
        text.TextColor3 = Color3.fromRGB(245, 245, 250)
        text.Text = label .. ": —"
        text.ZIndex = 3
        text.Parent = row
        -- right-aligned time pip
        local pip = Instance.new("TextLabel")
        pip.Name = "Pip"
        pip.Size = UDim2.new(0, 40, 1, 0)
        pip.Position = UDim2.new(1, -44, 0, 0)
        pip.BackgroundTransparency = 1
        pip.Font = Enum.Font.GothamMedium
        pip.TextSize = 11
        pip.TextXAlignment = Enum.TextXAlignment.Right
        pip.TextColor3 = Color3.fromRGB(210, 215, 230)
        pip.Text = ""
        pip.ZIndex = 3
        pip.Parent = row
        self.rows[key] =
            { row = row, fill = fill, text = text, pip = pip, label = label, color = color }
    end
    makeRow("attack", "⚔ Attack", Color3.fromRGB(225, 90, 80), 1)
    makeRow("defense", "🛡 Defense", Color3.fromRGB(120, 170, 235), 2)
    makeRow("coin", "💰 Coin", Color3.fromRGB(240, 200, 70), 3)
    makeRow("mining", "⛏ Mining", Color3.fromRGB(180, 150, 110), 4)
    makeRow("luck", "🍀 Luck", Color3.fromRGB(110, 210, 130), 5)
    -- targeted hatch-luck CHANNELS: rows exist but stay HIDDEN unless non-neutral
    -- (Jason: split them out, but "we're getting pretty cluttered" — conditional rows)
    makeRow("golden_luck", "🟡 Gold Luck", Color3.fromRGB(240, 200, 70), 51)
    makeRow("rainbow_luck", "🌈 Rainbow Luck", Color3.fromRGB(220, 120, 235), 52)
    makeRow("huge_luck", "🐘 Huge Luck", Color3.fromRGB(255, 140, 220), 53)
    -- PRESENCE buffs (config-styled, one row per source; visible only while active).
    -- Today: creator lucky-server (configs/creators.lua server_luck.display, purple —
    -- Jason: "should not be the green look... individually configurable; we might add
    -- this mechanic to other things").
    self._presenceBuffs = {}
    do
        local ok, creators = pcall(function()
            return require(game:GetService("ReplicatedStorage").Configs:WaitForChild("creators"))
        end)
        local d = ok and creators and creators.server_luck and creators.server_luck.display
        if d and d.attr then
            local c = d.color or { 170, 90, 255 }
            makeRow(
                "presence_creator",
                d.label or "👑 Creator Luck",
                Color3.fromRGB(c[1], c[2], c[3]),
                54
            )
            self._presenceBuffs[#self._presenceBuffs + 1] =
                { key = "presence_creator", attr = d.attr }
        end
    end
    makeRow("speed", "🐾 Speed", Color3.fromRGB(95, 180, 235), 6)
    makeRow("recharge", "⚡ Recharge", Color3.fromRGB(160, 130, 240), 7)
    makeRow("xp", "✨ XP", Color3.fromRGB(150, 110, 235), 8)
    makeRow("magnet", "🧲 Magnet", Color3.fromRGB(120, 200, 235), 9)
    -- Σ TEAM POWER (Jason's buffer-balance instrument): the dealt-chain ⛏/⚔ sums over the
    -- deployed squad in three layers — intrinsic, × zone resonance, × buffs (_teamPower).
    makeRow("team", "👥 Team Power", Color3.fromRGB(235, 235, 245), 10)
    makeRow("team_area", "🌍 In Area", Color3.fromRGB(120, 220, 160), 11)
    makeRow("team_buffed", "🌍 With Buffs", Color3.fromRGB(255, 170, 80), 12)
    -- EV row: accuracy + crit folded in (vs an even-level enemy — the dummy candle).
    makeRow("team_ev", "🎲 EV / Swing", Color3.fromRGB(200, 160, 255), 13)
    -- Team effective HP: endurance pools × armor curve (+ flat shields when buffed).
    makeRow("tough", "🛡 Toughness", Color3.fromRGB(140, 185, 240), 14)
    makeRow("tough_buffed", "🛡 With Buffs", Color3.fromRGB(95, 215, 230), 15)
    -- The PACING rows: expected battle clock vs each dev-candle matchup (config-driven:
    -- combat.dev_candle.matchups — one row per entry, add/remove scenarios in config).
    self._matchups = (CombatConfig.dev_candle and CombatConfig.dev_candle.matchups) or {}
    for i, m in ipairs(self._matchups) do
        makeRow("battle_" .. i, "⏱ " .. (m.label or "?"), Color3.fromRGB(235, 90, 80), 15 + i)
    end
end

-- ---- data ---------------------------------------------------------------

function BuffStatsHud:_connect()
    self._accum = 0
    RunService.Heartbeat:Connect(function(dt)
        self._accum += dt
        self._blinkAccum += dt
        if self._blinkAccum >= 0.4 then
            self._blinkAccum = 0
            self._blinkOn = not self._blinkOn
        end
        if self._accum < REFRESH then
            return
        end
        self._accum = 0
        if self.gui and self.gui.Enabled then
            self:_refresh()
        end
    end)
end

-- The DefenseBuff/TeamDefenseBuff axis lives per-pet. Read the SELECTED pet (CombatBuffTarget) if
-- one is set, else the best-defended pet in the squad, so the readout reflects what's on screen.
function BuffStatsHud:_defenseFlat(now)
    local pp = Workspace:FindFirstChild("PlayerPets")
    local folder = pp and pp:FindFirstChild(self.player.Name)
    if not folder then
        return 0, nil
    end
    local selected = self.player:GetAttribute("CombatBuffTarget")
    local best, bestUntil = 0, nil
    for _, m in ipairs(folder:GetChildren()) do
        local posNum = m:FindFirstChild("PositionNumber")
        local isSelected = selected and posNum and posNum.Value == selected
        local flat, soon = 0, nil
        if (m:GetAttribute("DefenseBuffUntil") or 0) > now then
            flat += m:GetAttribute("DefenseBuff") or 0
            soon = m:GetAttribute("DefenseBuffUntil")
        end
        if (m:GetAttribute("TeamDefenseBuffUntil") or 0) > now then
            flat += m:GetAttribute("TeamDefenseBuff") or 0
            -- TeamDefenseBuff is an AURA (permanent while the buffer pet is deployed): it counts
            -- toward the +Defense value but must NOT drive a countdown — only the timed DefenseBuff
            -- power above does. So a defense aura alone reads ∞, not a recast tick.
        end
        if isSelected then
            return flat, soon and (soon - now) or nil -- selected pet wins outright
        end
        if flat > best then
            best, bestUntil = flat, soon
        end
    end
    return best, bestUntil and (bestUntil - now) or nil
end

function BuffStatsHud:_refresh()
    local now = os.time()
    local p = self.player

    -- ⚔ Attack (pet_damage axis): two multipliers add as fractions.
    local atk = BuffStack.multiplier({
        {
            fraction = (p:GetAttribute("PetDamageBuff") or 1) - 1,
            expiry = p:GetAttribute("PetDamageBuffUntil") or 0,
        },
        {
            fraction = (p:GetAttribute("PetTeamDamageBuff") or 1) - 1,
            expiry = p:GetAttribute("PetTeamDamageBuffUntil") or 0,
        },
        {
            fraction = p:GetAttribute("PetDamageBuffPotion") or 0, -- Berserk potion (raw fraction)
            expiry = p:GetAttribute("PetDamageBuffPotionUntil") or 0,
        },
    }, now, axis("pet_damage"))
    -- Timer counts down the TIMED sources (PetDamageBuff / the potion); the offense AURA
    -- (PetTeamDamageBuff) is permanent while the pet is deployed -> no countdown (shows ∞).
    self:_setMult(
        "attack",
        atk,
        axis("pet_damage").cap,
        soonestRemaining(p, { "PetDamageBuffUntil", "PetDamageBuffPotionUntil" }, now)
    )

    -- 🛡 Defense (per-pet flat -> armor-curve mitigation %).
    local defFlat, defRem = self:_defenseFlat(now)
    self:_setDefense("defense", defFlat, defRem)

    -- 💰 Coin (coin_yield axis): aura multiplier + power fraction add.
    local coin = BuffStack.multiplier({
        {
            fraction = (p:GetAttribute("CoinYieldBuff") or 1) - 1,
            expiry = p:GetAttribute("CoinYieldBuffUntil") or 0,
        },
        {
            fraction = p:GetAttribute("CoinYieldPower") or 0,
            expiry = p:GetAttribute("CoinYieldPowerUntil") or 0,
        },
        {
            -- ENCHANT contribution (Jason: one honest coin number): EnchantService
            -- stamps the equipped pets' coin_finder total as EnchantCoinBonus
            fraction = p:GetAttribute("EnchantCoinBonus") or 0,
            expiry = math.huge, -- permanent while the enchanted pets stay equipped
        },
    }, now, axis("coin_yield"))
    -- Timer counts down only the TIMED power (CoinYieldPower); the yield AURA (CoinYieldBuff) is
    -- permanent while the buffer pet is deployed -> no countdown (shows ∞).
    self:_setMult(
        "coin",
        coin,
        axis("coin_yield").cap,
        soonestRemaining(p, { "CoinYieldPowerUntil" }, now)
    )

    -- ⛏ Mining (single fraction).
    local mining = BuffStack.multiplier({
        {
            fraction = p:GetAttribute("MiningBuff") or 0,
            expiry = p:GetAttribute("MiningBuffUntil") or 0,
        },
    }, now, axis("mining"))
    self:_setMult(
        "mining",
        mining,
        axis("mining").cap,
        soonestRemaining(p, { "MiningBuffUntil" }, now)
    )

    -- 🍀 Luck: the Fortune POWER + the bunny support AURA (HatchLuckBuff is a
    -- multiplier attribute; contribute its fraction) stack additively like everything.
    local luck = BuffStack.multiplier({
        {
            fraction = p:GetAttribute("LuckBuff") or 0,
            expiry = p:GetAttribute("LuckBuffUntil") or 0,
        },
        {
            fraction = p:GetAttribute("LuckBuffPotion") or 0, -- Fortune potion (raw fraction)
            expiry = p:GetAttribute("LuckBuffPotionUntil") or 0,
        },
        {
            fraction = math.max(0, (p:GetAttribute("HatchLuckBuff") or 1) - 1),
            expiry = p:GetAttribute("HatchLuckBuffUntil") or 0,
        },
    }, now, axis("luck"))
    self:_setMult(
        "luck",
        luck,
        axis("luck").cap,
        soonestRemaining(p, { "LuckBuffUntil", "LuckBuffPotionUntil", "HatchLuckBuffUntil" }, now)
    )

    -- targeted channels (events/powers set <X>LuckBuff multiplier attrs + Until):
    -- visible ONLY while non-neutral, so the panel stays compact day-to-day
    local channels = {
        golden_luck = "GoldenLuckBuff",
        rainbow_luck = "RainbowLuckBuff",
        huge_luck = "HugeLuckBuff",
    }
    for _, pb in ipairs(self._presenceBuffs or {}) do
        channels[pb.key] = pb.attr
    end
    for key, attr in pairs(channels) do
        local untilT = p:GetAttribute(attr .. "Until") or 0
        local mult = (untilT > now) and (tonumber(p:GetAttribute(attr)) or 1) or 1
        local row = self.rows[key]
        if row then
            row.row.Visible = mult > 1.0001
            if mult > 1.0001 then
                self:_setMult(key, mult, 4, math.max(0, untilT - now))
            end
        end
    end

    -- 🐾 Speed (power + potion ADD on the axis).
    local speed = BuffStack.multiplier({
        {
            fraction = p:GetAttribute("MoveSpeedBuff") or 0,
            expiry = p:GetAttribute("MoveSpeedBuffUntil") or 0,
        },
        {
            fraction = p:GetAttribute("MoveSpeedBuffPotion") or 0,
            expiry = p:GetAttribute("MoveSpeedBuffPotionUntil") or 0,
        },
    }, now, axis("move_speed"))
    self:_setMult(
        "speed",
        speed,
        axis("move_speed").cap,
        soonestRemaining(p, { "MoveSpeedBuffUntil", "MoveSpeedBuffPotionUntil" }, now)
    )

    -- ⚡ Recharge (cooldown reduction, clamped — shown as -N% CD).
    local rFrac = 0
    if (p:GetAttribute("RechargeBuffUntil") or 0) > now then
        rFrac = math.clamp(p:GetAttribute("RechargeBuff") or 0, 0, RECHARGE_CLAMP)
    end
    self:_setRecharge("recharge", rFrac, soonestRemaining(p, { "RechargeBuffUntil" }, now))

    -- ✨ XP.
    local xp = BuffStack.multiplier({
        { fraction = p:GetAttribute("XpBuff") or 0, expiry = p:GetAttribute("XpBuffUntil") or 0 },
    }, now, axis("xp"))
    self:_setMult("xp", xp, axis("xp").cap, soonestRemaining(p, { "XpBuffUntil" }, now))

    -- 🧲 Magnet collect radius (base + the Magnet power's bonus, in studs).
    local magBase = tonumber(DropsConfig.collect_radius) or 11
    local magBonus = 0
    if (p:GetAttribute("MagnetBuffUntil") or 0) > now then
        magBonus = p:GetAttribute("MagnetBuff") or 0
    end
    self:_setRange("magnet", magBase, magBonus, soonestRemaining(p, { "MagnetBuffUntil" }, now))

    -- 👥/🌍 Team power in three layers (Jason: "team power in area and team power with
    -- buffs in area as well"): intrinsic Σ (zone-neutral — a buffer's 0.35 aptitude
    -- honestly drags it down), × the current zone's biome resonance, × the SAME
    -- pet_damage axis the attack row shows (exactly where buffs land in _mine). Each
    -- pip isolates one layer: squad size / net area % (can be negative!) / net buff %.
    local t = self:_teamPower()
    self:_setTeam("team", t.mine, t.combat, t.count > 0, 0, string.format("×%d", t.count))
    local areaPct = t.mine > 0 and (t.areaMine / t.mine - 1) or 0
    self:_setTeam(
        "team_area",
        t.areaMine,
        t.areaCombat,
        t.count > 0 and math.abs(areaPct) > 0.0001,
        math.abs(areaPct), -- bar = how much the zone is moving the needle
        string.format("%+d%%", math.floor(areaPct * 100 + 0.5))
    )
    self:_setTeam(
        "team_buffed",
        t.areaMine * atk,
        t.areaCombat * atk,
        t.count > 0 and atk > 1.0001,
        (atk - 1) / math.max(axis("pet_damage").cap or 1, 0.0001),
        string.format("+%d%%", math.floor((atk - 1) * 100 + 0.5))
    )

    -- 🎲 EV / Swing: accuracy + crit folded into the With-Buffs sums as expected-value
    -- multipliers (a probability is a damage multiplier you haven't averaged yet).
    -- Combat to-hit vs an EVEN-LEVEL enemy — the standard candle the training dummy
    -- measures; mining never misses. Crit chance mirrors _mine's additive channels
    -- (config base + CritBuff power + CritAura pet), same 0.9 cap.
    local accCfg = CombatConfig.accuracy
    local petAtkRoll = CombatConfig.engagement
        and CombatConfig.engagement.rolls
        and CombatConfig.engagement.rolls.pet_attack
    local lvl = p:GetAttribute("EffectiveLevel") or p:GetAttribute("Level") or 1
    local hitEven = Accuracy.combatToHit(lvl, lvl, accCfg)
    local hitMining = Accuracy.miningHitChance(accCfg)
    local critChance = (petAtkRoll and petAtkRoll.crit_chance) or 0
    if (p:GetAttribute("CritBuffUntil") or 0) > now then
        critChance = critChance + (p:GetAttribute("CritBuff") or 0)
    end
    if (p:GetAttribute("CritAuraUntil") or 0) > now then
        critChance = critChance + (p:GetAttribute("CritAura") or 0)
    end
    critChance = math.min(critChance, 0.9)
    local critEv = 1 + critChance * (((petAtkRoll and petAtkRoll.crit_mult) or 2) - 1)
    local evCombatMult = hitEven * critEv
    self:_setTeam(
        "team_ev",
        t.areaMine * atk * hitMining * critEv,
        t.areaCombat * atk * evCombatMult,
        t.count > 0 and math.abs(evCombatMult - 1) > 0.0001,
        math.abs(evCombatMult - 1),
        string.format("%+d%%", math.floor((evCombatMult - 1) * 100 + 0.5)) -- ⚔ net roll EV
    )

    -- 🛡 Toughness: team effective HP. Intrinsic = endurance pools on the armor curve
    -- with innate role defense + the pet's own Defense only; buffed folds DefenseBuff +
    -- TeamDefenseBuff onto the curve and adds live CombatShield pools flat (shields are
    -- additive temporary HP; armor is multiplicative and also scales every heal).
    local toughPct = t.pool > 0 and (t.ehp / t.pool - 1) or 0
    self:_setOne(
        "tough",
        t.ehp,
        t.count > 0 and t.ehp > t.pool + 0.5,
        math.min(toughPct, 1),
        string.format("+%d%%", math.floor(toughPct * 100 + 0.5)) -- EHP above the raw pool
    )
    local toughBuffPct = t.ehp > 0 and (t.ehpBuffed / t.ehp - 1) or 0
    self:_setOne(
        "tough_buffed",
        t.ehpBuffed,
        t.count > 0 and t.ehpBuffed > t.ehp + 0.5,
        math.min(toughBuffPct, 1),
        string.format("+%d%%", math.floor(toughBuffPct * 100 + 0.5)) -- buffs' EHP contribution
    )

    -- ⏱ THE PACING ROWS (Jason: "battles are way too fast... over before you realize
    -- they've started"; "a Lieutenant, a boss, three minions and maybe a team"; then
    -- "the only way to make this real is to SIMULATE it... what if my armor buffer
    -- dies? It is no longer armoring"): each dev-candle matchup is played for real by
    -- BattleSim N times — swing timers, hit/crit rolls, threat/taunt targeting, downs
    -- that take a dead pet's damage AND its auras out of the fight. Throttled: sims
    -- recompute every SIM_REFRESH seconds, the rows repaint from cache in between.
    if not self._nextSimAt or os.clock() >= self._nextSimAt then
        self._nextSimAt = os.clock() + 2
        self._simAgg = {}
        local cd = CombatConfig.dev_candle or {}
        local trials = tonumber(cd.trials) or 5
        local eRolls = CombatConfig.engagement
            and CombatConfig.engagement.rolls
            and CombatConfig.engagement.rolls.enemy_attack
        -- per-pet sim entries share the squad-wide roll + static-buff context
        local petInterval = PetCombat.attackInterval(1)
        local staticDmgFraction = math.max(0, (p:GetAttribute("PetDamageBuff") or 1) - 1)
        if (p:GetAttribute("PetDamageBuffUntil") or 0) <= now then
            staticDmgFraction = 0
        end
        local simPets = {}
        for _, s in ipairs(t.squad) do
            table.insert(simPets, {
                perHit = s.perHit,
                interval = petInterval,
                hitChance = hitEven,
                critChance = critChance,
                critMult = (
                    CombatConfig.engagement
                    and CombatConfig.engagement.rolls
                    and CombatConfig.engagement.rolls.pet_attack
                    and CombatConfig.engagement.rolls.pet_attack.crit_mult
                ) or 2,
                pool = s.pool,
                shield = s.shield,
                defense = s.defense,
                threatMult = s.threatMult,
                taunt = s.taunt,
                dmgBuffFraction = staticDmgFraction,
                auras = s.auras,
            })
        end
        for i, m in ipairs(self._matchups or {}) do
            local pack = {}
            for _, entry in ipairs(m.pack or {}) do
                local def = enemiesOk
                    and EnemiesConfig
                    and EnemiesConfig.enemies
                    and EnemiesConfig.enemies[entry.enemy]
                if def then
                    local atkDef = def.attack or {}
                    for _ = 1, math.max(1, math.floor(tonumber(entry.count) or 1)) do
                        table.insert(pack, {
                            hp = tonumber(def.hp) or 1,
                            armor = tonumber(def.armor) or 0,
                            dmg = tonumber(atkDef.damage) or 0,
                            cadence = tonumber(atkDef.cadence) or 1.5,
                            hitChance = hitEven, -- same-level candle, both directions
                            critChance = (eRolls and eRolls.crit_chance) or 0,
                            critMult = (eRolls and eRolls.crit_mult) or 2,
                        })
                    end
                end
            end
            if #pack > 0 and #simPets > 0 then
                self._simAgg[i] = BattleSim.runMany(
                    {
                        tick = tonumber(cd.tick) or 0.1,
                        max_seconds = tonumber(cd.max_seconds) or 90,
                        armor_k = CombatConfig.armor_curve_k or 100,
                        dmg_axis_cap = axis("pet_damage").cap,
                        pets = simPets,
                        enemies = pack,
                    },
                    trials,
                    function()
                        return math.random()
                    end
                )
            end
        end
    end
    for i in ipairs(self._matchups or {}) do
        local key = "battle_" .. i
        local agg = self._simAgg and self._simAgg[i]
        if agg then
            self:_setBattle(key, agg, lvl)
        else
            local row = self.rows[key]
            if row then
                self:_style(row, false, 0, nil)
                row.text.Text = row.label .. ": —"
            end
        end
    end
end

-- Σ over the player's DEPLOYED pets of the dealt-chain power profile — the same resolver
-- the inventory card and the server damage path run (PetPowerView.profile, #132). One
-- profile call per pet yields both layers: miningBase/combatBase are the intrinsic
-- (zone-neutral) numbers, miningEffective/combatEffective the zone-resonant ones (the
-- pet's own element vs the current zone, so a mixed squad shifts unevenly). base = the
-- pet's server-stamped Power value (huge/level/eternal-resolved). Downed pets are out
-- healing (they neither mine nor fight — _mine skips them), so they contribute nothing.
function BuffStatsHud:_teamPower()
    local t = {
        mine = 0,
        combat = 0,
        areaMine = 0,
        areaCombat = 0,
        count = 0,
        -- defensive side: raw endurance pool, intrinsic EHP, buffed EHP (+ shields)
        pool = 0,
        ehp = 0,
        ehpBuffed = 0,
        -- per-pet snapshots for the BattleSim pacing rows
        squad = {},
    }
    local pp = Workspace:FindFirstChild("PlayerPets")
    local folder = pp and pp:FindFirstChild(self.player.Name)
    if not folder then
        return t
    end
    local nowT = os.time()
    local k = CombatConfig.armor_curve_k or 100
    local downFactor = CombatConfig.pet_down_threshold_factor or 1
    for _, m in ipairs(folder:GetChildren()) do
        local powerNV = m:IsA("Model") and m:FindFirstChild("Power")
        if powerNV and not m:GetAttribute("CombatDowned") then
            local petType = m:GetAttribute("PetType")
            local ok, profile = pcall(function()
                return PetPowerView.profile({
                    base = powerNV.Value,
                    petType = petType,
                    variant = m:GetAttribute("PetVariant"),
                    role = m:GetAttribute("PetRole"),
                    context = { zone = zoneResonanceFor(self.player, petType) },
                })
            end)
            if ok and profile then
                t.mine += profile.miningBase or 0
                t.combat += profile.combatBase or 0
                t.areaMine += profile.miningEffective or 0
                t.areaCombat += profile.combatEffective or 0
                t.count += 1
            end
            -- EHP (mirrors EnemyService:_hitPet): the pool is the endurance threshold
            -- (Power × pet_down_threshold_factor); armor curve turns Defense into a
            -- multiplicative EHP factor (D+k)/k; live CombatShield pools add flat.
            local pool = (tonumber(powerNV.Value) or 0) * downFactor
            local defense = roleDefenseFor(m) + (m:GetAttribute("Defense") or 0)
            local ownDefBuff = 0
            if (m:GetAttribute("DefenseBuffUntil") or 0) > nowT then
                ownDefBuff = m:GetAttribute("DefenseBuff") or 0
            end
            local defenseBuffed = defense + ownDefBuff
            if (m:GetAttribute("TeamDefenseBuffUntil") or 0) > nowT then
                defenseBuffed += m:GetAttribute("TeamDefenseBuff") or 0
            end
            t.pool += pool
            t.ehp += pool * (defense + k) / k
            t.ehpBuffed += pool * (defenseBuffed + k) / k + (m:GetAttribute("CombatShield") or 0)
            -- BattleSim snapshot: defense EXCLUDES the live TeamDefenseBuff stamp — the
            -- sim re-derives that from the buffer pet's aura so it can DIE mid-fight
            -- (Jason: "what if my armor buffer dies? It is no longer armoring").
            if ok and profile then
                local roleDef = roleDefFor(m)
                table.insert(t.squad, {
                    perHit = profile.combatEffective or 1,
                    pool = pool,
                    shield = m:GetAttribute("CombatShield") or 0,
                    defense = defense + ownDefBuff,
                    threatMult = tonumber(roleDef.threat_mult) or 1,
                    taunt = roleDef.implicit_taunt == true,
                    variantMult = variantEffectMultFor(m), -- rage scales by this in-sim
                    auras = simAurasFor(m),
                })
            end
        end
    end
    return t
end

-- ---- row writers --------------------------------------------------------

-- Shared styling: active rows show full color; base rows dim to grey. `frac01` drives the fill bar.
function BuffStatsHud:_style(row, active, frac01, rem)
    row.text.TextColor3 = active and Color3.fromRGB(245, 245, 250) or Color3.fromRGB(120, 124, 140)
    row.fill.Size = UDim2.new(active and math.clamp(frac01, 0.04, 1) or 0, 0, 1, 0)
    if active and rem then
        local blink = rem <= BLINK_LEAD and not self._blinkOn
        row.pip.Text = blink and "" or string.format("%ds", math.ceil(rem))
        row.pip.TextColor3 = rem <= BLINK_LEAD and Color3.fromRGB(255, 180, 90)
            or Color3.fromRGB(210, 215, 230)
    else
        row.pip.Text = active and "∞" or ""
    end
end

function BuffStatsHud:_setMult(key, mult, cap, rem)
    local row = self.rows[key]
    if not row then
        return
    end
    local active = mult > 1.0001
    local frac = (mult - 1) / math.max(cap or 1, 0.0001)
    self:_style(row, active, frac, rem)
    row.text.Text = string.format("%s: ×%.2f", row.label, mult)
end

function BuffStatsHud:_setDefense(key, flat, rem)
    local row = self.rows[key]
    if not row then
        return
    end
    local active = flat > 0
    local k = CombatConfig.armor_curve_k or 100
    local mitig = flat > 0 and (flat / (flat + k)) or 0
    -- bar scales toward a "heavy" reference of 50% mitigation so partial buffs read clearly.
    self:_style(row, active, mitig / 0.5, rem)
    row.text.Text = active
            and string.format("%s: +%d (%d%%)", row.label, flat, math.floor(mitig * 100 + 0.5))
        or string.format("%s: +0", row.label)
end

function BuffStatsHud:_setRecharge(key, frac, rem)
    local row = self.rows[key]
    if not row then
        return
    end
    local active = frac > 0.0001
    self:_style(row, active, frac / RECHARGE_CLAMP, rem)
    row.text.Text = active
            and string.format("%s: −%d%% CD", row.label, math.floor(frac * 100 + 0.5))
        or string.format("%s: −0%% CD", row.label)
end

-- Team-power rows: absolute ⛏/⚔ output sums, not multipliers. pipText replaces the timer
-- (squad size on the raw row; the net buff % on the buffed row — the balance verdict).
function BuffStatsHud:_setTeam(key, mine, combat, active, fillFrac, pipText)
    local row = self.rows[key]
    if not row then
        return
    end
    self:_style(row, active, fillFrac, nil)
    row.pip.Text = active and (pipText or "") or ""
    row.text.Text = string.format(
        "%s: ⛏ %d  ⚔ %d",
        row.label,
        math.floor(mine + 0.5),
        math.floor(combat + 0.5)
    )
end

-- Seconds for the battle clock: one decimal under 10s, whole above, ∞ when it never ends.
local function fmtSeconds(s)
    if s == math.huge then
        return "∞"
    elseif s < 10 then
        return string.format("%.1fs", s)
    end
    return string.format("%ds", math.floor(s + 0.5))
end

-- The pacing rows: BattleSim aggregate vs one matchup. Pip = wins/trials. The COLOR is
-- the VERDICT (Jason: "shouldn't it be green?"): green = every trial cleared with no
-- pets down, amber = wins but it cost pets (or a mixed record), red = mostly losses.
--   all wins   -> "⚔ <median clear>  ❤ <median pool left %>" (+ " ☠N" if pets went down)
--   mixed      -> "⚔ <median clear>  💀 <median die>"
--   all losses -> "💀 <median die>"  (timeout-dominated shows ⚔ ∞)
function BuffStatsHud:_setBattle(key, agg, candleLevel)
    local row = self.rows[key]
    if not row then
        return
    end
    local text
    if agg.winRate >= 1 then
        text = string.format(
            "⚔ %s  ❤ %d%%",
            fmtSeconds(agg.clearTime or math.huge),
            math.floor((agg.poolLeftFrac or 0) * 100 + 0.5)
        )
        if (agg.petsDown or 0) > 0 then
            text ..= string.format("  ☠%d", agg.petsDown)
        end
    elseif agg.winRate > 0 then
        text = string.format(
            "⚔ %s  💀 %s",
            fmtSeconds(agg.clearTime or math.huge),
            fmtSeconds(agg.dieTime or math.huge)
        )
    else
        text = agg.timeouts >= agg.trials and "⚔ ∞ (stalemate)"
            or string.format("💀 %s", fmtSeconds(agg.dieTime or math.huge))
    end
    if agg.winRate >= 1 and (agg.petsDown or 0) == 0 then
        row.fill.BackgroundColor3 = Color3.fromRGB(110, 210, 130) -- clean sweep
    elseif agg.winRate >= 0.5 then
        row.fill.BackgroundColor3 = Color3.fromRGB(240, 200, 70) -- costly / shaky
    else
        row.fill.BackgroundColor3 = Color3.fromRGB(235, 90, 80) -- losing record
    end
    self:_style(row, true, agg.winRate, nil)
    row.pip.Text = string.format("%d/%d L%d", agg.wins, agg.trials, candleLevel or 1)
    row.text.Text = string.format("%s: %s", row.label, text)
end

-- Single-value team rows (Toughness EHP): one number, pip carries the layer's contribution.
function BuffStatsHud:_setOne(key, value, active, fillFrac, pipText)
    local row = self.rows[key]
    if not row then
        return
    end
    self:_style(row, active, fillFrac, nil)
    row.pip.Text = active and (pipText or "") or ""
    row.text.Text = string.format("%s: %d", row.label, math.floor(value + 0.5))
end

-- Magnet collect RADIUS in studs (base + Magnet power bonus) — not a multiplier. Bar scales the
-- bonus against the base (a +base bonus = full bar).
function BuffStatsHud:_setRange(key, base, bonus, rem)
    local row = self.rows[key]
    if not row then
        return
    end
    local active = bonus > 0.0001
    self:_style(row, active, bonus / math.max(base, 1), rem)
    row.text.Text = active
            and string.format(
                "%s: %d studs (+%d)",
                row.label,
                math.floor(base + bonus + 0.5),
                math.floor(bonus + 0.5)
            )
        or string.format("%s: %d studs", row.label, math.floor(base + 0.5))
end

return BuffStatsHud
