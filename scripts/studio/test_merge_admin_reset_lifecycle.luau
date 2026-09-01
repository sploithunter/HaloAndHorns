-- Deterministic play-mode smoke test for the dedicated Merge place.
-- Run in the SERVER command bar after the player has loaded. The character walks to each real
-- opening pickup, buys five eggs, merges and equips them, lets combat advance, then invokes the
-- same Admin Reset service used by the live panel and asserts the clean beginning-of-session state.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

assert(RunService:IsStudio(), "Merge Admin Reset lifecycle automation is Studio-only")

local player = Players:GetPlayers()[1]
assert(player, "Start a one-player Play session before running this test")

local bridge = ServerStorage:WaitForChild("MergeEggStudioAutomation", 15)
assert(bridge and bridge:IsA("BindableFunction"), "MergeEggStudioAutomation bridge unavailable")

local function audit()
    local ok, result = bridge:Invoke("audit", player, {})
    assert(ok, "Merge lifecycle audit failed: " .. tostring(result))
    return result
end

local function waitUntil(label, timeoutSeconds, predicate)
    local deadline = os.clock() + timeoutSeconds
    local last
    repeat
        last = audit()
        if predicate(last) then
            return last
        end
        task.wait(0.1)
    until os.clock() >= deadline
    error(
        string.format(
            "Timed out waiting for %s; final audit=%s",
            label,
            game:GetService("HttpService"):JSONEncode(last)
        )
    )
end

local function openingDrops()
    local result = {}
    for _, instance in ipairs(workspace:GetDescendants()) do
        if
            instance:IsA("Model")
            and instance:GetAttribute("DropSource") == "merge_egg_prototype"
            and instance:GetAttribute("DropReason") == "opening"
        then
            result[#result + 1] = instance
        end
    end
    table.sort(result, function(a, b)
        return a:GetPivot().Position.X < b:GetPivot().Position.X
    end)
    return result
end

local function walkTo(part, arrivalDistance)
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    assert(humanoid, "Player character has no Humanoid")
    assert(root, "Player character has no HumanoidRootPart")
    local targetName = part:GetFullName()
    local targetPosition = part:GetPivot().Position
    arrivalDistance = math.max(1, tonumber(arrivalDistance) or 4)
    local horizontalOffset =
        Vector3.new(root.Position.X - targetPosition.X, 0, root.Position.Z - targetPosition.Z)
    local standOff = math.max(0, arrivalDistance - 2)
    local walkPosition = Vector3.new(targetPosition.X, root.Position.Y, targetPosition.Z)
    if horizontalOffset.Magnitude > 0 and standOff > 0 then
        walkPosition += horizontalOffset.Unit * standOff
    end
    local deadline = os.clock() + 15
    repeat
        humanoid:MoveTo(walkPosition)
        local repathAt = os.clock() + 2
        repeat
            task.wait(0.1)
            local distance = Vector3.new(
                root.Position.X - targetPosition.X,
                0,
                root.Position.Z - targetPosition.Z
            ).Magnitude
            if part.Parent == nil or distance <= arrivalDistance then
                return
            end
        until os.clock() >= repathAt
    until os.clock() >= deadline
    error("Could not walk to " .. targetName)
end

local function nearestBulwarkMenuHost()
    local character = player.Character or player.CharacterAdded:Wait()
    local root = character:FindFirstChild("HumanoidRootPart")
    assert(root, "Player character has no HumanoidRootPart")
    local closest
    local closestDistance = math.huge
    for _, instance in ipairs(workspace:GetDescendants()) do
        if
            instance:IsA("BasePart")
            and string.match(instance.Name, "^MergeEggBulwarkMenuHost_")
        then
            local distance = (root.Position - instance.Position).Magnitude
            if distance < closestDistance then
                closest = instance
                closestDistance = distance
            end
        end
    end
    return assert(closest, "Active bay has no Merge bulwark menu host")
end

local function nearestNamedPart(name)
    local character = player.Character or player.CharacterAdded:Wait()
    local root = character:FindFirstChild("HumanoidRootPart")
    assert(root, "Player character has no HumanoidRootPart")
    local closest
    local closestDistance = math.huge
    for _, instance in ipairs(workspace:GetDescendants()) do
        if instance:IsA("BasePart") and instance.Name == name then
            local distance = (root.Position - instance.Position).Magnitude
            if distance < closestDistance then
                closest = instance
                closestDistance = distance
            end
        end
    end
    return assert(closest, "Could not find nearest " .. name)
end

local function nearestNamedInstance(name)
    local character = player.Character or player.CharacterAdded:Wait()
    local root = character:FindFirstChild("HumanoidRootPart")
    assert(root, "Player character has no HumanoidRootPart")
    local closest
    local closestDistance = math.huge
    for _, instance in ipairs(workspace:GetDescendants()) do
        if (instance:IsA("BasePart") or instance:IsA("Model")) and instance.Name == name then
            local distance = (root.Position - instance:GetPivot().Position).Magnitude
            if distance < closestDistance then
                closest = instance
                closestDistance = distance
            end
        end
    end
    return assert(closest, "Could not find nearest " .. name)
end

local function isCleanOpening(state)
    return state.active == true
        and state.wave == 0
        and state.wallet == 0
        and state.openingDropCount == 5
        and state.openingDropAmount == 600
        and state.boardInventory == 0
        and state.deployedEggs == 0
        and state.bulwarkInstalled == false
end

-- Long-lived Studio sessions can outlast the ten-minute pickup lifetime. Establish the exact
-- beginning state ourselves instead of treating expired opening piles as a product failure.
local initial = audit()
if not isCleanOpening(initial) then
    local setupRunId = initial.runId
    local setupOk, setupReason = bridge:Invoke("admin_reset", player, {})
    assert(setupOk, "Initial Admin Reset failed: " .. tostring(setupReason))
    initial = waitUntil("clean Merge entry", 20, function(state)
        return isCleanOpening(state) and state.runId ~= setupRunId
    end)
end
assert(initial.tutorialCompleted == true, "Completed tutorial should remain completed")
assert(initial.wallet == 0, "Clean entry wallet must be 0")
assert(initial.openingDropAmount == 600, "Five opening piles must total 600 Waycoins")
assert(initial.boardInventory == 0 and initial.deployedEggs == 0, "Clean entry contains eggs")

local drops = openingDrops()
assert(#drops == 5, string.format("Expected five real opening pickup parts, found %d", #drops))
for _, drop in ipairs(drops) do
    walkTo(drop)
end

local collected = waitUntil("all opening piles collected", 10, function(state)
    return state.wallet == 600 and state.openingDropCount == 0
end)

-- The real card rejects remote purchases. Walk back from the field to the authored management
-- station before clicking it, matching the player-facing tutorial cadence.
walkTo(nearestNamedPart("EggMergeControl"), 12)
for index = 1, 5 do
    local ok, result = bridge:Invoke("create_egg", player, { managementBoard = true })
    assert(ok, string.format("Egg %d creation failed: %s", index, tostring(result)))
    task.wait(0.25)
end

local bought = audit()
assert(bought.eggsCreated == 5 and bought.boardInventory == 5, "Five eggs were not created")

-- Merging and Equip Best use the authored floor board, not the wall purchase station.
walkTo(nearestNamedInstance("MergeBoard"), 20)
local merged, mergeReason = bridge:Invoke("board_action", player, {
    action = "merge_slots",
    sourceSlot = 1,
    targetSlot = 2,
})
assert(merged, "Board merge failed: " .. tostring(mergeReason))
task.wait(0.25)

local equipped, equipReason = bridge:Invoke("board_action", player, { action = "equip_best" })
assert(equipped, "Equip Best failed: " .. tostring(equipReason))

local fighting = waitUntil("combat to advance", 45, function(state)
    return state.wave >= 2 and state.deployedEggs > 0
end)

-- Install a real visual line before reset so the lifecycle assertion below proves both durable
-- bulwark progress and the ten spawned runtime models are removed. The playtest price is one
-- Waycoin, so the five-egg tutorial economy always has enough left for this check.
walkTo(nearestBulwarkMenuHost(), 12)
local bulwarkOk, bulwarkReason = bridge:Invoke("board_action", player, {
    action = "bulwark",
    bulwarkAction = "select",
    family = "impaler_palisade",
})
assert(bulwarkOk, "Bulwark installation failed: " .. tostring(bulwarkReason))
local armed = waitUntil("bulwark installation", 10, function(state)
    return state.bulwarkInstalled == true and state.bulwarkVisuals == 10
end)

local oldRunId = fighting.runId
local resetOk, resetReason = bridge:Invoke("admin_reset", player, {})
assert(resetOk, "Admin Reset failed: " .. tostring(resetReason))

local reset = waitUntil("Admin Reset re-entry", 20, function(state)
    return state.active == true and state.runId ~= oldRunId and state.openingDropCount == 5
end)
assert(reset.wave == 0, "Admin Reset did not return to Wave 0")
assert(reset.wallet == 0, "Admin Reset wallet must be 0 before pickups")
assert(reset.openingDropAmount == 600, "Admin Reset did not create five 120-Waycoin piles")
assert(reset.boardInventory == 0 and reset.boardEggVisuals == 0, "Admin Reset left board eggs")
assert(reset.deployedEggs == 0 and reset.initializedHatchers == 0, "Admin Reset left deployed eggs")
assert(reset.bulwarkInstalled == false and reset.bulwarkVisuals == 0, "Admin Reset left a bulwark")
assert(
    reset.tutorialCompleted == true and reset.tutorialActive == false,
    "Admin Reset replayed the tutorial"
)

print("[MergeAdminResetLifecycle] PASS", {
    collectedWallet = collected.wallet,
    eggsCreated = bought.eggsCreated,
    combatWave = fighting.wave,
    installedBulwark = armed.bulwarkFamily,
    resetWallet = reset.wallet,
    openingPiles = reset.openingDropCount,
    openingAmount = reset.openingDropAmount,
})

return reset
