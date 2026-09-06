local Logic = loadModule("src/Shared/Game/HellGateLightning.lua")
local hall = loadModule("configs/hall_of_worlds.lua")
local cfg = hall.hell_gate_lightning

local function fixture()
    local markers = {}
    local n = 0
    for role, names in pairs(cfg.markers) do
        for _, name in ipairs(names) do
            n += 1
            markers[name] =
                { name = name, role = role, x = n, y = role == "sky" and 400 or 0, z = 0 }
        end
    end
    return Logic.roles(markers, cfg.markers), markers
end

return function()
    describe("Hell gate lightning", function()
        it("uses all sixteen authored points without accepting loose or legacy markers", function()
            local roles, markers = fixture()
            markers.lightning1 = { x = 0, y = 0, z = 0 }
            roles = Logic.roles(markers, cfg.markers)
            expect(#roles.sky).to.equal(1)
            expect(#roles.inner).to.equal(2)
            expect(#roles.left).to.equal(6)
            expect(#roles.right).to.equal(6)
            expect(#roles.crown).to.equal(1)
            expect(#roles.targets).to.equal(15)
        end)

        it("strikes from sky to every non-sky endpoint", function()
            local roles = fixture()
            local reached = {}
            for index = 1, #roles.targets do
                local from, to = Logic.pick(roles, "sky", "left", function(n)
                    return n == 1 and 1 or index
                end)
                expect(from.role).to.equal("sky")
                expect(to.role == "sky").to.equal(false)
                reached[to.name] = true
            end
            local count = 0
            for _ in pairs(reached) do
                count += 1
            end
            expect(count).to.equal(15)
        end)

        it("sends only front/back inner origins toward the selected left or right side", function()
            local roles = fixture()
            for _, side in ipairs({ "left", "right" }) do
                for index = 1, #roles[side] do
                    local from, to = Logic.pick(roles, "inner", side, function(n)
                        return n == #roles.inner and 2 or index
                    end)
                    expect(from.role).to.equal("inner")
                    expect(to.role).to.equal(side)
                end
            end
        end)

        it("does not fabricate endpoints when groups are absent or partial", function()
            local roles = Logic.roles({}, cfg.markers)
            local from, to = Logic.pick(roles, "sky", "left", function()
                return 1
            end)
            expect(from).never.to.be.ok()
            expect(to).never.to.be.ok()
            roles.inner = { {} }
            from, to = Logic.pick(roles, "inner", "right", function()
                return 1
            end)
            expect(from).never.to.be.ok()
            expect(to).never.to.be.ok()
        end)

        it("follows the character location rather than ownership or the high sky marker", function()
            local a = { id = "A", roles = { targets = { { x = 0, y = 0, z = 0 } } } }
            local b = { id = "B", roles = { targets = { { x = 100, y = 0, z = 0 } } } }
            local c = { id = "C", roles = { targets = { { x = 200, y = 0, z = 0 } } } }
            local nearby = Logic.nearest({ c, b, a }, { x = 0, y = 0, z = 0 }, 150, 2)
            expect(#nearby).to.equal(2)
            expect(nearby[1]).to.equal(a)
            expect(nearby[2]).to.equal(b)
            nearby = Logic.nearest({ c, b, a }, { x = 200, y = 0, z = 0 }, 150, 1)
            expect(#nearby).to.equal(1)
            expect(nearby[1]).to.equal(c)
            expect(#Logic.nearest({ a }, { x = 0, y = 400, z = 0 }, 150, 2)).to.equal(0)
        end)

        it(
            "reschedules from now after a delayed frame instead of replaying missed pulses",
            function()
                expect(Logic.nextAt(100, { 4, 7 }, 0)).to.equal(104)
                expect(Logic.nextAt(100, { 4, 7 }, 1)).to.equal(107)
                expect(Logic.nextAt(1000, { 4, 7 }, 0.5)).to.equal(1005.5)
            end
        )

        it("is independently enabled, silent, budgeted, and hooked into client startup", function()
            expect(cfg.enabled).to.equal(true)
            expect(cfg.maximum_visible_gates).to.equal(2)
            expect(cfg.maximum_active_strikes).to.equal(2)
            expect(cfg.bolt.origin_limit).to.equal(1)
            expect(cfg.bolt.strands_per_origin).to.equal(1)
            expect(cfg.bolt.segments).to.equal(24)
            expect(cfg.bolt.center_flash).to.equal(false)
            expect(cfg.bolt.sound_name).to.equal("_silent")
            expect(hall.arch_lightning.excluded_host_prefixes[1]).to.equal(cfg.host_prefix)
            expect(cfg.inner_interval[1] > cfg.bolt.duration + cfg.lifetime_margin_seconds).to.equal(
                true
            )
            local source = readFile("src/Client/Systems/HellGateLightning.lua")
            expect(string.find(source, "cfg.maximum_active_strikes", 1, true)).to.be.ok()
            expect(string.find(source, "FloraSway.isEnabled()", 1, true)).to.be.ok()
            expect(string.find(source, "FireServer", 1, true)).never.to.be.ok()
            expect(string.find(source, ".CFrame =", 1, true)).never.to.be.ok()
            expect(
                string.find(
                    readFile("src/Client/init.client.lua"),
                    "Systems.HellGateLightning",
                    1,
                    true
                )
            ).to.be.ok()
        end)
    end)
end
