# Development Rules – Cursor / VS Code + Rojo v7.5+

## 0. TL;DR
* **Write code in Cursor or VS Code, not in Studio.**  
* **Let Rojo own the DataModel mapping and sync.**  
* **Commit every change with Git.**  
* **Never push code that prints errors or warnings.**
* **Use defensive programming - no silent failures allowed.**
* **Use AI tools (e.g., Cursor's AI features) for generation, but always lint and test.**

---

## 1. Defensive Programming Rules 🛡️

### **CRITICAL: No Silent Failures**
Silent failures are production bugs. Every error condition must be explicitly caught and logged.

#### **Error Handling Pattern**
```lua
-- ✅ CORRECT - Defensive programming
local success, error = pcall(function()
    bridge:Fire(player, "PurchaseSuccess", data)
end)

if not success then
    self._logger:Error("Failed to send purchase success", {
        error = error, 
        player = player.Name, 
        itemId = data.itemId
    })
end
```

#### **Logging Levels**
- **ERROR**: System failures, exceptions, critical issues
- **WARN**: Unexpected conditions that don't break functionality  
- **INFO**: Business logic errors (insufficient funds, level requirements)
- **DEBUG**: Step-by-step tracing (disabled in production)

#### **Business Logic Error Pattern**
```lua
-- ✅ CORRECT - Use INFO level for user-facing errors
if not self:CanAfford(player, price.currency, price.amount) then
    self._logger:Info("Purchase failed - insufficient funds", {
        player = player.Name,
        required = price.amount,
        current = self:GetCurrency(player, price.currency)
    })
    self:_sendError(player, "Insufficient funds")
    return false
end
```

#### **External Call Protection**
Always wrap these in `pcall`:
- Network bridge calls (`bridge:Fire`)
- Signal fires (`signal:Fire`) 
- DataStore operations
- HTTP requests
- Any cross-service calls

#### **Never Use**
```lua
-- ❌ WRONG - Silent failure
if not someCondition then
    return false  -- No logging!
end

-- ❌ WRONG - Debug level for errors
self._logger:Debug("Purchase failed", {error = "insufficient funds"})
```

---

## 2. Environment Setup
1. Install **Roblox Studio** (release channel).
2. Install **mise** (modern tool version manager).  
   ```bash
   # Install mise
   curl https://mise.jdx.dev/install.sh | sh
   
   # Install all required tools
   mise install
   ```

3. Install the **Rojo Studio plugin** (Studio > Plugins > Search "Rojo" > Install latest).
4. In Cursor or VS Code:
   - Install the "Rojo – Roblox Studio Sync" extension.
   - Install "Selene" for linting, "Luau LSP" for autocomplete, and "StyLua" for formatting.
5. Clone/create repo and open in Cursor/VS Code. Root contains `rojo.project.json` and `.mise.toml`.
6. Run `mise run dev` to install dependencies and start Rojo sync.
7. Open Studio and connect via Rojo plugin.

**Best Practices**:
- **Code Editing**: Always edit Lua files in Cursor/VS Code. Studio is for asset placement only.
- **Asset Management**: Export models as .rbxmx from Studio to `/assets/`.
- **Sync Flow**: Use `rojo serve` for live updates. Avoid "Sync From" in Studio.

---

## 3. Editing Rules

| ✅ DO                                               | ❌ DON'T                                              |
| -------------------------------------------------- | ---------------------------------------------------- |
| Edit **only** files in `/src` & `/configs`.        | Edit scripts in Studio.                              |
| Keep Rojo server running (`mise run serve`).       | Sync from Studio to disk routinely.                  |
| Use one ModuleScript = one responsibility.         | Require server-only code on the client.              |
| Tag assets in Studio; use Matter components.       | Embed scripts in models.                             |
| Commit every functional change.                    | Commit `.rbxl`/`.rbxlx` binaries.                    |
| Use proper module dependencies.                    | Create circular dependencies.                         |
| Wrap external calls in `pcall` with error logging. | Allow silent failures or unhandled errors.           |
| Use INFO level for business logic errors.          | Use DEBUG level for user-facing error conditions.    |

---

## 4. File Structure Rules

### Source Code (`/src`)
```
src/
├── Shared/          # Code that runs on both client and server
├── Server/          # Server-only code (services, systems)
└── Client/          # Client-only code (UI, effects, input)
```

**Key Principles**:
- **Shared**: Put reusable code (utilities, components, configs) here
- **Server**: Business logic, data management, security validation
- **Client**: UI, visual effects, input handling, client prediction

### Configuration (`/configs`)
- Lua files for game data (items, enemies, currencies)
- Never hardcode values in Lua files
- Use ConfigLoader to access config data

### Assets (`/assets`)
- Models exported from Studio as `.rbxmx`
- UI layouts and images
- Audio files
- Reference from code, don't embed scripts

---

## 5. Code Standards

### Module Structure
```lua
--[[
    ModuleName - Brief description
    
    Usage:
    local ModuleName = require(script.ModuleName)
    ModuleName:DoSomething()
]]

local ModuleName = {}
ModuleName.__index = ModuleName

function ModuleName:Init()
    -- Initialize module
end

function ModuleName:Start()
    -- Start module (called after all Init)
end

return ModuleName
```

### Service Pattern
```lua
local MyService = {}
MyService.__index = MyService

function MyService:Init()
    self._logger = self._modules.Logger
    self._dataService = self._modules.DataService
    -- Setup but don't start
end

function MyService:Start()
    -- Begin operations
end

return MyService
```

### Dependency Injection
- Use ModuleLoader for dependency management
- Modules get dependencies via `self._modules`
- Never require modules directly (except utilities)

---

## 6. Networking Rules

### Client → Server
- Use NetworkBridge packet system
- Always validate data on server
- Rate limit all client packets
- Never trust client input

### Server → Client
- Sync only what client needs
- Use batch updates when possible
- Validate before sending

### Example
```lua
-- Server
bridge:DefinePacket("PurchaseItem", {
    rateLimit = 10,
    validator = function(data)
        return type(data.itemId) == "string"
    end
})

-- Client
bridge:Fire("PurchaseItem", {itemId = "sword"})
```

---

## 7. Testing & QA
* **Local Test**: Studio > Test > Start (Server + 2 Players).
* Monitor Output; fix errors before commit.
* **Unit Tests**: Run `tests/TestBootstrap.lua`.
* **Performance**: Keep frame time ≤8ms (120 FPS).

### Testing Checklist
- [ ] No errors in output
- [ ] No warnings in output
- [ ] Performance is acceptable
- [ ] Multiple players can join
- [ ] Data saves/loads correctly
- [ ] Network packets work properly

---

## 8. Git Workflow

### Branch Strategy
* `main`: Production ready code
* `develop`: Integration branch
* `feature/<name>`: New features
* `fix/<issue>`: Bug fixes

### Commit Rules
- Small, focused commits
- Descriptive commit messages
- Test before committing
- Never commit broken code

### What NOT to commit
- `.rbxl` or `.rbxlx` files
- `Packages/` folder (generated by Wally)
- Temporary files
- IDE-specific files

---

## 9. Performance Guidelines

### Memory
- Use object pooling for frequently created objects
- Clean up event connections
- Use Maid for proper cleanup

### Network
- Batch similar updates
- Use compression for large payloads
- Rate limit client actions

### Rendering
- Limit particle effects
- Use LOD for distant objects
- Profile with MicroProfiler

---

## 10. Security Rules

### Server Authority
- All game state lives on server
- Client predictions must be validated
- Never trust client-reported positions/stats

### Data Validation
- Validate all network inputs
- Sanitize user-generated content
- Log suspicious behavior

### Rate Limiting
- Limit all player actions
- Use exponential backoff for repeated violations
- Kick players who exceed limits

---

## 10. Common Mistakes to Avoid

❌ **DON'T**:
- Edit scripts in Studio
- Hardcode values instead of using configs
- Put server code in Shared
- Create circular dependencies
- Skip input validation
- Commit broken code

✅ **DO**:
- Use Cursor/VS Code for all coding
- Test frequently with multiple players
- Follow the module loading pattern
- Use proper error handling
- Keep performance in mind
- Document your code

---

## 11. Troubleshooting

### Rojo Not Syncing
1. Check `rojo serve` is running
2. Verify Rojo plugin is connected in Studio
3. Check file paths in `rojo.project.json`
4. Restart Rojo if needed

### Module Loading Errors
1. Check dependency order in ModuleLoader
2. Verify all required modules exist
3. Look for circular dependencies
4. Check Init/Start method errors

### Performance Issues
1. Use MicroProfiler (Ctrl+F6 in Studio)
2. Check for memory leaks
3. Profile network usage
4. Monitor frame time

---

**Remember**: The goal is to write maintainable, performant, and secure code that works reliably in production. When in doubt, ask for code review! 