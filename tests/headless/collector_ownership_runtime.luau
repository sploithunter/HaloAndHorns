-- Actual MonetizationService ownership reconciliation against isolated doubles; no API/profile writes.
local fs, luau = require("@lune/fs"), require("@lune/luau")
local function pure(path)
    return luau.load(fs.readFile(path))()
end
local function node(path)
    return setmetatable({}, {
        __index = function(_, key)
            return node(path .. "." .. key)
        end,
        __tostring = function()
            return path
        end,
    })
end
local answer, fail, calls = false, false, 0
local marketplace = {
    UserOwnsGamePassAsync = function()
        calls += 1
        if fail then
            error("Synthetic ownership outage")
        end
        return answer
    end,
}
local service = luau.load(fs.readFile("src/Server/Services/MonetizationService.lua"), {
    environment = {
        game = {
            GetService = function(_, name)
                if name == "MarketplaceService" then
                    return marketplace
                end
                if name == "RunService" then
                    return {
                        IsStudio = function()
                            return false
                        end,
                    }
                end
                return node(name)
            end,
        },
        require = function(path)
            local name = tostring(path):match("([^.]+)$")
            if name == "FoundersChoice" or name == "CollectorCommentPolicy" then
                return pure("src/Shared/Game/" .. name .. ".lua")
            end
            if name == "collector_voice" then
                return pure("configs/collector_voice.lua")
            end
            return {}
        end,
    },
})()
local pass = { id = "auto_collect", benefits = { features = { auto_collect_enabled = true } } }
local player = { UserId = 42, Name = "Synthetic", attrs = {} }
function player:SetAttribute(k, v)
    self.attrs[k] = v
end
function player:GetAttribute(k)
    return self.attrs[k]
end
local gate = { active = false, eligible = false, enabled = true }
local founder = ""
local runtime = setmetatable({
    _collectorCommentOwners = {},
    _passSources = {},
    _productIdMapper = {
        GetAllPasses = function()
            return { pass }
        end,
        GetProductId = function()
            return 123
        end,
        GetPassConfig = function()
            return pass
        end,
    },
    GetCreatorPassGateState = function()
        return gate
    end,
    _foundersChoiceService = {
        GetState = function()
            return { selectedPassId = founder }
        end,
        IsEligiblePass = function(_, id)
            return id == "auto_collect"
        end,
        TryUnlockLegacy = function()
            return false
        end,
        ReleaseForMarketplaceOwnership = function()
            founder = ""
        end,
    },
    _clearPassBenefits = function()
        player:SetAttribute("AutoCollectorEnabled", false)
    end,
    _dataService = { SetOwnedPasses = function() end, SetFeature = function() end },
    _logger = { Info = function() end, Error = function() end },
    _sendOwnedPasses = function() end,
}, service)
local function check(expected)
    runtime:CheckPlayerPasses(player)
    assert(player:GetAttribute("CollectorCommentEligible") == expected, "Wrong comment eligibility")
end
check(true)
assert(calls == 1, "Added an extra ownership lookup")
fail = true
check(false)
fail, founder = false, "auto_collect"
check(false)
assert(player:GetAttribute("AutoCollectorEnabled"), "Founder entitlement lost")
founder = ""
check(false) -- previously entitled session remains silent
runtime._collectorCommentOwners = {}
answer = true
check(false)
answer = false
check(false) -- stale/overlapping negative result cannot undo observed ownership
runtime._collectorCommentOwners = {}
gate.eligible, gate.enabled = true, false
local before = calls
check(false)
assert(calls == before, "Creator bypass made an unnecessary lookup")
gate.eligible, gate.enabled = false, true
runtime._testMode = true
check(false)
assert(calls == before, "Test mode made an ownership lookup")
print(
    "PASS: actual ownership reconciliation rejects unknown/outage/owners/Founder/test/creator bypass and latches entitlement"
)
