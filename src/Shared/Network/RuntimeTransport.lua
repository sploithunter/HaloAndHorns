-- Runtime transport used only by the generated signal registry.

local RunService = game:GetService("RunService")

local RuntimeTransport = {}
RuntimeTransport.__index = RuntimeTransport

function RuntimeTransport.new(net, replicatedStorage)
    return setmetatable({
        _net = net,
        _replicatedStorage = replicatedStorage,
    }, RuntimeTransport)
end

function RuntimeTransport:_rootRemote(className, name, parentName)
    local parent = self._replicatedStorage
    if parentName then
        parent = parent:WaitForChild(parentName, 10)
        assert(parent, "Missing parent remote: " .. parentName)
    end

    if RunService:IsServer() then
        local remote = parent:FindFirstChild(name)
        if remote and not remote:IsA(className) then
            remote:Destroy()
            remote = nil
        end
        if not remote then
            remote = Instance.new(className)
            remote.Name = name
            remote.Parent = parent
        end
        return remote
    end

    local remote = parent:WaitForChild(name, 10)
    assert(remote and remote:IsA(className), "Missing " .. className .. ": " .. name)
    return remote
end

function RuntimeTransport:RemoteEvent(name, location, parentName)
    if location == "replicated_storage" then
        return self:_rootRemote("RemoteEvent", name, parentName)
    end
    return self._net:RemoteEvent(name)
end

function RuntimeTransport:RemoteFunction(name, location, parentName)
    if location == "replicated_storage" then
        return self:_rootRemote("RemoteFunction", name, parentName)
    end
    return self._net:RemoteFunction(name)
end

return RuntimeTransport
