local Director = loadModule("src/Shared/Game/TutorialVoiceDirector.lua")
local lines = loadModule("configs/tutorial_voice_lines.lua")
local assets = loadModule("configs/tutorial_voice_assets.lua").clips
local config = loadModule("configs/tutorial_voice.lua")
local home = loadModule("configs/tutorial.lua")
local combat = loadModule("configs/combat_tutorial.lua")
return function()
    describe("Tutorial voice coverage and lifecycle", function()
        it("binds all 89 approved lines to uploaded audio and a face", function()
            local count = 0
            for cue, line in pairs(Director.catalog(lines)) do
                count += 1
                expect(config.faces[line.speaker] ~= nil).to.equal(true)
                expect(assets[cue].asset_id > 0).to.equal(true)
                expect(assets[cue].seconds > 0).to.equal(true)
            end
            expect(count).to.equal(89)
        end)
        it("covers every current Homeworld and combat lesson", function()
            for _, step in ipairs(home.steps) do
                expect(assets[Director.key({ id = step.id })] ~= nil).to.equal(true)
            end
            for _, step in ipairs(combat.steps) do
                expect(assets[Director.key({ id = step.id, courseId = "basic" })] ~= nil).to.equal(
                    true
                )
            end
        end)
        it(
            "distinguishes home/combat first fight without restarting on count or device updates",
            function()
                expect(Director.key({ id = "first_fight", count = 0 })).to.equal(
                    "tutorial.first_fight"
                )
                expect(Director.key({ id = "first_fight", count = 1, body_gamepad = "new" })).to.equal(
                    "tutorial.first_fight"
                )
                expect(Director.key({ id = "first_fight", courseId = "basic" })).to.equal(
                    "combat_tutorial.first_fight"
                )
            end
        )
        it("never celebrates an initial done state or a different track", function()
            expect(Director.completion(nil, { done = true })).to.equal(nil)
            expect(Director.completion({ done = true }, { done = true })).to.equal(nil)
            expect(Director.completion({ id = "ready", courseId = "basic" }, { done = true })).to.equal(
                nil
            )
            expect(
                Director.completion(
                    { id = "ready", courseId = "basic" },
                    { done = true, courseId = "advanced_1" }
                )
            ).to.equal(nil)
        end)
        it("uses independent course exits and the replay performance", function()
            for _, course in { "basic", "advanced_1", "advanced_2" } do
                local previous = { id = "finish", courseId = course }
                local cue = Director.completion(previous, { done = true, courseId = course })
                expect(cue).to.equal("combat_courses." .. course .. ".completion")
                expect(assets[cue] ~= nil).to.equal(true)
                expect(
                    Director.completion(previous, { done = true, courseId = course, replay = true })
                ).to.equal("combat_courses.replay.completion")
            end
            expect(Director.completion({ id = "rally_call" }, { done = true })).to.equal(
                "tutorial.completion"
            )
        end)
        it("selects resume introductions only on entry", function()
            expect(Director.introduction(nil, { id = "ready", index = 1, courseId = "basic" })).to.equal(
                nil
            )
            expect(Director.introduction(nil, { id = "cast_power", index = 6 })).to.equal(
                "tutorial.resume"
            )
            expect(Director.introduction(nil, { id = "bind_heal", index = 8, courseId = "basic" })).to.equal(
                "combat_tutorial.resume"
            )
            expect(
                Director.introduction(
                    { id = "ready", courseId = "basic" },
                    { id = "first_fight", index = 2, courseId = "basic" }
                )
            ).to.equal(nil)
            expect(
                Director.introduction(
                    nil,
                    { id = "ready", index = 1, courseId = "basic", replay = true }
                )
            ).to.equal("combat_courses.replay.start")
        end)
        it("uses authoritative unlock failures for blocked-door help", function()
            expect(Director.doorCue(config, "pets_equipped", "bind_heal")).to.equal(
                "combat_tutorial.door.pets_equipped"
            )
            expect(Director.doorCue(config, "hotbar_not_editing", "ready_heal")).to.equal(
                "combat_tutorial.door.hotbar_not_editing"
            )
            expect(Director.doorCue(config, nil, "enhance_heal")).to.equal(
                "combat_tutorial.door.heal_unenhanced"
            )
            expect(Director.doorCue(config, nil, "stack_brew", 3)).to.equal(
                "combat_tutorial.stack_brew.remaining_3"
            )
            expect(Director.doorCue(config, nil, "stack_brew", 0)).to.equal(nil)
        end)
    end)
end
