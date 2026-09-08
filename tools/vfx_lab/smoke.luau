-- Run in Studio Client after loading the dedicated lab. Leaves the UI preview intact.
local RS = game:GetService("ReplicatedStorage")
local FX = require(RS.Shared.Effects.CrystalEruption)
local CombatFX = require(RS.Shared.Effects.CombatFX)
local Timeline = require(RS.Shared.Effects.CrystalTimeline)
local saved = require(RS.Configs.vfx.crystal_eruption)
local schema = require(RS.Configs.vfx.crystal_schema)
local style = require(RS.Configs.vfx.crystal_style)
local probe = game:GetService("Players").LocalPlayer.PlayerGui.VFXLab.Probe
local handles = {}
local function cast(p)
    local h = CombatFX.play({ pattern = "impact", vfx = "crystal_eruption" }, {
        point = Vector3.new(20, 0, 0),
        vfxPreview = { preset = p, persistent = true },
    })
    assert(type(h) == "table", "CombatFX route failed")
    h.paused = true
    table.insert(handles, h)
    return h
end
local function run()
    assert(Timeline.validate(saved, schema))
    assert(
        CombatFX.play({ pattern = "impact", vfx = "crystal_eruption" }, {}) == false,
        "Missing point must reject"
    )
    local h = cast(table.clone(saved))
    local t = saved.anticipation + saved.stagger + saved.rise
    h:seek(t)
    local wedge = h.model.Crystal1Facet1
    local originalSize, originalFrame = wedge.Size, wedge.CFrame
    h:seek(0)
    assert(wedge.Transparency == 1, "Anticipation leaked crystals")
    h:seek(t)
    assert(wedge.Size == originalSize and wedge.CFrame == originalFrame, "Reverse seek drift")
    local changed = table.clone(saved)
    changed.height = saved.height + 1
    assert(h:update(changed))
    assert(wedge.Size.Y > originalSize.Y, "Paused shape edit was ignored")
    changed = table.clone(changed)
    changed.count += 1
    assert(h:update(changed))
    assert(
        #h.model:GetChildren() == changed.count * 12 + style.ring_segments + changed.spark_count,
        "Topology did not rebuild"
    )
    local invalid = table.clone(changed)
    invalid.height = math.huge
    assert(h:update(invalid) == false, "Invalid preview accepted")
    h:stop()
    h:stop()
    assert(h.model.Parent == nil, "Stop leaked geometry")
    for _ = 1, style.max_active + 2 do
        cast(table.clone(saved))
    end
    assert(FX.activeCount() == style.max_active, "Active cast budget exceeded")
    assert(handles[2].stopped, "Oldest cast was not retired")
    for _, effect in ipairs(handles) do
        effect:stop()
    end
    assert(FX.activeCount() == 0, "Cleanup leaked handles")
    local normal = CombatFX.play(
        { pattern = "impact", vfx = "crystal_eruption" },
        { point = Vector3.zero }
    )
    assert(normal and not normal.persistent, "Saved cast used preview persistence")
    normal:seek(Timeline.duration(saved))
    game:GetService("RunService").Heartbeat:Wait()
    game:GetService("RunService").Heartbeat:Wait()
    assert(normal.stopped, "Normal cast failed to auto-clean")
    return "PASS: config, CombatFX route, reverse seek, paused edit, rebuild, invalid input, cap and cleanup"
end
local ok, result = pcall(run)
for _, h in ipairs(handles) do
    h:stop()
end
probe:Invoke("cast")
probe:Invoke("seek", require(RS.Configs.vfx.lab).preview_time)
assert(ok, result)
return result
