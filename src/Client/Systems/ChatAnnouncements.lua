-- Server-authored, rarity-colored system messages in Roblox's standard chat window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local ChatAnnouncements = {}

local function escapeRichText(text)
    return tostring(text)
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
        :gsub('"', "&quot;")
        :gsub("'", "&apos;")
end

local function colorFromHex(colorHex)
    local red, green, blue = colorHex:match("^#(%x%x)(%x%x)(%x%x)$")
    if not red then
        return Color3.new(1, 1, 1)
    end
    return Color3.fromRGB(
        tonumber(red, 16) or 255,
        tonumber(green, 16) or 255,
        tonumber(blue, 16) or 255
    )
end

local function displayLegacy(text, colorHex)
    -- This place currently runs LegacyChatService. SetCore can race CoreScripts at join,
    -- so retry briefly instead of losing the first announcement of the session.
    local function attempt(remaining)
        local ok = pcall(StarterGui.SetCore, StarterGui, "ChatMakeSystemMessage", {
            Text = text,
            Color = colorFromHex(colorHex),
            Font = Enum.Font.GothamBold,
            TextSize = 18,
        })
        if ok then
            return
        end
        if remaining > 1 then
            task.defer(attempt, remaining - 1)
        end
    end
    attempt(5)
end

local function display(payload)
    if type(payload) ~= "table" or type(payload.text) ~= "string" then
        return
    end
    local colorHex = type(payload.colorHex) == "string"
            and payload.colorHex:match("^#%x%x%x%x%x%x$")
            and payload.colorHex
        or "#FFFFFF"
    if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
        displayLegacy(payload.text, colorHex)
        return
    end
    local channels = TextChatService:WaitForChild("TextChannels", 5)
    if not channels then
        return
    end
    local channel = channels:FindFirstChild("RBXGeneral") or channels:FindFirstChild("RBXSystem")
    if not channel or not channel:IsA("TextChannel") then
        return
    end
    local richText = ('<font color="%s"><b>%s</b></font>'):format(
        colorHex,
        escapeRichText(payload.text)
    )
    channel:DisplaySystemMessage(
        richText,
        ("HaloAndHorns:%s:%s"):format(tostring(payload.kind), tostring(payload.scope))
    )
end

function ChatAnnouncements.start()
    Signals.ChatAnnouncement.OnClientEvent:Connect(function(payload)
        task.spawn(display, payload)
    end)
end

return ChatAnnouncements
