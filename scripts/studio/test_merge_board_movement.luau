-- Actual production speed/first-use methods on isolated doubles; never touches player saves.
local module = game.ServerScriptService.Server.Services.HoverboardService
local shared = game.ReplicatedStorage.Shared.Game
local logic = assert(
    loadstring(
        shared.HoverboardLogic.Source:gsub(
            "local HallOfWorldsLogic = require%(script.Parent.HallOfWorldsLogic%)",
            "local HallOfWorldsLogic = {}"
        )
    )
)()
local function method(name)
    local source = module.Source
    local first = assert(source:find("function HoverboardService:" .. name .. "(", 1, true))
    local last = source:find("\nfunction HoverboardService:", first + 1, true)
        or source:find("\nreturn HoverboardService", first + 1, true)
        or #source + 1
    return assert(
        loadstring(
            "local HoverboardLogic=...\nlocal ReplicatedStorage=game.ReplicatedStorage\nlocal HoverboardService={}\n"
                .. "local function require(module) return assert(loadstring(module.Source))() end\n"
                .. source:sub(first, last - 1)
                .. "\nreturn HoverboardService."
                .. name
        )
    )(logic)
end
local cfg = assert(loadstring(game.ReplicatedStorage.Configs.hoverboard.Source))()
local attrs, saves = { Eff_Speed = 1 }, 0
local character = Instance.new("Model")
local humanoid = Instance.new("Humanoid", character)
local player = {
    Character = character,
    GetAttribute = function(_, key)
        return attrs[key]
    end,
    SetAttribute = function(_, key, value)
        attrs[key] = value
    end,
}
local save = { equipped = cfg.default_skin, speed_scale = 1 }
local service = {
    _config = cfg,
    _configLoader = {
        LoadConfig = function(_, name)
            return assert(loadstring(game.ReplicatedStorage.Configs[name].Source))()
        end,
    },
    _dataService = {
        RequestSave = function()
            saves += 1
        end,
    },
    _save = function()
        return save
    end,
    GetSave = function()
        return save
    end,
}
service._setMounted = method("_setMounted")
service._applySpeed = method("_applySpeed")
service:_setMounted(player, false)
assert(humanoid.WalkSpeed == 24 and saves == 0)
attrs.Eff_Speed = 2
service:_applySpeed(player)
assert(humanoid.WalkSpeed == 48)
service:_setMounted(player, true)
assert(humanoid.WalkSpeed == 64 and saves == 1 and save.first_use_complete == true)
assert(attrs.HoverboardFirstUseComplete == true)
service:_setMounted(player, false)
assert(humanoid.WalkSpeed == 48 and save.first_use_complete == true)
service:_setMounted(player, true)
assert(saves == 1, "Mounting again must not write another first-use receipt")
character:Destroy()
return "PASS: Merge walk 24, buff 48, board 64, dismount 48, successful-use receipt saved once"
