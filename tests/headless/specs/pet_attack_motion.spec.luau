-- Real-hit pet attack choreography: role resolution, starter overrides, and clean settling.

local PetAttackMotion = loadModule("src/Shared/Game/PetAttackMotion.lua")
local shippedConfig = loadModule("configs/pet_follow.lua")

local CONFIG = {
    enabled = true,
    roles = {
        melee = { style = "lunge", duration = 0.4, depth = 2, recoil = 0.2 },
        tank = { style = "slam", duration = 0.5, depth = 1, drop = 0.5, height = 0.3 },
        ranged = { style = "recoil", duration = 0.3, recoil = 0.8, pitch = 0.2 },
        support = { style = "cast", duration = 0.6, height = 0.7, yaw = 0.2 },
    },
    by_type = {
        doggy = { depth = 2.5 },
        kitty = { recoil = 1.1 },
    },
}

return function()
    describe("shipped attack choreography", function()
        it("keeps replicated pet-sync diagnostics opt-in", function()
            expect(shippedConfig.diagnostics.replicate_pet_sync).to.equal(false)
            local service = readFile("src/Server/Services/PetFollowService.lua")
            expect(service:find("replicate_pet_sync == true", 1, true)).to.be.ok()
        end)

        it("plants melee pets so real-hit motion is not hidden by continuous orbit", function()
            expect(shippedConfig.attack.role_styles.melee).to.equal("static_ring")
        end)

        it("gives the whole melee role a sidestep and Doggy a readable envelope", function()
            local generic =
                PetAttackMotion.resolve(shippedConfig.attack.strike_motion, "melee", "other")
            local doggy =
                PetAttackMotion.resolve(shippedConfig.attack.strike_motion, "melee", "doggy")
            expect(generic.sidestep_degrees).to.near(10, 1e-6)
            expect(doggy.depth >= 3).to.equal(true)
            expect(doggy.recoil >= 0.5).to.equal(true)
            expect(doggy.duration >= 0.5).to.equal(true)
            expect(doggy.sidestep_degrees).to.near(10, 1e-6)
        end)

        it("preserves blaster firing-line, recoil, and zero sidestep", function()
            local ranged =
                PetAttackMotion.resolve(shippedConfig.attack.strike_motion, "ranged", "kitty")
            expect(shippedConfig.attack.role_styles.ranged).to.equal("firing_line")
            expect(ranged.style).to.equal("recoil")
            expect(ranged.recoil > 0).to.equal(true)
            expect(ranged.sidestep_degrees).to.equal(0)
        end)

        it("uses role choreography and no continuous flourish for mining", function()
            expect(shippedConfig.attack.mode.mining).to.equal("individual")
            expect(shippedConfig.attack.anim.mining.style).to.equal("none")
        end)
    end)

    describe("PetAttackMotion.advanceSidestep", function()
        it("advances odd and even equip slots ten degrees in opposite directions", function()
            local profile = { sidestep_degrees = 10 }
            local clockwise = PetAttackMotion.advanceSidestep(0, profile, 1)
            local counter = PetAttackMotion.advanceSidestep(0, profile, 2)
            expect(clockwise).to.near(math.rad(10), 1e-6)
            expect(counter).to.near(math.rad(350), 1e-6)
        end)

        it("accumulates completed strikes and leaves non-sidestep roles planted", function()
            local profile = { sidestep_degrees = 10 }
            local angle = PetAttackMotion.advanceSidestep(math.rad(10), profile, 1)
            expect(angle).to.near(math.rad(20), 1e-6)
            expect(PetAttackMotion.advanceSidestep(angle, {}, 1)).to.near(angle, 1e-6)
        end)
    end)

    describe("PetAttackMotion.resolve", function()
        it("uses a role profile and lets a starter species override it", function()
            local generic = PetAttackMotion.resolve(CONFIG, "melee", "other")
            local doggy = PetAttackMotion.resolve(CONFIG, "melee", "doggy")
            expect(generic.style).to.equal("lunge")
            expect(generic.depth).to.near(2, 1e-6)
            expect(doggy.depth).to.near(2.5, 1e-6)
            expect(doggy.enabled).to.equal(true)
        end)

        it("disables unknown and explicitly disabled styles safely", function()
            local unknown =
                PetAttackMotion.resolve({ roles = { melee = { style = "wat" } } }, "melee")
            expect(unknown.enabled).to.equal(false)
            local disabled = PetAttackMotion.resolve(CONFIG, "missing", "missing")
            expect(disabled.enabled).to.equal(false)
        end)
    end)

    describe("PetAttackMotion.sample", function()
        it("opens a melee strike at contact and settles exactly to zero", function()
            local profile = PetAttackMotion.resolve(CONFIG, "melee", "doggy")
            local contact, active = PetAttackMotion.sample(profile, 0)
            expect(active).to.equal(true)
            expect(contact.forward).to.near(2.5, 1e-6)

            local done, stillActive = PetAttackMotion.sample(profile, profile.duration)
            expect(stillActive).to.equal(false)
            expect(done.forward).to.equal(0)
            expect(done.height).to.equal(0)
        end)

        it("gives tanks a low planted contact pose", function()
            local profile = PetAttackMotion.resolve(CONFIG, "tank", "bear")
            local contact = PetAttackMotion.sample(profile, 0)
            expect(contact.forward > 0).to.equal(true)
            expect(contact.height < 0).to.equal(true)
        end)

        it("recoils ranged pets away from the target", function()
            local profile = PetAttackMotion.resolve(CONFIG, "ranged", "kitty")
            local contact = PetAttackMotion.sample(profile, 0)
            expect(contact.forward).to.near(-1.1, 1e-6)
            expect(contact.pitch < 0).to.equal(true)
        end)

        it("makes support motion peak upward during its cast", function()
            local profile = PetAttackMotion.resolve(CONFIG, "support", "bunny")
            local middle, active = PetAttackMotion.sample(profile, profile.duration * 0.5)
            expect(active).to.equal(true)
            expect(middle.height).to.near(0.7, 1e-6)
        end)
    end)
end
