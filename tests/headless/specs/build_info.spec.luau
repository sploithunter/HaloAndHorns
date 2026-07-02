--[[
    build_info — [unit] the generated version stamp shape (scripts/stamp_build.sh).
    The VALUES change per build; this pins the SHAPE the BootLoader reads.
    Run: mise run test-headless
]]

local info = loadModule("configs/build_info.lua")

return function()
    describe("build_info", function()
        it("is a table with the fields the load screen reads", function()
            expect(type(info)).to.equal("table")
            expect(type(info.version)).to.equal("string")
            expect(type(info.commit)).to.equal("string")
            expect(type(info.branch)).to.equal("string")
            expect(type(info.commit_date)).to.equal("string")
            expect(type(info.built_at)).to.equal("string")
            expect(type(info.dirty)).to.equal("boolean")
        end)
    end)
end
