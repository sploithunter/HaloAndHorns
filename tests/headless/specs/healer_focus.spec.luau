--[[
    HealerFocus.tick — KILL THIS hides on click or auto-attack; never after death.
]]

local HealerFocus = loadModule("src/Shared/Game/HealerFocus.lua")

describe("HealerFocus.tick", function()
    it("keeps the opening cue while the healer is alive and unfocused", function()
        local focus = HealerFocus.tick({ cue = true }, { alive = true, attacking = false })
        expect(focus.cue).to.equal(true)
        expect(focus.committed).to.equal(false)
    end)

    it("hides the cue when pets auto-select the healer", function()
        local focus = HealerFocus.tick({ cue = true }, { alive = true, attacking = true })
        expect(focus.cue).to.equal(false)
        expect(focus.committed).to.equal(true)
        expect(focus.engaged).to.equal(true)
    end)

    it("does not ask for another click after an auto-killed healer dies", function()
        local engaged = HealerFocus.tick({ cue = true }, { alive = true, attacking = true })
        local focus, actions = HealerFocus.tick(engaged, { alive = false, attacking = false })
        expect(focus.cue).to.equal(false)
        expect(actions.lost_banner).to.equal(nil)
    end)

    it("does not ask for another click after a clicked healer dies", function()
        local clicked = HealerFocus.tick({ cue = true }, {
            alive = true,
            attacking = false,
            justClicked = true,
        })
        local engaged = HealerFocus.tick(clicked, { alive = true, attacking = true })
        local focus, actions = HealerFocus.tick(engaged, { alive = false, attacking = false })
        expect(focus.cue).to.equal(false)
        expect(actions.lost_banner).to.equal(nil)
    end)

    it("returns the cue only when live pets leave a still-alive healer", function()
        local engaged = HealerFocus.tick({ cue = true }, { alive = true, attacking = true })
        local focus, actions = HealerFocus.tick(engaged, { alive = true, attacking = false })
        expect(focus.cue).to.equal(true)
        expect(focus.lost).to.equal(true)
        expect(actions.lost_banner).to.equal(true)
    end)
end)
