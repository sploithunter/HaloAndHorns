local Resolver = loadModule("src/Shared/UI/PetThumbnailResolver.lua")
local realRegistry = loadModule("configs/pet_thumbnail_assets.lua")

return function()
    local registry = {
        pets = {
            bear = {
                basic = "rbxassetid://1",
                golden = "rbxassetid://2",
                golden__huge = "rbxassetid://3",
            },
        },
    }

    describe("PetThumbnailResolver", function()
        it("resolves ordinary uploaded pet art", function()
            expect(Resolver.resolve(registry, "bear", "golden", false)).to.equal("rbxassetid://2")
        end)

        it("prefers the Huge close-up when registered", function()
            expect(Resolver.resolve(registry, "bear", "golden", true)).to.equal("rbxassetid://3")
        end)

        it("falls back to ordinary art when a Huge close-up is absent", function()
            expect(Resolver.resolve(registry, "bear", "basic", true)).to.equal("rbxassetid://1")
        end)

        it("defaults a missing variant to basic", function()
            expect(Resolver.resolve(registry, "bear", nil, false)).to.equal("rbxassetid://1")
        end)

        it("returns nil for an unknown pet or malformed registry", function()
            expect(Resolver.resolve(registry, "bunny", "basic", false)).to.equal(nil)
            expect(Resolver.resolve(nil, "bear", "basic", false)).to.equal(nil)
        end)

        it("resolves the pets visible in the reported trade regression", function()
            expect(Resolver.resolve(realRegistry, "abyssal_wyrm", "basic", false)).to.ok()
            expect(Resolver.resolve(realRegistry, "ashfeather_phoenix", "golden", false)).to.ok()
            expect(Resolver.resolve(realRegistry, "ashmane_lion", "basic", false)).to.ok()
        end)
    end)
end
