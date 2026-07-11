local RuntimeServiceBindings = {}

local services

function RuntimeServiceBindings.configure(bindings)
    assert(services == nil, "RuntimeServiceBindings may only be configured once")
    services = {
        GameAPIService = assert(bindings.GameAPIService, "GameAPIService binding is required"),
        ModifierService = bindings.ModifierService,
        PetFollowService = assert(
            bindings.PetFollowService,
            "PetFollowService binding is required"
        ),
    }
end

function RuntimeServiceBindings.getGameAPIService()
    return services and services.GameAPIService or nil
end

function RuntimeServiceBindings.getModifierService()
    return services and services.ModifierService or nil
end

function RuntimeServiceBindings.getPetFollowService()
    return services and services.PetFollowService or nil
end

return RuntimeServiceBindings
