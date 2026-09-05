-- Edit-only lifecycle regression using the real controller's watch/unwatch/refresh functions.
-- Fake player signals and rows; no live Player, profile, or UI is modified.
local module = game.StarterPlayer.StarterPlayerScripts.Client.Systems.PeopleListController
local source = module.Source
local function chunk(firstText, lastText)
    local first = assert(source:find(firstText, 1, true))
    local last = assert(source:find(lastText, first + #firstText, true))
    return source:sub(first, last - 1)
end
local shared = game.ReplicatedStorage.Shared.Game.PeopleList
local PeopleList = assert(loadstring("local script = ...\n" .. shared.Source))(shared)
local config = require(game.ReplicatedStorage.Configs.people_list)
local function signal()
    local listeners = {}
    return {
        Connect = function(_, callback)
            local connection = { Connected = true }
            function connection:Disconnect()
                self.Connected = false
            end
            listeners[connection] = callback
            return connection
        end,
        Fire = function()
            for connection, callback in listeners do
                if connection.Connected then
                    callback()
                end
            end
        end,
    }
end
local function player(id, name)
    local who =
        { UserId = id, DisplayName = name, attrs = { ClaimedLevel = 50, MergeHighestWave = 307 } }
    local changed = signal()
    function who:GetAttributeChangedSignal()
        return changed
    end
    function who:GetPropertyChangedSignal()
        return changed
    end
    who.changed = changed
    return who
end
local me, stable = player(1, "You"), player(2, "Stable")
local engine = { me, stable }
local Players = {
    LocalPlayer = me,
    GetPlayers = function()
        return engine
    end,
}
local prelude = [[
local Players, PeopleList, config = ...
local watches, rowGuis, rowsFrame = {}, {}, {}
local cardPlayer, card
local function dockState() return { viewportWidth = 1280, viewportHeight = 720 } end
local function hidePopover() cardPlayer = nil end
local function fillCard() end
local function applyRow(row, player)
    row.rank, row.wave = player.attrs.ClaimedLevel, player.attrs.MergeHighestWave
end
local function ensureRow(player)
    local row = rowGuis[player]
    if not row then
        row = { Parent = true }
        function row:Destroy() self.Parent = nil end
        rowGuis[player] = row
    end
    applyRow(row, player)
    return row
end
]]
local runtime = assert(
    loadstring(
        prelude
            .. chunk("local function orderedPlayers()", "local function applyExpanded()")
            .. chunk("local function watchPlayer(player)", "local function build()")
            .. [[
return { watch = watchPlayer, remove = function(player)
    unwatchPlayer(player)
    refreshRows()
end, refresh = refreshRows, rows = rowGuis }
]]
    )
)(Players, PeopleList, config)
runtime.watch(me)
runtime.watch(stable)
runtime.refresh()
for _ = 1, 100 do
    local old = player(3, "Returning")
    engine = { me, stable, old }
    runtime.watch(old)
    runtime.refresh()
    local row = assert(runtime.rows[old])
    -- PlayerRemoving happens before GetPlayers stops listing old.
    runtime.remove(old)
    assert(runtime.rows[old] == nil and row.Parent == nil, "Departed player row resurrected")
    old.attrs = {}
    old.changed.Fire()
    runtime.refresh() -- viewport/layout refresh while the engine snapshot is still stale
    assert(runtime.rows[old] == nil, "Stale player returned without attribute watchers")
    local replacement = player(3, "Returning")
    engine = { me, stable, replacement }
    runtime.watch(replacement)
    runtime.refresh()
    replacement.attrs.MergeHighestWave = 350
    replacement.changed.Fire()
    assert(runtime.rows[replacement].wave == 350, "Rejoined player lost live updates")
    assert(runtime.rows[stable].rank == 50 and runtime.rows[stable].wave == 307)
    runtime.remove(replacement)
end
return { ok = true, leave_rejoin_cycles = 100, stable_peer_wave = runtime.rows[stable].wave }
