return function()
    local function count(source, needle)
        local total = 0
        local at = 1
        while true do
            local first, last = string.find(source, needle, at, true)
            if not first then
                return total
            end
            total += 1
            at = last + 1
        end
    end

    describe("authoritative combat application contract", function()
        it("keeps combat services from writing health around ApplyDamage/ApplyPowerHeal", function()
            local migrated = {
                "src/Server/Services/BreakableService.lua",
                "src/Server/Services/PetFollowService.lua",
                "src/Server/Services/PowerService.lua",
                "src/Server/Services/SummonService.lua",
            }
            for _, path in ipairs(migrated) do
                local source = readFile(path)
                expect(count(source, 'SetAttribute("HP"')).to.equal(0)
                expect(count(source, 'SetAttribute("CombatDamageTaken"')).to.equal(0)
            end
        end)

        it("allows EnemyService only its spawn/scale and silent-regeneration writes", function()
            local source = readFile("src/Server/Services/EnemyService.lua")
            -- HP: initial decor, silent enemy regen, spawn/team scaling.
            expect(count(source, 'SetAttribute("HP"')).to.equal(3)
            -- CombatDamageTaken: silent out-of-combat pet regen.
            expect(count(source, 'SetAttribute("CombatDamageTaken"')).to.equal(1)
        end)

        it("makes CombatApplication the visible mutation owner", function()
            local source = readFile("src/Server/CombatApplication.lua")
            expect(count(source, "function CombatApplication.ApplyHit")).to.equal(1)
            expect(count(source, "function CombatApplication.ApplyDamage")).to.equal(1)
            expect(count(source, "function CombatApplication.ApplyPowerHeal")).to.equal(1)
            expect(count(source, "Signals.Combat_Result:FireAllClients")).to.equal(1)
        end)

        it("retires feature-specific floating-number emissions", function()
            for _, path in ipairs({
                "src/Server/Services/EnemyService.lua",
                "src/Server/Services/PetFollowService.lua",
                "src/Server/Services/PowerService.lua",
                "src/Server/Services/SummonService.lua",
            }) do
                expect(count(readFile(path), "Combat_Heal:Fire")).to.equal(0)
            end

            local presenter = readFile("src/Client/Systems/CombatTextController.lua")
            expect(count(presenter, "Signals.Combat_Result.OnClientEvent")).to.equal(1)
            expect(count(presenter, "FloatingText.show")).to.equal(1)
            expect(
                count(
                    readFile("src/Client/Systems/PetFollowController.lua"),
                    "Signals.Combat_Result.OnClientEvent"
                )
            ).to.equal(0)
            expect(count(readFile("src/Client/Systems/EnemyMotion.lua"), "FloatingText.show")).to.equal(
                0
            )
            expect(count(readFile("src/Client/Systems/CombatAuraController.lua"), "DodgePop")).to.equal(
                0
            )
        end)

        it("re-resolves an armor badge when its replicated power identity arrives", function()
            local presenter = readFile("src/Client/Systems/CombatAuraController.lua")
            expect(count(presenter, 'GetAttributeChangedSignal("DefenseBuffPowerId")')).to.equal(1)
            expect(count(presenter, "current.powerId == powerId")).to.equal(1)
        end)

        it("gates enemy actions on disarm without adding it to movement immobilization", function()
            local enemyService = readFile("src/Server/Services/EnemyService.lua")
            expect(count(enemyService, 'model:GetAttribute("DisarmedUntil")') >= 3).to.equal(true)
            expect(count(enemyService, "not actionLocked") >= 5).to.equal(true)

            local crowdControl = readFile("src/Shared/Game/CrowdControl.lua")
            expect(count(crowdControl, "function CrowdControl.isActionLocked")).to.equal(1)
            expect(
                count(
                    crowdControl,
                    "function CrowdControl.isImmobilized(rootedUntil, heldUntil, now)"
                )
            ).to.equal(1)
        end)
    end)
end
