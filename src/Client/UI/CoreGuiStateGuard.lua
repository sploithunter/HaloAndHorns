-- Temporarily changes one CoreGui enabled state and restores exactly what was captured.
-- The getter/setter are injected so this lifecycle stays testable without Roblox services.
local CoreGuiStateGuard = {}
CoreGuiStateGuard.__index = CoreGuiStateGuard

function CoreGuiStateGuard.new(getEnabled, setEnabled)
    assert(type(getEnabled) == "function", "CoreGuiStateGuard requires a getter")
    assert(type(setEnabled) == "function", "CoreGuiStateGuard requires a setter")

    return setmetatable({
        _getEnabled = getEnabled,
        _setEnabled = setEnabled,
        _active = false,
        _restoreValue = nil,
    }, CoreGuiStateGuard)
end

function CoreGuiStateGuard:Suppress()
    if self._active then
        return true
    end

    local readOk, enabledOrError = pcall(self._getEnabled)
    if not readOk then
        return false, enabledOrError
    end

    local previousEnabled = enabledOrError == true
    if previousEnabled then
        local writeOk, writeError = pcall(self._setEnabled, false)
        if not writeOk then
            return false, writeError
        end
    end

    self._restoreValue = previousEnabled
    self._active = true
    return true
end

function CoreGuiStateGuard:Restore()
    if not self._active then
        return true
    end

    local writeOk, writeError = pcall(self._setEnabled, self._restoreValue)
    if not writeOk then
        -- Keep the captured state so a later Hide/Destroy call can retry restoration.
        return false, writeError
    end

    self._active = false
    self._restoreValue = nil
    return true
end

return CoreGuiStateGuard
