local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wally packages are placed in ReplicatedStorage.Packages by our Rojo project file
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Net = require(Packages:WaitForChild("Net"))

-- Central registry of RemoteEvents used by client/server
local Signals = {
    -- Economy core
    PurchaseItem = Net:RemoteEvent("PurchaseItem"), -- c->s
    SellItem = Net:RemoteEvent("SellItem"), -- c->s
    PurchaseResult = Net:RemoteEvent("PurchaseResult"), -- s->c (success/fail text)
    AdjustCurrency = Net:RemoteEvent("AdjustCurrency"), -- c->s
    ConvertCurrency = Net:RemoteEvent("ConvertCurrency"), -- c->s exchange configured currencies
    CurrencyUpdate = Net:RemoteEvent("CurrencyUpdate"), -- s->c
    PurchaseUpgrade = Net:RemoteEvent("PurchaseUpgrade"), -- c->s
    UpgradeResult = Net:RemoteEvent("UpgradeResult"), -- s->c

    -- Legacy-bridge replacements
    PurchaseSuccess = Net:RemoteEvent("PurchaseSuccess"), -- s->c UI toast
    SellSuccess = Net:RemoteEvent("SellSuccess"), -- s->c
    ShopItems = Net:RemoteEvent("ShopItems"), -- s->c
    PlayerDebugInfo = Net:RemoteEvent("PlayerDebugInfo"), -- s->c
    GiveItemSuccess = Net:RemoteEvent("GiveItemSuccess"), -- s->c
    EconomyError = Net:RemoteEvent("EconomyError"), -- s->c error message
    Admin_GetPlayerSnapshot = Net:RemoteEvent("Admin_GetPlayerSnapshot"), -- c->s admin player state request
    Admin_ForceSave = Net:RemoteEvent("Admin_ForceSave"), -- c->s admin force save
    Admin_GrantPet = Net:RemoteEvent("Admin_GrantPet"), -- c->s admin grant configured pet
    Admin_RetirePet = Net:RemoteEvent("Admin_RetirePet"), -- c->s admin remove a pet record by uid
    Admin_ResetPets = Net:RemoteEvent("Admin_ResetPets"), -- c->s admin wipe a player's pet inventory + equips
    Admin_ResetToBeginning = Net:RemoteEvent("Admin_ResetToBeginning"), -- c->s admin reset profile to start (KEEP huge pets); pass {dryRun=true} to preview
    Admin_SetZoneLock = Net:RemoteEvent("Admin_SetZoneLock"), -- c->s admin lock/unlock configured zone
    Admin_SetHatchEntitlement = Net:RemoteEvent("Admin_SetHatchEntitlement"), -- c->s admin hatch unlock/testing stubs
    Admin_SpawnEnemy = Net:RemoteEvent("Admin_SpawnEnemy"), -- c->s admin spawn a test combat enemy
    Squad_Recall = Net:RemoteEvent("Squad_Recall"), -- c->s recall a squad slot's pet (short cooldown)
    Squad_Summon = Net:RemoteEvent("Squad_Summon"), -- c->s re-summon a recovered squad slot's pet
    Squad_AdminKill = Net:RemoteEvent("Squad_AdminKill"), -- c->s (admin) force-down a squad slot's pet for testing the lockout, no enemies needed
    Admin_SetArea = Net:RemoteEvent("Admin_SetArea"), -- c->s (admin) set CurrentArea/HomeArea for testing area theming + play feel
    Admin_GrantAreaPowers = Net:RemoteEvent("Admin_GrantAreaPowers"), -- c->s (admin) grant + bind the current area's full power set to the hotbar for testing
    Admin_CastPower = Net:RemoteEvent("Admin_CastPower"), -- c->s (admin power bar) cast any power { powerId, mode="min"|"max" } via the full pipeline, no grant/save
    Admin_TogglePassive = Net:RemoteEvent("Admin_TogglePassive"), -- c->s (admin power bar) transiently stamp/clear an always-on power { powerId, on, mode }
    Power_ToggleActive = Net:RemoteEvent("Power_ToggleActive"), -- c->s (player HUD toggle badge) turn an OWNED always-on power on/off { powerId, on } — drains focus_upkeep while on
    Combat_SetAssist = Net:RemoteEvent("Combat_SetAssist"), -- c->s direct the squad to focus an enemy (assist target; 0 clears)
    Combat_SelectPetTarget = Net:RemoteEvent("Combat_SelectPetTarget"), -- c->s the selected squad pet (PositionNumber) for single-target buffs; 0 clears
    Combat_PetHit = Net:RemoteEvent("Combat_PetHit"), -- s->c (owner) a pet landed a swing {pet,target,crit} -> client plays the matching FX
    Combat_Heal = Net:RemoteEvent("Combat_Heal"), -- s->c a heal landed {target,amount} -> client floats a green number
    Combat_EnemyHit = Net:RemoteEvent("Combat_EnemyHit"), -- s->c (all) an enemy swung {enemy,target,ranged,kind,crit} -> client plays the attack FX via CombatHitFX (ranged=bolt, melee=impact); damage already applied server-side
    Hotbar_Activate = Net:RemoteEvent("Hotbar_Activate"), -- c->s fire the bind on a hotbar slot (1-20)
    Hotbar_Rebind = Net:RemoteEvent("Hotbar_Rebind"), -- c->s assign/clear a hotbar slot's bind
    Power_Cooldown = Net:RemoteEvent("Power_Cooldown"), -- s->c a cast power's cooldown {power, untilTime, cooldown}
    Power_AreaFx = Net:RemoteEvent("Power_AreaFx"), -- s->c play an area power's VFX {element, variant, center, radius, pit, hits=[{pos,amount}]}
    Hotbar_RequestState = Net:RemoteEvent("Hotbar_RequestState"), -- c->s ask for the player's hotbar
    Hotbar_State = Net:RemoteEvent("Hotbar_State"), -- s->c push hotbar bindings for the command bar UI
    LevelUp_Claimed = Net:RemoteEvent("LevelUp_Claimed"), -- s->c a level was claimed {level, kind, powerPick, slots, milestone, eggHatchTotal, rewards, pendingLevels}
    LevelUp_OpenChoice = Net:RemoteEvent("LevelUp_OpenChoice"), -- s->c open the level-up menu WITHOUT claiming (altar engaged; the level claims atomically on COMMIT)
    GameEvent = Net:RemoteEvent("GameEvent"), -- s->c fire a named gameplay event (name, ctx) -> client GameEvents reactions (configs/game_events)
    TutorialState = Net:RemoteEvent("TutorialState"), -- s->c current tutorial step view (TutorialFlow.stateFor)
    Admin_RequestHatchHistory = Net:RemoteEvent("Admin_RequestHatchHistory"), -- c->s recent hatch debug snapshot
    Admin_RequestHatchSimulation = Net:RemoteEvent("Admin_RequestHatchSimulation"), -- c->s no-mutation hatch odds/cost preview
    Admin_EventCommand = Net:RemoteEvent("Admin_EventCommand"), -- c->s admin global event command
    AdminToolResult = Net:RemoteEvent("AdminToolResult"), -- s->c admin action result

    -- Effects
    ActiveEffects = Net:RemoteEvent("ActiveEffects"), -- s->c unified list

    -- Monetization
    InitiatePurchase = Net:RemoteEvent("InitiatePurchase"), -- c->s
    GetOwnedPasses = Net:RemoteEvent("GetOwnedPasses"), -- c->s
    GetProductInfo = Net:RemoteEvent("GetProductInfo"), -- c->s
    PurchaseError = Net:RemoteEvent("PurchaseError"), -- s->c
    OwnedPasses = Net:RemoteEvent("OwnedPasses"), -- s->c
    ProductInfo = Net:RemoteEvent("ProductInfo"), -- s->c
    FirstPurchaseBonus = Net:RemoteEvent("FirstPurchaseBonus"), -- s->c

    -- Diagnostics
    RunDiagnostics = Net:RemoteEvent("RunDiagnostics"), -- c->s request & s->c reply

    -- Inventory Management
    DeleteInventoryItem = Net:RemoteEvent("DeleteInventoryItem"), -- c->s delete single item
    CleanupInventory = Net:RemoteEvent("CleanupInventory"), -- c->s admin cleanup
    FixItemCategories = Net:RemoteEvent("FixItemCategories"), -- c->s admin category migration
    CleanOrphanedBuckets = Net:RemoteEvent("CleanOrphanedBuckets"), -- c->s admin orphaned bucket cleanup
    InventoryUpdate = Net:RemoteEvent("InventoryUpdate"), -- s->c inventory changed
    ConsumeItem = Net:RemoteEvent("ConsumeItem"), -- c->s consume consumable
    TogglePetEquipped = Net:RemoteEvent("TogglePetEquipped"), -- c->s equip/unequip pet
    SetEquippedPets = Net:RemoteEvent("SetEquippedPets"), -- c->s commit a draft squad (clear + set Equipped.pets)
    ToggleToolEquipped = Net:RemoteEvent("ToggleToolEquipped"), -- c->s equip/unequip tool
    EnchantPetRequest = Net:RemoteEvent("EnchantPetRequest"), -- c->s reroll/apply pet enchant
    EnchantPetResult = Net:RemoteEvent("EnchantPetResult"), -- s->c enchant action result
    EnchantStationOpened = Net:RemoteEvent("EnchantStationOpened"), -- s->c player activated map enchanter

    -- User Display Preferences
    SaveDisplayPreferences = Net:RemoteEvent("SaveDisplayPreferences"),
    ForceRegenerateAssets = Net:RemoteEvent("ForceRegenerateAssets"), -- c->s admin force asset regeneration

    -- Breakables
    Breakables_Attack = Net:RemoteEvent("Breakables_Attack"), -- c->s attack a crystal by BreakableID

    -- Zones / progression
    UnlockZoneRequest = Net:RemoteEvent("UnlockZoneRequest"), -- c->s
    ZoneUnlockResult = Net:RemoteEvent("ZoneUnlockResult"), -- s->c
    ZoneTravelResult = Net:RemoteEvent("ZoneTravelResult"), -- s->c
    RealmTravelOffer = Net:RemoteEvent("RealmTravelOffer"), -- s->c (touched a realm portal -> yes/no offer)
    RealmTravelConfirm = Net:RemoteEvent("RealmTravelConfirm"), -- c->s (player chose Yes -> travel)

    -- Phase 3 stats-derived features
    PetIndexUpdated = Net:RemoteEvent("PetIndexUpdated"), -- s->c
    AchievementCompleted = Net:RemoteEvent("AchievementCompleted"), -- s->c
    LeaderboardUpdated = Net:RemoteEvent("LeaderboardUpdated"), -- s->c
    LeaderboardSnapshotRequest = Net:RemoteEvent("LeaderboardSnapshotRequest"), -- c->s

    -- Auto-target toggles
    -- Server validates and flips Player BoolValues (FreeTarget/PaidTarget).
    -- Client UI reflects state via AutoTarget_Status and Player value listeners.
    AutoTarget_ToggleFree = Net:RemoteEvent("AutoTarget_ToggleFree"), -- c->s request toggle free (low) targeting
    AutoTarget_TogglePaid = Net:RemoteEvent("AutoTarget_TogglePaid"), -- c->s request toggle paid (high) targeting
    AutoTarget_SetMode = Net:RemoteEvent("AutoTarget_SetMode"), -- c->s persist selected target mode
    AutoTarget_RequestAttack = Net:RemoteEvent("AutoTarget_RequestAttack"), -- c->s ask server to select/attack
    AutoDelete_SetFilters = Net:RemoteEvent("AutoDelete_SetFilters"), -- c->s persist hatch auto-delete filters
    HatchSettings_SetCount = Net:RemoteEvent("HatchSettings_SetCount"), -- c->s persist selected egg hatch count
    HatchSettings_SetActionMode = Net:RemoteEvent("HatchSettings_SetActionMode"), -- c->s persist what E does near eggs
    HatchSettings_SetModes = Net:RemoteEvent("HatchSettings_SetModes"), -- c->s persist selected egg hatch modes
    Settings_SetPetFormation = Net:RemoteEvent("Settings_SetPetFormation"), -- c->s persist equipped-pet formation layout
    Settings_SetPetAttackStyle = Net:RemoteEvent("Settings_SetPetAttackStyle"), -- c->s persist pet attack/mining formation
    Settings_SetInventoryCardScale = Net:RemoteEvent("Settings_SetInventoryCardScale"), -- c->s persist inventory pet-card grid size (small/medium/large)
    Settings_SetEnemyLevelOffset = Net:RemoteEvent("Settings_SetEnemyLevelOffset"), -- c->s persist enemy spawn-level offset vs player (-3..+3 difficulty knob)
    PetReportPositions = Net:RemoteEvent("PetReportPositions"), -- c->s throttled local pet positions (mining gate + multiplayer)
    PetPositionsRelay = Net:RemoteEvent("PetPositionsRelay"), -- s->c relay OTHER players' pet positions (owner renders its own locally)
    AutoTarget_Status = Net:RemoteEvent("AutoTarget_Status"), -- s->c push current auto-target status
}

return Signals
