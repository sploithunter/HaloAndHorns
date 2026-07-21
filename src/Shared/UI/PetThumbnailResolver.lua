--!strict

-- Pure lookup shared by every pet-card surface. Uploaded flat art is keyed by pet id and
-- variant; Huge pets prefer their close-up image but safely fall back to the normal variant.
local PetThumbnailResolver = {}

function PetThumbnailResolver.resolve(registry, petType, variant, huge)
    if type(registry) ~= "table" or type(registry.pets) ~= "table" then
        return nil
    end
    if type(petType) ~= "string" or petType == "" then
        return nil
    end

    variant = if type(variant) == "string" and variant ~= "" then variant else "basic"
    local byVariant = registry.pets[petType]
    if type(byVariant) ~= "table" then
        return nil
    end

    return (huge == true and byVariant[variant .. "__huge"]) or byVariant[variant]
end

return PetThumbnailResolver
