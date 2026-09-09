-- Keep Farm onboarding dormant until its gate is actually used.
local Gate = {}
function Gate.pending(enabled, isMain, inCrossroads, farmEntered)
    return enabled == true and isMain == true and (inCrossroads == true or farmEntered ~= true)
end
return Gate
