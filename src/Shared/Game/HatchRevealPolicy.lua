--!strict

-- Pure source selection for hatch-result pet reveals. Uploaded flat art is the scalable primary
-- path; the legacy generated-instance marker is retained only for catalog entries missing flat art.
local HatchRevealPolicy = {}

HatchRevealPolicy.FALLBACK_IMAGE = "rbxasset://textures/face.png"

function HatchRevealPolicy.source(flatThumbnailId: unknown, hasGeneratedViewport: boolean): string
    if type(flatThumbnailId) == "string" and flatThumbnailId ~= "" then
        return flatThumbnailId
    end
    if hasGeneratedViewport then
        return "generated_image"
    end
    return HatchRevealPolicy.FALLBACK_IMAGE
end

return HatchRevealPolicy
