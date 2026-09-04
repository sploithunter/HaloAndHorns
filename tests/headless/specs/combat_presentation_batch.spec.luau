local Queue = loadModule("src/Shared/Network/PresentationBatchQueue.lua")
local Interest = loadModule("src/Shared/Network/CombatPresentationInterest.lua")
local Transport = loadModule("src/Shared/Network/PresentationBatchTransport.lua")
local Manifest = loadModule("src/Shared/Network/NetworkManifest.lua")
local network = loadModule("configs/network.lua")
local config = network.combat_presentation

local function event()
    local handlers = {}
    return {
        Connect = function(_, callback)
            local connection = { Connected = true }
            function connection:Disconnect()
                self.Connected = false
            end
            handlers[#handlers + 1] = { callback, connection }
            return connection
        end,
        Fire = function(_, ...)
            for _, handler in ipairs(handlers) do
                if handler[2].Connected then
                    handler[1](...)
                end
            end
        end,
    }
end

local function facts(fight, direct, owners)
    return {
        fight = fight,
        direct = direct or {},
        owners = owners or {},
        participants = direct or {},
    }
end

return function()
    describe("combat presentation batching", function()
        it("retains every mixed-channel record in enqueue order", function()
            local deliveries = {}
            local queue = Queue.new(config.max_records, function(player, records)
                deliveries[#deliveries + 1] = { player, records }
            end)
            for index = 1, 1000 do
                queue:enqueue("owner", (index % 3) + 1, { amount = index })
            end
            queue:flushAll()
            queue:flushAll()
            local index = 0
            expect(#deliveries).to.equal(math.ceil(1000 / config.max_records))
            for _, delivery in ipairs(deliveries) do
                expect(delivery[1]).to.equal("owner")
                expect(#delivery[2] <= config.max_records).to.equal(true)
                for _, record in ipairs(delivery[2]) do
                    index += 1
                    expect(record[1]).to.equal((index % 3) + 1)
                    expect(record[2].amount).to.equal(index)
                end
            end
            expect(index).to.equal(1000)
        end)

        it(
            "snapshots owner/foreign flags and nested payloads before callers mutate them",
            function()
                local sent = {}
                local queue = Queue.new(128, function(player, records)
                    sent[player] = records
                end)
                local payload = { amount = 17, nested = { key = "original" } }
                queue:enqueue("owner", 2, payload)
                payload.foreign = true
                payload.nested.key = "spectator"
                queue:enqueue("spectator", 2, payload)
                queue:flushAll()
                expect(sent.owner[1][2].foreign).to.equal(nil)
                expect(sent.owner[1][2].nested.key).to.equal("original")
                expect(sent.spectator[1][2].foreign).to.equal(true)
                expect(sent.spectator[1][2].nested.key).to.equal("spectator")
            end
        )

        it("isolates departure, late joins, and queues created inside a flush callback", function()
            local sent = {}
            local queue
            queue = Queue.new(128, function(player, records)
                sent[#sent + 1] = records[1][2].amount
                if #sent == 1 then
                    queue:enqueue(player, 1, { amount = 2 })
                end
            end)
            queue:enqueue("leaving", 1, { amount = 99 })
            queue:enqueue("owner", 1, { amount = 1 })
            queue:remove("leaving")
            queue:flush("newcomer")
            queue:flushAll()
            expect(#sent).to.equal(1)
            queue:flushAll()
            expect(#sent).to.equal(2)
            expect(sent[2]).to.equal(2)
        end)

        it("uses one timed wire envelope for all three server signal facades", function()
            local heartbeat = event()
            local players = { PlayerRemoving = event() }
            local owner = { Parent = players, UserId = 1 }
            local other = { Parent = players, UserId = 2 }
            function players:GetPlayers()
                return { owner, other }
            end
            local sent = {}
            local signals = {
                [config.remote] = {
                    FireClient = function(_, player, records)
                        sent[player] = records
                    end,
                },
            }
            local audience = {
                select = function(_, _, _, candidates)
                    return candidates
                end,
                prune = function() end,
            }
            Transport.installServer(signals, config, players, heartbeat, audience)
            signals.Combat_Result:FireAllClients({ amount = 10 })
            signals.Combat_PetHit:FireClient(owner, { crit = true })
            signals.Combat_EnemyHit:FireAllClients({ ranged = true })
            heartbeat:Fire(config.flush_interval_seconds / 2)
            expect(next(sent)).to.equal(nil)
            heartbeat:Fire(config.flush_interval_seconds / 2)
            expect(#sent[owner]).to.equal(3)
            expect(#sent[other]).to.equal(2)
            expect(sent[owner][2][1]).to.equal(config.channels.Combat_PetHit)
            signals.Combat_Result:FireClient(other, {})
            players.PlayerRemoving:Fire(other)
            sent = {}
            heartbeat:Fire(1)
            expect(next(sent)).to.equal(nil)
        end)

        it(
            "dispatches client batches through existing listeners with bounded startup buffering",
            function()
                local wire = event()
                local signals = { [config.remote] = { OnClientEvent = wire } }
                Transport.installClient(signals, config, event)
                local result = config.channels.Combat_Result
                for index = 1, config.startup_records_per_channel + 1 do
                    wire:Fire({ { result, { amount = index } } })
                end
                local received = {}
                local connection = signals.Combat_Result.OnClientEvent:Connect(function(payload)
                    received[#received + 1] = payload.amount
                end)
                expect(#received).to.equal(config.startup_records_per_channel)
                expect(received[1]).to.equal(2)
                wire:Fire({ { result, { amount = 900 } }, { 9999, {} }, { result, false } })
                expect(received[#received]).to.equal(900)
                connection:Disconnect()
                wire:Fire({ { result, { amount = 901 } } })
                expect(received[#received]).to.equal(900)
            end
        )

        it("keeps nearby spectator animations but hides unrelated fight results", function()
            local policy = Interest.new(config)
            local record = facts("bay-A", { [1] = true }, { [2] = true })
            policy:observe(record, 0)
            local spectator = { userId = 3, distance = 20 }
            expect(policy:allows("Combat_Result", record, spectator, 0)).to.equal(false)
            expect(policy:allows("Combat_EnemyHit", record, spectator, 0)).to.equal(true)
            spectator.distance = config.animation_radius + 1
            expect(policy:allows("Combat_PetHit", record, spectator, 0)).to.equal(false)
            expect(policy:allows("Combat_Result", record, { userId = 2 }, 0)).to.equal(true)
            expect(policy:allows("Combat_PetHit", record, { userId = 1 }, 0)).to.equal(true)
        end)

        it(
            "admits helpers immediately, remembers short attack gaps, and expires participation",
            function()
                local policy = Interest.new(config)
                policy:observe(facts("bay-A", { [3] = true }), 5)
                local record = facts("bay-A", {}, { [1] = true })
                local viewer = { userId = 3 }
                expect(policy:allows("Combat_Result", record, viewer, 5)).to.equal(true)
                expect(
                    policy:allows(
                        "Combat_Result",
                        record,
                        viewer,
                        5 + config.participation_grace_seconds - 1
                    )
                ).to.equal(true)
                expect(policy:allows("Combat_Result", facts("bay-B"), viewer, 5)).to.equal(false)
                policy:prune(5 + config.participation_grace_seconds)
                expect(
                    policy:allows(
                        "Combat_Result",
                        record,
                        viewer,
                        5 + config.participation_grace_seconds
                    )
                ).to.equal(false)
                expect(next(policy._fights)).to.equal(nil)
                policy:observe(facts("bay-A", { [3] = true }), 30)
                policy:prune(30, 3)
                expect(next(policy._fights)).to.equal(nil)
            end
        )

        it("rejects invalid batch tuning and recursive/duplicate channels", function()
            for _, mutation in ipairs({
                function(c)
                    c.max_records = 0
                end,
                function(c)
                    c.flush_interval_seconds = math.huge
                end,
                function(c)
                    c.animation_radius = -1
                end,
                function(c)
                    c.startup_records_per_channel = 1.5
                end,
                function(c)
                    c.remote = "missing"
                end,
                function(c)
                    c.channels = { Combat_Result = 1, Combat_PetHit = 1 }
                end,
                function(c)
                    c.channels = { [c.remote] = 1 }
                end,
            }) do
                local copy = table.clone(network)
                copy.combat_presentation = table.clone(config)
                mutation(copy.combat_presentation)
                expect(Manifest.validate(copy)).to.equal(false)
            end
            expect(Manifest.validate(network)).to.equal(true)
        end)
    end)
end
