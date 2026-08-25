local RealmPortalPresentation = loadModule("src/Shared/Game/RealmPortalPresentation.lua")
local layers = loadModule("configs/layers.lua")

return function()
    describe("RealmPortalPresentation", function()
        it(
            "keeps Heaven 3 typography aligned with its neighboring layers during testing",
            function()
                expect(RealmPortalPresentation.caption("heaven_2", layers)).to.equal(
                    "Heaven 2\nLv 14"
                )
                expect(RealmPortalPresentation.caption("heaven_3", layers)).to.equal(
                    "Heaven 3\nLv 21"
                )
                expect(RealmPortalPresentation.caption("heaven_4", layers)).to.equal(
                    "Heaven 4\nLv 28"
                )
            end
        )

        it("keeps Hell 3 typography aligned with its neighboring layers during testing", function()
            expect(RealmPortalPresentation.caption("hell_2", layers)).to.equal("Hell 2\nLv 14")
            expect(RealmPortalPresentation.caption("hell_3", layers)).to.equal("Hell 3\nLv 21")
            expect(RealmPortalPresentation.caption("hell_4", layers)).to.equal("Hell 4\nLv 28")
        end)
    end)
end
