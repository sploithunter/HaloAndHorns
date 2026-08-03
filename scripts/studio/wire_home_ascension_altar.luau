--[[
    Wires the authored Home ascension altar to the existing gameplay/effect contract.

    The replacement mesh was imported as Workspace.AscensionAlter while the previous altar was
    retained below the map as Workspace.Maps.Home.AscensionAltar_old. The old altar remains a
    visual reference, but it must not remain a live station. This script:

      * moves the replacement under Workspace.Maps.Home and canonicalizes its name;
      * keeps its authored AscensionAltarHost placement;
      * clones NativeFX from the old altar and maps every effect part host-relative;
      * gives the replacement host the AscensionAltar tag used by AscensionAltarService; and
      * removes that tag from the buried old host.

    Safe to rerun. It never replaces an independently authored NativeFX folder.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local ALTAR_TAG = "AscensionAltar"
local HOST_NAME = "AscensionAltarHost"
local OLD_NAME = "AscensionAltar_old"
local TARGET_NAMES = { "AscensionAltar", "AscensionAlter" }
local FX_SOURCE_ATTRIBUTE = "AscensionFXSource"
local FX_SOURCE_VALUE = "Maps.Home.AscensionAltar_old.NativeFX"

local maps = assert(Workspace:FindFirstChild("Maps"), "Workspace.Maps is missing")
local home = assert(maps:FindFirstChild("Home"), "Workspace.Maps.Home is missing")
local oldAltar = assert(home:FindFirstChild(OLD_NAME), "Home.AscensionAltar_old is missing")
local oldHost =
    assert(oldAltar:FindFirstChild(HOST_NAME, true), "Old AscensionAltarHost is missing")
local oldFX = assert(oldAltar:FindFirstChild("NativeFX"), "Old altar NativeFX is missing")

local function findTarget()
    for _, name in ipairs(TARGET_NAMES) do
        local underHome = home:FindFirstChild(name)
        if underHome and underHome ~= oldAltar then
            return underHome
        end
        local underWorkspace = Workspace:FindFirstChild(name)
        if underWorkspace and underWorkspace ~= oldAltar then
            return underWorkspace
        end
    end
    return nil
end

local target = assert(findTarget(), "Replacement AscensionAltar/AscensionAlter is missing")
assert(target:IsA("Model"), "Replacement ascension altar must be a Model")
local targetHost = assert(
    target:FindFirstChild(HOST_NAME, true),
    "Replacement altar AscensionAltarHost is missing"
)
assert(oldHost:IsA("BasePart") and targetHost:IsA("BasePart"), "Altar hosts must be BaseParts")

ChangeHistoryService:SetWaypoint("Before Home ascension altar wiring")

target.Parent = home
target.Name = "AscensionAltar"

targetHost.Anchored = true
targetHost.CanCollide = false
targetHost.CanTouch = false
targetHost.CanQuery = false
targetHost.Transparency = 1
targetHost:SetAttribute(
    "LabelHeight",
    tonumber(targetHost:GetAttribute("LabelHeight"))
        or tonumber(oldHost:GetAttribute("LabelHeight"))
        or 26
)
CollectionService:AddTag(targetHost, ALTAR_TAG)
CollectionService:RemoveTag(oldHost, ALTAR_TAG)

local targetFX = target:FindFirstChild("NativeFX")
if targetFX then
    assert(
        targetFX:GetAttribute(FX_SOURCE_ATTRIBUTE) == FX_SOURCE_VALUE,
        "Replacement already has independently authored NativeFX; refusing to overwrite it"
    )
else
    targetFX = oldFX:Clone()
    targetFX:SetAttribute(FX_SOURCE_ATTRIBUTE, FX_SOURCE_VALUE)

    -- Preserve the complete effect layout even when the replacement mesh has a different world
    -- position or orientation. The host is the shared coordinate contract between both altars.
    local hostTransform = targetHost.CFrame * oldHost.CFrame:Inverse()
    for _, descendant in ipairs(targetFX:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.CFrame = hostTransform * descendant.CFrame
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
        end
    end
    targetFX.Parent = target
end

target:SetAttribute("AscensionAltarWired", true)
target:SetAttribute("AscensionFXSource", FX_SOURCE_VALUE)
ChangeHistoryService:SetWaypoint("Home ascension altar wired")

print(
    string.format(
        "ASCENSION ALTAR WIRED target=%s host=%s fx=%d oldHostActive=%s",
        target:GetFullName(),
        tostring(targetHost.Position),
        #targetFX:GetDescendants(),
        tostring(CollectionService:HasTag(oldHost, ALTAR_TAG))
    )
)

return target
