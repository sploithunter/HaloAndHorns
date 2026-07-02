# CurrentTarget System Implementation

🎯 **Now exactly matches the working game's proven pattern!**

## **System Architecture**

### **🔧 EggCurrentTargetService** (like VisibleHandler)
- **Continuous scanning**: Updates every 0.05 seconds (exactly like working game)
- **World-to-screen UI**: Positions egg UI at the egg's world position
- **CurrentTarget tracking**: Sets current egg name for other systems to use
- **Server persistence**: Calls `setLastEgg` every 30 frames for crash recovery
- **Distance validation**: Only shows UI within 20 studs

### **🎮 EggInteractionService** (simplified)
- **E key handling**: Only listens for E key presses
- **Uses CurrentTarget**: Gets current egg from targeting service
- **Distance validation**: Re-validates distance before purchase
- **Direct server calls**: Uses RemoteFunction like working game

### **🖥️ EggService** (server)
- **setLastEgg tracking**: Stores player's current egg for persistence
- **RemoteFunction structure**: `EggOpened` with nested `setLastEgg`
- **Crash recovery ready**: Can restore players to their last egg

## **How It Works** (exactly like working game)

### **1. Proximity Detection**
```lua
-- Scans workspace every 0.05 seconds
for _, obj in pairs(workspace:GetChildren()) do
    if obj:FindFirstChild("UIanchor") then
        local mag = (eggAnchor.Position - playerPos).Magnitude
        if mag <= 20 then
            -- Add to available eggs
        end
    end
end
```

### **2. UI Positioning**
```lua
-- Position UI at egg's world position
local screenPos = camera:WorldToScreenPoint(eggAnchor.Position)
frame.Position = UDim2.new(0, screenPos.X - 100, 0, screenPos.Y - 50)
```

### **3. Server Persistence**
```lua
-- Every 30 frames, call server
if counter > 30 then
    counter = 0
    setLastEggRemote:InvokeServer(eggType)
end
```

### **4. E Key Purchase**
```lua
-- When E pressed, use current target
local currentTarget = currentTargetService:GetCurrentTarget()
local result = eggRemote:InvokeServer(currentTarget, "Single")
```

## **Expected Behavior**

### **✅ When Near Egg:**
1. **UI appears** at egg's world position
2. **Shows "Press E to open Basic Egg"**
3. **Server tracks** current egg via `setLastEgg`
4. **Multiple eggs**: Shows closest one

### **✅ When Press E:**
1. **Distance check** on client and server
2. **Currency validation** 
3. **Hatching simulation**
4. **Success notification** appears

### **✅ Server Logs:**
```
[INFO] EggService initialized with RemoteFunction and setLastEgg tracking
[DEBUG] Set last egg for player: coloradoplays, eggType: basic_egg
```

### **✅ Client Logs:**
```
[INFO] EggCurrentTargetService initialized - targeting system active
[INFO] EggInteractionService initialized
🎯 Now targeting egg: basic_egg
✅ Distance check passed: 8.5
✅ Purchase successful!
🎉 You hatched a basic bear with 10 power!
```

## **Key Benefits**

✅ **World-positioned UI**: Egg UI appears right at the egg (not screen overlay)  
✅ **CurrentTarget tracking**: Always know which egg player is near  
✅ **Server persistence**: Crash recovery with last egg tracking  
✅ **Performance optimized**: 0.05s updates like working game  
✅ **Multiple egg support**: Automatically finds closest egg  
✅ **AFK hatching ready**: Foundation for future AFK mechanics  

## **CurrentTarget Integration**

The `CurrentTarget` value is now available for:
- **AFK hatching systems** 
- **Server crash recovery**
- **Auto-resume functionality**
- **Progress tracking**
- **UI state management**

Just like the working game, players can now have their "current egg" tracked persistently, enabling advanced features like AFK hatching and seamless reconnection.

## **Testing**

**Restart your game and:**
1. **Walk near the egg** → UI should appear at egg's position
2. **Press E** → Should purchase and hatch successfully  
3. **Check console** → Should see targeting and persistence logs
4. **Move away** → UI should disappear

The system now follows the working game's architecture exactly! 🚀