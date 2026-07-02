local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModifierPipeline = require(ReplicatedStorage.Shared.Economy.ModifierPipeline)

local ModifierService = {}
ModifierService.__index = ModifierService

function ModifierService:Init()
    self._logger = self._modules.Logger
    self._configLoader = self._modules.ConfigLoader
    self._providers = {}

    local economyConfig = self._configLoader:LoadConfig("economy")
    self._pipelineConfig = economyConfig.modifier_pipeline or {}

    self._logger:Info("ModifierService initialized", {
        stageCount = #(self._pipelineConfig.stage_order or {}),
        context = "ModifierService",
    })
end

function ModifierService:RegisterProvider(stageName, provider)
    if type(stageName) ~= "string" then
        error("Modifier provider stageName must be a string")
    end
    if
        type(provider) ~= "function"
        and type(provider) ~= "table"
        and type(provider) ~= "number"
    then
        error("Modifier provider must be a function, table, or number")
    end

    self._providers[stageName] = self._providers[stageName] or {}
    table.insert(self._providers[stageName], provider)
end

function ModifierService:_providerForStage(stageName)
    local providers = self._providers[stageName]
    if not providers or #providers == 0 then
        return nil
    end

    return function(context)
        local contributions = {}
        for _, provider in ipairs(providers) do
            local result
            if type(provider) == "function" then
                result = provider(context)
            else
                result = provider
            end

            if type(result) == "table" and result.amount == nil then
                for _, entry in ipairs(result) do
                    table.insert(contributions, entry)
                end
            elseif result ~= nil then
                table.insert(contributions, result)
            end
        end
        return contributions
    end
end

function ModifierService:Resolve(baseValue, context)
    local providers = {}

    for _, stageName in ipairs(self._pipelineConfig.stage_order or {}) do
        providers[stageName] = self:_providerForStage(stageName)
    end

    return ModifierPipeline.Resolve(baseValue, context, providers, self._pipelineConfig)
end

return ModifierService
