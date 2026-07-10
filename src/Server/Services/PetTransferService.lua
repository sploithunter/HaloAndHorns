-- Moves an already-owned pet record between owners without passing through the
-- mint path. The returned receipt makes an in-progress multi-asset trade reversible.

local PetTransferService = {}
PetTransferService.__index = PetTransferService

function PetTransferService:Init()
    self._inventoryService = self._modules and self._modules.InventoryService
end

function PetTransferService:GrantRecord(player, recordKey, record, opts)
    if not self._inventoryService then
        return nil, "service_unavailable"
    end
    return self._inventoryService:InsertRecordSnapshot(player, "pets", recordKey, record, opts)
end

function PetTransferService:RevokeGrant(receipt, opts)
    if not self._inventoryService then
        return false
    end
    return self._inventoryService:RollbackRecordInsert(receipt, opts)
end

return PetTransferService
