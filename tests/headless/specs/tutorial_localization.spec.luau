--[[
    Tutorial localization catalog and stable-key contract.
    Run: mise run test-headless
]]

local TutorialFlow = loadModule("src/Shared/Game/TutorialFlow.lua")
local TutorialLocalization = loadModule("src/Shared/Game/TutorialLocalization.lua")
local cfg = loadModule("configs/tutorial.lua")

return function()
    describe("TutorialLocalization", function()
        it("normalizes Roblox locale variants", function()
            expect(TutorialLocalization.languageFor("es-MX")).to.equal("es")
            expect(TutorialLocalization.languageFor("es_ES")).to.equal("es")
            expect(TutorialLocalization.languageFor("pt-BR")).to.equal("pt-br")
            expect(TutorialLocalization.languageFor("pt-PT")).to.equal("pt-br")
            expect(TutorialLocalization.languageFor("fr-FR")).to.equal("en")
        end)

        it("translates supported tutorial copy and falls back safely", function()
            expect(TutorialLocalization.text("es-MX", "tutorial.target.hatch", "fallback")).to.equal(
                "⬇ ABRE"
            )
            expect(TutorialLocalization.text("pt-BR", "tutorial.target.fight", "fallback")).to.equal(
                "⬇ LUTE"
            )
            expect(TutorialLocalization.text("fr-FR", "missing.key", "English fallback")).to.equal(
                "English fallback"
            )
        end)

        it("has Spanish and Brazilian Portuguese copy for every authored step", function()
            for _, step in ipairs(cfg.steps) do
                expect(type(step.localization_key)).to.equal("string")
                for _, localeId in ipairs({ "es", "pt-br" }) do
                    local missingTitle = "missing-title-" .. step.id
                    local missingBody = "missing-body-" .. step.id
                    expect(
                        TutorialLocalization.text(
                            localeId,
                            step.localization_key .. ".title",
                            missingTitle
                        )
                    ).never.to.equal(missingTitle)
                    expect(
                        TutorialLocalization.text(
                            localeId,
                            step.localization_key .. ".body",
                            missingBody
                        )
                    ).never.to.equal(missingBody)
                    if type(step.guide) == "table" then
                        for phase, entry in pairs(step.guide) do
                            if type(entry) == "table" and type(entry.title) == "string" then
                                local missingGuide = "missing-guide-" .. step.id .. "-" .. phase
                                expect(
                                    TutorialLocalization.text(
                                        localeId,
                                        step.localization_key .. ".guide." .. phase .. ".title",
                                        missingGuide
                                    )
                                ).never.to.equal(missingGuide)
                            end
                        end
                    end
                end
            end
        end)

        it("carries stable localization keys in tutorial state packets", function()
            local state = TutorialFlow.stateFor(cfg, { step = 1, count = 0 })
            expect(state.title_key).to.equal(cfg.steps[1].localization_key .. ".title")
            expect(state.body_key).to.equal(cfg.steps[1].localization_key .. ".body")
            expect(type(state.title)).to.equal("string")
            expect(type(state.body)).to.equal("string")
        end)
    end)
end
