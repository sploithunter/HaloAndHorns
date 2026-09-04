local Awards = loadModule("src/Shared/Game/AchievementBannerAwards.lua")

local function config()
    local c = table.clone(loadModule("configs/achievement_banners.lua"))
    c.awards = table.clone(c.awards)
    return c
end

return function()
    describe("endless wave banner milestones", function()
        it("defines 300, 350, 400 and later milestones with alternating cloth colors", function()
            local c = config()
            for _, wave in ipairs({ 300, 350, 400, 450, 1000, 10000 }) do
                Awards.expandWaveCatalog(c, wave, {})
                local award = c.awards["wave_" .. tostring(wave)]
                expect(award.trigger.at_least).to.equal(wave)
                expect(award.value).to.equal(tostring(wave))
                expect(c.styles[award.style]).to.be.ok()
                expect(c.model.variants[award.variant]).to.be.ok()
            end
            expect(c.awards.wave_300.style == c.awards.wave_350.style).to.equal(false)
            expect(c.awards.wave_350.style == c.awards.wave_400.style).to.equal(false)
        end)
        it(
            "does not award a milestone early and reconstructs owned definitions on rejoin",
            function()
                local c = config()
                Awards.expandWaveCatalog(c, 349, { wave_400 = {} })
                expect(c.awards.wave_300).to.be.ok()
                expect(c.awards.wave_400).to.be.ok()
                local eligible = Awards.eligible(c.awards, { merge_wave = 349 })
                expect(table.find(eligible, "wave_300")).to.be.ok()
                expect(table.find(eligible, "wave_400")).never.to.be.ok()
                Awards.expandWaveCatalog(c, math.huge, {})
                expect(c.awards.wave_inf).never.to.be.ok()
            end
        )
        it(
            "replaces only lower wave cloth and preserves ownership and other wall awards",
            function()
                local c = config()
                local state = Awards.normalize(nil)
                for id in pairs(c.awards) do
                    Awards.grant(state, id, {}, 1)
                end
                Awards.present(state, Awards.pendingIds(state, c.awards), 8, 1, c.awards)
                expect(#state.displayed).to.equal(7)
                for _, wave in ipairs({ 300, 350, 400 }) do
                    Awards.expandWaveCatalog(c, wave, state.owned)
                    local id = "wave_" .. tostring(wave)
                    Awards.grant(state, id, { value = wave }, wave)
                    -- Earned during combat does not replace the displayed banner before ceremony.
                    Awards.reconcileDisplayed(state, c.awards, 8)
                    expect(table.find(state.displayed, id)).never.to.be.ok()
                    Awards.present(state, Awards.pendingIds(state, c.awards), 8, wave, c.awards)
                    expect(#state.displayed).to.equal(7)
                    expect(table.find(state.displayed, id)).to.be.ok()
                    expect(table.find(state.displayed, "level_50")).to.be.ok()
                    expect(table.find(state.displayed, "heaven_3_egg")).to.be.ok()
                    expect(state.owned.wave_250).to.be.ok()
                end
                expect(table.find(state.displayed, "wave_350")).never.to.be.ok()
                expect(state.owned.wave_350).to.be.ok()
                local rejoined = Awards.normalize(state)
                Awards.reconcileDisplayed(rejoined, c.awards, 8)
                expect(table.find(rejoined.displayed, "wave_400")).to.be.ok()
                expect(#rejoined.displayed).to.equal(7)
            end
        )
    end)
end
