--[[
    MeshAssembly — THE single path: a separately-uploaded MESH + TEXTURE -> a textured Model.

    Roblox FBX->Model uploads import UNTEXTURED (the texture is a sibling asset), so we combine the
    raw mesh and the image at runtime via AssetService:CreateMeshPartAsync(Content.fromUri(meshId))
    + MeshPart.TextureID = imageId. This module is the ONE implementation of that combine. Every
    caller (pets, enemies, gems/drops, eggs) routes through it instead of re-deriving the same
    pcall+CreateMeshPartAsync+TextureID dance — that duplication is exactly what kept producing grey
    meshes (e.g. eggs, which never had a combine path at all).

    Usage — build once, clone per instance (the common "store a template, instantiate it" pattern):

        local MeshAssembly = require(ReplicatedStorage.Shared.Assets.MeshAssembly)
        local model = MeshAssembly.build(meshId, imageId, { modelName = "solar_egg" })
        -- model.PrimaryPart is the textured MeshPart; parent/clone it like any other Model.

    Returns nil (+ error string) on failure so callers can fall back to a procedural placeholder.
    CreateMeshPartAsync yields and is server-side; call from a server context off the hot path.
]]

local AssetService = game:GetService("AssetService")

local MeshAssembly = {}

local function isUsableId(id)
    return type(id) == "string" and id ~= "" and id ~= "rbxassetid://0"
end

-- Build a Model whose PrimaryPart is a textured MeshPart from a mesh id + (optional) image id.
-- opts: modelName, partName, anchored (default true), canCollide (default false),
--       collisionFidelity (default Box), renderFidelity (default Automatic).
-- Returns (model) on success, or (nil, errorString) on failure.
function MeshAssembly.build(meshId, textureId, opts)
    opts = opts or {}
    if not isUsableId(meshId) then
        return nil, "no mesh id"
    end

    local ok, mesh = pcall(function()
        -- selene: allow(undefined_variable)
        local content = Content.fromUri(meshId) -- `Content` is a runtime global selene's std lacks
        return AssetService:CreateMeshPartAsync(content, {
            CollisionFidelity = opts.collisionFidelity or Enum.CollisionFidelity.Box,
            RenderFidelity = opts.renderFidelity or Enum.RenderFidelity.Automatic,
        })
    end)
    if not ok or not mesh then
        return nil, tostring(mesh)
    end

    if isUsableId(textureId) then
        pcall(function()
            mesh.TextureID = textureId
        end)
    end
    mesh.Name = opts.partName or "Body"
    mesh.Anchored = opts.anchored ~= false
    mesh.CanCollide = opts.canCollide == true

    local model = Instance.new("Model")
    model.Name = opts.modelName or "MeshModel"
    mesh.Parent = model
    model.PrimaryPart = mesh
    return model
end

return MeshAssembly
