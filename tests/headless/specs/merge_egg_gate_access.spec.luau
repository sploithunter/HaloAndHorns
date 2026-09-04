local MergeEggGateAccess = loadModule("src/Shared/Game/MergeEggGateAccess.lua")
local internalAccounts = loadModule("configs/internal_accounts.lua")
local mergeConfig = loadModule("configs/merge_egg_prototype.lua")

return function()
    describe("Merge Egg public gate access", function()
        local access = mergeConfig.gate.access

        it("allows every canonical internal account", function()
            for _, account in ipairs(internalAccounts.accounts) do
                expect(MergeEggGateAccess.allows(access, internalAccounts, account.id)).to.equal(
                    true
                )
            end
        end)

        it("allows Kade without adding him to the global internal-account registry", function()
            expect(MergeEggGateAccess.allows(access, internalAccounts, 536245038)).to.equal(true)
            expect(#internalAccounts.accounts).to.equal(28)
        end)

        it("opens to ordinary players without internal-account or collaborator grants", function()
            expect(access.public).to.equal(true)
            expect(MergeEggGateAccess.allows(access, {}, 1)).to.equal(true)
            expect(MergeEggGateAccess.allows(access, {}, 9876543210)).to.equal(true)
            expect(MergeEggGateAccess.allows(access, internalAccounts, nil)).to.equal(false)
        end)
        it("retains fail-closed preview policy when explicitly configured non-public", function()
            local preview =
                { public = false, internal_accounts = true, additional_user_ids = { 536245038 } }
            expect(MergeEggGateAccess.allows(preview, internalAccounts, 1)).to.equal(false)
            expect(MergeEggGateAccess.allows(preview, internalAccounts, 536245038)).to.equal(true)
            expect(MergeEggGateAccess.allows({}, {}, 1)).to.equal(false)
        end)
    end)
end
