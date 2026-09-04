local Design = loadModule("src/Shared/Game/AchievementBannerDesign.lua")
local Motion = loadModule("src/Shared/Game/AchievementBannerMotion.lua")
local config = loadModule("configs/achievement_banners.lua")

return function()
    describe("achievement banner design", function()
        it("normalizes arbitrary achievement copy into the cloth alphabet", function()
            local spec = Design.normalizeSpec({
                style = "battle",
                title = "Wave!",
                value = " 1,250 ",
                footer = "No pets down?",
            }, config)
            expect(spec.style).to.equal("battle")
            expect(spec.title).to.equal("WAVE")
            expect(spec.value).to.equal("1250")
            expect(spec.footer).to.equal("NO PETS DOWN")
        end)

        it("rasterizes a full RGBA cloth map with achievement-dependent art", function()
            local champion = Design.render({ style = "champion", value = 100 }, config)
            local battle = Design.render({ style = "battle", value = 250 }, config)
            expect(buffer.len(champion.pixels)).to.equal(512 * 512 * 4)
            expect(champion.cacheKey).to.equal("champion|LEVEL|100|REALM CHAMPION")
            expect(battle.cacheKey).to.equal("battle|WAVE|250|BATTLE HONORS")
            -- The top-left textile field and central achievement field are opaque and style-specific.
            expect(buffer.readu8(champion.pixels, 3)).to.equal(255)
            expect(buffer.readu8(champion.pixels, 0) == buffer.readu8(battle.pixels, 0)).to.equal(
                false
            )
            local centerOffset = ((256 * 512 + 256) * 4)
            expect(buffer.readu8(champion.pixels, centerOffset + 3)).to.equal(255)
        end)
    end)

    describe("achievement banner flutter", function()
        it("is deterministic and bounded by the configured bone amplitude", function()
            local first = Motion.sample(4.5, 1.2, 5, config.motion)
            local second = Motion.sample(4.5, 1.2, 5, config.motion)
            expect(first.roll).to.equal(second.roll)
            local limit = math.rad(config.motion.amplitudes_degrees[5])
            expect(math.abs(first.pitch) <= limit).to.equal(true)
            expect(math.abs(first.yaw) <= limit).to.equal(true)
            expect(math.abs(first.roll) <= limit).to.equal(true)
        end)
    end)

    describe("achievement banner asset and runtime wiring", function()
        it("keeps text in EditableImage content and movement on explicit bones", function()
            local renderer = readFile("src/Client/Systems/AchievementBannerRenderer.lua")
            local flutter = readFile("src/Client/Systems/AchievementBannerFlutter.lua")
            local client = readFile("src/Client/init.client.lua")
            expect(renderer:find("CreateEditableImage", 1, true)).to.be.ok()
            expect(renderer:find("WritePixelsBuffer", 1, true)).to.be.ok()
            expect(renderer:find("CreateSurfaceAppearanceAsync", 1, true)).to.be.ok()
            expect(renderer:find("ContentType.fromObject", 1, true)).to.be.ok()
            expect(renderer:find("config.texture.rescan_seconds", 1, true)).to.be.ok()
            expect(renderer:find("TextLabel", 1, true)).to.equal(nil)
            expect(flutter:find("CollectionService:GetTagged(config.tag)", 1, true)).to.be.ok()
            expect(flutter:find("host:FindFirstChild(name, true)", 1, true)).to.be.ok()
            expect(flutter:find("bone.Transform = CFrame.Angles", 1, true)).to.be.ok()
            expect(client:find("AchievementBannerController).start()", 1, true)).to.be.ok()
        end)

        it("ships both shared-rig Blender silhouettes with fully weighted UV cloth", function()
            local manifest = readFile(
                "assets/source/props/achievement_banners/generated/achievement_banners_manifest.json"
            )
            expect(manifest:find('"variant": "champion_standard"', 1, true)).to.be.ok()
            expect(manifest:find('"variant": "victory_swallowtail"', 1, true)).to.be.ok()
            expect(manifest:find('"weighted_vertices": 425', 1, true)).to.be.ok()
            expect(manifest:find('"texture_uv": "UVMap"', 1, true)).to.be.ok()
            expect(manifest:find('"ClothTip"', 1, true)).to.be.ok()
        end)
    end)
end
