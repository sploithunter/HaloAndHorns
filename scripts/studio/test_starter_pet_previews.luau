-- Edit-only regression: real starter templates, isolated published shelf, and production
-- publisher/picker functions. No profile, live Workspace, or actual replicated shelf is changed.
local rs = game:GetService("ReplicatedStorage")
local serviceSource = game.ServerScriptService.Server.Services.AssetPreloadService.Source
local controllerSource =
    game.StarterPlayer.StarterPlayerScripts.Client.Systems.StarterPetController.Source
local function chunk(source, firstText, lastText)
    local first = assert(source:find(firstText, 1, true))
    local last = assert(source:find(lastText, first + #firstText, true))
    return source:sub(first, last - 1)
end
local function fresh(module)
    return assert(loadstring(module.Source))()
end
local config = fresh(rs.Configs.starter_pets)
local places = fresh(rs.Configs.places)
local role = fresh(rs.Shared.Game.PlaceRuntime)
local fakeRS = Instance.new("Folder")
local assets = Instance.new("Folder")
assets.Name = "Assets"
assets.Parent = fakeRS
local frames = Instance.new("Folder")
local ok, result = pcall(function()
    local service = assert(
        loadstring(
            "local ReplicatedStorage, ServerStorage, PlaceRuntime, game, logger = ...\nlocal AssetPreloadService = {}\n"
                .. chunk(
                    serviceSource,
                    "function AssetPreloadService:_warmStarterPetPreviews()",
                    "local function hasFlatPetThumbnail"
                )
                .. "\nreturn AssetPreloadService"
        )
    )(fakeRS, game.ServerStorage, role, { PlaceId = role.placeIdForRole(places, "main") }, {
        Warn = function(_, message, details)
            error(message .. ": " .. details.pet)
        end,
    })
    service._starterConfig, service._placesConfig = config, places
    service:_warmStarterPetPreviews()
    local shelf = assert(assets:FindFirstChild(config.preview.folder))
    assert(#shelf:GetChildren() == #config.choices, "Preview shelf must contain only four starters")
    local preloads = {}
    local queued = {}
    local client = assert(
        loadstring(
            "local ReplicatedStorage, STARTER, PLACES, PlaceRuntime, game, THUMBNAILS, PETS, PetThumbnailResolver, ViewportModelPlacement, ContentProvider, task = ...\n"
                .. chunk(
                    controllerSource,
                    "local function cameraDirection",
                    "local function attachFlatThumbnail"
                )
                .. "\nreturn {warm = prewarmStarterChoices, attach = attachModelFallback}"
        )
    )(
        fakeRS,
        config,
        places,
        role,
        { PlaceId = role.placeIdForRole(places, "main") },
        fresh(rs.Configs.pet_thumbnail_assets),
        fresh(rs.Configs.pets),
        fresh(rs.Shared.UI.PetThumbnailResolver),
        fresh(rs.Shared.UI.ViewportModelPlacement),
        {
            PreloadAsync = function(_, items)
                table.insert(preloads, items[1])
            end,
        },
        {
            spawn = function(callback)
                table.insert(queued, callback)
            end,
        }
    )
    client.warm()
    assert(#queued == #config.choices * 2, "Image and model preload must start independently")
    for _, callback in ipairs(queued) do
        callback()
    end
    table.clear(queued)
    assert(#preloads == #config.choices * 2, "All starter thumbnails and models must be prefetched")
    for _, choice in ipairs(config.choices) do
        local template = assert(shelf:FindFirstChild(choice.id))
        assert(template:IsA("Model") and template:FindFirstChildWhichIsA("BasePart", true))
        local frame = Instance.new("Frame")
        frame.Parent = frames
        local paw = Instance.new("TextLabel")
        paw.Parent = frame
        local viewport = client.attach(frame, choice, paw)
        for _, callback in ipairs(queued) do
            callback()
        end
        table.clear(queued)
        assert(viewport:FindFirstChildWhichIsA("Model"), choice.id .. " has no viewport model")
        assert(not paw.Visible, choice.id .. " still shows paw")
        assert(viewport.CurrentCamera, choice.id .. " has no camera")
    end
    service:_warmStarterPetPreviews()
    assert(shelf.Parent == nil, "Rebuild must replace the old shelf")
    assert(#assets:GetChildren() == 1, "Rebuild duplicated the shelf")
    -- Simulate Merge role using the actual published role map; no catalog should replicate.
    service._placesConfig = { default_role = "merge", roles = {} }
    service:_warmStarterPetPreviews()
    assert(#assets:GetChildren() == 0, "Merge retained starter-only templates")
    assert(
        game.ServerStorage.Assets.Models.Pets:FindFirstChild(config.choices[1].id),
        "Source catalog altered"
    )
    return "PASS: four boot previews, eight independent preloads, four no-paw viewport fallbacks, idempotent rebuild, Merge exclusion; source catalog intact"
end)
frames:Destroy()
fakeRS:Destroy()
assert(ok, result)
return result
