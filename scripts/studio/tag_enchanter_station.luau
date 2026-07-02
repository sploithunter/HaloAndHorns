--[[
    Tags an imported enchanter model as a config-driven map hook.

    Run from Studio Command Bar after importing/placing an enchanter model.
    By default it targets Workspace.Enchanter and preserves cosmetic scripts
    while disabling the old copied touch gameplay script.
]]

local CollectionService = game:GetService("CollectionService")

local MODEL_NAME = "Enchanter"
local ENCHANTER_ID = "basic_enchanter"
local AREA_ID = "Spawn"
local TOUCH_PART_NAME = "EnchantTouchPart"

local enchanter = workspace:FindFirstChild(MODEL_NAME)
assert(enchanter, "Missing Workspace." .. MODEL_NAME)

if not CollectionService:HasTag(enchanter, "EnchanterStation") then
    CollectionService:AddTag(enchanter, "EnchanterStation")
end

enchanter:SetAttribute("EnchanterId", ENCHANTER_ID)
enchanter:SetAttribute("AreaId", AREA_ID)
enchanter:SetAttribute("TouchPartName", TOUCH_PART_NAME)

local touchPart = enchanter:FindFirstChild(TOUCH_PART_NAME, true)
assert(touchPart and touchPart:IsA("BasePart"), "Missing enchanter touch part")

touchPart.CanTouch = true
touchPart.CanCollide = false
touchPart.Transparency = 1

local oldTouchScript = touchPart:FindFirstChild("Script")
if oldTouchScript and oldTouchScript:IsA("BaseScript") then
    oldTouchScript.Enabled = false
    oldTouchScript:SetAttribute("MovedToService", "EnchantService")
end

print(
    string.format(
        "Tagged %s as EnchanterStation (%s) using touch part %s",
        enchanter:GetFullName(),
        ENCHANTER_ID,
        touchPart:GetFullName()
    )
)
