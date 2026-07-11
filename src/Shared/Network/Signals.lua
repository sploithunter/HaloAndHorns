local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wally packages are placed in ReplicatedStorage.Packages by our Rojo project file
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Net = require(Packages:WaitForChild("Net"))
local NetworkManifest = require(script.Parent.NetworkManifest)
local SignalRegistry = require(script.Parent.SignalRegistry)
local networkConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("network"))

local manifestOk, manifestError = NetworkManifest.validate(networkConfig)
assert(manifestOk, "Invalid network manifest: " .. tostring(manifestError))

-- Central registry of RemoteEvents used by client/server
local Signals = SignalRegistry.build(networkConfig, Net)

-- Legacy declarations migrate into configs/network.lua in small compatibility slices.
local legacySignals = {
    -- Legacy-bridge replacements
    ShopItems = Net:RemoteEvent("ShopItems"), -- s->c
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
    Hotbar_Activate = Net:RemoteEvent("Hotbar_Activate"), -- c->s fire the bind on a hotbar slot (1-20)
    Hotbar_Rebind = Net:RemoteEvent("Hotbar_Rebind"), -- c->s assign/clear a hotbar slot's bind
    Hotbar_RequestState = Net:RemoteEvent("Hotbar_RequestState"), -- c->s ask for the player's hotbar
    TutorialState = Net:RemoteEvent("TutorialState"), -- s->c current tutorial step view (TutorialFlow.stateFor)
    Admin_RequestHatchHistory = Net:RemoteEvent("Admin_RequestHatchHistory"), -- c->s recent hatch debug snapshot
    Admin_RequestHatchSimulation = Net:RemoteEvent("Admin_RequestHatchSimulation"), -- c->s no-mutation hatch odds/cost preview
    Admin_EventCommand = Net:RemoteEvent("Admin_EventCommand"), -- c->s admin global event command

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
    InventoryUpdate = Net:RemoteEvent("InventoryUpdate"), -- s->c inventory changed
    ConsumeItem = Net:RemoteEvent("ConsumeItem"), -- c->s consume consumable

    -- Breakables
    Breakables_Attack = Net:RemoteEvent("Breakables_Attack"), -- c->s attack a crystal by BreakableID

    -- Zones / progression
    RealmTravelConfirm = Net:RemoteEvent("RealmTravelConfirm"), -- c->s (player chose Yes -> travel)

    -- Phase 3 stats-derived features
    LeaderboardSnapshotRequest = Net:RemoteEvent("LeaderboardSnapshotRequest"), -- c->s
}

for name, remote in pairs(legacySignals) do
    assert(Signals[name] == nil, "Duplicate network packet declaration: " .. name)
    Signals[name] = remote
end

return Signals
