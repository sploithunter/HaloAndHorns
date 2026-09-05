local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Receipt = require(script.Parent.Parent.UI.Components.AwardReceiptModal)
local Service = {}

function Service.start()
    local player = Players.LocalPlayer
    local shown
    local function check()
        local encoded = player:GetAttribute("OfflineMergeReceipt")
        if player:GetAttribute("ClientUIReady") ~= true or not encoded or shown == encoded then
            return
        end
        local ok, value = pcall(HttpService.JSONDecode, HttpService, encoded)
        if ok and type(value) == "table" then
            shown = encoded
            Receipt.show(value)
        end
    end
    player:GetAttributeChangedSignal("OfflineMergeReceipt"):Connect(check)
    player:GetAttributeChangedSignal("ClientUIReady"):Connect(check)
    check()
end

return Service
