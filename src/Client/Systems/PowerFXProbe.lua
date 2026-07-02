--[[
    PowerFXProbe (client) — the admin FX-probe harness (docs/PET_REALM_POWER_DATA_MODEL.md §11).

    Plays the `configs/power_fx.lua` registry primitives on demand so you can eyeball every
    primitive × element through the REAL CombatFX renderer — the "first visual test". Three modes:
      • casting — each `probe.casting` primitive on the player, cycling elements.
      • impact  — spawns a dummy ~N studs ahead, plays each `probe.impact` primitive at it.
      • real    — casting then impact (the full chain).

    A floating label names each effect (id · element) as it plays. The screen-capture stills catch
    presence / colour / lighting; you confirm motion + (later) sound. Client-only: FX are rendered
    locally, so the admin button calls PowerFXProbe.run(mode) directly — no server round-trip.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CombatFX = require(
    ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Effects"):WaitForChild("CombatFX")
)
local FloatingText = require(ReplicatedStorage.Shared.Effects.FloatingText)
local PowerSound = require(ReplicatedStorage.Shared.Effects.PowerSound)
local FX = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("power_fx"))

local PowerFXProbe = {}

local running = 0 -- token: a new run cancels any in-flight one
local manualSeq, manualCursor, manualMode = nil, 0, "real" -- Next/Repeat stepping state

local function hrp()
    local char = Players.LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- Play one registry primitive through CombatFX.
--   pbaoe (self burst)  → ctx.caster
--   st_aoe (strike)     → ctx.point  (a position)
--   st_attack (bolt)    → ctx.target (a target Instance — the dummy)
--   attached (aura/bubble) → ctx.caster, with spec.category + spec.duration
local function playPrimitive(prim, element, point, targetInst)
    local spec = {
        pattern = prim.pattern,
        element = element,
        origin = prim.origin,
        category = prim.category,
        duration = prim.duration,
    }
    local ctx = { caster = hrp() }
    local soundPos = point
    if prim.pattern == "st_attack" then
        ctx.target = targetInst -- bolt needs a target Instance, not a point
    elseif prim.anchor == "target" then
        ctx.point = point
    else
        local r = hrp()
        soundPos = r and r.Position
    end
    pcall(function()
        CombatFX.play(spec, ctx)
    end)
    -- sound rides the primitive: an explicit soundPhase wins (buff/shield), else self ⇒ cast clip,
    -- target ⇒ impact clip (silent if none authored).
    local phase = prim.soundPhase or ((prim.anchor == "target") and "impact" or "cast")
    pcall(function()
        PowerSound.play(phase, element, soundPos)
    end)
end

local function label(pos, text)
    pcall(function()
        FloatingText.show(pos + Vector3.new(0, 6, 0), text, {
            color = Color3.fromRGB(255, 255, 255),
            size = 22,
            duration = 1.4,
            rise = 4,
        })
    end)
end

-- A persistent screen-space readout pinned to the LEFT side, so you always know which primitive ×
-- element is on screen (the floating text marks the spot; this names it).
local labelGui
local function ensureSideLabel()
    if labelGui and labelGui.Parent then
        return labelGui
    end
    local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then
        return nil
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "FXProbeReadout"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 60
    local box = Instance.new("Frame")
    box.Name = "Box"
    -- top-RIGHT, in the clear band above the squad strip: the left column (admin spawn + active-buffs)
    -- is packed while the probe runs, so this is the clear "off to the side" readout spot.
    box.AnchorPoint = Vector2.new(1, 0)
    box.Position = UDim2.new(1, -16, 0, 110)
    box.Size = UDim2.fromOffset(320, 60)
    box.BackgroundColor3 = Color3.fromRGB(18, 16, 26)
    box.BackgroundTransparency = 0.2
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = box
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(155, 120, 235)
    stroke.Thickness = 2
    stroke.Parent = box
    local txt = Instance.new("TextLabel")
    txt.Name = "Txt"
    txt.BackgroundTransparency = 1
    txt.Position = UDim2.fromOffset(14, 8)
    txt.Size = UDim2.new(1, -28, 1, -16)
    txt.Font = Enum.Font.GothamBold
    txt.TextColor3 = Color3.fromRGB(245, 240, 255)
    txt.TextSize = 19
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.TextYAlignment = Enum.TextYAlignment.Center
    txt.TextWrapped = true
    txt.RichText = true
    txt.Text = ""
    txt.Parent = box
    box.Parent = gui
    gui.Parent = pg
    labelGui = gui
    return gui
end
local function setSideLabel(modeWord, id, element)
    local gui = ensureSideLabel()
    if not gui then
        return
    end
    gui.Enabled = true
    gui.Box.Txt.Text = string.format(
        '<font color="#b88cff"><b>%s</b></font>\n%s  ·  <b>%s</b>',
        modeWord,
        id,
        element
    )
end
local function hideSideLabel()
    if labelGui then
        labelGui.Enabled = false
    end
end

-- ===== sequence model (shared by the auto sweep + manual Next/Repeat) =====
-- Each step = { kind = "cast"|"impact", id, element }. casting = on the player, impact = at a dummy.
local function buildSequence(mode)
    local seq = {}
    local probe = FX.probe
    local function add(kind, list)
        for _, element in ipairs(probe.elements) do
            for _, id in ipairs(list or {}) do
                seq[#seq + 1] = { kind = kind, id = id, element = element }
            end
        end
    end
    if mode == "casting" or mode == "real" then
        add("cast", probe.casting)
    end
    if mode == "impact" or mode == "real" then
        add("impact", probe.impact)
    end
    return seq
end

-- the impact dummy persists across manual steps (spawned for impact steps, cleared on cast steps)
local probeDummy
local function clearDummy()
    if probeDummy then
        pcall(function()
            probeDummy:Destroy()
        end)
        probeDummy = nil
    end
end
local function ensureDummy()
    if probeDummy and probeDummy.Parent then
        return probeDummy
    end
    local r = hrp()
    if not r then
        return nil
    end
    local d = Instance.new("Part")
    d.Name = "FXProbeDummy"
    d.Anchored = true
    d.CanCollide = false
    d.CanQuery = false
    d.Size = Vector3.new(4, 6, 4)
    d.Color = Color3.fromRGB(60, 60, 70)
    d.Material = Enum.Material.SmoothPlastic
    d.Transparency = 0.4
    d.CFrame = r.CFrame * CFrame.new(0, 0, -(FX.probe.dummy_distance or 16))
    d.Parent = Workspace
    probeDummy = d
    return d
end

-- play one step: cast on the player, impact at the dummy, with label + sound
local function playStep(step)
    if not step then
        return
    end
    local prim = FX.primitives[step.id]
    if not prim then
        return
    end
    if step.kind == "impact" then
        local d = ensureDummy()
        setSideLabel("IMPACT", step.id, step.element)
        playPrimitive(prim, step.element, d and d.Position, d)
        if d then
            label(d.Position, ("impact: %s · %s"):format(step.id, step.element))
        end
    else
        clearDummy()
        setSideLabel("CASTING", step.id, step.element)
        playPrimitive(prim, step.element)
        local r = hrp()
        if r then
            label(r.Position, ("cast: %s · %s"):format(step.id, step.element))
        end
    end
end

-- ===== auto sweep (the cycling FX PROBE button) =====
function PowerFXProbe.run(mode)
    running += 1
    local token = running
    manualMode = mode -- Next/Repeat continue in the same mode
    manualSeq = nil
    task.spawn(function()
        if not hrp() then
            return
        end
        local wait = FX.probe.step_seconds or 2.0
        for i, s in ipairs(buildSequence(mode)) do
            if token ~= running then
                return
            end
            manualCursor = i -- keep the manual cursor in sync so Next/Repeat pick up where it stopped
            playStep(s)
            task.wait(wait)
        end
        if token == running then
            clearDummy()
            hideSideLabel()
        end
    end)
end

-- ===== manual stepping (Next / Repeat buttons) =====
-- Next advances one step (wraps at the end); Repeat replays the current one. Both cancel any running
-- auto sweep (bump the token) so a sweep and a manual press don't fight.
function PowerFXProbe.next()
    running += 1
    if not manualSeq or #manualSeq == 0 then
        manualSeq = buildSequence(manualMode)
        manualCursor = 1
    else
        manualCursor = (manualCursor % #manualSeq) + 1
    end
    playStep(manualSeq[manualCursor])
end

function PowerFXProbe.repeatStep()
    running += 1
    if not manualSeq or #manualSeq == 0 then
        return PowerFXProbe.next()
    end
    playStep(manualSeq[manualCursor])
end

return PowerFXProbe
