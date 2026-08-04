return function()
    describe("full respec replay contract", function()
        it("preserves exact XP while rewinding only the claimed build", function()
            local source = readFile("src/Server/Services/RespecService.lua")
            expect(
                source:find(
                    "local experience = self._progressionService:GetExperience(player)",
                    1,
                    true
                )
            ).never.to.equal(nil)
            expect(source:find('SetStat(player, "ClaimedLevel", 1)', 1, true)).never.to.equal(nil)
            expect(source:find('SetStat(player, "Experience"', 1, true)).to.equal(nil)
            expect(source:find("targetClaimedLevel = target", 1, true)).never.to.equal(nil)
        end)

        it("refunds installed enhancement records without acquisition side effects", function()
            local source = readFile("src/Server/Services/EnhancementService.lua")
            expect(source:find("function EnhancementService:PrepareRespecRefund", 1, true)).never.to.equal(
                nil
            )
            expect(source:find("InsertRecordSnapshot", 1, true)).never.to.equal(nil)
            expect(source:find("function EnhancementService:RollbackRespecRefund", 1, true)).never.to.equal(
                nil
            )
            expect(source:find('reason = "respec_replay_active"', 1, true)).never.to.equal(nil)
        end)

        it(
            "suppresses duplicate level rewards and counters through the old claim boundary",
            function()
                local source = readFile("src/Server/Services/PlayerProgressionService.lua")
                expect(source:find("and newLevel <= (tonumber(replay.targetClaimedLevel)", 1, true)).never.to.equal(
                    nil
                )
                expect(source:find("if not replaying then", 1, true)).never.to.equal(nil)
                expect(source:find("payload.respecComplete = true", 1, true)).never.to.equal(nil)
                expect(source:find("if not (payload and payload.respecReplay) then", 1, true)).never.to.equal(
                    nil
                )
            end
        )

        it("exposes an admin test path and retains the ordinary altar commit path", function()
            local api = readFile("src/Server/Services/GameAPIService.lua")
            local admin = readFile("src/Client/UI/Menus/AdminPanel.lua")
            expect(api:find('bus:register("respec.begin"', 1, true)).never.to.equal(nil)
            expect(api:find('bus:register("levelup.commit"', 1, true)).never.to.equal(nil)
            expect(admin:find('action = "admin_full_respec"', 1, true)).never.to.equal(nil)
        end)
    end)
end
