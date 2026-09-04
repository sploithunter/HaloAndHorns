--!strict

local AchievementBannerController = {}

local started = false

function AchievementBannerController.start()
    if started then
        return
    end
    started = true
    require(script.Parent.AchievementBannerRenderer).start()
    require(script.Parent.AchievementBannerFlutter).start()
    require(script.Parent.AchievementBannerCeremony).start()
end

return AchievementBannerController
