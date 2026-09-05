-- Server-only identity registry. A facade is never accepted from a remote or confused with a
-- Roblox Player. Username-impossible names isolate every NPC folder from connected players.
local Actors = {}
local byId, byName = {}, {}

function Actors.get(id)
    return byId[tonumber(id)]
end

function Actors.named(name)
    return byName[name]
end

function Actors.is(actor)
    return type(actor) == "table" and byId[actor.UserId] == actor
end

function Actors.create(userId, name, displayName, parent)
    assert(not byId[userId], "offline account already registered")
    assert(name:find(" ", 1, true), "offline name must not collide with a username")
    local state = Instance.new("Folder")
    state.Name = name
    state.Parent = parent
    local removing = Instance.new("BindableEvent")
    removing.Parent = state
    local actor = {
        UserId = userId,
        Name = name,
        DisplayName = displayName,
        Parent = parent,
        OfflineActor = true,
        CharacterRemoving = removing.Event,
        State = state,
    }
    for _, method in ipairs({
        "GetAttribute",
        "SetAttribute",
        "GetAttributes",
        "GetAttributeChangedSignal",
        "FindFirstChild",
        "FindFirstChildOfClass",
        "WaitForChild",
        "GetChildren",
    }) do
        actor[method] = function(_, ...)
            return state[method](state, ...)
        end
    end
    actor.IsA = function()
        return false
    end
    actor.Destroy = function()
        if byId[userId] ~= actor then
            return
        end
        byId[userId], byName[name] = nil, nil
        actor.Parent = nil
        removing:Fire()
        if actor.Character then
            actor.Character:Destroy()
        end
        state:Destroy()
    end
    byId[userId], byName[name] = actor, actor
    actor:SetAttribute("OfflineWorker", true)
    return actor
end

return Actors
