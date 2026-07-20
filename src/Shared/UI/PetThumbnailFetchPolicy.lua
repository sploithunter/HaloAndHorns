--!strict

-- Pure decision policy for inventory pet thumbnails. Flat images are the only steady-state card
-- renderer; a 3D viewport is constructed lazily only after a terminal delivery failure.
local PetThumbnailFetchPolicy = {}

export type Action = "flat" | "lazy_3d" | "pending"

function PetThumbnailFetchPolicy.action(statusName: string): Action
    if statusName == "Success" then
        return "flat"
    end
    if statusName == "Failure" or statusName == "TimedOut" then
        return "lazy_3d"
    end
    return "pending"
end

function PetThumbnailFetchPolicy.needsCachedBake(hasFlatThumbnail: boolean): boolean
    return not hasFlatThumbnail
end

return PetThumbnailFetchPolicy
