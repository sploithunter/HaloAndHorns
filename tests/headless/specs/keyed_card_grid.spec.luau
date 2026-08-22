local KeyedCardGrid = loadModule("src/Client/UI/Components/KeyedCardGrid.lua")

return function()
    describe("KeyedCardGrid", function()
        it("retains unchanged controllers and patches them in place", function()
            local created = 0
            local destroyed = 0
            local parent = { name = "grid" }
            local grid = KeyedCardGrid.new(parent, function(_, item)
                created += 1
                local controller = {
                    frame = {},
                    item = item,
                    updates = 0,
                }
                function controller:update(nextItem)
                    self.item = nextItem
                    self.updates += 1
                end
                function controller:destroy()
                    destroyed += 1
                end
                return controller
            end)

            grid:update({ { uid = "a", count = 1 }, { uid = "b", count = 1 } }, function(item)
                return item.uid
            end)
            local a = grid._entries.a
            local b = grid._entries.b

            grid:update({ { uid = "b", count = 2 }, { uid = "a", count = 1 } }, function(item)
                return item.uid
            end)

            expect(created).to.equal(2)
            expect(destroyed).to.equal(0)
            expect(grid._entries.a).to.equal(a)
            expect(grid._entries.b).to.equal(b)
            expect(grid._entries.b.item.count).to.equal(2)
            expect(grid._entries.b.frame.LayoutOrder).to.equal(1)
        end)

        it("destroys only keys that leave the snapshot", function()
            local destroyed = {}
            local grid = KeyedCardGrid.new({}, function(_, item)
                local controller = { frame = {}, uid = item.uid }
                function controller:update() end
                function controller:destroy()
                    destroyed[self.uid] = true
                end
                return controller
            end)

            local function key(item)
                return item.uid
            end
            grid:update({ { uid = "a" }, { uid = "b" } }, key)
            grid:update({ { uid = "b" }, { uid = "c" } }, key)

            expect(destroyed.a).to.equal(true)
            expect(destroyed.b).to.equal(nil)
            expect(destroyed.c).to.equal(nil)
        end)
    end)
end
