--[[
    ModuleLoader - Advanced dependency injection and module loading system
    
    Features:
    - Dependency resolution with topological sorting
    - Circular dependency detection
    - Lazy loading for performance
    - Module caching and lifecycle management
    - Hot reloading support (Studio only)
    
    Usage:
    local loader = ModuleLoader.new()
    loader:RegisterModule("Logger", script.Logger)
    loader:RegisterModule("DataService", script.DataService, {"Logger"})
    loader:LoadAll()
    local logger = loader:Get("Logger")
]]

local RunService = game:GetService("RunService")

local ModuleLoader = {}
ModuleLoader.__index = ModuleLoader

function ModuleLoader.new()
    local self = setmetatable({}, ModuleLoader)

    self._modules = {} -- Module definitions
    self._loaded = {} -- Loaded module instances
    self._loading = {} -- Currently loading (for circular detection)
    self._dependencies = {} -- Dependency graph
    self._lazy = {} -- Lazy-loaded modules

    return self
end

function ModuleLoader:RegisterModule(name, moduleScript, dependencies, config)
    dependencies = dependencies or {}
    config = config or {}

    if self._modules[name] then
        error(string.format("Module '%s' is already registered", name))
    end

    self._modules[name] = {
        name = name,
        script = moduleScript,
        dependencies = dependencies,
        config = config,
        isLazy = config.lazy == true,
        singleton = config.singleton ~= false, -- Default to singleton
    }

    self._dependencies[name] = dependencies

    -- Validate dependencies exist (or will be registered)
    for _, dep in ipairs(dependencies) do
        if not self._modules[dep] then
            -- Dependency will be checked later when LoadAll is called
        end
    end
end

function ModuleLoader:RegisterLazyModule(name, moduleScript, dependencies, config)
    config = config or {}
    config.lazy = true
    self:RegisterModule(name, moduleScript, dependencies, config)
end

function ModuleLoader:_validateDependencies()
    for name, deps in pairs(self._dependencies) do
        for _, dep in ipairs(deps) do
            if not self._modules[dep] then
                error(string.format("Module '%s' has unregistered dependency '%s'", name, dep))
            end
        end
    end
end

function ModuleLoader:_detectCircularDependencies()
    local visited = {}
    local recursionStack = {}

    local function dfs(name)
        if recursionStack[name] then
            error(string.format("Circular dependency detected involving module '%s'", name))
        end

        if visited[name] then
            return
        end

        visited[name] = true
        recursionStack[name] = true

        for _, dep in ipairs(self._dependencies[name] or {}) do
            dfs(dep)
        end

        recursionStack[name] = false
    end

    for name in pairs(self._modules) do
        if not visited[name] then
            dfs(name)
        end
    end
end

function ModuleLoader:_topologicalSort()
    local visited = {}
    local stack = {}

    local function dfs(name)
        if visited[name] then
            return
        end

        visited[name] = true

        for _, dep in ipairs(self._dependencies[name] or {}) do
            dfs(dep)
        end

        table.insert(stack, name)
    end

    for name in pairs(self._modules) do
        if not visited[name] and not self._modules[name].isLazy then
            dfs(name)
        end
    end

    return stack
end

function ModuleLoader:_loadModule(name)
    if self._loaded[name] then
        return self._loaded[name]
    end

    if self._loading[name] then
        error(string.format("Circular dependency detected during runtime loading of '%s'", name))
    end

    local moduleInfo = self._modules[name]
    if not moduleInfo then
        error(string.format("Module '%s' is not registered", name))
    end

    self._loading[name] = true

    -- Load dependencies first
    local dependencies = {}
    for _, depName in ipairs(moduleInfo.dependencies) do
        dependencies[depName] = self:_loadModule(depName)
    end

    -- Require the module
    local success, moduleResult = pcall(require, moduleInfo.script)
    if not success then
        self._loading[name] = nil
        error(string.format("Failed to require module '%s': %s", name, moduleResult))
    end

    local instance

    -- Handle different module types
    if type(moduleResult) == "table" then
        if moduleResult.new then
            -- Constructor pattern
            instance = moduleResult.new()
        else
            -- Service/static module pattern
            instance = moduleResult
        end
    elseif type(moduleResult) == "function" then
        -- Function module
        instance = moduleResult()
    else
        instance = moduleResult
    end

    -- Inject dependencies
    if instance and type(instance) == "table" then
        instance._modules = dependencies
        instance._moduleLoader = self

        -- Call Init if it exists
        if instance.Init then
            local initSuccess, initError = pcall(instance.Init, instance)
            if not initSuccess then
                self._loading[name] = nil
                error(string.format("Failed to initialize module '%s': %s", name, initError))
            end
        end
    end

    self._loaded[name] = instance
    self._loading[name] = nil

    return instance
end

function ModuleLoader:LoadAll()
    -- Validate all dependencies
    self:_validateDependencies()

    -- Check for circular dependencies
    self:_detectCircularDependencies()

    -- Get load order
    local loadOrder = self:_topologicalSort()

    -- Load modules in order
    for _, name in ipairs(loadOrder) do
        self:_loadModule(name)
    end

    -- Call Start on all loaded modules
    for _, name in ipairs(loadOrder) do
        local instance = self._loaded[name]
        if instance and type(instance) == "table" and instance.Start then
            local startSuccess, startError = pcall(instance.Start, instance)
            if not startSuccess then
                error(string.format("Failed to start module '%s': %s", name, startError))
            end
        end
    end

    return loadOrder
end

function ModuleLoader:Get(name)
    -- Load if not already loaded
    if not self._loaded[name] then
        self:_loadModule(name)
    end

    return self._loaded[name]
end

function ModuleLoader:IsLoaded(name)
    return self._loaded[name] ~= nil
end

function ModuleLoader:Unload(name)
    local instance = self._loaded[name]
    if instance and type(instance) == "table" and instance.Destroy then
        pcall(instance.Destroy, instance)
    end

    self._loaded[name] = nil
end

function ModuleLoader:UnloadAll()
    for name in pairs(self._loaded) do
        self:Unload(name)
    end
end

function ModuleLoader:GetLoadOrder()
    return self:_topologicalSort()
end

function ModuleLoader:GetDependencies(name)
    return self._dependencies[name] or {}
end

function ModuleLoader:GetLoadedModules()
    local loaded = {}
    for name in pairs(self._loaded) do
        table.insert(loaded, name)
    end
    return loaded
end

-- Hot reloading support (Studio only)
if RunService:IsStudio() then
    function ModuleLoader:HotReload(name)
        if not self._modules[name] then
            error(string.format("Cannot hot reload unregistered module '%s'", name))
        end

        -- Unload the module
        self:Unload(name)

        -- Clear from cache and reload
        self._loaded[name] = nil
        return self:_loadModule(name)
    end
end

return ModuleLoader
