--- Client-side network message handlers.
-- @module Client.NetHandlers

local DataStore = Mods.InventoryExpanded.DataStore

--- Receive full inventory from server.
Ext.RegisterNetListener("InvRework_FullInventory", function(channel, payload)
    local ok, items = pcall(Ext.Json.Parse, payload)
    if ok and items then
        DataStore.LoadFullInventory(items)
        _P("[InventoryExpanded] Inventory loaded: " .. DataStore.GetItemCount() .. " items")

        -- Notify UI to refresh
        if Mods.InventoryExpanded.InventoryUI then
            pcall(Mods.InventoryExpanded.InventoryUI.RefreshTable)
        end
        if Mods.InventoryExpanded.ArmoryUI then
            pcall(Mods.InventoryExpanded.ArmoryUI.OnDataUpdated)
        end
        if Mods.InventoryExpanded.InventoryPanelVM then
            pcall(Mods.InventoryExpanded.InventoryPanelVM.OnDataUpdated)
        end
        if Mods.InventoryExpanded.ArmoryPanelVM then
            pcall(Mods.InventoryExpanded.ArmoryPanelVM.OnDataUpdated)
        end
    else
        _P("[InventoryExpanded] Failed to parse inventory data")
    end
end)

--- Receive action result from server.
Ext.RegisterNetListener("InvRework_ActionResult", function(channel, payload)
    local ok, result = pcall(Ext.Json.Parse, payload)
    if ok and result then
        if result.success then
            _P("[InventoryExpanded] Action OK: " .. (result.message or ""))
        else
            _P("[InventoryExpanded] Action failed: " .. (result.message or "unknown error"))
        end
    end
end)

--- Request a full inventory refresh from server.
function Mods.InventoryExpanded.RequestRefresh()
    Ext.ClientNet.PostMessageToServer("InvRework_RequestRefresh", "")
end

--- Request moving an item to a character.
function Mods.InventoryExpanded.RequestMoveItem(itemUUID, targetCharUUID)
    Ext.ClientNet.PostMessageToServer("InvRework_MoveItem",
        Ext.Json.Stringify({ itemUUID = itemUUID, targetCharUUID = targetCharUUID }))
end

--- Request equipping an item on a character.
function Mods.InventoryExpanded.RequestEquipItem(itemUUID, targetCharUUID)
    Ext.ClientNet.PostMessageToServer("InvRework_EquipItem",
        Ext.Json.Stringify({ itemUUID = itemUUID, targetCharUUID = targetCharUUID }))
end
