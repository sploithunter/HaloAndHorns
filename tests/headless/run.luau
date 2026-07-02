--!strict
--[[
	Headless unit-test runner (lune).

	Runs pure-logic specs with NO Roblox Studio. Specs live in
	`tests/headless/specs/*.spec.luau` and use a TestEZ-compatible subset
	(`describe`/`it`/`expect`/`beforeEach`/`afterEach`) so the same logic can
	also be exercised by TestEZ inside Studio.

	Run:  mise exec -- lune run tests/headless/run.luau
	(or:  mise run test-headless)

	Specs load the module-under-test with `loadModule("src/.../Foo.lua")`, which
	loads a PURE (Roblox-API-free) module from the repo and returns its export.
	Modules that touch Roblox services cannot be loaded this way by design — the
	headless tier only covers pure logic; runtime behavior is covered in Studio.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local luau = require("@lune/luau")
local stdio = require("@lune/stdio")

type Result = { name: string, ok: boolean, err: string? }

local results: { Result } = {}
local contextStack: { string } = {}
local beforeStack: { { () -> () } } = {}

local function fullName(name: string): string
    local parts = table.clone(contextStack)
    table.insert(parts, name)
    return table.concat(parts, " › ")
end

-- ---- matchers ----------------------------------------------------------
local function makeMatchers(value: any, negated: boolean)
    local function check(pass: boolean, message: string)
        if negated then
            pass = not pass
        end
        if not pass then
            error(message, 3)
        end
    end

    local to = {}
    to.equal = function(expected: any)
        check(value == expected, `expected {tostring(value)} to equal {tostring(expected)}`)
    end
    to.ok = function()
        check(value ~= nil, `expected value to be ok (non-nil), got {tostring(value)}`)
    end
    to.near = function(expected: number, limit: number?)
        local lim = limit or 1e-7
        check(
            type(value) == "number" and math.abs(value - expected) <= lim,
            `expected {tostring(value)} to be near {tostring(expected)} (±{lim})`
        )
    end
    to.a = function(typeName: string)
        check(
            type(value) == typeName,
            `expected {tostring(value)} to be a {typeName}, got {type(value)}`
        )
    end
    -- TestEZ-style `.to.be.<matcher>` alias
    to.be = { ok = to.ok, near = to.near, a = to.a, equal = to.equal }
    return to
end

local function expect(value: any)
    return {
        to = makeMatchers(value, false),
        never = { to = makeMatchers(value, true) },
    }
end

-- ---- structure ---------------------------------------------------------
local function describe(name: string, fn: () -> ())
    table.insert(contextStack, name)
    table.insert(beforeStack, {})
    fn()
    table.remove(beforeStack)
    table.remove(contextStack)
end

local function beforeEach(fn: () -> ())
    local top = beforeStack[#beforeStack]
    if top then
        table.insert(top, fn)
    end
end

local function it(name: string, fn: () -> ())
    for _, hooks in beforeStack do
        for _, hook in hooks do
            hook()
        end
    end
    local ok, err = pcall(fn)
    table.insert(
        results,
        { name = fullName(name), ok = ok, err = if ok then nil else tostring(err) }
    )
end

-- ---- pure-module loader ------------------------------------------------
-- Build a fresh global environment that includes the Luau standard library
-- (luau.load with a custom `environment` does not inherit defaults), plus any
-- extras the caller wants exposed to the chunk.
local function makeEnv(extra: { [string]: any }?): { [string]: any }
    local env: { [string]: any } = {
        -- base functions
        assert = assert,
        error = error,
        ipairs = ipairs,
        next = next,
        pairs = pairs,
        pcall = pcall,
        xpcall = xpcall,
        print = print,
        warn = warn,
        select = select,
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        typeof = typeof,
        unpack = unpack,
        rawequal = rawequal,
        rawget = rawget,
        rawset = rawset,
        rawlen = rawlen,
        setmetatable = setmetatable,
        getmetatable = getmetatable,
        newproxy = newproxy,
        -- libraries
        table = table,
        string = string,
        math = math,
        os = os,
        coroutine = coroutine,
        utf8 = utf8,
        bit32 = bit32,
        buffer = buffer,
        _VERSION = _VERSION,
        -- Roblox DATATYPE shims (data-only stand-ins) so CONFIGS that bake UI values
        -- (Color3/UDim2/...) can be loaded + structurally validated headless. These are NOT
        -- functional re-implementations — just enough for a config table to construct.
        Color3 = {
            new = function(r: number?, g: number?, b: number?)
                return { __kind = "Color3", r = r or 0, g = g or 0, b = b or 0 }
            end,
            fromRGB = function(r: number?, g: number?, b: number?)
                return {
                    __kind = "Color3",
                    r = (r or 0) / 255,
                    g = (g or 0) / 255,
                    b = (b or 0) / 255,
                }
            end,
            fromHSV = function(h: number?, s2: number?, v: number?)
                return { __kind = "Color3", h = h or 0, s = s2 or 0, v = v or 0 }
            end,
        },
        UDim = {
            new = function(scale: number?, offset: number?)
                return { __kind = "UDim", scale = scale or 0, offset = offset or 0 }
            end,
        },
        UDim2 = {
            new = function(...)
                return { __kind = "UDim2", ... }
            end,
            fromScale = function(x: number?, y: number?)
                return { __kind = "UDim2", x = x or 0, y = y or 0 }
            end,
            fromOffset = function(x: number?, y: number?)
                return { __kind = "UDim2", x = x or 0, y = y or 0 }
            end,
        },
        Vector2 = {
            new = function(x: number?, y: number?)
                return { __kind = "Vector2", x = x or 0, y = y or 0 }
            end,
        },
        Vector3 = {
            new = function(x: number?, y: number?, z: number?)
                return { __kind = "Vector3", x = x or 0, y = y or 0, z = z or 0 }
            end,
        },
        NumberRange = {
            new = function(min: number?, max: number?)
                return { __kind = "NumberRange", Min = min or 0, Max = max or min or 0 }
            end,
        },
        -- permissive Enum: Enum.Anything.Member -> a named token table
        Enum = setmetatable({}, {
            __index = function(_, enumName)
                return setmetatable({}, {
                    __index = function(_, member)
                        return { __kind = "EnumItem", EnumType = enumName, Name = member }
                    end,
                })
            end,
        }),
    }
    if extra then
        for key, value in extra do
            env[key] = value
        end
    end
    return env
end

local moduleCache: { [string]: any } = {}

-- Forward declaration so loadModule can be referenced inside the module env.
local loadModule: (path: string) -> any

function loadModule(path: string): any
    local cached = moduleCache[path]
    if cached ~= nil then
        return cached
    end
    if not fs.isFile(path) then
        error(`loadModule: file not found: {path}`, 2)
    end
    local source = fs.readFile(path)
    -- Pure modules may require() sibling pure modules; route that through
    -- loadModule so the same env + cache applies. Roblox-API requires are not
    -- supported here (they error with a clear message).
    local dir = path:match("^(.*)/[^/]+$") or "."
    local env = makeEnv({
        loadModule = loadModule,
        -- `script.Parent:WaitForChild("x")` / `.x` resolve to sibling module PATHS, so configs
        -- that require sibling configs (power_icons -> power_icons_assets) load headless too.
        script = {
            Parent = setmetatable({
                WaitForChild = function(_self: any, name: string)
                    return `{dir}/{name}.lua`
                end,
                FindFirstChild = function(_self: any, name: string)
                    local sibling = `{dir}/{name}.lua`
                    return fs.isFile(sibling) and sibling or nil
                end,
            }, {
                __index = function(_self, name: string)
                    return `{dir}/{name}.lua`
                end,
            }),
        },
        require = function(target: any): any
            if type(target) == "string" then
                return loadModule(target)
            end
            error(
                "headless require() only supports pure modules via a string path; "
                    .. "this module appears to touch Roblox APIs and must be tested in Studio",
                2
            )
        end,
    })
    local chunk = luau.load(source, { debugName = path, environment = env })
    local export = chunk()
    moduleCache[path] = export
    return export
end

-- ---- discover + load specs --------------------------------------------
local SPEC_DIR = "tests/headless/specs"

local env = makeEnv({
    describe = describe,
    it = it,
    expect = expect,
    beforeEach = beforeEach,
    -- list files in a repo dir (for config-integrity sweeps)
    listFiles = function(dir: string): { string }
        local out = {}
        for _, name in fs.readDir(dir) do
            table.insert(out, name)
        end
        table.sort(out)
        return out
    end,
    afterEach = function(_: () -> ()) end, -- no-op subset for now
    loadModule = loadModule,
})

local specFiles: { string } = {}
if fs.isDir(SPEC_DIR) then
    for _, entry in fs.readDir(SPEC_DIR) do
        if string.match(entry, "%.spec%.luau$") then
            table.insert(specFiles, `{SPEC_DIR}/{entry}`)
        end
    end
end
table.sort(specFiles)

for _, path in specFiles do
    local source = fs.readFile(path)
    local chunk = luau.load(source, { debugName = path, environment = env })
    local exported = chunk()
    if type(exported) == "function" then
        exported()
    end
end

-- ---- report ------------------------------------------------------------
local passed, failed = 0, 0
for _, r in results do
    if r.ok then
        passed += 1
    else
        failed += 1
    end
end

print(string.rep("=", 56))
print("🧪 HEADLESS TEST RESULTS")
print(string.rep("=", 56))
for _, r in results do
    if r.ok then
        stdio.write(`  ✓ {r.name}\n`)
    else
        stdio.write(`  ✗ {r.name}\n      {r.err}\n`)
    end
end
print(string.rep("-", 56))
print(`Total: {#results} | Passed: {passed} | Failed: {failed} | Specs: {#specFiles}`)
print(string.rep("=", 56))

if failed > 0 then
    process.exit(1)
end
