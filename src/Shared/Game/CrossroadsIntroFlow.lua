-- A side change records intent; it cannot replace a line in an active conversation.
local Flow = {}
Flow.__index = Flow
function Flow.new(config)
    return setmetatable({ config = config, owner = "angel", seen = {} }, Flow)
end
function Flow:observe(side)
    if side == "hell" or side == "heaven" then
        self.side = side
    end
end
function Flow:nextSequence()
    if not self.welcomed then
        self.welcomed = true
        return self.config.welcome
    end
    local side = self.side
    if side == "hell" then
        self.owner = "demon"
        if not self.seen.hell then
            self.seen.hell = true
            return self.config.hell_handoff
        end
    elseif side == "heaven" then
        self.owner = "angel"
        if self.seen.hell and not self.seen.heaven then
            self.seen.heaven = true
            return self.config.heaven_return
        end
    end
    return nil
end
return Flow
