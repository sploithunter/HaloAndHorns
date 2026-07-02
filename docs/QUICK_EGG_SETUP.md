# Quick Egg Setup Guide

🚀 **Get your eggs working in 2 minutes!**

## The Problem

The proximity system needs an **EggSpawnPoint** in your workspace, but you probably haven't created one yet.

## The Solution

### Step 1: Create the Spawn Point

1. **In Roblox Studio**, go to your **Workspace**
2. **Insert a Part** (right-click Workspace → Insert Object → Part)
3. **Rename the part** to `EggSpawnPoint` (exact spelling!)
4. **Add an attribute**:
   - Right-click the part → Add Attribute
   - Name: `EggType`
   - Type: `String` 
   - Value: `basic_egg`

### Step 2: Position the Part

- **Move the part** to where you want your egg shop
- **Make it invisible** if you want (set Transparency to 1)
- **Or style it** as a platform/pedestal

### Step 3: Restart the Game

- **Stop** the current game
- **Run** it again

## What You Should See

After restarting, you should see these logs:

```
✅ EggSpawner: Found 1 spawn points
✅ EggSpawner: Initialized with 1 spawn points  
✅ EggInteractionService: Found 1 existing eggs
✅ Added proximity prompt to egg: BasicEgg
```

## Testing the Proximity

1. **Walk near the egg** (within 15 studs)
2. **Press E** when the prompt appears
3. **See the purchase UI** with pet chances
4. **Click Purchase** to test hatching

## Troubleshooting

### No EggSpawner Messages?
- Check server logs for errors
- Make sure the part is named exactly `EggSpawnPoint`

### No Proximity Prompt?
- Check client logs for EggInteractionService messages
- Make sure you have the `EggType` attribute set

### Still Not Working?
- Restart Studio completely
- Check the part is in Workspace (not in a folder)
- Make sure the attribute value is `basic_egg` (lowercase)

## Quick Check Script

Run this in the command bar to verify your setup:

```lua
for _, child in pairs(workspace:GetChildren()) do
    if child.Name == "EggSpawnPoint" then
        print("✅ Found spawn point:", child.Name)
        print("✅ EggType:", child:GetAttribute("EggType"))
        return
    end
end
print("❌ No EggSpawnPoint found")
```

## Success Screenshot

Once working, you'll see:
- Your BasicEgg model floating above the spawn point
- A proximity prompt when you get close
- Professional purchase UI when you press E

**The system is ready - you just need to create the spawn point!** 🎯