--[[
    CommandBus

    A pure (Roblox-API-free) command dispatcher that forms the single seam
    between *intent* and *execution* in the template.

    Why this exists
    ---------------
    Every gameplay action ("purchase upgrade", "hatch egg", "travel to zone")
    can be expressed as a named command with a payload. The GUI, the network
    layer, and automated tests are all just different *callers* of the same
    command set:

        GUI button        ─┐
        Network remote    ─┼─►  CommandBus:execute(context, name, args)  ─►  handler
        Automation driver ─┘

    Because the bus is pure, the exact code path a button triggers can be
    exercised headlessly (lune) or via the Studio MCP without touching any UI.
    This is the "sit underneath the GUI" boundary: tests drive intents, not
    pixels.

    Two levels of success
    ---------------------
    The bus separates *dispatch* success from *domain* success:

      • envelope.ok == false  → the dispatch itself failed (unknown command,
        validation rejected the args, the command was test-only and the caller
        was not a test, or the handler threw). See envelope.code.
      • envelope.ok == true   → the handler ran. Its return value is in
        envelope.result, which may itself be a domain envelope such as
        { ok = false, reason = "insufficient_currency" }. Domain outcomes are
        NOT dispatch failures.

    This lets existing services (which already return { ok = ..., reason = ... }
    tables) be wrapped as handlers with zero changes.

    Purity contract
    ---------------
    This module must never require a Roblox service or touch a Roblox global.
    Handlers may close over services, but the bus itself stays pure so it can be
    unit-tested with `mise run test-headless`.
]]

local CommandBus = {}
CommandBus.__index = CommandBus

-- Where a command came from. Informational: passed through to handlers so they
-- can branch on origin (e.g. stricter checks for network-origin commands).
CommandBus.Origin = {
    GUI = "gui",
    Network = "network",
    Automation = "automation",
    Internal = "internal",
}

-- Dispatch-level failure codes (envelope.code when envelope.ok == false).
CommandBus.Code = {
    UnknownCommand = "unknown_command",
    ValidationFailed = "validation_failed",
    Forbidden = "forbidden", -- test-only command invoked by a non-test caller
    HandlerError = "handler_error",
}

--[[
    Create a new bus.

    opts (optional):
      onError(err, name, context) → called when a handler throws, before the
        error envelope is returned. Use for logging. Must not throw.
]]
function CommandBus.new(opts)
    local self = setmetatable({}, CommandBus)
    self._commands = {}
    self._onError = opts and opts.onError
    return self
end

--[[
    Register a command.

    name  : string, unique. Convention: "domain.verb" (e.g. "economy.purchaseUpgrade").
    spec  :
      handler(context, args) → any        REQUIRED. The work to perform.
      validate(args) → ok, errMessage      optional. Reject bad payloads early.
      testOnly : boolean                   optional. If true, only callers with
                                           context.isTest == true may invoke it.
      description : string                 optional. For introspection / docs.

    Returns the bus for chaining.
]]
function CommandBus:register(name, spec)
    assert(type(name) == "string" and name ~= "", "command name must be a non-empty string")
    assert(type(spec) == "table", "command spec must be a table")
    assert(type(spec.handler) == "function", `command "{name}" must define a handler function`)
    assert(
        spec.validate == nil or type(spec.validate) == "function",
        `command "{name}" validate must be a function if provided`
    )
    assert(self._commands[name] == nil, `command "{name}" is already registered`)

    self._commands[name] = {
        handler = spec.handler,
        validate = spec.validate,
        testOnly = spec.testOnly == true,
        description = spec.description,
    }
    return self
end

--[[
    Register many commands at once from a { [name] = spec } map.
    Returns the bus for chaining.
]]
function CommandBus:registerMany(map)
    assert(type(map) == "table", "registerMany expects a table of { name = spec }")
    for name, spec in pairs(map) do
        self:register(name, spec)
    end
    return self
end

-- True if a command name is registered.
function CommandBus:has(name)
    return self._commands[name] ~= nil
end

--[[
    List registered commands for introspection (e.g. an automation driver
    discovering what it can call). Returns a sorted array of:
      { name, description, testOnly }
]]
function CommandBus:list()
    local out = {}
    for name, spec in pairs(self._commands) do
        table.insert(out, {
            name = name,
            description = spec.description,
            testOnly = spec.testOnly,
        })
    end
    table.sort(out, function(a, b)
        return a.name < b.name
    end)
    return out
end

local function ok(result)
    return { ok = true, result = result }
end

local function fail(code, message)
    return { ok = false, code = code, error = message }
end

--[[
    Execute a command.

    context : table describing the caller. Conventional fields:
      player  : the acting player (or a test double) — passed to the handler
      origin  : one of CommandBus.Origin.* (defaults to Internal)
      isTest  : boolean — gates testOnly commands
    The context is passed through to the handler untouched, so callers may add
    their own fields (services, request id, etc.).

    args : the command payload (any). Defaults to an empty table.

    Returns an envelope (see module header):
      success : { ok = true,  result = <handler return> }
      failure : { ok = false, code = <CommandBus.Code.*>, error = <message> }
]]
function CommandBus:execute(context, name, args)
    context = context or {}
    if context.origin == nil then
        context.origin = CommandBus.Origin.Internal
    end
    if args == nil then
        args = {}
    end

    local spec = self._commands[name]
    if not spec then
        return fail(CommandBus.Code.UnknownCommand, `unknown command: {tostring(name)}`)
    end

    if spec.testOnly and not context.isTest then
        return fail(CommandBus.Code.Forbidden, `command "{name}" is test-only`)
    end

    if spec.validate then
        local valid, validationError = spec.validate(args)
        if not valid then
            return fail(
                CommandBus.Code.ValidationFailed,
                validationError or `invalid arguments for "{name}"`
            )
        end
    end

    local succeeded, resultOrErr = pcall(spec.handler, context, args)
    if not succeeded then
        if self._onError then
            -- Logging hook must not break dispatch; swallow its errors.
            pcall(self._onError, resultOrErr, name, context)
        end
        return fail(CommandBus.Code.HandlerError, tostring(resultOrErr))
    end

    return ok(resultOrErr)
end

return CommandBus
