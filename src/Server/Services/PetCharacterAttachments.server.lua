local Players = game:GetService("Players")
local originalPosition = Vector3.new(0, 0, 15)

-- Create globalPetFloat if it doesn't exist (matches original game)
local globalPetFloat = game.ServerScriptService:FindFirstChild("globalPetFloat")
if not globalPetFloat then
    globalPetFloat = Instance.new("NumberValue")
    globalPetFloat.Name = "globalPetFloat"
    globalPetFloat.Value = 333 -- Exact value from original game
    globalPetFloat.Parent = game.ServerScriptService
end

Players.PlayerAdded:Connect(function(plr)
    local character = plr.Character or plr.CharacterAdded:Wait()

    local attachment1 = Instance.new("Attachment")
    attachment1.Name = "attachment1"
    attachment1.Parent = character.HumanoidRootPart
    attachment1.Position = Vector3.new(-2, 0, 15)

    local attachment2 = Instance.new("Attachment")
    attachment2.Name = "attachment2"
    attachment2.Parent = character.HumanoidRootPart
    attachment2.Position = Vector3.new(0, 0, 15)

    local attachment3 = Instance.new("Attachment")
    attachment3.Name = "attachment3"
    attachment3.Parent = character.HumanoidRootPart
    attachment3.Position = Vector3.new(2, 0, 15)

    local attachment4 = Instance.new("Attachment")
    attachment4.Name = "attachment4"
    attachment4.Parent = character.HumanoidRootPart
    attachment4.Position = Vector3.new(-2, 0, -15)

    local attachment5 = Instance.new("Attachment")
    attachment5.Name = "attachment5"
    attachment5.Parent = character.HumanoidRootPart
    attachment5.Position = Vector3.new(0, 0, -15)

    local attachment6 = Instance.new("Attachment")
    attachment6.Name = "attachment6"
    attachment6.Parent = character.HumanoidRootPart
    attachment6.Position = Vector3.new(2, 0, -15)

    local attachmentFar = Instance.new("Attachment")
    attachmentFar.Name = "attachmentFar"
    attachmentFar.Parent = character.HumanoidRootPart
    attachmentFar.Position = Vector3.new(0, 0, 30)

    -- EXACT COPY: Simple attachmentFar animation only (like original)
    while task.wait(0.05) do
        if
            character:FindFirstChild("HumanoidRootPart")
            and character.HumanoidRootPart:FindFirstChild("attachmentFar")
        then
            character.HumanoidRootPart.attachmentFar.Position = originalPosition
                + Vector3.new(0, game.ServerScriptService.globalPetFloat.Value - 0, 0)
        else
            break
        end
    end
end)
