--!strict

-- Pure decision policy for inventory pet thumbnails. A configured asset id is not proof that the
-- client actually received its pixels; Roblox can report a terminal delivery failure after the card
-- exists. Keeping this policy pure makes every terminal state headless-testable.
local PetThumbnailFetchPolicy = {}

export type Action = "flat" | "viewport" | "emergency" | "pending" | "wait_for_bake"

function PetThumbnailFetchPolicy.action(
    statusName: string,
    hasBakedViewport: boolean,
    bakedThumbnailsReady: boolean
): Action
    if statusName == "Success" then
        return "flat"
    end
    if statusName ~= "Failure" and statusName ~= "TimedOut" then
        return "pending"
    end
    if hasBakedViewport then
        return "viewport"
    end
    if bakedThumbnailsReady then
        return "emergency"
    end
    return "wait_for_bake"
end

return PetThumbnailFetchPolicy
