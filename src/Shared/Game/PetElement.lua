--[[
    PetElement (pure) — Feature 5.

    Element assignment at hatch is determined by the layer the hatch happened on
    (base → neutral, Heaven → light, Hell → shadow; chaotic is fusion-only, never
    at hatch). Realm eggs hatch distinct pet IDs/species, so element is metadata
    on the owned record rather than a stack-key axis. Mappings are config-driven
    (configs/layers.lua).
]]

local PetElement = {}

-- Element a pet is born with when hatched on `layer` (default neutral).
function PetElement.elementForLayer(layer, layersConfig)
    local map = layersConfig and layersConfig.hatch_element
    return (map and map[layer]) or "neutral"
end

-- Realm alignment of a layer ("neutral"/"heaven"/"hell"), default neutral.
function PetElement.realmAlignmentForLayer(layer, layersConfig)
    local map = layersConfig and layersConfig.realm_alignment
    return (map and map[layer]) or "neutral"
end

-- Legacy helper retained for pure tests and callers that need a species key. Element is
-- intentionally ignored: base/Heaven/Hell content uses different pet ids instead.
function PetElement.stackKey(petId, variant, element)
    local _ = element
    return table.concat({ petId, variant or "basic" }, ":")
end

return PetElement
