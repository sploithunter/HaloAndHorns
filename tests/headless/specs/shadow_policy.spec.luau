local Policy = loadModule("src/Shared/Game/ShadowPolicy.lua")
local config = loadModule("configs/client_graphics.lua").shadows

return function()
    describe("nearby shadow policy", function()
        it("defaults missing or invalid preferences to Auto", function()
            expect(Policy.normalize(nil, config)).to.equal("auto")
            expect(Policy.normalize("invalid", config)).to.equal("auto")
            for _, mode in ipairs(config.modes) do
                expect(Policy.normalize(mode, config)).to.equal(mode)
            end
        end)

        it("does not change shadows during startup or a short slowdown", function()
            local state = Policy.new(config)
            Policy.sample(state, 10, config.warmup_seconds, config)
            expect(state.enabled).to.equal(true)
            Policy.sample(state, 10, config.slow_seconds - 1, config)
            expect(state.enabled).to.equal(true)
            Policy.sample(state, 60, 1, config)
            expect(state.slow).to.equal(0)
        end)

        it("disables only after sustained slow frames", function()
            local state = Policy.new(config)
            state.hold = 0
            for _ = 1, config.slow_seconds do
                Policy.sample(state, config.disable_below_fps - 1, 1, config)
            end
            expect(state.enabled).to.equal(false)
            expect(state.hold).to.equal(config.cooldown_seconds)
        end)

        it("requires both a cooldown and sustained recovery before restoring", function()
            local state = Policy.new(config)
            state.enabled = false
            state.hold = config.cooldown_seconds
            Policy.sample(state, 100, config.cooldown_seconds, config)
            expect(state.enabled).to.equal(false)
            Policy.sample(state, 60, config.recovery_seconds - 1, config)
            expect(state.enabled).to.equal(false)
            Policy.sample(state, 60, 1, config)
            expect(state.enabled).to.equal(true)
        end)

        it("resets the recovery timer if performance falls again", function()
            local state = Policy.new(config)
            state.enabled = false
            state.hold = 0
            Policy.sample(state, 60, config.recovery_seconds - 1, config)
            Policy.sample(state, 40, 1, config)
            expect(state.healthy).to.equal(0)
            expect(state.enabled).to.equal(false)
        end)

        it("respects manual On and Off independently of adaptive state", function()
            local state = Policy.new(config)
            expect(Policy.enabled("off", state)).to.equal(false)
            state.enabled = false
            expect(Policy.enabled("on", state)).to.equal(true)
            expect(Policy.enabled("auto", state)).to.equal(false)
        end)

        it("clears observations after backgrounding without undoing the current state", function()
            local state = Policy.new(config)
            state.enabled = false
            state.hold = 0
            state.healthy = 19
            Policy.resetObservation(state, config)
            expect(state.enabled).to.equal(false)
            expect(state.healthy).to.equal(0)
            expect(state.hold).to.equal(config.warmup_seconds)
        end)

        it("uses separate entrance and exit distances to prevent boundary flicker", function()
            local middle = (config.near_studs + config.far_studs) / 2
            expect(Policy.nearby(middle * middle, false, config)).to.equal(false)
            expect(Policy.nearby(middle * middle, true, config)).to.equal(true)
            expect(Policy.nearby((config.far_studs + 1) ^ 2, true, config)).to.equal(false)
            expect(Policy.nearby(config.near_studs ^ 2, false, config)).to.equal(true)
        end)

        it("measures from the nearest surface, preserving large nearby walls", function()
            expect(Policy.distanceSquared(505, 0, 0, 500, 10, 10)).to.equal(25)
            expect(Policy.distanceSquared(0, 0, 0, 500, 10, 10)).to.equal(0)
            expect(Policy.distanceSquared(-13, -14, 10, 10, 10, 10)).to.equal(25)
        end)

        it("wires the preference to boot, Settings, and the server whitelist", function()
            local client = readFile("src/Client/Systems/ShadowController.lua")
            local boot = readFile("src/Client/init.client.lua")
            local panel = readFile("src/Client/UI/Menus/SettingsPanel.lua")
            local api = readFile("src/Server/Services/GameAPIService.lua")
            expect(boot:find("require(script.Systems.ShadowController).start()", 1, true)).to.be.ok()
            expect(panel:find("ShadowController.setPreference(value)", 1, true)).to.be.ok()
            expect(api:find("data.Settings.ClientPrefs.shadowMode = args.shadowMode", 1, true)).to.be.ok()
            expect(client:find("Workspace.DescendantRemoving:Connect(forget)", 1, true)).to.be.ok()
            expect(client:find("UserInputService.WindowFocusReleased", 1, true)).to.be.ok()
            expect(client:find('callBus("settings.set", { shadowMode = mode })', 1, true)).to.be.ok()
            expect(client:find("Destroy(", 1, true)).to.equal(nil)
        end)
    end)
end
