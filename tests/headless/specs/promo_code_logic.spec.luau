local PromoCodeLogic = loadModule("src/Shared/Game/PromoCodeLogic.lua")

local function config()
    return {
        version = 1,
        enabled = true,
        input = { min_length = 3, max_length = 16 },
        codes = {
            kade_week_one = {
                code = "KADEWEEK1",
                aliases = { "KADE-1" },
                enabled = true,
                campaign = "kade_x_week_1",
                minimum_level = 2,
                per_player_limit = 1,
                starts_at = 100,
                ends_at = 200,
                reward = { currencies = { gems = 25 } },
            },
        },
    }
end

return function()
    describe("PromoCodeLogic", function()
        it("normalizes case and accidental whitespace", function()
            expect(PromoCodeLogic.normalize("  kade week 1 ")).to.equal("KADEWEEK1")
            expect(PromoCodeLogic.normalize("bad!code")).to.equal(nil)
        end)

        it("finds canonical codes and aliases by stable id", function()
            local id = PromoCodeLogic.find(config(), "kadE-week1")
            expect(id).to.equal(nil)
            id = PromoCodeLogic.find(config(), "kade-1")
            expect(id).to.equal("kade_week_one")
        end)

        it("extracts a code from plain and query LaunchData", function()
            expect(PromoCodeLogic.extractLaunchCode("code=KADE-1&source=x")).to.equal("KADE-1")
            expect(PromoCodeLogic.extractLaunchCode("promo=KADE%20WEEK%201")).to.equal("KADEWEEK1")
            expect(PromoCodeLogic.extractLaunchCode("KADE-1")).to.equal("KADE-1")
        end)

        it("enforces dates, level, Studio-only, and per-player claims", function()
            local definition = config().codes.kade_week_one
            expect(PromoCodeLogic.evaluate(definition, { now = 99, level = 50 })).to.equal(false)
            expect(PromoCodeLogic.evaluate(definition, { now = 150, level = 1 })).to.equal(false)
            expect(PromoCodeLogic.evaluate(definition, { now = 150, level = 2 })).to.equal(true)
            expect(PromoCodeLogic.evaluate(definition, { now = 150, level = 2, claimedCount = 1 })).to.equal(
                false
            )
            expect(PromoCodeLogic.evaluate(definition, { now = 200, level = 50 })).to.equal(false)

            definition.studio_only = true
            expect(PromoCodeLogic.evaluate(definition, { now = 150, level = 2, isStudio = false })).to.equal(
                false
            )
            expect(PromoCodeLogic.evaluate(definition, { now = 150, level = 2, isStudio = true })).to.equal(
                true
            )
        end)

        it("validates canonical unique definitions with a non-empty reward", function()
            local cfg = config()
            expect(PromoCodeLogic.validate(cfg)).to.equal(true)
            cfg.codes.other = {
                code = "KADE-1",
                reward = { currencies = { gems = 1 } },
            }
            expect(PromoCodeLogic.validate(cfg)).to.equal(false)
            cfg.codes.other.code = "OTHER"
            cfg.codes.other.reward = {}
            expect(PromoCodeLogic.validate(cfg)).to.equal(false)
        end)

        it("ships only a Studio-safe smoke code", function()
            local live = loadModule("configs/promo_codes.lua")
            expect(PromoCodeLogic.validate(live)).to.equal(true)
            expect(live.codes.studio_smoke.studio_only).to.equal(true)
            expect(live.codes.studio_smoke.reward.currencies.gems).to.equal(25)
        end)
    end)
end
