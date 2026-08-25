-- EnvironmentGlow — inexpensive emissive treatment for dark textured map dressing.
--
-- Neon keeps near-black texels dark while lifting authored colored accents. A restrained optional
-- PointLight then lets those accents tint the nearby ground/model, following the same no-shadows
-- policy used by crystal glow.

local EnvironmentGlow = {}

local LIGHT_NAME = "EnvironmentGlow"

local function resolveColor(value)
    if typeof(value) == "Color3" then
        return value
    end
    if type(value) == "table" then
        return Color3.fromRGB(value[1] or 255, value[2] or 255, value[3] or 255)
    end
    return Color3.new(1, 1, 1)
end

function EnvironmentGlow.apply(model, spec)
    if not model or type(spec) ~= "table" then
        return false
    end

    if spec.neon ~= false then
        for _, descendant in ipairs(model:GetDescendants()) do
            if descendant:IsA("MeshPart") then
                descendant.Material = Enum.Material.Neon
            end
        end
    end

    local brightness = math.max(0, tonumber(spec.brightness) or 0)
    local range = math.max(0, tonumber(spec.range) or 0)
    if brightness <= 0 or range <= 0 then
        return true
    end

    local host = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
    if not host then
        return false
    end

    local light = host:FindFirstChild(LIGHT_NAME)
    if not (light and light:IsA("PointLight")) then
        if light then
            light:Destroy()
        end
        light = Instance.new("PointLight")
        light.Name = LIGHT_NAME
        light.Parent = host
    end
    light.Color = resolveColor(spec.color)
    light.Brightness = brightness
    light.Range = range
    light.Shadows = spec.shadows == true
    return true
end

return EnvironmentGlow
