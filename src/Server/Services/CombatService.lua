--[[
    CombatService — Feature 10 (Combat System, Hell-focused).

    Server owner of combat resolution. Composes the pure cores (Targeting,
    CombatMath, FocusMath via CombatSim) with the live services so combat is
    config-driven and bus-testable:

      Simulate(opts)               — deterministic full-fight resolution (read-only;
                                     auto-target + damage + encounter-end + loot +
                                     sundering + pet-down, no state mutation).
      AwardLoot(player, enemyId)   — resolve a defeated enemy's drop table and
                                     credit the player (biome currency + tokens).
      SunderPlayer(player, enemyId)— apply the enemy attack's Focus drain (-> FocusService).
      DownPetInCombat(player,uid,enemyId)
                                   — down a pet at the enemy's tier (-> SpiritFormService,
                                     which auto-returns it from the active squad). This is
                                     the real "combat down" trigger deferred from Phase 3.

    Live enemy spawning, auto-attack traversal, and player-invulnerability visuals
    are [studio]/authored-map work (enemy spawner markers in a Hell combat zone);
    see docs/wiki/CURRENT_STATUS.md. The resolution math + economy/Spirit-Form/Focus
    interconnections are owned + verified here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Targeting = require(ReplicatedStorage.Shared.Game.Targeting)
local CombatMath = require(ReplicatedStorage.Shared.Game.CombatMath)
local FocusMath = require(ReplicatedStorage.Shared.Game.FocusMath)
local CombatSim = require(ReplicatedStorage.Shared.Game.CombatSim)
local PetCombat = require(ReplicatedStorage.Shared.Game.PetCombat)
local XpReward = require(ReplicatedStorage.Shared.Game.XpReward)
local LevelDiffYield = require(ReplicatedStorage.Shared.Game.LevelDiffYield)

local CombatService = {}
CombatService.__index = CombatService

function CombatService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._combatConfig = self._configLoader:LoadConfig("combat")
    self._enemiesConfig = self._configLoader:LoadConfig("enemies")
    self._focusConfig = self._configLoader:LoadConfig("focus")
    -- "Everything you do grants XP": defeating an enemy feeds the level bar (see AwardLoot).
    local okLvl, lvlCfg = pcall(function()
        return self._configLoader:LoadConfig("leveling")
    end)
    self._xpRewards = (okLvl and type(lvlCfg) == "table" and lvlCfg.xp_rewards) or {}
    self._xpLevelScale = okLvl and type(lvlCfg) == "table" and lvlCfg.xp_level_scale or nil
    -- LEVEL-based combat XP (not loot-based): scale off the enemy's effective level + rank.
    self._combatXp = (okLvl and type(lvlCfg) == "table" and lvlCfg.combat_xp) or {}
    self._combatCoins = (okLvl and type(lvlCfg) == "table" and lvlCfg.combat_coins) or {}
    self._deps = { Targeting = Targeting, CombatMath = CombatMath, FocusMath = FocusMath }
end

-- Runtime locators (these services may not be registered in every build).
function CombatService:_service(name)
    local locator = _G.RBXTemplateServices
    if not locator then
        return nil
    end
    local ok, service = pcall(function()
        return locator:Get(name)
    end)
    return ok and service or nil
end

function CombatService:_enemyDef(enemyId)
    return self._enemiesConfig.enemies[enemyId]
end

-- Expand a configured spawner into fight-ready enemy records (HP scaled by party
-- size), spread along +x so nearest-target selection is meaningful.
function CombatService:_expandSpawner(spawnerId, partySize)
    local spawner = self._combatConfig.spawners[spawnerId]
    if not spawner then
        return nil
    end
    local enemies = {}
    local x = 20
    for _, entry in ipairs(spawner.enemies) do
        local def = self:_enemyDef(entry.id)
        if def then
            for _ = 1, entry.count do
                table.insert(enemies, {
                    id = entry.id,
                    hp = CombatMath.groupScaledHp(def.hp, partySize or 1, self._combatConfig),
                    position = { x = x, y = 0, z = 0 },
                    attack = def.attack,
                    drop_table = def.drop_table,
                })
                x += 20
            end
        end
    end
    return enemies
end

-- Deterministic, read-only combat resolution. opts:
--   { spawner = "hell_1_lava", partySize?, petPowers = {..}, buff?, maxRounds?, focusStart? }
--   or { enemies = {..explicit records..}, petPowers = {..}, ... }
function CombatService:Simulate(opts)
    opts = opts or {}
    local partySize = opts.partySize or 1

    local enemies = opts.enemies
    if not enemies and opts.spawner then
        enemies = self:_expandSpawner(opts.spawner, partySize)
    end
    if not enemies then
        return { ok = false, reason = "no_enemies" }
    end

    local pets = {}
    for _, power in ipairs(opts.petPowers or {}) do
        table.insert(pets, { power = power })
    end
    if #pets == 0 then
        return { ok = false, reason = "no_pets" }
    end

    local scenario = {
        enemies = enemies,
        pets = pets,
        buff = opts.buff,
        maxRounds = opts.maxRounds,
        focusStart = opts.focusStart,
    }
    local report = CombatSim.run(
        scenario,
        self._deps,
        { combat = self._combatConfig, focus = self._focusConfig }
    )
    report.spawner = opts.spawner
    return report
end

-- Credit a defeated enemy's deterministic drops to the player (Feature 10:
-- "loot includes biome currency + Shadow Tokens in Hell").
function CombatService:AwardLoot(player, enemyId, enemyLevel, enemyTier)
    -- Pet-INVADER enemies (petinv_*, synthesized at spawn from the opposing realm's pets) have NO
    -- entry in the static enemies config — and the REALMS are populated almost entirely by them. Their
    -- Level AND elite Tier are stamped on the model and passed in here, so a def-less invader is still
    -- fully resolvable: rank-scaled XP + coins. `tier` below = static def.tier → the stamped model tier
    -- → trash_mob, so a boss invader finally pays boss rates (was flat trash — the fix we skipped).
    local def = self:_enemyDef(enemyId)
    if not def then
        -- No STATIC def. Pet-invaders are def-less BY DESIGN and carry a stamped tier, so they're
        -- handled. Only warn when we have NEITHER a def NOR a passed tier — a GENUINELY unknown enemy
        -- (a real config gap, Jason: those should always warn), once per id so it never floods.
        if not enemyTier then
            self._unknownEnemyWarned = self._unknownEnemyWarned or {}
            if not self._unknownEnemyWarned[enemyId] then
                self._unknownEnemyWarned[enemyId] = true
                warn(
                    string.format(
                        "[CombatService] AwardLoot: unknown enemy '%s' (no static def, no stamped tier) — level-only fallback. Wire a def/drop_table if it needs bespoke loot.",
                        tostring(enemyId)
                    )
                )
            end
        end
        def = {}
    end
    -- Resolved elite tier: static def wins, else the model-stamped tier (pet-invaders), else trash_mob.
    local tier = def.tier or enemyTier or "trash_mob"
    local loot = CombatMath.resolveLoot(def.drop_table or {})
    for currency, amount in pairs(loot) do
        self._dataService:AddCurrency(player, currency, amount, "combat_loot") -- coins unchanged
    end
    -- COIN FALLBACK for def-less kills (Jason: "you should drill coins also"). A pet-invader
    -- (petinv_*, the realm population) has no drop_table, so the loop above paid nothing. Pay a
    -- level-scaled coin in the player's CURRENT-AREA coin so realm combat earns like farming there.
    -- Only fires when the drop_table produced NOTHING — static enemies with a real table are
    -- untouched (no double-pay). effLevel is computed just below; resolve it here for the coin too.
    if next(loot) == nil then
        local cc = self._combatCoins or {}
        local perLevel = tonumber(cc.coins_per_level) or 0
        if perLevel > 0 then
            local coinLevel = tonumber(enemyLevel) or tonumber(def.level) or 1
            local coinRank = (cc.rank_coin_mult and cc.rank_coin_mult[tier]) or 1
            local coins = math.max(1, math.floor(coinLevel * perLevel * coinRank))
            -- Which coin? The player's current-area mining coin (the SSOT RewardService uses for
            -- "area_coins"). Falls back to grass_coins if the area is unknown.
            local rewardService = self:_service("RewardService")
            local currency = (
                rewardService
                and rewardService._resolveAreaCoin
                and rewardService:_resolveAreaCoin(player)
            ) or "grass_coins"
            self._dataService:AddCurrency(player, currency, coins, "combat_loot_realm")
            loot[currency] = (loot[currency] or 0) + coins
        end
    end
    -- Combat XP scales off the enemy's effective LEVEL + rank (NOT its coin drop), so reward tracks
    -- CHALLENGE and pays a premium over farming (configs/leveling.lua combat_xp). enemyLevel = the
    -- model's Level attribute — base + elite rank offset + the player's ±difficulty offset already
    -- baked in. rank_xp_mult adds a lieutenant/boss premium on top of their level. Floor 1 so any kill
    -- ticks the bar. AddExperience publishes the XP attribute -> the HUD level bar ticks live.
    local cx = self._combatXp or {}
    local effLevel = tonumber(enemyLevel) or tonumber(def.level) or 1
    local rankMult = (cx.rank_xp_mult and cx.rank_xp_mult[tier]) or 1
    local xp = XpReward.fromEnemyLevel(effLevel, cx.xp_per_level, rankMult)
    -- DIMINISHING XP vs out-leveled enemies (Jason: no overnight farm-leveling; same
    -- gate as mining). enemyLevel = the model's Level attribute (rank already baked).
    -- REALM RESCALE: the player's realm depth lifts the target level (layers.level_offsets) so
    -- realms keep paying XP instead of flooring a high-level player on arrival — parity with mining.
    local layerService = self:_service("LayerService")
    local realmLevelOffset = (
        layerService
        and layerService.GetLevelOffset
        and layerService:GetLevelOffset(player)
    ) or 0
    local baseXp = xp
    local diminish = LevelDiffYield.xp(
        player:GetAttribute("Level"),
        (enemyLevel or def.level or 1) + realmLevelOffset,
        self._xpLevelScale
    )
    xp = math.floor(xp * diminish)
    -- [CombatXP] trace (Jason balance pass): why did a kill pay what it paid? base = level×rate×rank
    -- before diminish; diminish = LevelDiffYield vs (enemy effLevel + realm offset). Gated on
    -- combat.combat_trace (leave in, flip the flag for a balancing pass).
    if self._combatConfig and self._combatConfig.combat_trace then
        print(
            string.format(
                "[CombatXP] %s tier=%s effLevel=%d base=%d playerLvl=%s realmOff=%s diminish=%.2f -> %d XP",
                tostring(enemyId),
                tostring(tier),
                effLevel,
                baseXp,
                tostring(player:GetAttribute("Level")),
                tostring(realmLevelOffset),
                diminish,
                xp
            )
        )
    end
    if xp > 0 then
        local progression = self:_service("PlayerProgressionService")
        if progression and progression.AddExperience then
            progression:AddExperience(player, xp)
        end
    end
    return { ok = true, loot = loot, xp = xp }
end

-- Apply this enemy attack's Sundering Focus drain to the player (Feature 12).
function CombatService:SunderPlayer(player, enemyId)
    local def = self:_enemyDef(enemyId)
    if not def then
        return { ok = false, reason = "unknown_enemy" }
    end
    local amount = CombatMath.sunderAmount(def.attack)
    local focusService = self:_service("FocusService")
    if not focusService then
        return { ok = false, reason = "service_unavailable" }
    end
    local result = focusService:Sunder(player, amount)
    result.amount = amount
    return result
end

-- The real "combat down" trigger (deferred from Phase 3): an enemy downs a pet,
-- which enters Spirit Form at the enemy's content tier and auto-returns from the
-- active squad (Features 7 + 9).
function CombatService:DownPetInCombat(player, uid, enemyId)
    local def = self:_enemyDef(enemyId)
    if not def then
        return { ok = false, reason = "unknown_enemy" }
    end
    local spirit = self:_service("SpiritFormService")
    if not spirit then
        return { ok = false, reason = "service_unavailable" }
    end
    local result = spirit:Down(player, uid, def.tier or "trash_mob")
    result.tier = def.tier
    return result
end

-- ── Pet work / mining damage (issue #4) ───────────────────────────────────
-- Single, service-owned source of truth for pet damage + cadence, replacing the
-- formula that used to live inline in the cloned PetScripts/Follow script. Pet
-- power flows through the ModifierService pipeline (pet_damage / pet_efficiency
-- stages), then the deterministic PetCombat rules are applied.

-- ctx: { power, petId, variant, breakableId, currency }
function CombatService:ResolvePetDamage(player, ctx)
    ctx = ctx or {}
    local power = ctx.power or 1
    local resolved = power
    local modifier = self:_service("ModifierService")
    if modifier and modifier.Resolve then
        local ok, value = pcall(function()
            return modifier:Resolve(power, {
                player = player,
                kind = "pet_damage",
                petId = ctx.petId,
                variant = ctx.variant,
                breakableId = ctx.breakableId,
                currency = ctx.currency,
                source = "PetWork",
            })
        end)
        if ok then
            resolved = tonumber(value) or power
        end
    end
    return PetCombat.damagePerHit(resolved)
end

-- Seconds to wait between this pet's hits, from the pet_efficiency pipeline.
function CombatService:ResolvePetAttackInterval(player, ctx)
    ctx = ctx or {}
    local efficiency = 1
    local modifier = self:_service("ModifierService")
    if modifier and modifier.Resolve then
        local ok, value = pcall(function()
            return modifier:Resolve(1, {
                player = player,
                kind = "pet_efficiency",
                petId = ctx.petId,
                variant = ctx.variant,
                source = "PetWork",
            })
        end)
        if ok then
            efficiency = tonumber(value) or 1
        end
    end
    return PetCombat.attackInterval(efficiency)
end

return CombatService
