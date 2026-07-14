--[[
    PetEnduranceBar — the single event-driven presenter for pet world health bars.

    CombatDamageTaken is the replicated source of truth. Any system may heal or hurt a pet by
    changing that attribute; this observer owns creating, updating, and removing the overhead bar.
    Callers must not try to keep a second GUI state in sync with the same value.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetEndurance = require(ReplicatedStorage.Shared.Game.PetEndurance)
local OverheadBar = require(ReplicatedStorage.Shared.UI.OverheadBar)

local PetEnduranceBar = {}

local boundPets = setmetatable({}, { __mode = "k" })
local watchedRoots = setmetatable({}, { __mode = "k" })

local function enduranceBar(pet)
    local primary = pet and pet.PrimaryPart
    return primary and primary:FindFirstChild("EnduranceBar")
end

function PetEnduranceBar.clear(pet)
    local bar = enduranceBar(pet)
    while bar do
        bar:Destroy()
        bar = enduranceBar(pet)
    end
end

function PetEnduranceBar.sync(pet, factor)
    if not (pet and pet:IsA("Model") and pet.Parent) then
        return
    end
    local primary = pet.PrimaryPart
    if not primary then
        return
    end

    local taken = tonumber(pet:GetAttribute("CombatDamageTaken")) or 0
    if pet:GetAttribute("CombatDowned") or taken <= 0 then
        PetEnduranceBar.clear(pet)
        return
    end

    if not enduranceBar(pet) then
        OverheadBar.create({
            adornee = primary,
            name = "EnduranceBar",
            studsOffset = Vector3.new(0, 3.5, 0),
            bgColor = Color3.fromRGB(25, 25, 25),
            fillColor = Color3.fromRGB(70, 200, 90),
        })
    end

    local powerValue = pet:FindFirstChild("Power")
    local power = (powerValue and tonumber(powerValue.Value))
        or tonumber(pet:GetAttribute("Power"))
        or 0
    local fraction = PetEndurance.healthFraction(taken, power, factor)
    OverheadBar.setFraction(
        OverheadBar.fillOf(primary, "EnduranceBar"),
        fraction,
        Color3.fromRGB(math.floor(215 * (1 - fraction)) + 40, math.floor(195 * fraction) + 30, 45)
    )
end

local function isPetModel(root, candidate)
    local folder = candidate and candidate.Parent
    return candidate:IsA("Model") and folder ~= nil and folder.Parent == root
end

local function disconnectPet(pet)
    local record = boundPets[pet]
    if not record then
        return
    end
    boundPets[pet] = nil
    for _, connection in ipairs(record.connections) do
        connection:Disconnect()
    end
end

function PetEnduranceBar.bind(pet, factor)
    if not (pet and pet:IsA("Model")) then
        return
    end
    if boundPets[pet] then
        PetEnduranceBar.sync(pet, factor)
        return
    end

    local record = { connections = {}, powerConnection = nil }
    boundPets[pet] = record
    local function connect(signal, callback)
        record.connections[#record.connections + 1] = signal:Connect(callback)
    end
    local function sync()
        PetEnduranceBar.sync(pet, factor)
    end
    local function bindPower(value)
        if record.powerConnection then
            record.powerConnection:Disconnect()
            record.powerConnection = nil
        end
        if value and value:IsA("NumberValue") then
            record.powerConnection = value:GetPropertyChangedSignal("Value"):Connect(sync)
        end
    end

    connect(pet:GetAttributeChangedSignal("CombatDamageTaken"), sync)
    connect(pet:GetAttributeChangedSignal("CombatDowned"), sync)
    connect(pet:GetPropertyChangedSignal("PrimaryPart"), sync)
    connect(pet.ChildAdded, function(child)
        if child.Name == "Power" then
            bindPower(child)
            sync()
        end
    end)
    connect(pet.AncestryChanged, function(_, parent)
        if parent == nil then
            if record.powerConnection then
                record.powerConnection:Disconnect()
            end
            disconnectPet(pet)
        end
    end)

    bindPower(pet:FindFirstChild("Power"))
    sync()
end

function PetEnduranceBar.watchRoot(root, factor)
    if not root or watchedRoots[root] then
        return
    end
    watchedRoots[root] = true

    for _, folder in ipairs(root:GetChildren()) do
        for _, pet in ipairs(folder:GetChildren()) do
            if isPetModel(root, pet) then
                PetEnduranceBar.bind(pet, factor)
            end
        end
    end
    root.DescendantAdded:Connect(function(candidate)
        if isPetModel(root, candidate) then
            PetEnduranceBar.bind(candidate, factor)
        end
    end)
end

function PetEnduranceBar.watchWorkspace(workspace, factor)
    PetEnduranceBar.watchRoot(workspace:FindFirstChild("PlayerPets"), factor)
    workspace.ChildAdded:Connect(function(child)
        if child.Name == "PlayerPets" then
            PetEnduranceBar.watchRoot(child, factor)
        end
    end)
end

return PetEnduranceBar
