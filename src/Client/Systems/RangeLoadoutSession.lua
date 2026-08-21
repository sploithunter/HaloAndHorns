--[[
    RangeLoadoutSession — shared Range entry draft across Inventory and PowerChoice.

    The door starts this session. Pets and Powers menus read/write the same picks.
    Switching panels must markSwitch() first so Hide does not abandon the draft.
    Enter starts the run; Close abandons.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local RangeLoadoutSession = {}
local state = nil
local heldDoors = {}

local PROMPT_NAME = "MissionDoorPrompt"
local DOOR_HOLD_RADIUS = 16

local function eachNearbyDoorPrompt(fn)
    local player = Players.LocalPlayer
    local hrp = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    for _, part in ipairs(CollectionService:GetTagged("MissionDoor")) do
        if part:IsA("BasePart") and (part.Position - hrp.Position).Magnitude <= DOOR_HOLD_RADIUS then
            local prompt = part:FindFirstChild(PROMPT_NAME)
            if prompt and prompt:IsA("ProximityPrompt") then
                fn(prompt)
            end
        end
    end
end

local function pulsePrompt(prompt)
    if not (prompt and prompt.Parent) then
        return
    end
    prompt.Enabled = false
    task.defer(function()
        if prompt.Parent then
            prompt.Enabled = true
        end
    end)
end

local function holdNearbyDoors()
    eachNearbyDoorPrompt(function(prompt)
        heldDoors[prompt] = true
        prompt.Enabled = false
    end)
end

local function releaseNearbyDoors()
    for prompt in pairs(heldDoors) do
        pulsePrompt(prompt)
        heldDoors[prompt] = nil
    end
    eachNearbyDoorPrompt(pulsePrompt)
end

local function cloneList(list)
    local out = {}
    for _, value in ipairs(type(list) == "table" and list or {}) do
        out[#out + 1] = value
    end
    return out
end

function RangeLoadoutSession.isActive()
    return type(state) == "table" and type(state.ctx) == "table"
end

function RangeLoadoutSession.get()
    return state
end

function RangeLoadoutSession.ctx()
    return state and state.ctx or nil
end

local function copyByOrigin(raw)
    local out = {}
    if type(raw) ~= "table" then
        return out
    end
    for origin, kit in pairs(raw) do
        if type(origin) == "string" and type(kit) == "table" then
            out[origin] = { powers = cloneList(kit.powers) }
        end
    end
    return out
end

function RangeLoadoutSession.begin(ctx)
    if type(ctx) ~= "table" then
        return nil
    end
    local catalog = type(ctx.catalog) == "table" and ctx.catalog or {}
    local powerSlots = math.max(0, math.floor(tonumber(catalog.power_slots) or 6))
    local defaults = {}
    for _, powerId in ipairs(catalog.default_powers or {}) do
        if type(powerId) == "string" then
            defaults[#defaults + 1] = powerId
        end
        if #defaults >= powerSlots then
            break
        end
    end
    local saved = type(ctx.defaults) == "table" and ctx.defaults or {}
    local byOrigin = copyByOrigin(saved.by_origin)
    local origin = type(saved.last_origin) == "string" and saved.last_origin or nil
    local powers = defaults
    if origin and byOrigin[origin] and #byOrigin[origin].powers > 0 then
        powers = cloneList(byOrigin[origin].powers)
    end
    local pets = type(saved.pets) == "table" and saved.pets or nil
    state = {
        ctx = ctx,
        pets = pets,
        powers = powers,
        origin = origin,
        byOrigin = byOrigin,
        catalogDefaults = defaults,
        switching = false,
        petSlots = math.max(1, math.floor(tonumber(catalog.pet_slots) or 5)),
        powerSlots = powerSlots,
    }
    return state
end

function RangeLoadoutSession.holdDoors()
    holdNearbyDoors()
end

function RangeLoadoutSession.setPets(picks)
    if state then
        state.pets = type(picks) == "table" and picks or nil
    end
end

function RangeLoadoutSession.setPowers(powers)
    if not state then
        return
    end
    state.powers = cloneList(powers)
    if state.origin then
        state.byOrigin = state.byOrigin or {}
        state.byOrigin[state.origin] = { powers = cloneList(powers) }
    end
end

function RangeLoadoutSession.setOrigin(origin)
    if not state then
        return
    end
    local nextOrigin = type(origin) == "string" and origin or nil
    if state.origin == nextOrigin then
        return
    end
    if state.origin then
        state.byOrigin = state.byOrigin or {}
        state.byOrigin[state.origin] = { powers = cloneList(state.powers) }
    end
    state.origin = nextOrigin
    if not nextOrigin then
        return
    end
    local kit = state.byOrigin and state.byOrigin[nextOrigin]
    if kit and type(kit.powers) == "table" then
        state.powers = cloneList(kit.powers)
    elseif not state.powers or #state.powers == 0 then
        state.powers = cloneList(state.catalogDefaults)
    end
end

function RangeLoadoutSession.markSwitch()
    if state then
        state.switching = true
    end
end

function RangeLoadoutSession.consumeSwitch()
    if not state then
        return false
    end
    local switching = state.switching == true
    state.switching = false
    return switching
end

function RangeLoadoutSession.clear()
    state = nil
    releaseNearbyDoors()
end

local function menu()
    return _G.MenuManager
end

function RangeLoadoutSession.openPets()
    if not RangeLoadoutSession.isActive() then
        return
    end
    RangeLoadoutSession.markSwitch()
    local mm = menu()
    local panel = mm and mm.GetPanel and mm:GetPanel("Inventory")
    if panel and panel.BeginRangeCatalog then
        panel:BeginRangeCatalog(state.ctx)
    end
    if mm and mm.OpenInventoryPanel then
        mm:OpenInventoryPanel()
    elseif mm and mm.OpenPanel then
        mm:OpenPanel("Inventory")
    end
end

function RangeLoadoutSession.openPowers()
    if not RangeLoadoutSession.isActive() then
        return
    end
    RangeLoadoutSession.markSwitch()
    local mm = menu()
    if mm and mm.OpenPanel then
        mm:OpenPanel("PowerChoice")
    end
end

function RangeLoadoutSession.abandon()
    RangeLoadoutSession.clear()
    local mm = menu()
    if mm and mm.CloseCurrentPanel then
        mm:CloseCurrentPanel()
    end
end

function RangeLoadoutSession.enter(pets, powers)
    if not RangeLoadoutSession.isActive() then
        return
    end
    if type(pets) == "table" then
        RangeLoadoutSession.setPets(pets)
    end
    if type(powers) == "table" then
        RangeLoadoutSession.setPowers(powers)
    end
    if not state.origin then
        RangeLoadoutSession.openPowers()
        return
    end
    if not (Signals and Signals.ChallengeRun_Start) then
        return
    end
    Signals.ChallengeRun_Start:FireServer({
        missionId = state.ctx.mission,
        pets = state.pets,
        powers = state.powers,
        origin = state.origin,
    })
    RangeLoadoutSession.clear()
    local mm = menu()
    if mm and mm.CloseCurrentPanel then
        mm:CloseCurrentPanel()
    end
end

return RangeLoadoutSession
