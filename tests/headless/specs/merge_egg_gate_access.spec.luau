local MergeEggGateAccess = loadModule("src/Shared/Game/MergeEggGateAccess.lua")
local internalAccounts = loadModule("configs/internal_accounts.lua")
local mergeConfig = loadModule("configs/merge_egg_prototype.lua")

return function()
    describe("Merge Egg preview gate access", function()
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

        it("fails closed for public players", function()
            expect(MergeEggGateAccess.allows(access, internalAccounts, 1)).to.equal(false)
            expect(MergeEggGateAccess.allows(access, internalAccounts, nil)).to.equal(false)
        end)
    end)
end
