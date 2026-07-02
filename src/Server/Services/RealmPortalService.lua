--[[
    RealmPortalService — in-world entry to the heaven/hell realms (World S3, test slice).

    Binds a ProximityPrompt to named workspace parts (configs/layers.lua `realm_portals`, e.g.
    Portal_Halo1 -> heaven_1, Portal_Horn1 -> hell_1). Triggering TOGGLES the player between base
    and that realm via LayerService:UseLayer. `bypass_access` (config) forces the entry so the
    realm is reachable for testing before the soul/level/token economy is grindable.

    This reuses the SAME map — the RealmAtmosphere client skin retints the world (heaven = gold,
    hell = ember) on the published CurrentRealm attribute. Not the production realm-geometry path
    (task #157); a convenient solo-test entry. Mirrors AscensionAltarService's prompt setup.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local PROMPT_NAME = "RealmPortalPrompt"
local TOUCH_DEBOUNCE = 3 -- seconds between offers per player (walking the arch shouldn't spam)
local OFFER_TTL = 20 -- a confirm must arrive within this many seconds of the offer

local RealmPortalService = {}
RealmPortalService.__index = RealmPortalService

function RealmPortalService.new()
    local self = setmetatable({}, RealmPortalService)
    self._logger = nil
    self._configLoader = nil
    self._portalsConfig = nil
    self._touchAt = {} -- [userId] = os.clock() of last offer (debounce)
    self._pending = {} -- [userId] = { layer, expires } (the offer awaiting a confirm)
    return self
end

function RealmPortalService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    local ok, layers = pcall(function()
        return self._configLoader:LoadConfig("layers")
    end)
    self._layersConfig = (ok and type(layers) == "table") and layers or {}
    self._portalsConfig = self._layersConfig.realm_portals or {}
end

function RealmPortalService:_layerService()
    local locator = _G.RBXTemplateServices
    if not locator then
        return nil
    end
    local ok, svc = pcall(function()
        return locator:Get("LayerService")
    end)
    return ok and svc or nil
end

function RealmPortalService:_adminService()
    local locator = _G.RBXTemplateServices
    if not locator then
        return nil
    end
    local ok, svc = pcall(function()
        return locator:Get("AdminService")
    end)
    return ok and svc or nil
end

function RealmPortalService:_isAdmin(player)
    local admin = self:_adminService()
    return (admin and admin:IsAuthorized(player)) and true or false
end

-- The Maps/<World> folder name for a layer id: "heaven_1" -> "Heaven_1", "base" -> "Home".
local function layerFolderName(layerId)
    if layerId == "base" then
        return "Home"
    end
    local realm, n = tostring(layerId):match("^(%a+)_(%d+)$")
    if realm then
        return realm:sub(1, 1):upper() .. realm:sub(2) .. "_" .. n
    end
    return layerId
end

-- Player-facing name for a portal label: "heaven_1" -> "Heaven 1".
local function layerDisplayName(layerId)
    local realm, n = tostring(layerId):match("^(%a+)_(%d+)$")
    if realm then
        return realm:sub(1, 1):upper() .. realm:sub(2) .. " " .. n
    end
    return tostring(layerId)
end

-- A layer is enterable only if its geometry exists, else the player falls into the void. The
-- stacked worlds are authored incrementally, so most layers have no folder yet.
function RealmPortalService:_layerHasGeometry(layerId)
    local maps = Workspace:FindFirstChild("Maps")
    return (maps and maps:FindFirstChild(layerFolderName(layerId))) and true or false
end

-- Resolve a named workspace instance to a BasePart to host the prompt (Model -> primary/first part).
local function resolvePart(inst)
    if not inst then
        return nil
    end
    if inst:IsA("BasePart") then
        return inst
    end
    if inst:IsA("Model") then
        return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

-- LEVEL GATE (Jason): realm travel requires the target layer's `requires_level`, even though
-- `bypass_access` still skips the soul/token economy (not grind-ready yet). Heaven/Hell 1 = Lv 7,
-- 2 = 14, … (+7 per layer, configs/layers.lua access). Returns ok, required. base / unset layers are
-- always allowed; reads the published Level attribute. NOTE: no admin bypass — Jason wants the gate
-- enforced for everyone (the realms were open only because bypass_access skipped this entirely).
function RealmPortalService:_levelGate(player, target)
    if not target or target == "base" then
        return true, 0
    end
    local access = self._layersConfig.access and self._layersConfig.access[target]
    local required = access and tonumber(access.requires_level)
    if not required or required <= 1 then
        return true, 0
    end
    local level = tonumber(player:GetAttribute("Level")) or 1
    return level >= required, required
end

-- Direct jump: enter this portal's exact layer; if already standing on it, return to base.
-- (Per-layer toggle lets you hop base -> Halo3 -> Halo5 to test any depth, and step out anywhere.)
function RealmPortalService:_onTriggered(player, destLayer)
    if self._portalsConfig.locked == true then
        -- admin_unlock: admins may pass the lock to TEST realms; everyone else stays blocked.
        if not (self._portalsConfig.admin_unlock == true and self:_isAdmin(player)) then
            return
        end
    end
    local layers = self:_layerService()
    if not layers then
        return
    end
    local current = layers:GetCurrentLayer(player)
    local target = (current == destLayer) and "base" or destLayer
    -- Never teleport INTO a layer whose geometry isn't built yet (a void fall). base is always safe.
    if target ~= "base" and not self:_layerHasGeometry(target) then
        if self._logger then
            self._logger:Info("Realm portal blocked: layer has no geometry", { layer = target })
        end
        return
    end
    -- LEVEL GATE: enforced even though bypass_access skips the soul/token economy.
    local lvlOk, requiredLevel = self:_levelGate(player, target)
    if not lvlOk then
        if self._logger then
            self._logger:Info(
                "Realm portal blocked: level too low",
                { layer = target, required = requiredLevel }
            )
        end
        return
    end
    local force = self._portalsConfig.bypass_access ~= false
    layers:UseLayer(player, target, { force = force })
end

-- TOUCH system (replaces the press-E ProximityPrompt): a portal whose realm is BUILT is "open" —
-- touching any of its surfaces sends the player a yes/no travel offer. A portal whose realm has no
-- geometry yet keeps the "COMING SOON" badge and does nothing on touch.
function RealmPortalService:_ensureTouch(part, def)
    -- retire any legacy ProximityPrompt left on the part — touch is the trigger now.
    local oldPrompt = part:FindFirstChild(PROMPT_NAME)
    if oldPrompt then
        oldPrompt:Destroy()
    end

    if not self:_layerHasGeometry(def.layer) then
        self:_addLockBadge(part) -- realm not built yet → "COMING SOON", no travel
        return
    end
    -- OPEN portal (realm built): swap the lock for a "Heaven 1 · Lv 7" info label, so the destination
    -- and its level gate read at a glance even before touching (Jason: "if they're unlocked we should
    -- still have a label"). The touch path still enforces the level for a too-low player.
    self:_clearLockBadge(part)
    local access = self._layersConfig.access and self._layersConfig.access[def.layer]
    local req = access and tonumber(access.requires_level)
    -- "Heaven 1\nLv 7" — level on its OWN line under the name so it never wraps mid-word (Jason).
    local label = layerDisplayName(def.layer)
    if req and req > 1 then
        label = label .. "\nLv " .. req
    end
    local tint = tostring(def.layer):match("^hell") and Color3.fromRGB(255, 150, 100)
        or Color3.fromRGB(255, 235, 150)
    self:_addLockBadge(part, label, false, tint)

    -- Bind Touched on every BasePart of the portal model so touching the surface anywhere offers
    -- travel. Server-side touch = no client trust; the per-player debounce keeps it from spamming.
    local model = part:FindFirstAncestorOfClass("Model")
    local parts = {}
    if model then
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") then
                table.insert(parts, d)
            end
        end
    else
        parts = { part }
    end
    for _, p in ipairs(parts) do
        if not p:GetAttribute("RealmPortalTouchBound") then
            p:SetAttribute("RealmPortalTouchBound", true)
            p.CanTouch = true -- anchored decor sometimes ships with CanTouch off → Touched never fires
            p.Touched:Connect(function(hit)
                self:_onTouched(hit, def)
            end)
        end
    end
end

-- A character part touched a portal surface → offer travel (debounced per player).
function RealmPortalService:_onTouched(hit, def)
    local char = hit and hit.Parent
    local player = char and Players:GetPlayerFromCharacter(char)
    if not player then
        return
    end
    local now = os.clock()
    local last = self._touchAt[player.UserId]
    if last and (now - last) < TOUCH_DEBOUNCE then
        return
    end
    self._touchAt[player.UserId] = now
    self:_offerTravel(player, def)
end

-- Send the client a yes/no travel offer. Records the pending offer so a spoofed confirm can't
-- teleport without a real touch. Mirrors _onTriggered's base<->realm toggle for the label.
function RealmPortalService:_offerTravel(player, def)
    local layers = self:_layerService()
    if not layers then
        return
    end
    local current = layers:GetCurrentLayer(player)
    local target = (current == def.layer) and "base" or def.layer
    if target ~= "base" and not self:_layerHasGeometry(target) then
        return
    end
    -- LEVEL GATE: too-low players get a denial offer (no Travel button) naming the requirement, instead
    -- of a Yes/No they'd be blocked on at confirm. (Stage 2 adds the same Lv on the portal face.)
    local lvlOk, requiredLevel = self:_levelGate(player, target)
    local label
    if target ~= "base" and not lvlOk then
        label = ("🔒 Reach Level %d to enter %s"):format(
            requiredLevel,
            ((def.action and def.action:gsub("^Enter ", "")) or "this realm")
        )
        Signals.RealmTravelOffer:FireClient(
            player,
            { layer = def.layer, label = label, locked = true }
        )
        return
    end
    if target == "base" then
        label = "Return to Home?"
    else
        label = "Travel to "
            .. ((def.action and def.action:gsub("^Enter ", "")) or "the realm")
            .. "?"
    end
    self._pending[player.UserId] = { layer = def.layer, expires = os.clock() + OFFER_TTL }
    Signals.RealmTravelOffer:FireClient(player, { layer = def.layer, label = label })
end

-- Client chose Yes. Honor it only if it matches a live offer we sent (anti-spoof), then travel.
function RealmPortalService:_onConfirm(player, payload)
    local layer = type(payload) == "table" and payload.layer
    local pend = self._pending[player.UserId]
    if not (pend and layer == pend.layer and os.clock() <= pend.expires) then
        return
    end
    self._pending[player.UserId] = nil
    self:_onTriggered(player, layer)
end

-- A big lock ON THE PORTAL FACE of a locked gate (programmatic — no 3D asset).
-- SurfaceGuis (front + back), not a billboard: the gates stand back-to-back in
-- Halo/Horn pairs 3 studs apart, and an AlwaysOnTop billboard showed the FAR
-- gate's lock bleeding through the near one (Jason: "two sides to the gate so you
-- get to see both locks"). Surface rendering occludes naturally — one lock per
-- viewing side. Removed when the config unlocks.
-- The lock belongs on the big glowing face, not the foot/frame chunk the prompt sat on. Pick the
-- model's largest part and the two faces perpendicular to its thinnest axis (the flat oval plane).
function RealmPortalService:_badgeHostAndFaces(part)
    local host = part
    local model = part:FindFirstAncestorOfClass("Model")
    if model then
        local bestArea = 0
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") then
                local sz = d.Size
                local area = math.max(sz.X * sz.Y, sz.X * sz.Z, sz.Y * sz.Z)
                if area > bestArea then
                    bestArea = area
                    host = d
                end
            end
        end
    end
    local sz = host.Size
    local faceA, faceB
    if sz.Z <= sz.X and sz.Z <= sz.Y then
        faceA, faceB = Enum.NormalId.Front, Enum.NormalId.Back
    elseif sz.X <= sz.Y and sz.X <= sz.Z then
        faceA, faceB = Enum.NormalId.Left, Enum.NormalId.Right
    else
        faceA, faceB = Enum.NormalId.Top, Enum.NormalId.Bottom
    end
    return host, faceA, faceB
end

local BADGE_NAMES = { "RealmLockBadgeFront", "RealmLockBadgeBack", "RealmLockBadge" }

-- Drop the "COMING SOON" badge — the realm is built, the gate is open.
function RealmPortalService:_clearLockBadge(part)
    local host = self:_badgeHostAndFaces(part)
    for _, holder in ipairs({ part, host }) do
        for _, n in ipairs(BADGE_NAMES) do
            local g = holder:FindFirstChild(n)
            if g then
                g:Destroy()
            end
        end
    end
end

-- Stamp a portal-face badge. Front+back SurfaceGuis (the gates stand back-to-back in Halo/Horn
-- pairs, so a billboard bled through — surface rendering occludes cleanly).
--   captionText  the label under the icon (default "COMING SOON")
--   showLock     true → 🔒 over the caption (realm not built / hard-locked); false → caption only,
--                centered + larger (an OPEN portal's "REALM · Lv N" info label, per Jason)
--   tint         caption color (default gold)
function RealmPortalService:_addLockBadge(part, captionText, showLock, tint)
    captionText = captionText or "COMING SOON"
    if showLock == nil then
        showLock = true
    end
    tint = tint or Color3.fromRGB(255, 215, 0)
    local host, faceA, faceB = self:_badgeHostAndFaces(part)
    local function makeFace(face, name)
        if host:FindFirstChild(name) then
            return
        end
        local gui = Instance.new("SurfaceGui")
        gui.Name = name
        gui.Face = face
        gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        gui.PixelsPerStud = 24
        gui.LightInfluence = 0
        gui.Parent = host
        if showLock then
            local lock = Instance.new("TextLabel")
            lock.Size = UDim2.fromScale(0.62, 0.62)
            lock.AnchorPoint = Vector2.new(0.5, 0.5)
            lock.Position = UDim2.fromScale(0.5, 0.45)
            lock.BackgroundTransparency = 1
            lock.Text = "🔒"
            lock.TextScaled = true
            lock.Font = Enum.Font.GothamBlack
            lock.TextColor3 = Color3.fromRGB(255, 255, 255)
            lock.TextStrokeTransparency = 0.2
            lock.Parent = gui
        end
        local caption = Instance.new("TextLabel")
        -- narrow + high enough to fit INSIDE the visible oval (the glow plane runs
        -- behind the dark frame, which cropped a 0.9-wide caption to "OMING SOO"). With no lock the
        -- caption owns the whole face, so center it and let it run taller.
        caption.Size = showLock and UDim2.fromScale(0.52, 0.1) or UDim2.fromScale(0.62, 0.34)
        caption.AnchorPoint = showLock and Vector2.new(0.5, 0) or Vector2.new(0.5, 0.5)
        caption.Position = showLock and UDim2.fromScale(0.5, 0.66) or UDim2.fromScale(0.5, 0.5)
        caption.BackgroundTransparency = 1
        caption.Text = captionText
        caption.TextScaled = true
        caption.Font = Enum.Font.GothamBlack
        caption.TextColor3 = tint
        caption.TextStrokeTransparency = 0.1
        caption.Parent = gui
    end
    makeFace(faceA, "RealmLockBadgeFront")
    makeFace(faceB, "RealmLockBadgeBack")
end

-- World S3: LoadAsset the Hell-face model once into ReplicatedStorage.RealmModels so the client
-- RealmHellFaces system can clone it (runtime-created, so rojo never prunes it; works on published
-- servers too). No-op if disabled / already loaded / load fails.
function RealmPortalService:_preloadHellFace()
    local cfg = self._layersConfig.hell_faces
    if not cfg or cfg.enabled == false or not cfg.model_asset_id then
        return
    end
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local folder = ReplicatedStorage:FindFirstChild("RealmModels")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "RealmModels"
        folder.Parent = ReplicatedStorage
    end
    local name = cfg.template_name or "HellFace"
    if folder:FindFirstChild(name) then
        return
    end
    local InsertService = game:GetService("InsertService")

    local AssetFetch = require(ReplicatedStorage.Shared.Utils.AssetFetch)
    local ok, container = pcall(function()
        return AssetFetch.load(cfg.model_asset_id)
    end)
    if not ok or not container then
        if self._logger then
            self._logger:Warn("RealmHellFaces: LoadAsset failed", { error = tostring(container) })
        end
        return
    end
    local model = container:GetChildren()[1]
    if model then
        model.Name = name
        -- Anchor the model AND every descendant. NB: when the asset is a single MeshPart,
        -- GetDescendants() does NOT include the part itself — so we must anchor `model` directly,
        -- or the cached template ships unanchored and every spawned head gets physics-flung.
        local function lockPart(p)
            p.Anchored, p.CanCollide, p.CanQuery, p.CastShadow = true, false, false, false
        end
        if model:IsA("BasePart") then
            lockPart(model)
        end
        for _, p in ipairs(model:GetDescendants()) do
            if p:IsA("BasePart") then
                lockPart(p)
            end
        end
        if model:IsA("Model") and not model.PrimaryPart then
            model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
        end
        model.Parent = folder
        if self._logger then
            self._logger:Info(
                "RealmHellFaces: cached model in ReplicatedStorage.RealmModels",
                { name = name }
            )
        end
    end
    container:Destroy()
end

function RealmPortalService:Start()
    self:_preloadHellFace()

    -- Yes/No travel confirmations come back here (anti-spoof checked against the pending offer).
    Signals.RealmTravelConfirm.OnServerEvent:Connect(function(player, payload)
        self:_onConfirm(player, payload)
    end)
    Players.PlayerRemoving:Connect(function(player)
        self._touchAt[player.UserId] = nil
        self._pending[player.UserId] = nil
    end)

    local portals = self._portalsConfig.portals or {}
    if #portals == 0 then
        return
    end
    -- Index the config portals by part name for a whole-workspace scan.
    local defByName = {}
    for _, def in ipairs(portals) do
        defByName[def.part] = def
    end
    -- Bind EVERY instance matching a portal name — each stacked world (Home, Heaven_n, Hell_n) has
    -- its own copy of the portals, so binding only the first (FindFirstChild) left the cloned worlds
    -- with no working gate. Walk all descendants; the RealmPortalBound guard keeps it idempotent.
    -- Map geometry is server-resident (streaming is client-only), so a couple of retries suffice.
    task.spawn(function()
        local totalBound = 0
        for _ = 1, 10 do
            local boundThisPass = 0
            for _, inst in ipairs(Workspace:GetDescendants()) do
                local def = defByName[inst.Name]
                if def then
                    local part = resolvePart(inst)
                    if part and not part:GetAttribute("RealmPortalBound") then
                        part:SetAttribute("RealmPortalBound", true)
                        self:_ensureTouch(part, def)
                        boundThisPass += 1
                        totalBound += 1
                        if self._logger then
                            self._logger:Info("RealmPortalService bound portal", {
                                part = inst:GetFullName(),
                                layer = def.layer,
                            })
                        end
                    end
                end
            end
            -- Done once we've bound at least one and a later pass finds nothing new to bind.
            if totalBound > 0 and boundThisPass == 0 then
                return
            end
            task.wait(2)
        end
    end)
end

return RealmPortalService
