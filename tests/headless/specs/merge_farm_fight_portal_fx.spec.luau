local mergeConfig = loadModule("configs/merge_egg_prototype.lua")

return function()
    describe("Merge Farm & Fight portal presentation", function()
        it("authors one cheeky but explicit return gate for each realm theme", function()
            local cfg = mergeConfig.farm_fight_portals
            expect(cfg.enabled).to.equal(true)
            expect(cfg.marker_name).to.equal("LightningRing")
            expect(#cfg.portals).to.equal(2)

            local heaven = cfg.portals[1]
            local hell = cfg.portals[2]
            expect(heaven.id).to.equal("heaven_farm")
            expect(heaven.destination).to.equal("PORTAL TO FARM & FIGHT")
            expect(heaven.word).to.equal("FARM")
            expect(heaven.tagline).to.equal("GROW YOUR FORTUNE")
            expect(hell.id).to.equal("hell_fight")
            expect(hell.destination).to.equal("PORTAL TO FARM & FIGHT")
            expect(hell.word).to.equal("FIGHT")
            expect(hell.tagline).to.equal("EARN IT THE HARD WAY")
            expect(heaven.ancestor_name == hell.ancestor_name).to.equal(false)
        end)

        it("keeps the veil, motes, lettering, and lightning config-owned", function()
            local cfg = mergeConfig.farm_fight_portals
            expect(cfg.veil.material).to.equal("ForceField")
            expect(cfg.veil.diameter_scale < 1).to.equal(true)
            expect(cfg.orbit.count >= 18).to.equal(true)
            expect(cfg.particles.texture).to.equal(
                "rbxasset://textures/particles/sparkles_main.dds"
            )
            expect(cfg.lightning.minimum_arc_degrees >= 60).to.equal(true)
            expect(cfg.lightning.bolt.sound_name).to.equal("_silent")
            expect(#cfg.portals[1].palette.lightning).to.equal(3)
            expect(#cfg.portals[2].palette.lightning).to.equal(3)
            expect(cfg.portals[1].palette.veil[2] > cfg.portals[1].palette.veil[1]).to.equal(true)
            expect(cfg.portals[2].palette.veil[1] > cfg.portals[2].palette.veil[2]).to.equal(true)
        end)

        it("boots the client effect and derives presentation from the authored ring", function()
            local initSource = readFile("src/Client/init.client.lua")
            local source = readFile("src/Client/Systems/MergeFarmFightPortalFX.lua")
            expect(initSource:find("Systems.MergeFarmFightPortalFX", 1, true)).to.be.ok()
            expect(source:find("EnchantLightning.Play", 1, true)).to.be.ok()
            expect(source:find("math.min(ring.Size.Y, ring.Size.Z)", 1, true)).to.be.ok()
            expect(source:find("ring.CFrame", 1, true)).to.be.ok()
            expect(source:find("ring.LocalTransparencyModifier = 1", 1, true)).to.be.ok()
            expect(source:find("spec.ancestor_name", 1, true)).to.be.ok()
            expect(source:find("Meshy_AI_", 1, true)).never.to.be.ok()
        end)
    end)
end
