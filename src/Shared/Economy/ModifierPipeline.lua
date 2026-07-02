local ModifierPipeline = {}

local function normalizeContributions(raw)
    if raw == nil then
        return {}
    end

    if type(raw) == "number" then
        return {
            {
                amount = raw,
                label = "anonymous",
            },
        }
    end

    if type(raw) ~= "table" then
        return {}
    end

    if raw.amount ~= nil then
        return { raw }
    end

    return raw
end

local function applyContribution(value, combineMode, amount)
    if combineMode == "add" then
        return value + amount
    elseif combineMode == "multiply" then
        return value * amount
    elseif combineMode == "override" then
        return amount
    elseif combineMode == "cap" then
        return math.min(value, amount)
    end

    error("Unknown modifier combine mode: " .. tostring(combineMode))
end

function ModifierPipeline.Resolve(baseValue, context, providers, pipelineConfig)
    context = context or {}
    providers = providers or {}
    pipelineConfig = pipelineConfig or {}

    local stageOrder = pipelineConfig.stage_order or {}
    local stages = pipelineConfig.stages or {}
    local value = baseValue
    local breakdown = {
        base = baseValue,
        stages = {},
        final = baseValue,
    }

    for _, stageName in ipairs(stageOrder) do
        if stageName ~= "base" then
            local stageConfig = stages[stageName] or {}
            local combineMode = stageConfig.combine or "multiply"
            local provider = providers[stageName]
            local raw = nil

            if type(provider) == "function" then
                raw = provider(context)
            elseif provider ~= nil then
                raw = provider
            end

            local contributions = normalizeContributions(raw)
            local stageBefore = value
            local applied = {}

            for _, contribution in ipairs(contributions) do
                local amount = contribution.amount
                if type(amount) == "number" then
                    value = applyContribution(value, contribution.combine or combineMode, amount)
                    table.insert(applied, {
                        label = contribution.label or contribution.id or "anonymous",
                        amount = amount,
                        combine = contribution.combine or combineMode,
                        before = stageBefore,
                        after = value,
                    })
                    stageBefore = value
                end
            end

            table.insert(breakdown.stages, {
                stage = stageName,
                combine = combineMode,
                before = breakdown.final,
                after = value,
                contributions = applied,
            })
            breakdown.final = value
        end
    end

    return value, breakdown
end

return ModifierPipeline
