--[[
    UpgradeService

    Server-authoritative permanent upgrade purchases. Upgrade definitions live in
    configs/upgrades.lua; profile state stores only levels by upgrade id.
]]

local Players = game:GetService("Players")

local UpgradeService = {}
UpgradeService.__index = UpgradeService

local DATA_READY_TIMEOUT_SECONDS = 10

function UpgradeService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._dataService = self._modules.DataService
    self._modifierService = self._modules.ModifierService
    self._upgradesConfig = self._configLoader:LoadConfig("upgrades")
    self._inventoryConfig = self._configLoader:LoadConfig("inventory")

    if self._modifierService and self._modifierService.RegisterProvider then
        self._modifierService:RegisterProvider("permanent_upgrades", function(context)
            return self:_getModifierContributions(context)
        end)
    end

    self._logger:Info("UpgradeService initialized", {
        upgradeCount = self:_countUpgrades(),
    })
end

function UpgradeService:Start()
    self:_setupNetworkSignals()

    Players.PlayerAdded:Connect(function(player)
        self:_applyInventoryEffectsWhenReady(player)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        self:_applyInventoryEffectsWhenReady(player)
    end
end

function UpgradeService:_setupNetworkSignals()
    local Signals = require(game:GetService("ReplicatedStorage").Shared.Network.Signals)
    Signals.PurchaseUpgrade.OnServerEvent:Connect(function(player, payload)
        payload = type(payload) == "table" and payload or {}
        local result = self:PurchaseUpgrade(player, payload.upgradeId)
        Signals.UpgradeResult:FireClient(player, result)
    end)
end

function UpgradeService:_countUpgrades()
    local count = 0
    for _ in pairs(self._upgradesConfig.upgrades or {}) do
        count += 1
    end
    return count
end

function UpgradeService:_applyInventoryEffectsWhenReady(player)
    task.spawn(function()
        local waited = 0
        while not self._dataService:IsDataLoaded(player) and waited < DATA_READY_TIMEOUT_SECONDS do
            task.wait(0.1)
            waited += 0.1
        end

        if self._dataService:IsDataLoaded(player) then
            self:ApplyInventoryEffects(player)
        end
    end)
end

function UpgradeService:GetUpgradeConfig(upgradeId)
    return self._upgradesConfig.upgrades and self._upgradesConfig.upgrades[upgradeId]
end

function UpgradeService:GetUpgradeLevel(player, upgradeId)
    local data = self._dataService:GetData(player)
    local upgrades = data and data.Upgrades
    return tonumber(upgrades and upgrades[upgradeId]) or 0
end

function UpgradeService:GetUpgradeCost(player, upgradeId)
    local upgrade = self:GetUpgradeConfig(upgradeId)
    if not upgrade then
        return nil, "unknown_upgrade"
    end

    local currentLevel = self:GetUpgradeLevel(player, upgradeId)
    if currentLevel >= upgrade.max_level then
        return nil, "max_level"
    end

    local cost = upgrade.cost or {}
    local amount
    if cost.type == "linear" then
        amount = (cost.base or 0) + ((cost.increment or 0) * currentLevel)
    elseif cost.type == "exponential" then
        amount = (cost.base or 0) * ((cost.growth or 1) ^ currentLevel)
    else
        return nil, "invalid_cost_curve"
    end

    return {
        currency = cost.currency,
        amount = math.max(0, math.floor(amount + 0.5)),
        nextLevel = currentLevel + 1,
        currentLevel = currentLevel,
    }
end

function UpgradeService:GetUpgradeEffectTotal(player, effectType, targetId)
    local total = 0
    local data = self._dataService:GetData(player)
    local levels = data and data.Upgrades
    if type(levels) ~= "table" then
        return total
    end

    for upgradeId, upgrade in pairs(self._upgradesConfig.upgrades or {}) do
        local level = tonumber(levels[upgradeId]) or 0
        if level > 0 then
            for _, effect in ipairs(upgrade.effects or {}) do
                local matchesTarget = false
                if effect.type == "equip_slots" then
                    matchesTarget = effect.category == targetId
                elseif effect.type == "storage_slots" then
                    matchesTarget = effect.bucket == targetId
                end

                if effect.type == effectType and matchesTarget then
                    total += (tonumber(effect.amount_per_level) or 0) * level
                end
            end
        end
    end

    return total
end

function UpgradeService:PurchaseUpgrade(player, upgradeId)
    local upgrade = self:GetUpgradeConfig(upgradeId)
    if not upgrade then
        return {
            ok = false,
            reason = "unknown_upgrade",
            upgradeId = upgradeId,
        }
    end

    local data = self._dataService:GetData(player)
    if not data then
        return {
            ok = false,
            reason = "data_not_loaded",
            upgradeId = upgradeId,
        }
    end

    data.Upgrades = data.Upgrades or {}
    local currentLevel = tonumber(data.Upgrades[upgradeId]) or 0
    if currentLevel >= upgrade.max_level then
        return {
            ok = false,
            reason = "max_level",
            upgradeId = upgradeId,
            level = currentLevel,
        }
    end

    local cost, costError = self:GetUpgradeCost(player, upgradeId)
    if not cost then
        return {
            ok = false,
            reason = costError or "invalid_cost",
            upgradeId = upgradeId,
        }
    end

    if cost.amount > 0 and not self._dataService:CanAfford(player, cost.currency, cost.amount) then
        return {
            ok = false,
            reason = "insufficient_currency",
            upgradeId = upgradeId,
            currency = cost.currency,
            cost = cost.amount,
            level = currentLevel,
        }
    end

    if cost.amount > 0 then
        self._dataService:RemoveCurrency(player, cost.currency, cost.amount, "upgrade_purchase")
    end

    local newLevel = currentLevel + 1
    data.Upgrades[upgradeId] = newLevel
    self:ApplyInventoryEffects(player)
    self._dataService:RequestSave(player, "upgrade_purchase_" .. tostring(upgradeId), {
        critical = true,
    })

    self._logger:Info("Upgrade purchased", {
        player = player.Name,
        upgradeId = upgradeId,
        level = newLevel,
        currency = cost.currency,
        cost = cost.amount,
    })

    return {
        ok = true,
        upgradeId = upgradeId,
        level = newLevel,
        maxLevel = upgrade.max_level,
        currency = cost.currency,
        cost = cost.amount,
    }
end

function UpgradeService:ApplyInventoryEffects(player)
    local data = self._dataService:GetData(player)
    if not data or type(data.Inventory) ~= "table" then
        return false
    end

    local changed = false
    for bucketName, bucketConfig in pairs(self._inventoryConfig.buckets or {}) do
        local bucket = data.Inventory[bucketName]
        if type(bucket) == "table" then
            local baseLimit = tonumber(bucketConfig.base_limit) or 0
            local extraSlots = self:GetUpgradeEffectTotal(player, "storage_slots", bucketName)
            local targetSlots = baseLimit + extraSlots
            if targetSlots > 0 and (tonumber(bucket.total_slots) or 0) < targetSlots then
                bucket.total_slots = targetSlots
                changed = true
            end
        end
    end

    if changed then
        self._dataService:RequestSave(player, "upgrade_inventory_effects", { critical = true })
    end

    return changed
end

function UpgradeService:_getModifierContributions(context)
    if type(context) ~= "table" or not context.player then
        return {}
    end

    local data = self._dataService:GetData(context.player)
    local levels = data and data.Upgrades
    if type(levels) ~= "table" then
        return {}
    end

    local contributions = {}
    for upgradeId, upgrade in pairs(self._upgradesConfig.upgrades or {}) do
        local level = tonumber(levels[upgradeId]) or 0
        if level > 0 then
            for _, effect in ipairs(upgrade.effects or {}) do
                local kindMatches = effect.kind == nil or effect.kind == context.kind
                local currencyMatches = effect.currency == nil
                    or effect.currency == context.currency
                if effect.type == "modifier" and kindMatches and currencyMatches then
                    table.insert(contributions, {
                        id = upgradeId,
                        label = upgrade.display_name or upgradeId,
                        combine = effect.combine,
                        amount = 1 + ((tonumber(effect.amount_per_level) or 0) * level),
                    })
                end
            end
        end
    end

    return contributions
end

return UpgradeService
