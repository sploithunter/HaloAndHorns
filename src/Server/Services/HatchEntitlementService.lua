local HatchEntitlementService = {}
HatchEntitlementService.__index = HatchEntitlementService

function HatchEntitlementService.new()
    local self = setmetatable({}, HatchEntitlementService)
    self._logger = nil
    self._configLoader = nil
    self._eggSystemConfig = nil
    return self
end

function HatchEntitlementService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._eggSystemConfig = self._configLoader:LoadConfig("egg_system")
    self._logger:Info("HatchEntitlementService initialized")
end

function HatchEntitlementService:GetHatchingConfig()
    local config = self._eggSystemConfig or {}
    return config.hatching or {}
end

function HatchEntitlementService:GetMaxHatchCount()
    local hatching = self:GetHatchingConfig()
    return math.clamp(math.floor(tonumber(hatching.max_count) or 99), 1, 99)
end

function HatchEntitlementService:GetDefinitions()
    return {
        autoHatch = {
            attribute = "AutoHatchUnlocked",
            label = "Auto Hatch",
            stub = "auto_hatch",
            type = "boolean",
        },
        goldenMode = {
            attribute = "GoldenHatchUnlocked",
            label = "Golden Mode",
            stub = "golden_mode",
            type = "boolean",
        },
        chargedMode = {
            attribute = "ChargedHatchUnlocked",
            label = "Charged Mode",
            stub = "charged_mode",
            type = "boolean",
        },
        fastHatch = {
            attribute = "FastHatchUnlocked",
            label = "Fast Hatch",
            stub = "fast_hatch",
            type = "boolean",
        },
        skipHatch = {
            attribute = "SkipHatchUnlocked",
            label = "Skip Hatch",
            stub = "skip_hatch",
            type = "boolean",
        },
        maxHatchCount = {
            attribute = "MaxEggHatchCount",
            label = "Max Hatch Count",
            stub = "max_hatch_count",
            type = "number",
        },
        luckBonus = {
            attribute = "HatchLuckBonus",
            label = "Hatch Luck Bonus",
            stub = "luck_bonus",
            type = "number",
        },
        secretLuckBonus = {
            attribute = "SecretHatchLuckBonus",
            label = "Secret Luck Bonus",
            stub = "secret_luck_bonus",
            type = "number",
        },
    }
end

function HatchEntitlementService:GetDefinition(entitlementId)
    return self:GetDefinitions()[entitlementId]
end

function HatchEntitlementService:GetStub(entitlementId)
    local definition = self:GetDefinition(entitlementId)
    local hatching = self:GetHatchingConfig()
    local stubs = hatching.shop_stubs or {}
    return definition and stubs[definition.stub] or nil
end

function HatchEntitlementService:GetDefault(entitlementId)
    local definition = self:GetDefinition(entitlementId)
    if not definition then
        return nil
    end

    local hatching = self:GetHatchingConfig()
    local stub = self:GetStub(entitlementId) or {}
    if definition.type == "boolean" then
        if stub.enabled == false then
            return false
        end
        return stub.owned_by_default == true
    end

    if entitlementId == "maxHatchCount" then
        local defaultValue = tonumber(stub.default_value)
            or tonumber(hatching.default_max_entitled_count)
            or self:GetMaxHatchCount()
        return math.clamp(math.floor(defaultValue), 1, self:GetMaxHatchCount())
    end

    return math.max(0, tonumber(stub.default_multiplier) or 0)
end

function HatchEntitlementService:GetEffective(player, entitlementId)
    local definition = self:GetDefinition(entitlementId)
    if not definition then
        return nil
    end

    local stub = self:GetStub(entitlementId) or {}
    if definition.type == "boolean" and stub.enabled == false then
        return false
    end

    local attributeValue = player:GetAttribute(definition.attribute)
    if attributeValue == nil then
        return self:GetDefault(entitlementId)
    end

    if definition.type == "boolean" then
        return attributeValue == true
    end

    if entitlementId == "maxHatchCount" then
        return math.clamp(
            math.floor(tonumber(attributeValue) or self:GetDefault(entitlementId)),
            1,
            self:GetMaxHatchCount()
        )
    end

    return math.max(0, tonumber(attributeValue) or self:GetDefault(entitlementId) or 0)
end

function HatchEntitlementService:Resolve(player)
    return {
        maxHatchCount = self:GetEffective(player, "maxHatchCount"),
        autoHatch = self:GetEffective(player, "autoHatch") == true,
        fastHatch = self:GetEffective(player, "fastHatch") == true,
        skipHatch = self:GetEffective(player, "skipHatch") == true,
        goldenMode = self:GetEffective(player, "goldenMode") == true,
        chargedMode = self:GetEffective(player, "chargedMode") == true,
        -- World S3 (depth = desirability): deeper realm layers add hatch luck on top of the
        -- player's own entitlements. LayerService publishes RealmHatchLuckBonus on layer change.
        luckBonus = (tonumber(self:GetEffective(player, "luckBonus")) or 0)
            + (tonumber(player:GetAttribute("RealmHatchLuckBonus")) or 0),
        secretLuckBonus = tonumber(self:GetEffective(player, "secretLuckBonus")) or 0,
    }
end

function HatchEntitlementService:BuildSnapshot(player)
    local snapshot = {}
    for entitlementId, definition in pairs(self:GetDefinitions()) do
        local value = player:GetAttribute(definition.attribute)
        snapshot[entitlementId] = {
            attribute = definition.attribute,
            label = definition.label,
            value = value,
            effective = self:GetEffective(player, entitlementId),
            default = self:GetDefault(entitlementId),
            type = definition.type,
        }
    end
    return snapshot
end

function HatchEntitlementService:SetPlayerOverride(player, entitlementId, value)
    local definition = self:GetDefinition(entitlementId)
    if not definition then
        return false, "Unknown hatch entitlement: " .. tostring(entitlementId)
    end

    if value == nil then
        player:SetAttribute(definition.attribute, nil)
        return true, string.format("Reset %s to config default", definition.label)
    end

    if definition.type == "number" then
        local numericValue = tonumber(value)
        if not numericValue then
            return false, string.format("%s requires a number", definition.label)
        end

        if entitlementId == "maxHatchCount" then
            numericValue = math.clamp(math.floor(numericValue), 1, self:GetMaxHatchCount())
        else
            numericValue = math.max(0, numericValue)
        end
        player:SetAttribute(definition.attribute, numericValue)
        return true, string.format("Set %s to %s", definition.label, tostring(numericValue))
    end

    player:SetAttribute(definition.attribute, value == true)
    return true, string.format("%s %s", value == true and "Unlocked" or "Locked", definition.label)
end

return HatchEntitlementService
