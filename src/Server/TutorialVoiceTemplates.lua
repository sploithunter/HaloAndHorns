-- Two sanitized, shared presentation assets. No NPCs, physics, or executable asset descendants.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetFetch = require(ReplicatedStorage.Shared.Utils.AssetFetch)
local Templates = {}
function Templates.start(config)
    if not config.enabled then
        return
    end
    local folder = ReplicatedStorage:FindFirstChild(config.templates_folder)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = config.templates_folder
        folder.Parent = ReplicatedStorage
    end
    for speaker, face in pairs(config.faces) do
        task.spawn(function()
            for attempt = 1, config.template_attempts do
                if folder:FindFirstChild(speaker) then
                    return
                end
                local ok, container = pcall(AssetFetch.load, face.model_asset_id)
                if ok and container then
                    local head
                    for _, part in ipairs(container:GetDescendants()) do
                        if
                            part:IsA("MeshPart")
                            and (not head or part.Size.Magnitude > head.Size.Magnitude)
                        then
                            head = part
                        end
                    end
                    if head then
                        head = head:Clone()
                        head.Name = speaker
                        head.Anchored = true
                        head.CanCollide, head.CanTouch, head.CanQuery, head.CastShadow =
                            false, false, false, false
                        for _, child in ipairs(head:GetChildren()) do
                            if not child:IsA("SurfaceAppearance") then
                                child:Destroy()
                            end
                        end
                        head.CFrame = CFrame.identity
                        head.Parent = folder
                        container:Destroy()
                        return
                    end
                    container:Destroy()
                end
                if attempt < config.template_attempts then
                    task.wait(config.template_retry_seconds)
                end
            end
            warn("Tutorial voice face unavailable: " .. speaker)
        end)
    end
end
return Templates
