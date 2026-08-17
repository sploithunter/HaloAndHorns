return function()
    describe("shop access and quest claim UI contract", function()
        it("keeps a permanent six-cell shop route for admins and regular players", function()
            local ui = readFile("configs/ui.lua")
            local baseUI = readFile("src/Client/UI/BaseUI.lua")

            expect(ui:find('name = "Shop"', 1, true) ~= nil).to.equal(true)
            expect(ui:find('action = "shop_action"', 1, true) ~= nil).to.equal(true)
            expect(ui:find("non_admin_only = true", 1, true) ~= nil).to.equal(true)
            expect(baseUI:find("config.non_admin_only", 1, true) ~= nil).to.equal(true)
        end)

        it("gives claimable quests priority over rotating tips", function()
            local tips = readFile("src/Client/Systems/GameplayTips.lua")
            local tracker = readFile("src/Client/Systems/QuestTrackerStyle.lua")

            expect(tips:find("QuestTrackerStyle.isClaimAvailable()", 1, true) ~= nil).to.equal(true)
            expect(tracker:find("function QuestTrackerStyle.setClaimAvailable", 1, true) ~= nil).to.equal(
                true
            )
            expect(tracker:find("or QuestTrackerStyle._claimAvailable", 1, true) ~= nil).to.equal(
                true
            )
        end)

        it("keeps quest actions accessible in their established corners", function()
            local baseUI = readFile("src/Client/UI/BaseUI.lua")
            local tracker = readFile("src/Client/Systems/QuestTrackerStyle.lua")

            expect(baseUI:find("btn.AnchorPoint = Vector2.new(0, 1)", 1, true) ~= nil).to.equal(
                true
            )
            expect(baseUI:find("btn.Position = UDim2.fromScale(0, 1)", 1, true) ~= nil).to.equal(
                true
            )
            expect(tracker:find("CloseButton.attach(pane", 1, true) ~= nil).to.equal(true)
            expect(tracker:find('x.Name = "DismissX"', 1, true) ~= nil).to.equal(true)
        end)

        it("uses a shared ground-height prompt anchor for every streamed pet shop", function()
            local prompt = readFile("src/Client/Systems/ShopWorldPrompt.lua")

            expect(prompt:find('ANCHOR_NAME = "PetShopPromptAnchor"', 1, true) ~= nil).to.equal(
                true
            )
            expect(prompt:find("model:GetBoundingBox()", 1, true) ~= nil).to.equal(true)
            expect(prompt:find("prompt.Parent = anchor", 1, true) ~= nil).to.equal(true)
        end)
    end)
end
