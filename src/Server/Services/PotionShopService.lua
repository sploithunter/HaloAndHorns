--[[
    PotionShopService — server-authoritative buy/sell boundary for the authored
    Home/Heaven/Hell potion tents.

    The map models are presentation hooks only. This service discovers the configured
    model names, attaches one prompt to each banner, grants short-lived proximity access,
    and performs transactional gem/inventory mutations through the existing economy and
    inventory services.

    Bus:
      potion.shop.catalog {}                         -> offers + owned counts + balance
      potion.shop.buy    { potionId, quantity }     -> debit, grant, refund on failure
      potion.shop.sell   { potionId, quantity }     -> remove + credit atomically
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PotionDescribe = require(ReplicatedStorage.Shared.Game.PotionDescribe)
local PotionShopLogic = require(ReplicatedStorage.Shared.Game.PotionShopLogic)
local ShopPurchaseTransaction = require(ReplicatedStorage.Shared.Game.ShopPurchaseTransaction)
local Signals = require(ReplicatedStorage.Shared.Network.Signals)

local BUCKET = "potions"
local PROMPT_NAME = "PotionShopPrompt"
local ANCHOR_NAME = "PotionShopPromptAnchor"

local PotionShopService = {}
PotionShopService.__index = PotionShopService

function PotionShopService:Init()
    self._logger = self._modules and self._modules.Logger
    self._configLoader = self._modules and self._modules.ConfigLoader
    self._dataService = self._modules and self._modules.DataService
    self._economyService = self._modules and self._modules.EconomyService
    self._inventoryService = self._modules and self._modules.InventoryService
    self._potionService = self._modules and self._modules.PotionService
    self._config = self._configLoader:LoadConfig("potions")
    self._access = setmetatable({}, { __mode = "k" })
    self._bound = setmetatable({}, { __mode = "k" })

    self._modelNames = {}
    for _, name in ipairs(((self._config.shop or {}).interaction or {}).model_names or {}) do
        self._modelNames[name] = true
    end
end

function PotionShopService:_shop()
    return self._config and self._config.shop
end

function PotionShopService:_interaction()
    return (self:_shop() and self:_shop().interaction) or {}
end

function PotionShopService:_isShopModel(instance)
    return instance
        and instance:IsA("Model")
        and self._modelNames[instance.Name] == true
        and instance:IsDescendantOf(Workspace)
end

function PotionShopService:_promptPart(model)
    local partName = self:_interaction().prompt_part_name
    local named = partName and model:FindFirstChild(partName, true)
    if named and named:IsA("BasePart") then
        return named
    end
    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

function PotionShopService:_bindModel(model)
    if self._bound[model] or not self:_isShopModel(model) then
        return
    end
    local part = self:_promptPart(model)
    if not part then
        self._logger:Warn("Potion shop model has no prompt part", { model = model:GetFullName() })
        return
    end
    self._bound[model] = true

    local interaction = self:_interaction()
    local anchor = part:FindFirstChild(ANCHOR_NAME)
    if anchor and not anchor:IsA("Attachment") then
        anchor:Destroy()
        anchor = nil
    end
    if not anchor then
        anchor = Instance.new("Attachment")
        anchor.Name = ANCHOR_NAME
        anchor.Parent = part
    end
    local offset = interaction.prompt_offset
    anchor.Position = Vector3.new(
        tonumber(offset and (offset.x or offset.X or offset[1])) or 0,
        tonumber(offset and (offset.y or offset.Y or offset[2])) or -4,
        tonumber(offset and (offset.z or offset.Z or offset[3])) or 0
    )

    local prompt = anchor:FindFirstChild(PROMPT_NAME)
    if prompt and not prompt:IsA("ProximityPrompt") then
        prompt:Destroy()
        prompt = nil
    end
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.Name = PROMPT_NAME
        prompt.Parent = anchor
    end

    prompt.ActionText = interaction.action_text or "Browse Potions"
    prompt.ObjectText = interaction.object_text or "Potion Shop"
    prompt.KeyboardKeyCode = Enum.KeyCode[interaction.key or "E"] or Enum.KeyCode.E
    prompt.MaxActivationDistance = tonumber(interaction.max_distance) or 14
    prompt.HoldDuration = tonumber(interaction.hold_duration) or 0
    prompt.RequiresLineOfSight = interaction.requires_line_of_sight == true
    prompt.Enabled = true
    prompt.Triggered:Connect(function(player)
        self:_openFor(player, model)
    end)
end

function PotionShopService:_openFor(player, model)
    if not (player and self:_isShopModel(model)) then
        return
    end
    self._access[player] = {
        model = model,
        expiresAt = os.clock() + (tonumber(self:_interaction().access_seconds) or 120),
    }
    Signals.PotionShopOpened:FireClient(player, {
        displayName = self:_interaction().object_text or "Potion Shop",
        modelName = model.Name,
    })
end

function PotionShopService:_hasAccess(player)
    local access = self._access[player]
    if not access or os.clock() > access.expiresAt or not self:_isShopModel(access.model) then
        self._access[player] = nil
        return false
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local part = self:_promptPart(access.model)
    if not (root and part) then
        return false
    end
    local allowed = (tonumber(self:_interaction().max_distance) or 14)
        + (tonumber(self:_interaction().distance_grace) or 8)
    if (root.Position - part.Position).Magnitude > allowed then
        return false
    end
    access.expiresAt = os.clock() + (tonumber(self:_interaction().access_seconds) or 120)
    return true
end

function PotionShopService:_owned(player)
    local inventory = self._inventoryService:GetInventory(player, BUCKET)
    local counts = {}
    for _, item in pairs((inventory and inventory.items) or {}) do
        if item.id then
            counts[item.id] = (counts[item.id] or 0)
                + math.max(0, math.floor(tonumber(item.quantity) or 1))
        end
    end
    return counts
end

function PotionShopService:Catalog(player)
    if not self:_hasAccess(player) then
        return { ok = false, reason = "shop_out_of_range" }
    end

    local catalog = PotionShopLogic.catalog(self._config, self:_owned(player))
    if not catalog.ok then
        return catalog
    end
    catalog.balance = self._economyService:GetCurrency(player, catalog.currency)

    for _, offer in ipairs(catalog.offers) do
        local description = PotionDescribe.describe(self._config, offer.id)
        local meter = self._config.meters and self._config.meters[offer.meter]
        offer.type = description and description.type or "Potion"
        offer.summary = description and description.summary or ""
        offer.details = description and description.lines or {}
        offer.badge = meter and meter.badge or nil
    end
    return catalog
end

function PotionShopService:Buy(player, args)
    if not self:_hasAccess(player) then
        return { ok = false, reason = "shop_out_of_range" }
    end
    args = args or {}
    local settings = PotionShopLogic.settings(self._config)
    local currency = settings and settings.currency or "gems"
    local balance = self._economyService:GetCurrency(player, currency)
    local quote = PotionShopLogic.buyQuote(self._config, args.potionId, balance, args.quantity)
    if not quote.ok then
        return quote
    end

    local reason = ("potion_shop_buy:%s"):format(args.potionId)
    local transaction = ShopPurchaseTransaction.execute({
        costs = { [currency] = quote.total },
        debit = function(kind, amount)
            return self._economyService:RemoveCurrency(player, kind, amount, reason)
        end,
        grant = function()
            return self._potionService:Grant(player, args.potionId, quote.quantity)
        end,
        refund = function(kind, amount)
            return self._economyService:AddCurrency(player, kind, amount, reason .. ":refund")
        end,
    })
    if not transaction.ok then
        return transaction
    end

    self._dataService:RequestSave(player, "potion_shop_buy", { critical = true })
    return {
        ok = true,
        potionId = args.potionId,
        bought = quote.quantity,
        unit = quote.unit,
        gems = quote.total,
        owned = self._potionService:Count(player, args.potionId),
        balance = self._economyService:GetCurrency(player, currency),
    }
end

function PotionShopService:_stack(player, potionId)
    local inventory = self._inventoryService:GetInventory(player, BUCKET)
    for uid, item in pairs((inventory and inventory.items) or {}) do
        if item.id == potionId then
            return uid, math.max(0, math.floor(tonumber(item.quantity) or 1))
        end
    end
    return nil, 0
end

function PotionShopService:Sell(player, args)
    if not self:_hasAccess(player) then
        return { ok = false, reason = "shop_out_of_range" }
    end
    args = args or {}
    local uid, owned = self:_stack(player, args.potionId)
    local quote = PotionShopLogic.sellQuote(self._config, args.potionId, owned, args.quantity)
    if not quote.ok then
        return quote
    end

    local settings = PotionShopLogic.settings(self._config)
    local currency = settings.currency
    local reason = ("potion_shop_sell:%s"):format(args.potionId)
    local ok, removed, _, failureReason = self._inventoryService:BulkRemove(
        player,
        BUCKET,
        { { uid = uid, quantity = quote.quantity } },
        {
            commit = function()
                return self._economyService:AddCurrency(player, currency, quote.total, reason)
            end,
            saveTag = "potion_shop_sell",
        }
    )
    if not (ok and removed and removed[uid] == quote.quantity) then
        return {
            ok = false,
            reason = failureReason == "commit_failed" and "credit_failed_items_restored"
                or "remove_failed",
        }
    end

    self._potionService:Refresh(player)
    return {
        ok = true,
        potionId = args.potionId,
        sold = quote.quantity,
        unit = quote.unit,
        gems = quote.total,
        owned = owned - quote.quantity,
        balance = self._economyService:GetCurrency(player, currency),
    }
end

function PotionShopService:Start()
    local shop = self:_shop()
    if not (shop and shop.enabled ~= false) then
        return
    end
    for _, instance in ipairs(Workspace:GetDescendants()) do
        if self:_isShopModel(instance) then
            self:_bindModel(instance)
        end
    end
    Workspace.DescendantAdded:Connect(function(instance)
        if self:_isShopModel(instance) then
            task.defer(function()
                self:_bindModel(instance)
            end)
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        self._access[player] = nil
    end)
end

return PotionShopService
