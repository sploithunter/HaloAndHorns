local Confirmation = loadModule("src/Shared/Game/MergeReplacementConfirmation.lua")
local config = loadModule("configs/merge_egg_prototype.lua")

return function()
    describe("Merge workshop replacement confirmation", function()
        local families = {
            { id = "saw_blade", name = "Saw Blades" },
            { id = "impaler_palisade", name = "Impaler Palisade" },
        }

        it("requires confirmation only when a different family replaces an installation", function()
            local replacement = Confirmation.describe({
                installed = true,
                slot = "lane",
                family = "saw_blade",
                tier = 3,
                families = families,
            }, families[2])
            expect(replacement.currentName).to.equal("Saw Blades")
            expect(replacement.currentTier).to.equal(3)
            expect(replacement.targetName).to.equal("Impaler Palisade")
            expect(Confirmation.isConfirmed(nil, replacement)).to.equal(false)
            expect(Confirmation.isConfirmed(replacement.key, replacement)).to.equal(true)

            expect(Confirmation.describe({ installed = false }, families[2])).never.to.be.ok()
            expect(Confirmation.describe({
                installed = true,
                family = "saw_blade",
                tier = 3,
                families = families,
            }, families[1])).never.to.be.ok()
        end)

        it("invalidates confirmation when the source tier, slot, or target changes", function()
            local original = Confirmation.describe({
                installed = true,
                slot = "lane",
                family = "saw_blade",
                tier = 3,
                families = families,
            }, families[2])
            local changed = Confirmation.describe({
                installed = true,
                slot = "egg",
                family = "saw_blade",
                tier = 2,
                families = families,
            }, families[2])
            expect(Confirmation.isConfirmed(original.key, changed)).to.equal(false)
        end)

        it(
            "keeps destructive warning copy in config and enforces confirmation on the server",
            function()
                local copy = config.team.workshop_replacement_confirmation
                expect(copy.title:find("REPLACE", 1, true)).to.be.ok()
                expect(#copy.lines).to.equal(3)
                expect(copy.button).to.equal("CONFIRM REPLACE")

                local service = readFile("src/Server/Services/MergeEggPrototypeService.lua")
                expect(service:find('nextState.operation == "replaced"', 1, true)).to.be.ok()
                expect(service:find("MergeReplacementConfirmation.key", 1, true)).to.be.ok()
                expect(
                    service:find(
                        "request.replacementConfirmationKey ~= expectedConfirmationKey",
                        1,
                        true
                    )
                ).to.be.ok()

                for _, path in ipairs({
                    "src/Client/UI/Components/MergeCannonMenu.lua",
                    "src/Client/UI/Components/MergeBulwarkMenu.lua",
                }) do
                    local menu = readFile(path)
                    expect(menu:find("replacementConfirmKey", 1, true)).to.be.ok()
                    expect(
                        menu:find(
                            "replacementConfirmationKey = replacement and replacement.key or nil",
                            1,
                            true
                        )
                    ).to.be.ok()
                end
            end
        )
    end)
end
