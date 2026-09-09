-- A side change records intent; it cannot replace a line in an active conversation.
local Flow = {}
Flow.__index = Flow
function Flow.new(config)
    return setmetatable({ config = config, owner = "angel", seen = {} }, Flow)
end
function Flow:sync(progress)
    self.welcomed = self.welcomed or progress.welcome or progress.farm_visited
    self.seen.hell = self.seen.hell or progress.hell_handoff or progress.siege_visited
    self.seen.heaven = self.seen.heaven or progress.heaven_return or progress.farm_visited
end
function Flow:observe(side)
    if side == "hell" or side == "heaven" then
        self.side = side
    end
end
function Flow:nextSequence()
    self.sequenceKey = nil
    if not self.welcomed then
        self.welcomed = true
        self.sequenceKey = "welcome"
        return self.config.welcome
    end
    local side = self.side
    if side == "hell" then
        self.owner = "demon"
        if not self.seen.hell then
            self.seen.hell = true
            self.sequenceKey = "hell_handoff"
            return self.config.hell_handoff
        end
    elseif side == "heaven" then
        self.owner = "angel"
        if self.seen.hell and not self.seen.heaven then
            self.seen.heaven = true
            self.sequenceKey = "heaven_return"
            return self.config.heaven_return
        end
    end
    return nil
end
return Flow
