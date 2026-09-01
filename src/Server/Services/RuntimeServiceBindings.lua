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
        AdminToolsService = bindings.AdminToolsService,
        MergeEggPrototypeService = bindings.MergeEggPrototypeService,
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

function RuntimeServiceBindings.getAdminToolsService()
    return services and services.AdminToolsService or nil
end

function RuntimeServiceBindings.getMergeEggPrototypeService()
    return services and services.MergeEggPrototypeService or nil
end

return RuntimeServiceBindings
