# Asset Preloading System

## Overview

The Asset Preloading System solves the problem of runtime asset loading failures by preloading all game models at server startup directly into `ReplicatedStorage.Assets`, providing instant client access without any network calls.

## Problem Solved

**Before**: Pet preview UI was failing because:
- External asset IDs (like `rbxassetid://133150464787030`) required runtime loading via `InsertService:LoadAsset()`
- Runtime loading can fail due to network issues, permissions, or asset availability
- No preloading meant every model request was a potential failure point

**After**: 
- All models are loaded at server startup directly into `ReplicatedStorage.Assets.Models.Pets`
- Client accesses models instantly via simple path: `ReplicatedStorage.Assets.Models.Pets.Bear.basic`
- No RemoteFunction complexity - direct folder access
- Organized folder structure mirrors configuration hierarchy
- Graceful fallback to runtime loading if models aren't preloaded

## Architecture

### Server-Side Components

**AssetPreloadService** (`src/Server/Services/AssetPreloadService.lua`):
- Extracts all asset IDs from configuration files (`pets.lua`)
- Loads models via `InsertService:LoadAsset()` and places them in organized folder structure
- Creates hierarchy: `ReplicatedStorage.Assets.Models.Pets.{PetType}.{Variant}`
- Handles failures gracefully with detailed logging

### Client-Side Integration

**EggPetPreviewService** (`src/Shared/Services/EggPetPreviewService.lua`):
- First attempts to get models from `ReplicatedStorage.Assets.Models.Pets.{petType}.{variant}`
- Falls back to runtime `InsertService:LoadAsset()` if model not found in assets
- Maintains same 3D model display functionality with ViewportFrame

## Asset Flow

```
Server Startup
├── AssetPreloadService:Start()
├── Create ReplicatedStorage.Assets.Models.Pets folder structure
├── Extract asset IDs from pets.lua configuration
├── Load each model via InsertService:LoadAsset()
└── Place models in organized folders: Assets.Models.Pets.{PetType}.{Variant}

Client Request (Instant Access)
├── EggPetPreviewService:Load3DPetModel()
├── Check ReplicatedStorage.Assets.Models.Pets.{petType}.{variant}
├── If found: Clone model instantly (no network call)
└── If not found: Fallback to runtime InsertService:LoadAsset()
```

## Folder Structure

The system creates this organized structure in ReplicatedStorage:

```
ReplicatedStorage/
└── Assets/
    └── Models/
        └── Pets/
            ├── bear/
            │   ├── basic (Model)
            │   ├── golden (Model)
            │   └── rainbow (Model)
            ├── bunny/
            │   ├── basic (Model)
            │   ├── golden (Model)
            │   └── rainbow (Model)
            └── dragon/
                ├── basic (Model)
                ├── golden (Model)
                └── rainbow (Model)
```

## Configuration Integration

The system automatically extracts asset IDs from:

**Pet Assets** (`configs/pets.lua`):
```lua
pets = {
    bear = {
        variants = {
            basic = {
                asset_id = "rbxassetid://95584496209726",
                -- ...
            },
            golden = {
                asset_id = "rbxassetid://97337398672225", 
                -- ...
            }
        }
    }
}
```

**Egg Model Assets** (`configs/pets.lua`):
```lua
egg_sources = {
    basic_egg = {
        egg_model_asset_id = "rbxassetid://77451518796778",
        icon_asset_id = "rbxassetid://77451518796778",
        -- ...
    }
}
```

## API Reference

### AssetPreloadService

#### Methods

- `AssetPreloadService:GetModelFromAssets(petType, variant)` - Get a cloned model from ReplicatedStorage.Assets
- `AssetPreloadService:IsModelInAssets(petType, variant)` - Check if model is available
- `AssetPreloadService:GetLoadingStats()` - Get statistics about loaded models

#### Client Direct Access

- `ReplicatedStorage.Assets.Models.Pets.{petType}.{variant}:Clone()` - Direct model access from client

### EggPetPreviewService  

#### Enhanced Methods

- `EggPetPreviewService:Load3DPetModel(assetId, viewport, camera, petType, variant)` - Now uses ReplicatedStorage.Assets first

## Performance Benefits

1. **Instant UI Display**: Models load instantly from ReplicatedStorage with no network delay
2. **Zero Network Calls**: Direct folder access eliminates all runtime network requests
3. **Perfect Reliability**: Models in ReplicatedStorage can't fail due to network issues
4. **Simple Architecture**: No RemoteFunction complexity - just direct folder access
5. **Graceful Degradation**: Runtime fallback maintains functionality if models aren't preloaded

## Logging & Debugging

The system provides detailed logging at multiple levels:

- **Startup**: Asset extraction, preloading progress, cache statistics
- **Runtime**: Cache hits/misses, fallback usage, performance metrics  
- **Errors**: Asset loading failures, invalid asset IDs, network issues

Example logs:
```
[INFO] AssetPreloadService: Extracted asset IDs for preloading {"totalAssets": 25}
[INFO] AssetPreloadService: ContentProvider preload completed {"assetCount": 25, "duration": 2.3}
[INFO] AssetPreloadService: Model caching completed {"successful": 23, "failed": 2, "total": 25}
[DEBUG] EggPetPreviewService: Got model from server cache {"assetId": "95584496209726", "modelName": "Bear"}
```

## Error Handling

The system handles various failure scenarios:

1. **Invalid Asset IDs**: Skipped during extraction with warnings
2. **ContentProvider Failures**: Continues with individual loading  
3. **InsertService Failures**: Logged and excluded from cache
4. **Network Issues**: Client falls back to runtime loading
5. **Cache Misses**: Automatic fallback to original loading method

## Future Enhancements

- **Static Model Fallback**: Use `/assets/Models/` for critical assets
- **Configurable Debug Logging**: Turn on/off detailed logging per service
- **Asset Validation**: Pre-flight checks for asset availability
- **Cache Warming**: Periodic refresh of cached assets