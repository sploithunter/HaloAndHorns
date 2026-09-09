-- Regression checks against a supplied native fixture; writes only an explicit scratch directory.
local fs = require("@lune/fs")
local process = require("@lune/process")
local r = require("@lune/roblox")
local fixture, directory = process.args[1], process.args[2]
assert(
    fixture and directory,
    "Usage: test_checkpoint_validation.luau <fixture.rbxl> <scratch-directory>"
)
fs.writeDir(directory)
local cases = {
    {
        "installer",
        "Installer source mismatch",
        function(g)
            g.ServerStorage.CrossroadsCorePolish.Source = "return function() end"
        end,
    },
    {
        "payload",
        "Supplemental source mismatch",
        function(g)
            g.ServerStorage.CrossroadsAuthoringInputs.CrossroadsPondLifeInstaller.client_source.Value =
                "stale"
        end,
    },
    {
        "client",
        "Installed client source mismatch",
        function(g)
            g.StarterPlayer.StarterPlayerScripts.CrossroadsPondLife.Source = "-- stale"
        end,
    },
    {
        "cache",
        "Missing PondFish",
        function(g)
            g.ServerStorage.CrossroadsPondFishAssets.PondFish:Destroy()
        end,
    },
    {
        "paving",
        "Native paver count mismatch",
        function(g)
            for _, item in ipairs(g.Workspace.RealmCrossroadsR4.CrossroadsCraftR11:GetDescendants()) do
                if item.Name == "StonePaver" then
                    item:Destroy()
                    break
                end
            end
        end,
    },
}
for _, case in ipairs(cases) do
    local game = r.deserializePlace(fs.readFile(fixture))
    case[3](game)
    local path = directory .. "/" .. case[1] .. ".rbxl"
    fs.writeFile(path, r.serializePlace(game))
    local result = process.exec("lune", {
        "run",
        "tools/realm_crossroads/validate_checkpoint.luau",
        "--checkpoint",
        path,
        "--expected-pavers",
        "300",
    })
    assert(
        not result.ok and (result.stderr .. result.stdout):find(case[2], 1, true),
        "Expected rejection: " .. case[1]
    )
    fs.removeFile(path)
    print("PASS rejection: " .. case[1])
end
