-- Pure observer scheduling. This never schedules server combat or owning-player movement.
local PetPresentationBudget = {}

function PetPresentationBudget.step(elapsed, dt, nearby, config)
    local pending = elapsed + dt
    if not config or config.enabled ~= true or nearby then
        return true, 0, pending
    end
    if pending >= config.distant_interval then
        return true, 0, pending
    end
    return false, pending, 0
end

return PetPresentationBudget
